#!/usr/bin/env bash
# scripts/diagnostics/m018-runtime-parity.sh
#
# M018/P07/T01 — Zero-LLM compression-tier parity runner.
#
# For each fixture in tests/compression-runtime-parity/fixtures/, stage a
# hermetic orch_root under each simulated runtime (claude-code|codex|cursor),
# invoke scripts/dispatch/build-context.sh with the fixture's
# `payload-input.txt` folded into the task plan body, capture the
# post-pipeline payload, compute SHA-256 over the bytes, and assert the
# three runtimes' hashes match.
#
# Usage:
#   m018-runtime-parity.sh [--corpus-dir <path>] [--fixture <name>]
#                          [--runtimes <csv>] [--output-dir <path>]
#
# Defaults: --corpus-dir tests/compression-runtime-parity, --fixture all,
#           --runtimes claude-code,codex,cursor.
#
# Output: per (fixture, runtime) `runtime-parity` line on stdout, plus a
#         per-fixture `parity ... result=<match|divergence>` summary line,
#         plus a final `regression_flag: <none|divergence>` line. A
#         `runtime_parity` JSONL record is appended to each staged fixture's
#         execution-log.jsonl.
#
# Tier 3 is short-circuited via INTENSITY_METADATA_FILE=Quick so the
# zero-LLM contract holds; the tier3-oversized-section fixture is skipped
# (T02 ships the routing-parity runner that consumes it).
#
# Knowledge-state side-effect (build-context.sh runs increment-hits.sh on
# every resolved MEM ID, mutating the project's knowledge tree's
# `hit_count:` fields and KNOWLEDGE-INDEX.md). The runner snapshots both
# before the first invocation per fixture and restores between invocations
# so the three runtime runs see byte-identical input state.
#
# Always exits 0 (FR-12 advisory pattern). Per-fixture FAIL surfaces via
# the `regression_flag: divergence` line read by the T03 verifier.
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant. MEM004 carve-out applies
# inside the runner body — single-pass awk + pipes permitted INSIDE the
# script. The single-script-file rule applies only to the Check: line at
# task / phase plan level.

set -u

# ---------------------------------------------------------------------------
# Resolve project root + helper path. PROJECT_ROOT is "this script's
# parent's parent" = the orchestrator repo root.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/verify/_helpers/m018-p07-build-fixture.sh"
BUILD_CONTEXT="$PROJECT_ROOT/scripts/dispatch/build-context.sh"

# ---------------------------------------------------------------------------
# CLI parsing — case ladder; no compound chains > 2.
# ---------------------------------------------------------------------------
CORPUS_DIR_REL="tests/compression-runtime-parity"
CORPUS_DIR=""
FIXTURE_FILTER="all"
RUNTIMES_CSV="claude-code,codex,cursor"
OUTPUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --corpus-dir)
      CORPUS_DIR="$2"
      shift 2
      ;;
    --fixture)
      FIXTURE_FILTER="$2"
      shift 2
      ;;
    --runtimes)
      RUNTIMES_CSV="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      printf 'm018-runtime-parity.sh: unknown option: %s\n' "$1" >&2
      shift
      ;;
  esac
done

if [ -z "$CORPUS_DIR" ]; then
  CORPUS_DIR="$PROJECT_ROOT/$CORPUS_DIR_REL"
fi
if [ ! -d "$CORPUS_DIR/fixtures" ]; then
  printf 'm018-runtime-parity.sh: corpus directory missing: %s/fixtures\n' "$CORPUS_DIR" >&2
  printf 'regression_flag: corpus-missing\n'
  exit 0
fi
if [ ! -f "$HELPER" ]; then
  printf 'm018-runtime-parity.sh: fixture helper missing: %s\n' "$HELPER" >&2
  printf 'regression_flag: helper-missing\n'
  exit 0
fi
if [ ! -f "$BUILD_CONTEXT" ]; then
  printf 'm018-runtime-parity.sh: build-context.sh missing: %s\n' "$BUILD_CONTEXT" >&2
  printf 'regression_flag: build-context-missing\n'
  exit 0
fi

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="${TMPDIR:-/tmp}/_p07_runtime_parity"
fi
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Snapshot the project's knowledge state. build-context.sh's resolved-
# knowledge pipeline calls scripts/knowledge/increment-hits.sh on every
# MEM ID it embeds, mutating frontmatter `hit_count:` and the
# KNOWLEDGE-INDEX.md row counts. Restore between invocations so each of
# the three runtime runs sees byte-identical input state.
# ---------------------------------------------------------------------------
KSNAP_DIR="$OUTPUT_DIR/_knowledge_snapshot"
mkdir -p "$KSNAP_DIR"
if [ -d "$PROJECT_ROOT/knowledge" ]; then
  cp -R "$PROJECT_ROOT/knowledge" "$KSNAP_DIR/knowledge"
fi
if [ -f "$PROJECT_ROOT/KNOWLEDGE-INDEX.md" ]; then
  cp "$PROJECT_ROOT/KNOWLEDGE-INDEX.md" "$KSNAP_DIR/KNOWLEDGE-INDEX.md"
fi

restore_knowledge() {
  if [ -d "$KSNAP_DIR/knowledge" ]; then
    rm -rf "$PROJECT_ROOT/knowledge"
    cp -R "$KSNAP_DIR/knowledge" "$PROJECT_ROOT/knowledge"
  fi
  if [ -f "$KSNAP_DIR/KNOWLEDGE-INDEX.md" ]; then
    cp "$KSNAP_DIR/KNOWLEDGE-INDEX.md" "$PROJECT_ROOT/KNOWLEDGE-INDEX.md"
  fi
}

# ---------------------------------------------------------------------------
# Stage an intensity-metadata file forcing T3 to short-circuit. T01 is the
# zero-LLM parity contract — Tier 3's LLM-routed compaction is T02's job.
# Setting intensity=Quick triggers _bc_apply_tier3's intensity gate when
# tier3.intensity_floor is at the default (standard). Bash 3.2 here-doc
# is fine; this is the only env-var input build-context honors for T3.
# ---------------------------------------------------------------------------
INTENSITY_FILE="$OUTPUT_DIR/_intensity-quick.txt"
printf 'intensity: Quick\n' > "$INTENSITY_FILE"

# ---------------------------------------------------------------------------
# Resolve fixture list. Two modes:
#   - --fixture all : every directory under <corpus>/fixtures/ except the
#                     tier3-oversized-section slug (consumed by T02).
#   - --fixture <name> : just that slug.
# ---------------------------------------------------------------------------
FIXTURES_FILE="$OUTPUT_DIR/_fixtures.txt"
: > "$FIXTURES_FILE"
if [ "$FIXTURE_FILTER" = "all" ]; then
  # List directory entries via find (single-script-form, no compound chain).
  find "$CORPUS_DIR/fixtures" -mindepth 1 -maxdepth 1 -type d -print > "$OUTPUT_DIR/_dirs.txt" 2>/dev/null
  while IFS= read -r d; do
    if [ -z "$d" ]; then
      continue
    fi
    name="$(basename "$d")"
    # T01 skips T02's fixture.
    if [ "$name" = "tier3-oversized-section" ]; then
      continue
    fi
    printf '%s\n' "$name" >> "$FIXTURES_FILE"
  done < "$OUTPUT_DIR/_dirs.txt"
else
  printf '%s\n' "$FIXTURE_FILTER" >> "$FIXTURES_FILE"
fi

# Sort the fixture list so output ordering is deterministic across hosts.
sort -o "$FIXTURES_FILE" "$FIXTURES_FILE"

# ---------------------------------------------------------------------------
# Resolve runtime list — comma-split into a parallel-indexed array (no
# `read -ra`, MEM001).
# ---------------------------------------------------------------------------
RUNTIMES_FILE="$OUTPUT_DIR/_runtimes.txt"
printf '%s\n' "$RUNTIMES_CSV" | tr ',' '\n' > "$RUNTIMES_FILE"

# ---------------------------------------------------------------------------
# For each fixture × runtime: stage, invoke, capture, hash, restore. After
# all runtimes for a fixture, compare hashes and emit summary.
# ---------------------------------------------------------------------------
ANY_DIVERGENCE=0
FIXTURE_COUNT=0

while IFS= read -r FIXTURE; do
  if [ -z "$FIXTURE" ]; then
    continue
  fi
  FIXTURE_COUNT=$(( FIXTURE_COUNT + 1 ))
  FIXTURE_HASHES_FILE="$OUTPUT_DIR/_${FIXTURE}_hashes.txt"
  : > "$FIXTURE_HASHES_FILE"

  while IFS= read -r RUNTIME; do
    if [ -z "$RUNTIME" ]; then
      continue
    fi

    # Stage hermetic root.
    STAGE_ROOT="$(bash "$HELPER" "$RUNTIME" "$FIXTURE" 2>/dev/null)"
    if [ -z "$STAGE_ROOT" ] || [ ! -d "$STAGE_ROOT" ]; then
      printf 'runtime-parity fixture=%s runtime=%s sha256=stage-failed\n' "$FIXTURE" "$RUNTIME"
      printf 'stage-failed\n' >> "$FIXTURE_HASHES_FILE"
      continue
    fi

    # Capture the post-pipeline payload to a fixture-local file. Suppress
    # stderr to keep parity output stable across runtimes.
    PAYLOAD_FILE="$STAGE_ROOT/_runtime_payload.txt"
    HASH_FILE="$STAGE_ROOT/_runtime_payload.sha256"
    INTENSITY_METADATA_FILE="$INTENSITY_FILE" \
      ORCH_BACKEND="$RUNTIME" \
      bash "$BUILD_CONTEXT" "$STAGE_ROOT" M-FIXTURE P01 T01 \
      > "$PAYLOAD_FILE" 2>/dev/null

    # SHA-256 over the captured payload. AP-009: write the hash to a file
    # via shasum, then awk-extract field 1. No inline pipes here (single
    # invocation pattern); awk reads the hash file.
    shasum -a 256 "$PAYLOAD_FILE" > "$HASH_FILE" 2>/dev/null
    HASH="$(awk 'NR==1 { print $1 }' "$HASH_FILE")"
    if [ -z "$HASH" ]; then
      HASH="hash-failed"
    fi

    printf 'runtime-parity fixture=%s runtime=%s sha256=%s\n' "$FIXTURE" "$RUNTIME" "$HASH"
    printf '%s\n' "$HASH" >> "$FIXTURE_HASHES_FILE"

    # Append a runtime_parity JSONL record to the staged execution log
    # (CON-5 additive record_type).
    LOG_FILE="$STAGE_ROOT/milestones/M-FIXTURE/execution-log.jsonl"
    TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"record_type":"runtime_parity","fixture":"%s","runtime":"%s","sha256":"%s","timestamp":"%s"}\n' \
      "$FIXTURE" "$RUNTIME" "$HASH" "$TS" \
      >> "$LOG_FILE" 2>/dev/null || true

    # Restore project knowledge state so the next runtime sees identical
    # input bytes (build-context's increment-hits side-effect mutates
    # both knowledge entry frontmatter and KNOWLEDGE-INDEX.md).
    restore_knowledge
  done < "$RUNTIMES_FILE"

  # Compare hashes for this fixture. AP-009-clean: sort -u into a file,
  # then `wc -l` from the file (no inline pipe to wc).
  UNIQUE_FILE="$OUTPUT_DIR/_${FIXTURE}_unique.txt"
  sort -u "$FIXTURE_HASHES_FILE" > "$UNIQUE_FILE"
  UNIQUE_COUNT="$(awk 'END { print NR }' "$UNIQUE_FILE")"
  TOTAL_COUNT="$(awk 'END { print NR }' "$FIXTURE_HASHES_FILE")"

  if [ "$UNIQUE_COUNT" = "1" ]; then
    printf 'parity fixture=%s result=match runtimes=%s\n' "$FIXTURE" "$TOTAL_COUNT"
  else
    printf 'parity fixture=%s result=divergence runtimes=%s unique=%s\n' \
      "$FIXTURE" "$TOTAL_COUNT" "$UNIQUE_COUNT"
    ANY_DIVERGENCE=1
  fi
done < "$FIXTURES_FILE"

# ---------------------------------------------------------------------------
# Final summary line. T03's verifier asserts on this line.
# ---------------------------------------------------------------------------
if [ "$FIXTURE_COUNT" = "0" ]; then
  printf 'regression_flag: no-fixtures\n'
elif [ "$ANY_DIVERGENCE" = "0" ]; then
  printf 'regression_flag: none\n'
else
  printf 'regression_flag: divergence\n'
fi

exit 0

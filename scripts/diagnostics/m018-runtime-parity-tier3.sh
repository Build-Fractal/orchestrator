#!/usr/bin/env bash
# scripts/diagnostics/m018-runtime-parity-tier3.sh
#
# M018/P07/T02 — Tier 3 routing parity driver.
#
# For each runtime in {claude-code, codex, cursor}: stage the hermetic
# tier3-oversized-section fixture via the T01 helper, set
# ORCH_TIER3_LLM_BIN to the deterministic stub, set ORCH_BACKEND to
# the runtime, invoke scripts/dispatch/build-context.sh, then assert:
#
#   - On the success path (default): the stub fired exactly once, the
#     post-pipeline payload contains the stub's deterministic envelope
#     marker (`compressed:tier3 model=stub-deterministic`), and the
#     payload_breakdown JSONL record carries `"tier3_invocations":1`
#     plus a positive `"tier3_compression_savings_tokens"`.
#
#   - On the failure-passthrough path (--fail-stub): the stub still
#     fired exactly once (and exited 1), the dispatch survived
#     (build-context exit 0), and the JSONL contains a `tier3_failed`
#     record with `reason=llm-call-nonzero`.
#
# A `runtime_parity` JSONL record (CON-5 additive record_type, same
# shape as T01's runner emits) is appended to each staged fixture's
# execution-log.jsonl per (runtime) pass.
#
# CLI:
#   m018-runtime-parity-tier3.sh [--runtimes <csv>] [--fail-stub]
#                                [--fixture <name>]
#
# Defaults: --runtimes claude-code,codex,cursor,
#           --fixture tier3-oversized-section.
#
# Always exits 0 (FR-12 advisory pattern). The T03 verifier asserts on
# stdout shape — per-runtime line + final `tier3-routing-parity` line +
# `regression_flag:` line.
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant. MEM004 carve-out applies
# inside the runner body — single-pass awk + simple pipes permitted
# INSIDE the script. The single-script-file rule applies only to the
# Check: line at task / phase plan level.

set -u

# ---------------------------------------------------------------------------
# Resolve project root + helper / build-context / stub paths.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/verify/_helpers/m018-p07-build-fixture.sh"
BUILD_CONTEXT="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
STUB="$PROJECT_ROOT/tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh"

# ---------------------------------------------------------------------------
# CLI parsing — case ladder; no compound chains > 2.
# ---------------------------------------------------------------------------
RUNTIMES_CSV="claude-code,codex,cursor"
FAIL_STUB=0
FIXTURE="tier3-oversized-section"
OUTPUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --runtimes)
      RUNTIMES_CSV="$2"
      shift 2
      ;;
    --fail-stub)
      FAIL_STUB=1
      shift
      ;;
    --fixture)
      FIXTURE="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *)
      printf 'm018-runtime-parity-tier3.sh: unknown option: %s\n' "$1" >&2
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight — bail out with a regression_flag rather than a non-zero exit
# (FR-12 advisory pattern). T03's verifier asserts on the regression_flag
# line.
# ---------------------------------------------------------------------------
if [ ! -f "$HELPER" ]; then
  printf 'm018-runtime-parity-tier3.sh: fixture helper missing: %s\n' "$HELPER" >&2
  printf 'regression_flag: helper-missing\n'
  exit 0
fi
if [ ! -f "$BUILD_CONTEXT" ]; then
  printf 'm018-runtime-parity-tier3.sh: build-context.sh missing: %s\n' "$BUILD_CONTEXT" >&2
  printf 'regression_flag: build-context-missing\n'
  exit 0
fi
if [ ! -x "$STUB" ]; then
  printf 'm018-runtime-parity-tier3.sh: stub missing or not executable: %s\n' "$STUB" >&2
  printf 'regression_flag: stub-missing\n'
  exit 0
fi

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="${TMPDIR:-/tmp}/_p07_tier3_routing_parity"
fi
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# Snapshot the project's knowledge state. build-context.sh's resolved-
# knowledge pipeline runs scripts/knowledge/increment-hits.sh on every
# resolved MEM ID, mutating the project's knowledge tree. Restore between
# runtime invocations so each runtime sees byte-identical input state
# (mirrors the T01 runner).
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
# Runtime list — comma-split into a newline-per-line file (no `read -ra`
# array, MEM001 — bash 3.2-safe).
# ---------------------------------------------------------------------------
RUNTIMES_FILE="$OUTPUT_DIR/_runtimes.txt"
printf '%s\n' "$RUNTIMES_CSV" | tr ',' '\n' > "$RUNTIMES_FILE"

# ---------------------------------------------------------------------------
# Per-runtime body. Tracks divergence so the final summary line surfaces
# the boolean.
# ---------------------------------------------------------------------------
ANY_DIVERGENCE=0
RUNTIME_COUNT=0

while IFS= read -r RUNTIME; do
  if [ -z "$RUNTIME" ]; then
    continue
  fi
  RUNTIME_COUNT=$(( RUNTIME_COUNT + 1 ))

  # Stage hermetic root for this (runtime, fixture) pair.
  STAGE_ROOT="$(bash "$HELPER" "$RUNTIME" "$FIXTURE" 2>/dev/null)"
  if [ -z "$STAGE_ROOT" ] || [ ! -d "$STAGE_ROOT" ]; then
    printf 'tier3-routing runtime=%s result=stage-failed\n' "$RUNTIME"
    ANY_DIVERGENCE=1
    continue
  fi

  # Per-runtime stub-invocations log. Truncate before the build-context
  # invocation so line counts reflect THIS runtime's fires only.
  STUB_LOG="$STAGE_ROOT/_stub-invocations.log"
  : > "$STUB_LOG"

  PAYLOAD_FILE="$STAGE_ROOT/_runtime_payload.txt"
  STDERR_FILE="$STAGE_ROOT/_build-context.stderr"

  # The fixture config does NOT override compression.tier3.intensity_floor.
  # Default is `standard`. We do NOT pass INTENSITY_METADATA_FILE — the
  # absent metadata file resolves to `standard` per kf_resolve_intensity,
  # which clears the FR-14 gate. (T01's zero-LLM runner deliberately
  # forces Quick to short-circuit T3; T02 does the inverse.)
  ORCH_BACKEND="$RUNTIME" \
    ORCH_TIER3_LLM_BIN="$STUB" \
    ORCH_TIER3_STUB_INVOCATIONS_LOG="$STUB_LOG" \
    ORCH_TIER3_STUB_FAIL="$FAIL_STUB" \
    bash "$BUILD_CONTEXT" "$STAGE_ROOT" M-FIXTURE P01 T01 \
    > "$PAYLOAD_FILE" 2>"$STDERR_FILE"
  BC_RC=$?

  # Count stub invocations for this runtime. AP-009-clean: awk over the
  # log file (no inline pipe to wc).
  STUB_FIRES="$(awk 'END { print NR }' "$STUB_LOG")"
  if [ -z "$STUB_FIRES" ]; then
    STUB_FIRES=0
  fi

  LOG_FILE="$STAGE_ROOT/milestones/M-FIXTURE/execution-log.jsonl"

  if [ "$FAIL_STUB" = "1" ]; then
    # ----- Failure-passthrough path (FR-9) -------------------------------
    # Assertions:
    #   1. Stub fired exactly once (the stub records its invocation
    #      BEFORE exiting 1 so the parity check can prove the call
    #      reached the operator-binary surface).
    #   2. build-context survived (exit 0; tier3 failure does NOT
    #      crash the dispatch).
    #   3. JSONL carries a tier3_failed record with reason=llm-call-nonzero.
    HAS_TIER3_FAILED=0
    if [ -f "$LOG_FILE" ]; then
      if grep -q '"record_type":"tier3_failed"' "$LOG_FILE"; then
        if grep -q 'reason=llm-call-nonzero' "$LOG_FILE"; then
          HAS_TIER3_FAILED=1
        fi
      fi
    fi

    PASSTHROUGH_OK=ok
    if [ "$STUB_FIRES" != "1" ]; then
      PASSTHROUGH_OK=missing-fire
      ANY_DIVERGENCE=1
    elif [ "$BC_RC" != "0" ]; then
      PASSTHROUGH_OK=dispatch-crashed
      ANY_DIVERGENCE=1
    elif [ "$HAS_TIER3_FAILED" != "1" ]; then
      PASSTHROUGH_OK=missing-tier3-failed
      ANY_DIVERGENCE=1
    fi

    printf 'tier3-routing runtime=%s stub_fail=1 stub_invocations=%s passthrough=%s bc_rc=%s\n' \
      "$RUNTIME" "$STUB_FIRES" "$PASSTHROUGH_OK" "$BC_RC"
  else
    # ----- Success path --------------------------------------------------
    # Assertions:
    #   1. Stub fired exactly once.
    #   2. Post-pipeline payload contains the stub's deterministic
    #      envelope marker.
    #   3. payload_breakdown JSONL carries tier3_invocations=1 and
    #      tier3_compression_savings_tokens > 0.
    HAS_MARKER=0
    if grep -q 'compressed:tier3 model=stub-deterministic' "$PAYLOAD_FILE"; then
      HAS_MARKER=1
    fi

    HAS_INVOC=0
    HAS_SAVINGS=0
    if [ -f "$LOG_FILE" ]; then
      if grep -q '"tier3_invocations":1' "$LOG_FILE"; then
        HAS_INVOC=1
      fi
      # Awk-extract the savings field from the payload_breakdown line and
      # check it is a positive integer. Single awk script, no inline pipe
      # at task-plan-Check level.
      SAVINGS_VAL="$(awk '
        /"record_type":"payload_breakdown"/ {
          if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
            v = substr($0, RSTART, RLENGTH)
            sub(/^"tier3_compression_savings_tokens":/, "", v)
            print v
            exit
          }
        }
      ' "$LOG_FILE")"
      if [ -n "$SAVINGS_VAL" ] && [ "$SAVINGS_VAL" != "0" ]; then
        HAS_SAVINGS=1
      fi
    fi

    RESULT=routed
    if [ "$BC_RC" != "0" ]; then
      RESULT=dispatch-crashed
      ANY_DIVERGENCE=1
    elif [ "$STUB_FIRES" != "1" ]; then
      RESULT=missing-fire
      ANY_DIVERGENCE=1
    elif [ "$HAS_MARKER" != "1" ]; then
      RESULT=missing-marker
      ANY_DIVERGENCE=1
    elif [ "$HAS_INVOC" != "1" ]; then
      RESULT=missing-invocations
      ANY_DIVERGENCE=1
    elif [ "$HAS_SAVINGS" != "1" ]; then
      RESULT=missing-savings
      ANY_DIVERGENCE=1
    fi

    printf 'tier3-routing runtime=%s result=%s stub_invocations=%s\n' \
      "$RUNTIME" "$RESULT" "$STUB_FIRES"
  fi

  # Append a runtime_parity JSONL record (CON-5 additive record_type).
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  STUB_FIRED_BOOL=true
  if [ "$STUB_FIRES" = "0" ]; then
    STUB_FIRED_BOOL=false
  fi
  printf '{"record_type":"runtime_parity","fixture":"%s","runtime":"%s","tier":"3","stub_fired":%s,"stub_invocations":%s,"fail_stub":%s,"timestamp":"%s"}\n' \
    "$FIXTURE" "$RUNTIME" "$STUB_FIRED_BOOL" "$STUB_FIRES" "$FAIL_STUB" "$TS" \
    >> "$LOG_FILE" 2>/dev/null || true

  # Restore project knowledge state so the next runtime sees identical
  # input bytes (build-context's increment-hits side-effect).
  restore_knowledge
done < "$RUNTIMES_FILE"

# ---------------------------------------------------------------------------
# Final summary lines. T03's verifier asserts on these.
# ---------------------------------------------------------------------------
if [ "$RUNTIME_COUNT" = "0" ]; then
  printf 'tier3-routing-parity result=no-runtimes\n'
  printf 'regression_flag: no-runtimes\n'
elif [ "$ANY_DIVERGENCE" = "0" ]; then
  if [ "$FAIL_STUB" = "1" ]; then
    printf 'tier3-routing-parity result=all-passthrough\n'
  else
    printf 'tier3-routing-parity result=all-routed\n'
  fi
  printf 'regression_flag: none\n'
else
  printf 'tier3-routing-parity result=divergence\n'
  printf 'regression_flag: divergence\n'
fi

exit 0

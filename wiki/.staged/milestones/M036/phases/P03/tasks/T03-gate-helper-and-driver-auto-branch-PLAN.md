---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M036"
name: "Conversus fidelity-gate helper + driver auto-branch + PASS/BLOCK retention"
depends_on: ["T02"]
---

## Prerequisites

- T01 closed: `templates/conversus-presets/tier-2-fidelity.yml` exists.
- T02 closed: `scripts/knowledge/lib/extract-tier-2-llm.sh` exists with `extract_tier_2_dispatch` + `extract_tier_2_emit_unit_close`.
- `scripts/dispatch/adapters/tool/conversus.sh` exists, exposes `gate <preset> <artifact> <output>` and `parse-verdict <gate-result-path>` subcommands.
- `scripts/knowledge/lib/extract-tier-0-summary.sh` exists with the auto-branch hard-error from P02.
- `scripts/knowledge/extract-reference.sh` exists and sources `extract-tier-0-summary.sh`.

Verified at plan-authoring time: all five files present.

## Description

Author `scripts/knowledge/lib/extract-tier-2-gate.sh` (gate helper), modify `scripts/knowledge/lib/extract-tier-0-summary.sh` (sentinel return for tier=2 + auto), and modify `scripts/knowledge/extract-reference.sh` (Tier 2 dispatch + gate + promote/retain block). Author six verifiers.

## Steps

### Step 1 — Author `scripts/knowledge/lib/extract-tier-2-gate.sh`

Create `scripts/knowledge/lib/extract-tier-2-gate.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-2-gate.sh -- M036 P03 T03 helper.
# Pure functions for Tier 2 conversus fidelity-gate invocation +
# PASS/BLOCK retention logic. Sourced by extract-reference.sh.
# No top-level I/O (MEM004). Bash 3.2 / POSIX-sh per CON-2.

# extract_tier_2_invoke_gate <structured-md-path> <gate-output-path>
#   Invokes scripts/dispatch/adapters/tool/conversus.sh with the
#   tier-2-fidelity preset; writes gate-result.md to <gate-output-path>.
#   Returns: 0 on PASS, 2 on BLOCK, 1 on adapter error or missing inputs.
extract_tier_2_invoke_gate() {
  local artifact="$1"
  local out="$2"
  local root="${ORCHESTRATOR_ROOT:-$(pwd)}"
  local adapter="$root/scripts/dispatch/adapters/tool/conversus.sh"
  if [ ! -f "$artifact" ]; then
    echo "extract_tier_2_invoke_gate: structured-md missing at $artifact" >&2
    return 1
  fi
  if [ ! -x "$adapter" ]; then
    echo "extract_tier_2_invoke_gate: conversus adapter not executable at $adapter" >&2
    return 1
  fi
  # Bypass the conversus TODO-marker preflight: structured Markdown
  # extraction may legitimately contain TODO-shaped strings if the
  # source did. Tests + this gate path always run with the bypass.
  CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
    bash "$adapter" gate tier-2-fidelity "$artifact" "$out"
  local rc=$?
  case "$rc" in
    0) return 0 ;;   # PASS
    2) return 2 ;;   # BLOCK
    *) return 1 ;;   # adapter error
  esac
}

# extract_tier_2_promote_or_retain <verdict> <structured-tmp-path> <chunk-dir> <cite_id> <category> <gate-output-path> <log-dir>
#   verdict: 0 (PASS) | 2 (BLOCK)
#   PASS: mv <structured-tmp> -> <chunk-dir>/REF-<category>-<cite_id>.structured.md
#         cp <gate-output-path> -> <log-dir>/<cite_id>.pass.md
#   BLOCK: cp <gate-output-path> -> <log-dir>/<cite_id>.block.md
#          rm <structured-tmp>     (do NOT promote)
#   Returns 0 on success, 1 on error.
extract_tier_2_promote_or_retain() {
  local verdict="$1"
  local tmp="$2"
  local chunk_dir="$3"
  local cite_id="$4"
  local category="$5"
  local gate_out="$6"
  local log_dir="$7"
  mkdir -p "$log_dir"
  case "$verdict" in
    0)
      local final="$chunk_dir/REF-${category}-${cite_id}.structured.md"
      mkdir -p "$chunk_dir"
      mv "$tmp" "$final"
      cp "$gate_out" "$log_dir/${cite_id}.pass.md"
      return 0
      ;;
    2)
      cp "$gate_out" "$log_dir/${cite_id}.block.md"
      rm -f "$tmp"
      return 0
      ;;
    *)
      echo "extract_tier_2_promote_or_retain: unknown verdict '$verdict' (expected 0|2)" >&2
      return 1
      ;;
  esac
}
```

Make executable: `chmod +x scripts/knowledge/lib/extract-tier-2-gate.sh`.

### Step 2 — Modify `scripts/knowledge/lib/extract-tier-0-summary.sh`

Replace the `auto)` branch in `generate_tier_0_summary` so that when `tier=2`, it returns a sentinel string `__TIER_2_AUTO__` (single line on stdout, exit 0) instead of hard-erroring. The non-tier-2 + auto path keeps its existing deferral-error behavior so the M036/P02 `tier-2-deferred-error.sh` verifier still passes for tier!=2 + auto inputs.

Use the `Edit` tool. Old string (the entire `auto)` case body):

```
    auto)
      if [ "$tier" = "2" ]; then
        echo "generate_tier_0_summary: P03 not implemented: Tier 2 LLM extraction is the P03 deliverable; current P02 ships the synchronous Tier 0/1 path. Use summary_mode: operator or stub instead, or wait for P03 to land." >&2
      else
        echo "generate_tier_0_summary: summary_mode=auto deferred to P03 (Tier 2 path). Use summary_mode: operator or stub for tier $tier." >&2
      fi
      return 1
      ;;
```

New string:

```
    auto)
      if [ "$tier" = "2" ]; then
        # P03 (M036): tier=2 + auto returns the sentinel; the driver
        # consumes it and dispatches the Tier 2 helper chain
        # (extract_tier_2_dispatch + extract_tier_2_invoke_gate +
        # extract_tier_2_promote_or_retain + extract_tier_2_emit_unit_close).
        printf '__TIER_2_AUTO__\n'
        return 0
      else
        echo "generate_tier_0_summary: summary_mode=auto deferred to P03 (Tier 2 path). Use summary_mode: operator or stub for tier $tier." >&2
        return 1
      fi
      ;;
```

This change preserves the M036/P02 `m036-p02-tier-2-deferred-error.sh` verifier semantics ONLY for tier!=2 + auto. The P02 verifier asserts on `tier:2 + auto`, which now succeeds — so the P02 verifier behavior changes. T03 also authors `m036-p03-tier-2-deferred-error-removed.sh` to assert the new behavior (driver no longer hard-errors on tier:2+auto), and `m036-p03-p02-regression-pass.sh` re-runs the P02 phase-suite excluding the now-stale `m036-p02-tier-2-deferred-error.sh` (it's the one P02 verifier whose semantics intentionally flip in P03; the other 14 P02 verifiers still pass).

### Step 3 — Modify `scripts/knowledge/extract-reference.sh`

Source the two new helpers after the existing P02 sources, then add the Tier 2 dispatch logic in the per-document loop. Use `Edit`:

**Edit A — add the source lines.** Old string (the existing source block):

```
# shellcheck disable=SC1091
. "$HERE/lib/extract-manifest.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-binary-preservation.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-0-summary.sh"   # authored in T03
```

New string:

```
# shellcheck disable=SC1091
. "$HERE/lib/extract-manifest.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-binary-preservation.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-0-summary.sh"
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-2-llm.sh"        # M036/P03 T02
# shellcheck disable=SC1091
. "$HERE/lib/extract-tier-2-gate.sh"       # M036/P03 T03
```

**Edit B — replace the summary-emit block with Tier 2 dispatch.** Old string:

```
  # Tier 0 summary (T03 helper).
  operator_summary=$(extract_manifest_doc_field "$MANIFEST" "$i" summary)
  summary_text=$(generate_tier_0_summary "$summary_mode" "$category" "$cite_id" "$operator_summary" "$tier") || {
    echo "extract-reference.sh: summary generation failed for $cite_id" >&2
    exit 1
  }
```

New string:

```
  # Tier 0 summary -- operator|stub branches return the body verbatim;
  # auto + tier=2 returns the sentinel __TIER_2_AUTO__ which the loop
  # consumes below to drive the Tier 2 helper chain (M036/P03 T03).
  operator_summary=$(extract_manifest_doc_field "$MANIFEST" "$i" summary)
  summary_text=$(generate_tier_0_summary "$summary_mode" "$category" "$cite_id" "$operator_summary" "$tier") || {
    echo "extract-reference.sh: summary generation failed for $cite_id" >&2
    exit 1
  }
```

(Edit B is a no-op rename for clarity — it's load-bearing only as an anchor for the next edit, but kept identical so the diff is minimal.)

**Edit C — add the Tier 2 branch and modify the EXTRACTED emit.** Old string:

```
  # Emit chunk frontmatter + body.
  {
    printf -- "---\n"
    printf 'schema_version: "1.0"\n'
    printf 'type: reference-chunk\n'
    printf 'milestone: "M036"\n'
    printf 'category: "%s"\n' "$category"
    printf 'chunk_id: "REF-%s-%s"\n' "$category" "$cite_id"
    printf 'cite_id: "%s"\n' "$cite_id"
    printf 'source: "%s"\n' "$source"
    printf 'published: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" published)"
    printf 'version: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" version)"
    printf 'tier: %s\n' "$tier"
    printf 'content_hash: "%s"\n' "$hash"
    printf 'size_bytes: %s\n' "$size"
    if [ -n "$external_pointer" ]; then
      printf 'external_pointer: "%s"\n' "$external_pointer"
    fi
    printf 'summary_mode: "%s"\n' "$summary_mode"
    printf -- "---\n\n"
    printf '%s\n' "$summary_text"
  } > "$chunk_file"

  echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}}"
  i=$((i + 1))
done
exit 0
```

New string:

```
  # Tier 2 dispatch + gate + promote/retain (M036/P03).
  # Triggered when generate_tier_0_summary returned the sentinel.
  tier_2_verdict=""
  if [ "$summary_text" = "__TIER_2_AUTO__" ]; then
    summary_text="[tier-2-auto] structured Markdown gated by conversus tier-2-fidelity preset"
    log_dir="$ROOT/.orchestrator/knowledge/reference/_extraction-log"
    mkdir -p "$log_dir"
    tmp_struct=$(mktemp "${TMPDIR:-/tmp}/m036-p03-struct.XXXXXX.md")
    gate_out=$(mktemp "${TMPDIR:-/tmp}/m036-p03-gate.XXXXXX.md")
    # Capture stub metrics (stderr name=value pairs) for unit_close.
    metrics_file=$(mktemp "${TMPDIR:-/tmp}/m036-p03-metrics.XXXXXX.txt")
    extract_tier_2_dispatch "$src_abs" "$tmp_struct" "$category" "$cite_id" 2>"$metrics_file" || {
      echo "extract-reference.sh: Tier 2 dispatch failed for $cite_id" >&2
      rm -f "$tmp_struct" "$gate_out" "$metrics_file"
      exit 1
    }
    set +e
    extract_tier_2_invoke_gate "$tmp_struct" "$gate_out"
    gate_rc=$?
    set -e
    case "$gate_rc" in
      0) tier_2_verdict="PASS" ;;
      2) tier_2_verdict="BLOCK" ;;
      *)
        echo "extract-reference.sh: Tier 2 gate adapter error for $cite_id (rc=$gate_rc)" >&2
        rm -f "$tmp_struct" "$gate_out" "$metrics_file"
        exit 1
        ;;
    esac
    extract_tier_2_promote_or_retain "$gate_rc" "$tmp_struct" "$chunk_dir" "$cite_id" "$category" "$gate_out" "$log_dir" || {
      echo "extract-reference.sh: Tier 2 promote/retain failed for $cite_id" >&2
      rm -f "$gate_out" "$metrics_file"
      exit 1
    }
    # Parse stub metrics from the metrics_file (name=value lines) and
    # emit the unit_close record.
    t2_model=$(grep -E '^MODEL=' "$metrics_file" | sed -E 's/^MODEL=//' | head -n 1)
    t2_in=$(grep -E '^TOKENS_IN=' "$metrics_file" | sed -E 's/^TOKENS_IN=//' | head -n 1)
    t2_out=$(grep -E '^TOKENS_OUT=' "$metrics_file" | sed -E 's/^TOKENS_OUT=//' | head -n 1)
    t2_cost=$(grep -E '^COST_USD=' "$metrics_file" | sed -E 's/^COST_USD=//' | head -n 1)
    t2_qual=$(grep -E '^QUALITY_SCORE=' "$metrics_file" | sed -E 's/^QUALITY_SCORE=//' | head -n 1)
    [ -z "$t2_model" ] && t2_model="unknown"
    [ -z "$t2_in" ]    && t2_in=0
    [ -z "$t2_out" ]   && t2_out=0
    [ -z "$t2_cost" ]  && t2_cost=0
    [ -z "$t2_qual" ]  && t2_qual=0
    extract_tier_2_emit_unit_close "$cite_id" "$t2_model" "$t2_in" "$t2_out" "$t2_cost" "$t2_qual"
    rm -f "$gate_out" "$metrics_file"
  fi

  # Emit chunk frontmatter + body.
  {
    printf -- "---\n"
    printf 'schema_version: "1.0"\n'
    printf 'type: reference-chunk\n'
    printf 'milestone: "M036"\n'
    printf 'category: "%s"\n' "$category"
    printf 'chunk_id: "REF-%s-%s"\n' "$category" "$cite_id"
    printf 'cite_id: "%s"\n' "$cite_id"
    printf 'source: "%s"\n' "$source"
    printf 'published: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" published)"
    printf 'version: "%s"\n' "$(extract_manifest_doc_field "$MANIFEST" "$i" version)"
    printf 'tier: %s\n' "$tier"
    printf 'content_hash: "%s"\n' "$hash"
    printf 'size_bytes: %s\n' "$size"
    if [ -n "$external_pointer" ]; then
      printf 'external_pointer: "%s"\n' "$external_pointer"
    fi
    printf 'summary_mode: "%s"\n' "$summary_mode"
    if [ -n "$tier_2_verdict" ]; then
      printf 'tier_2_verdict: "%s"\n' "$tier_2_verdict"
    fi
    printf -- "---\n\n"
    printf '%s\n' "$summary_text"
  } > "$chunk_file"

  if [ "$tier_2_verdict" = "BLOCK" ]; then
    echo "BLOCKED: $cite_id reason=fidelity-gate"
  else
    if [ -n "$tier_2_verdict" ]; then
      echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}} verdict=$tier_2_verdict"
    else
      echo "EXTRACTED: $cite_id tier=$tier bytes=$size hash=${hash%${hash#????????}}"
    fi
  fi
  i=$((i + 1))
done
exit 0
```

### Step 4 — Author six verifiers under `tools/verify/m036-p03-*`

**4a.** `tools/verify/m036-p03-gate-helper-shape.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-gate-helper-shape.sh -- M036 P03 T03.
# Asserts gate helper exists, executable, exposes the documented funcs.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-gate.sh"
fail=0
if [ -f "$LIB" ] && [ -x "$LIB" ]; then
  echo "PASS: exists+executable $LIB"
else
  echo "FAIL: missing or non-executable $LIB"
  fail=$((fail + 1))
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LIB"; then
    echo "PASS: '$pat' in $(basename "$LIB")"
  else
    echo "FAIL: '$pat' missing in $(basename "$LIB")"
    fail=$((fail + 1))
  fi
}
checkpat "extract_tier_2_invoke_gate()"
checkpat "extract_tier_2_promote_or_retain()"
checkpat "tier-2-fidelity"
checkpat ".pass.md"
checkpat ".block.md"
echo "SUMMARY: m036-p03-gate-helper-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

**4b.** `tools/verify/m036-p03-tier-2-deferred-error-removed.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-deferred-error-removed.sh -- M036 P03 T03.
# Drives the driver against a manifest declaring tier:2 + summary_mode:
# auto with EXTRACT_TIER_2_DISPATCH=stub:pass + CONVERSUS_STUB=1 +
# CONVERSUS_STUB_VERDICT=PASS, asserts exit 0 and stdout EXTRACTED:
# (NOT the P02 'P03 not implemented' hard-error). Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-deferred.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
fail=0
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md" "$WORK/sample.md"
cat > "$WORK/manifest.yaml" <<'YAML'
schema_version: "1.0"
type: extract-manifest
milestone: "M036"
size_cap_bytes: 10485760

documents:
  - cite_id: "tier2-deferred-removed-01"
    source_path: "sample.md"
    category: "glossary"
    source: "internal-glossary"
    published: "2026-05-02"
    version: "test"
    tier: 2
    summary_mode: "auto"
YAML
set +e
ORCHESTRATOR_ROOT="$ROOT" \
EXTRACT_TIER_2_DISPATCH=stub:pass \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
bash "$DRV" --manifest "$WORK/manifest.yaml" \
  --reference-root "$WORK/reference" \
  --originals-root "$WORK/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "PASS: driver exited 0 on tier:2+auto"
else
  echo "FAIL: driver exited $rc on tier:2+auto (expected 0)"
  cat "$WORK/stderr.txt" >&2
  fail=$((fail + 1))
fi
if grep -qF -e "EXTRACTED:" "$WORK/stdout.txt"; then
  echo "PASS: stdout contains EXTRACTED:"
else
  echo "FAIL: stdout missing EXTRACTED:"
  fail=$((fail + 1))
fi
if grep -qF -e "P03 not implemented" "$WORK/stderr.txt"; then
  echo "FAIL: stderr still carries the P02 'P03 not implemented' string"
  fail=$((fail + 1))
else
  echo "PASS: P02 deferred-error string is gone"
fi
echo "SUMMARY: m036-p03-tier-2-deferred-error-removed.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

**4c.** `tools/verify/m036-p03-tier-2-pass-end-to-end.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-pass-end-to-end.sh -- M036 P03 T03.
# Drives the PASS path: stub:pass dispatch + CONVERSUS_STUB_VERDICT=PASS.
# Asserts: .structured.md present in chunk-store, pass.md present in
# _extraction-log, unit_close JSONL appended.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-pass.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
MANIFEST="$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml"
fail=0
# Use a per-run ORCHESTRATOR_ROOT so the unit_close lands in WORK, not repo.
mkdir -p "$WORK/repo"
cp -R "$ROOT/scripts" "$WORK/repo/scripts"
cp -R "$ROOT/templates" "$WORK/repo/templates"
mkdir -p "$WORK/repo/tests/fixtures/m036-p03-tier-2"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
# canned-structured.md authored in T04; check before copying.
if [ -f "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured.md" ]; then
  cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
else
  echo "FAIL: canned-structured.md missing -- T04 deliverable"
  echo "SUMMARY: m036-p03-tier-2-pass-end-to-end.sh fail=1"
  exit 1
fi
set +e
ORCHESTRATOR_ROOT="$WORK/repo" \
EXTRACT_TIER_2_DISPATCH=stub:pass \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS \
bash "$WORK/repo/scripts/knowledge/extract-reference.sh" \
  --manifest "$WORK/repo/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" \
  --reference-root "$WORK/repo/knowledge/reference" \
  --originals-root "$WORK/repo/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL: driver rc=$rc"
  cat "$WORK/stderr.txt" >&2
  fail=$((fail + 1))
else
  echo "PASS: driver rc=0"
fi
STRUCT="$WORK/repo/knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md"
if [ -f "$STRUCT" ]; then
  echo "PASS: structured-md present"
else
  echo "FAIL: structured-md missing at $STRUCT"
  fail=$((fail + 1))
fi
PASS_LOG="$WORK/repo/.orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.pass.md"
if [ -f "$PASS_LOG" ]; then
  echo "PASS: pass.md present"
else
  echo "FAIL: pass.md missing at $PASS_LOG"
  fail=$((fail + 1))
fi
JSONL="$WORK/repo/.orchestrator/execution-log.jsonl"
if [ -f "$JSONL" ] && grep -qF -e '"task_type":"extraction"' "$JSONL"; then
  echo "PASS: unit_close extraction record appended"
else
  echo "FAIL: unit_close extraction record missing in $JSONL"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p03-tier-2-pass-end-to-end.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

**4d.** `tools/verify/m036-p03-tier-2-block-retention.sh`:

(Same shape as 4c but with `EXTRACT_TIER_2_DISPATCH=stub:block` + `CONVERSUS_STUB_VERDICT=BLOCK`. Asserts: BLOCKED: stdout line, `block.md` present in `_extraction-log`, `.structured.md` **NOT** present in chunk-store.)

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-block-retention.sh -- M036 P03 T03.
# Drives the BLOCK path. Asserts block.md retained, .structured.md NOT
# in chunk-store, BLOCKED: stdout line.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-block.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
mkdir -p "$WORK/repo"
cp -R "$ROOT/scripts" "$WORK/repo/scripts"
cp -R "$ROOT/templates" "$WORK/repo/templates"
mkdir -p "$WORK/repo/tests/fixtures/m036-p03-tier-2"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/sample.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
cp "$ROOT/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
if [ -f "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md" ]; then
  cp "$ROOT/tests/fixtures/m036-p03-tier-2/canned-structured-low-fidelity.md" "$WORK/repo/tests/fixtures/m036-p03-tier-2/"
else
  echo "FAIL: canned-structured-low-fidelity.md missing -- T04 deliverable"
  echo "SUMMARY: m036-p03-tier-2-block-retention.sh fail=1"
  exit 1
fi
set +e
ORCHESTRATOR_ROOT="$WORK/repo" \
EXTRACT_TIER_2_DISPATCH=stub:block \
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK \
bash "$WORK/repo/scripts/knowledge/extract-reference.sh" \
  --manifest "$WORK/repo/tests/fixtures/m036-p03-tier-2/extract-manifest.yaml" \
  --reference-root "$WORK/repo/knowledge/reference" \
  --originals-root "$WORK/repo/_originals" \
  >"$WORK/stdout.txt" 2>"$WORK/stderr.txt"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "PASS: driver rc=0 on BLOCK"
else
  echo "FAIL: driver rc=$rc on BLOCK (expected 0 -- BLOCK is not a driver error)"
  cat "$WORK/stderr.txt" >&2
  fail=$((fail + 1))
fi
if grep -qF -e "BLOCKED: tier2-fixture-01" "$WORK/stdout.txt"; then
  echo "PASS: stdout BLOCKED: line"
else
  echo "FAIL: stdout missing BLOCKED: line"
  fail=$((fail + 1))
fi
BLOCK_LOG="$WORK/repo/.orchestrator/knowledge/reference/_extraction-log/tier2-fixture-01.block.md"
if [ -f "$BLOCK_LOG" ]; then
  echo "PASS: block.md present"
else
  echo "FAIL: block.md missing at $BLOCK_LOG"
  fail=$((fail + 1))
fi
STRUCT="$WORK/repo/knowledge/reference/glossary/REF-glossary-tier2-fixture-01.structured.md"
if [ -f "$STRUCT" ]; then
  echo "FAIL: .structured.md was promoted on BLOCK (FR-18 violation)"
  fail=$((fail + 1))
else
  echo "PASS: .structured.md NOT in chunk-store (FR-18 invariant)"
fi
echo "SUMMARY: m036-p03-tier-2-block-retention.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

**4e.** `tools/verify/m036-p03-p02-regression-pass.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-p02-regression-pass.sh -- M036 P03 T03.
# Asserts the P02 phase-suite minus the now-stale tier-2-deferred-error
# verifier still passes after P03 driver edits (operator|stub modes
# unchanged + tier!=2+auto deferral still errors).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
fail=0
GATES="m036-p02-manifest-contract-shape.sh
m036-p02-fixture-manifest-shape.sh
m036-p02-fixture-corpus-shape.sh
m036-p02-extract-driver-shape.sh
m036-p02-binary-preservation.sh
m036-p02-content-hash.sh
m036-p02-size-cap-external-pointer.sh
m036-p02-extract-md.sh
m036-p02-extract-pdf-host-aware.sh
m036-p02-extract-docx-host-aware.sh
m036-p02-extract-command-shape.sh
m036-p02-summary-mode-stub-vs-operator.sh
m036-p02-idempotency.sh
m036-p02-test-harness.sh"
old_ifs="$IFS"
IFS='
'
for g in $GATES; do
  if bash "$ROOT/tools/verify/$g" >/dev/null 2>&1; then
    echo "PASS: $g"
  else
    echo "FAIL: $g (P03 driver edits regressed P02 behavior)"
    fail=$((fail + 1))
  fi
done
IFS="$old_ifs"
echo "SUMMARY: m036-p03-p02-regression-pass.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

(Note: 14 gates; the 15th P02 gate `m036-p02-tier-2-deferred-error.sh` is intentionally excluded — its semantics flip in P03, replaced by `m036-p03-tier-2-deferred-error-removed.sh`.)

**4f.** `tools/verify/m036-p03-fixture-canned-structured-shape.sh` (presence check; canned files land in T04 — verifier authored in T03 because the fixture-shape check needs to assert in this same task's scope; goes green at T04 close per cross-task ordering):

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-fixture-canned-structured-shape.sh -- M036 P03 T03.
# Asserts the two canned-structured fixtures exist (T04 authors them).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FX="$ROOT/tests/fixtures/m036-p03-tier-2"
fail=0
for f in canned-structured.md canned-structured-low-fidelity.md; do
  if [ -f "$FX/$f" ]; then
    echo "PASS: exists $FX/$f"
  else
    echo "FAIL: missing $FX/$f"
    fail=$((fail + 1))
  fi
done
echo "SUMMARY: m036-p03-fixture-canned-structured-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all six new verifiers executable.

## Must-Haves

- The Tier 2 fidelity-gate helper exposes `extract_tier_2_invoke_gate` + `extract_tier_2_promote_or_retain`.
- A Tier 2 extraction PASS path produces `.structured.md` in chunk-store + `pass.md` in `_extraction-log`.
- A Tier 2 extraction BLOCK path produces `block.md` in `_extraction-log` and does NOT promote `.structured.md`.
- `summary_mode: auto` no longer hard-errors when `tier: 2`.
- Backwards compatibility: 14/15 P02 verifiers continue to pass.

## Verification

```bash
bash tools/verify/m036-p03-gate-helper-shape.sh
```

```bash
bash tools/verify/m036-p03-tier-2-deferred-error-removed.sh
```

```bash
bash tools/verify/m036-p03-tier-2-pass-end-to-end.sh
```

```bash
bash tools/verify/m036-p03-tier-2-block-retention.sh
```

```bash
bash tools/verify/m036-p03-p02-regression-pass.sh
```

```bash
bash tools/verify/m036-p03-driver-tier-2-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/extract-tier-2-llm.sh` (from T02)
  - Key API: `extract_tier_2_dispatch <input> <out> <category> <cite_id>` (returns 0|1; emits stub metrics on stderr as NAME=VALUE pairs); `extract_tier_2_emit_unit_close <cite_id> <model> <tokens_in> <tokens_out> <cost_usd> <quality_score>` (appends JSONL to `${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl`).
- `templates/conversus-presets/tier-2-fidelity.yml` (from T01) — preset name slug `tier-2-fidelity` is the contract passed to `conversus.sh gate <preset> ...`.
- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` + `sample.md` (from T01).

### From Disk (Pre-existing)

- `scripts/knowledge/extract-reference.sh` — P02 driver. T03 modifies it (sources two new helpers; adds Tier 2 dispatch block; new EXTRACTED/BLOCKED stdout shape).
- `scripts/knowledge/lib/extract-tier-0-summary.sh` — P02 lib. T03 modifies the `auto)` branch to return the `__TIER_2_AUTO__` sentinel for tier=2.
- `scripts/dispatch/adapters/tool/conversus.sh` — Tier 2 gate adapter. Subcommand contract: `gate <preset> <artifact> <output>` → exit 0 on PASS, 2 on BLOCK, 1 on adapter error. `parse-verdict <gate-result>` → emits `verdict=PASS|BLOCK`. Stub mode: `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS|BLOCK`. The TODO-marker preflight check is bypassed via `CONVERSUS_GATE_SKIP_TODO_CHECK=1` in the gate helper.
- `scripts/integrations/github-common.sh::emit_tier1_record` — JSONL convention reference (single-line, fields include `event`, `source: "runtime"`, ISO 8601 timestamp). T02's emitter uses the same convention.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (test fixtures markdown-only; conversus invocation in tests uses `CONVERSUS_STUB=1`; no live LLM).
- CON-4 (idempotency — Tier 2 PASS path must be idempotent: re-running with unchanged source produces zero diff. The content-hash gate at line 112 of the existing driver covers this; T03 does not bypass it).
- CON-6 (explicit-tier-upgrade-determinism — Tier 2 only triggers via explicit `summary_mode: auto + tier: 2` declaration in the manifest, not lazy at dispatch-time).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- The driver edit must NOT affect operator|stub paths — verified by `m036-p03-p02-regression-pass.sh`.
- `grep -qF -e "$pat"` form throughout.
- The `bash -c '...'` style is forbidden by AD-19 / AP-009 (compound-chain-gt2). All driver edits use direct `if`/`case` blocks; helpers are sourced + invoked as functions.
- The `set +e` ... `rc=$?` ... `set -e` pattern is used to capture non-zero exits without aborting the loop (specifically around `extract_tier_2_invoke_gate` which legitimately exits 2 on BLOCK). This pattern is verbatim from M036/P02's `m036-p02-tier-2-deferred-error.sh` and is the canonical M036 shape for capturing distinguished non-zero exits.

## Expected Output

After T03 completes:

- `scripts/knowledge/lib/extract-tier-2-gate.sh` exists, executable.
- `scripts/knowledge/lib/extract-tier-0-summary.sh` modified — auto+tier=2 returns sentinel; auto+tier!=2 still deferral-errors.
- `scripts/knowledge/extract-reference.sh` modified — sources two new helpers; per-doc loop dispatches Tier 2 helper chain when summary_text matches the sentinel; emits BLOCKED: on BLOCK, EXTRACTED: with `verdict=PASS` on PASS, EXTRACTED: unchanged on operator|stub.
- 6 new executable verifiers under `tools/verify/m036-p03-*`.
- 5 of 6 verifiers exit 0 at T03-close; `m036-p03-fixture-canned-structured-shape.sh` exits 1 until T04 lands the canned fixtures (cross-task ordering — auto-loop carries it forward).
- `m036-p03-driver-tier-2-shape.sh` (authored in T02 plan but listed in T03 verification) now exits 0 because the driver carries the new sources + function calls.

## Notes

The driver's `set +e ... set -e` block around `extract_tier_2_invoke_gate` captures the BLOCK exit code (2) without aborting the loop. The driver itself exits 0 even when the gate returns BLOCK — BLOCK is a verdict, not a driver error. This matches the conversus adapter's documented exit-code contract (`gate` exits 2 on BLOCK; the caller decides whether BLOCK is fatal).

The choice to write a `tier_2_verdict:` field into the chunk frontmatter (rather than only into the verdict file) makes downstream graph traversal able to filter for PASS vs BLOCK chunks without having to walk into `_extraction-log/`. Trade-off: BLOCK chunks have a Tier 0 entry on disk (with the placeholder summary) but no `.structured.md` — the verdict field is the discriminator.

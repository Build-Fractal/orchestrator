---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M036"
name: "Tier 2 LLM dispatch helper + unit_close emitter (mockable; no live LLM in CI)"
depends_on: ["T01"]
---

## Prerequisites

- T01 closed: `templates/conversus-presets/tier-2-fidelity.yml` exists, `templates/model-routing.yml` carries `task_type.extraction: smart` for claude-code, `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` + `sample.md` exist.
- P02 driver `scripts/knowledge/extract-reference.sh` exists and sources `scripts/knowledge/lib/extract-tier-0-summary.sh`.
- `scripts/dispatch/select-model.sh` exists (M030 P01).

Verified at plan-authoring time: all five files present.

## Description

Author a pure helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` (MEM004 — args-in / stdout+exit-out / no top-level I/O) that:

1. Performs the Tier 2 LLM extraction call (live mode — uses `select-model.sh` for `task_type=extraction` resolution; **NOT exercised in CI per CON-3**) OR routes to a deterministic fixture when `EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block`.
2. Emits an M030-shape `unit_close` JSONL record with `task_type=extraction`, `model`, `tokens_in`, `tokens_out`, `cost_usd`, `quality_score` to `${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl`.

Three verifiers under `tools/verify/m036-p03-*` (driver shape, unit_close shape, llm-helper shape).

## Steps

### Step 1 — Author `scripts/knowledge/lib/extract-tier-2-llm.sh`

Create `scripts/knowledge/lib/extract-tier-2-llm.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/extract-tier-2-llm.sh -- M036 P03 T02 helper.
# Pure functions for Tier 2 LLM extraction dispatch + unit_close emission.
# Sourced by scripts/knowledge/extract-reference.sh. No top-level I/O
# (MEM004 pure-lib pattern). Bash 3.2 / POSIX-sh per CON-2.
#
# Mock contract (CON-3: no live LLM in CI):
#   EXTRACT_TIER_2_DISPATCH=live          (default) — call M030 + LLM
#   EXTRACT_TIER_2_DISPATCH=stub:pass     — copy canned-structured.md to <out>
#   EXTRACT_TIER_2_DISPATCH=stub:block    — copy canned-structured-low-fidelity.md
#
# In stub modes the helper emits stub model/token/cost values to stderr
# in NAME=VALUE form (one pair per line) so the driver can parse them
# back into unit_close fields.

# extract_tier_2_dispatch <input-path> <out-path> <category> <cite_id>
#   Returns 0 on success, 1 on error.
#   Always emits to stderr (one pair per line, NAME=VALUE form):
#     MODEL=<model-id>
#     TOKENS_IN=<n>
#     TOKENS_OUT=<n>
#     COST_USD=<float>
#     QUALITY_SCORE=<float>
extract_tier_2_dispatch() {
  local input="$1"
  local out="$2"
  local category="$3"
  local cite_id="$4"
  local mode="${EXTRACT_TIER_2_DISPATCH:-live}"
  local fx_dir="${ORCHESTRATOR_ROOT:-$(pwd)}/tests/fixtures/m036-p03-tier-2"
  case "$mode" in
    stub:pass)
      if [ ! -f "$fx_dir/canned-structured.md" ]; then
        echo "extract_tier_2_dispatch: canned-structured.md missing at $fx_dir" >&2
        return 1
      fi
      cp "$fx_dir/canned-structured.md" "$out"
      printf 'MODEL=claude-haiku-4-5\nTOKENS_IN=512\nTOKENS_OUT=2048\nCOST_USD=0.0123\nQUALITY_SCORE=0.92\n' >&2
      return 0
      ;;
    stub:block)
      if [ ! -f "$fx_dir/canned-structured-low-fidelity.md" ]; then
        echo "extract_tier_2_dispatch: canned-structured-low-fidelity.md missing at $fx_dir" >&2
        return 1
      fi
      cp "$fx_dir/canned-structured-low-fidelity.md" "$out"
      printf 'MODEL=claude-haiku-4-5\nTOKENS_IN=512\nTOKENS_OUT=1800\nCOST_USD=0.0119\nQUALITY_SCORE=0.61\n' >&2
      return 0
      ;;
    live)
      # Live path: route through M030, dispatch LLM, write structured-md.
      # NOT exercised in CI per CON-3. Implementation surface:
      #   - resolve model via select-model.sh against task_type=extraction
      #   - call backend dispatch with the source text + extraction prompt
      #   - persist real model+tokens+cost values for the unit_close record
      echo "extract_tier_2_dispatch: live mode not yet implemented (use EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block in CI)" >&2
      return 1
      ;;
    *)
      echo "extract_tier_2_dispatch: unknown mode '$mode' (expected: live|stub:pass|stub:block)" >&2
      return 1
      ;;
  esac
}

# extract_tier_2_emit_unit_close <cite_id> <model> <tokens_in> <tokens_out> <cost_usd> <quality_score>
#   Appends one JSONL record to ${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl.
#   Returns 0 on success, 1 on error.
extract_tier_2_emit_unit_close() {
  local cite_id="$1"
  local model="$2"
  local tokens_in="$3"
  local tokens_out="$4"
  local cost_usd="$5"
  local quality_score="$6"
  local root="${ORCHESTRATOR_ROOT:-$(pwd)}"
  local log="$root/.orchestrator/execution-log.jsonl"
  mkdir -p "$(dirname "$log")"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '{"event":"unit_close","task_type":"extraction","cite_id":"%s","model":"%s","tokens_in":%s,"tokens_out":%s,"cost_usd":%s,"quality_score":%s,"timestamp":"%s","source":"runtime"}\n' \
    "$cite_id" "$model" "$tokens_in" "$tokens_out" "$cost_usd" "$quality_score" "$ts" >> "$log"
}
```

Make it executable: `chmod +x scripts/knowledge/lib/extract-tier-2-llm.sh`.

### Step 2 — Author `tools/verify/m036-p03-tier-2-llm-helper-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-tier-2-llm-helper-shape.sh -- M036 P03 T02.
# Asserts the Tier 2 LLM helper exists, executable, exposes the two
# documented functions, and honors the EXTRACT_TIER_2_DISPATCH env var.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
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
checkpat "extract_tier_2_dispatch()"
checkpat "extract_tier_2_emit_unit_close()"
checkpat "EXTRACT_TIER_2_DISPATCH"
checkpat "stub:pass"
checkpat "stub:block"
checkpat "task_type"
echo "SUMMARY: m036-p03-tier-2-llm-helper-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 3 — Author `tools/verify/m036-p03-driver-tier-2-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-driver-tier-2-shape.sh -- M036 P03 T02.
# Asserts that scripts/knowledge/extract-reference.sh sources both new
# helpers (extract-tier-2-llm.sh + extract-tier-2-gate.sh authored in
# T03) and references the Tier 2 dispatch path. Cross-task ordering
# note: this verifier passes after T03 lands the gate helper +
# driver edits; T02 is responsible only for the llm helper part.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
DRV="$ROOT/scripts/knowledge/extract-reference.sh"
fail=0
if [ ! -f "$DRV" ]; then
  echo "FAIL: driver missing $DRV"
  echo "SUMMARY: m036-p03-driver-tier-2-shape.sh fail=1"
  exit 1
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$DRV"; then
    echo "PASS: '$pat' in $(basename "$DRV")"
  else
    echo "FAIL: '$pat' missing in $(basename "$DRV")"
    fail=$((fail + 1))
  fi
}
checkpat "extract-tier-2-llm.sh"
checkpat "extract-tier-2-gate.sh"
checkpat "extract_tier_2_dispatch"
checkpat "extract_tier_2_invoke_gate"
checkpat "extract_tier_2_emit_unit_close"
checkpat "BLOCKED:"
echo "SUMMARY: m036-p03-driver-tier-2-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

### Step 4 — Author `tools/verify/m036-p03-unit-close-extraction-shape.sh`

```bash
#!/usr/bin/env bash
# tools/verify/m036-p03-unit-close-extraction-shape.sh -- M036 P03 T02.
# Drives extract_tier_2_emit_unit_close in a mktemp -d workspace and
# asserts the resulting JSONL line carries the required M030 unit_close
# fields. Bash 3.2 / POSIX-sh per CON-2. Single-script-file shape.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
LIB="$ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/m036-p03-unitclose.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
if [ ! -f "$LIB" ]; then
  echo "FAIL: helper lib missing $LIB"
  echo "SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=1"
  exit 1
fi
# shellcheck disable=SC1090
. "$LIB"
ORCHESTRATOR_ROOT="$WORK" extract_tier_2_emit_unit_close "verifier-cite-01" "claude-haiku-4-5" 100 200 0.005 0.95
LOG="$WORK/.orchestrator/execution-log.jsonl"
if [ ! -f "$LOG" ]; then
  echo "FAIL: log not created at $LOG"
  fail=$((fail + 1))
else
  echo "PASS: log created at $LOG"
fi
checkpat() {
  local pat="$1"
  if grep -qF -e "$pat" "$LOG"; then
    echo "PASS: '$pat' in unit_close JSONL"
  else
    echo "FAIL: '$pat' missing in unit_close JSONL"
    fail=$((fail + 1))
  fi
}
checkpat '"event":"unit_close"'
checkpat '"task_type":"extraction"'
checkpat '"model":"claude-haiku-4-5"'
checkpat '"cite_id":"verifier-cite-01"'
checkpat '"cost_usd":0.005'
checkpat '"tokens_in":100'
checkpat '"tokens_out":200'
echo "SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
```

Make all three verifiers executable: `chmod +x tools/verify/m036-p03-{tier-2-llm-helper-shape,driver-tier-2-shape,unit-close-extraction-shape}.sh`.

## Must-Haves

- The Tier 2 helper lib `scripts/knowledge/lib/extract-tier-2-llm.sh` exposes `extract_tier_2_dispatch` (mockable via `EXTRACT_TIER_2_DISPATCH`) and `extract_tier_2_emit_unit_close`.
- Each Tier 2 invocation appends one well-formed `unit_close` JSONL record with `task_type=extraction`, `model`, `tokens_in`, `tokens_out`, `cost_usd`, `quality_score`.

## Verification

```bash
bash tools/verify/m036-p03-tier-2-llm-helper-shape.sh
```

```bash
bash tools/verify/m036-p03-unit-close-extraction-shape.sh
```

(Note: `m036-p03-driver-tier-2-shape.sh` is authored in T02 but exercises driver edits that land in T03 — under the cross-task-ordering pattern carried from M036/P02, this verifier goes green retroactively at T03 close. Listed in T03's verification block, not T02's, so the auto-loop's first-fail-retry doesn't pause T02 incorrectly.)

## Inputs

### From Previous Tasks

- `tests/fixtures/m036-p03-tier-2/extract-manifest.yaml` (from T01)
  - Key API: declares one tier-2 doc with `summary_mode: auto` + cite_id `tier2-fixture-01`. Source path: `sample.md` (markdown — CON-3).

### From Disk (Pre-existing)

- `scripts/dispatch/select-model.sh` — M030 model resolver. Live-path uses it; not exercised in CI.
- `scripts/knowledge/extract-reference.sh` — P02 driver. T02 does NOT modify it; T03 will (sources the new helper + adds Tier 2 dispatch).
- `scripts/knowledge/lib/extract-binary-preservation.sh` — provides `preservation_sha256` (used by the P02 driver for content-hash idempotency; the live-path Tier 2 helper would re-use it but the live path is deferred).
- `scripts/dispatch/adapters/tool/conversus.sh` — invoked by T03's gate helper, not by T02's llm helper.

## Constraints

- CON-2 (Bash 3.2 / POSIX-sh).
- CON-3 (no live LLM in CI — `extract_tier_2_dispatch` returns error 1 in `live` mode for now; CI uses stub modes).
- MEM004 (pure-lib pattern: args-in / stdout+exit-out / no top-level I/O — the lib has only function definitions).
- AD-19 single-script-file shape for verifier `Check:` invocations.
- Verifier filename milestone-prefixed slug `m036-p03-*`.
- `grep -qF -e "$pat"` form throughout (BSD-grep flag-safety carried from M036/P02).
- The `unit_close` JSONL record format MUST match the existing emitter convention used by `scripts/integrations/github-common.sh::emit_tier1_record` (single-line JSONL, fields: `event`, `source`, `timestamp`, plus task-specific fields). The M036/P03 record adds `task_type` + `cite_id` + `model` + `tokens_in` + `tokens_out` + `cost_usd` + `quality_score`.

## Expected Output

After T02 completes:

- `scripts/knowledge/lib/extract-tier-2-llm.sh` exists (~80 lines), executable, sources cleanly with no top-level I/O.
- 3 new executable verifiers under `tools/verify/m036-p03-*`.
- `m036-p03-tier-2-llm-helper-shape.sh` and `m036-p03-unit-close-extraction-shape.sh` exit 0.
- `m036-p03-driver-tier-2-shape.sh` may FAIL at T02-close (driver not yet edited) and goes green at T03-close. Documented under cross-task-ordering.

## Notes

The `live` branch is intentionally a stub error in T02 because:
1. CON-3 forbids live LLM in CI — the live path can never be exercised by the auto-loop or phase-suite.
2. The live-path implementation requires choosing a backend dispatch surface (subprocess `claude -p`, MCP, conversus run, etc.) that is out of scope for the M036a critical path. PBJ pilot uses the stub path with operator-supplied summaries authored in advance.
3. M036b (post-launch) will land the live extraction path with operator-facing UX (queue, retry, etc.) — the stub seam in T02 is the future-extension point.

The decision to ship `live` as a stub-error is captured here in the plan body rather than in `.orchestrator/DECISIONS.md` because it's an implementation seam (re-openable when M036b plans), not a load-bearing architectural commitment.

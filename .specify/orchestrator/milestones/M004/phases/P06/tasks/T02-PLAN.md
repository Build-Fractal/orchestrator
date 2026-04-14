---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M004"
name: "Integrate record-result.sh with run_id and error_kind"
depends_on: [T01]
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# P02 libraries exist
test -f scripts/lib/errors.sh && echo "ok: errors.sh"
test -f scripts/lib/events.sh && echo "ok: events.sh"

# Target script exists
test -f scripts/lifecycle/record-result.sh && echo "ok: record-result.sh"

# T01 complete: check-must-haves.sh has been integrated
grep -q 'emit_result' scripts/verify/check-must-haves.sh && echo "ok: T01 complete"
```

All must print `ok:`. If any fail, STOP.

## Description

Add engine integration to `scripts/lifecycle/record-result.sh`. This script appends structured JSON lines to execution-log.jsonl files. The changes are:

1. Source `lib/errors.sh` and `lib/events.sh` near the top.
2. Add a new optional `--error_kind=<KIND>` argument. When provided, validate it against the closed error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) and include it in the JSONL entry.
3. When `ORCH_RUN_ID` is set (engine mode), add a `"run_id":"<value>"` field to every JSONL entry.
4. Emit `TASK_COMPLETE` event to stderr when a record is successfully appended (engine mode only).
5. Emit `emit_result` to stderr via EXIT trap (engine mode only).
6. Preserve the existing stdout output: `RECORD:APPENDED <log-file>`.

This implements US8/AS3 (record-result.sh records error_kind), US9/AS2 (JSONL entries include run_id), and US4/AS1 (every engine-managed script emits at least one event).

## Cross-Cutting Constraints (verbatim from P06-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **Standalone safety (NFR-204)** -- wrap event/result calls in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`.
3. **Source libs near the top** -- after shebang + comment + set -euo pipefail.
4. **emit_result on exit via trap** -- result goes to stderr (stdout is RECORD:APPENDED).
5. **emit_event at key points** -- TASK_COMPLETE after successful append.
6. **No jq.**
7. **Do not modify P02 libraries or P05 scripts.**
8. **Existing test suites must not break** -- RECORD:APPENDED output, exit codes, all existing arguments preserved.

## Steps

### Step 1: Read the current record-result.sh

Read `scripts/lifecycle/record-result.sh` in full. Currently 185 lines. Key structure:
- Argument parsing (lines 38-90): positional `<execution-log>` + named `--milestone=`, `--phase=`, `--task=`, `--outcome=`, plus optional telemetry flags.
- Validation (lines 92-111): required field checks, outcome enum check.
- JSON construction (lines 113-173): builds JSON string with printf.
- File write (lines 175-184): mkdir -p + echo >> + "RECORD:APPENDED" output.

### Step 2: Add library sourcing

After `set -euo pipefail` (line 35), add:

```bash
# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"
```

### Step 3: Add EXIT trap for result emission

After the library sourcing block:

```bash
# --- Result emission on exit (stderr, not stdout) ---
_RR_RESULT_EMITTED=0
_rr_final_result() {
  local rc=$?
  if [ "$_RR_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "record appended" >&2
    else
      emit_result error IO "record-result failed rc=$rc" >&2
    fi
    _RR_RESULT_EMITTED=1
  fi
}
trap _rr_final_result EXIT
```

### Step 4: Add --error_kind argument

In the argument parsing `while` loop, add a new case:

```bash
--error_kind=*) ERROR_KIND="${1#--error_kind=}" ;;
```

Initialize `ERROR_KIND=""` with the other variable declarations.

After argument parsing, validate error_kind if provided:

```bash
if [ -n "$ERROR_KIND" ]; then
  if ! orch_is_error_kind "$ERROR_KIND"; then
    echo "record-result.sh: invalid error_kind: $ERROR_KIND (expected: CONFIG|STATE|DISPATCH|VERIFY|BUDGET|IO)" >&2
    exit 1
  fi
fi
```

### Step 5: Add run_id and error_kind to JSON construction

In the JSON building section (after line 128 where `"attempt":${ATTEMPT}` is added), add:

```bash
# Engine fields (optional, added only when ORCH_RUN_ID is set)
if [ -n "${ORCH_RUN_ID:-}" ]; then
  json="${json},\"run_id\":\"${ORCH_RUN_ID}\""
fi

if [ -n "$ERROR_KIND" ]; then
  json="${json},\"error_kind\":\"${ERROR_KIND}\""
fi
```

### Step 6: Add event emission after successful append

After the `echo "$json" >> "$EXECUTION_LOG"` line and before the `echo "RECORD:APPENDED"` line, add:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event TASK_COMPLETE stage=record_result unit="$UNIT_ID" outcome="$OUTCOME" >&2
fi
```

### Step 7: Verify the changes

Run from repo root:

```bash
# 1. Standalone mode: same output, no events
unset ORCH_RUN_ID
tmp=$(mktemp)
bash scripts/lifecycle/record-result.sh "$tmp" --milestone=M001 --phase=P01 --task=T01 --outcome=success 2>/tmp/rr-stderr.txt
echo "stdout:"; cat "$tmp"
echo "stderr:"; cat /tmp/rr-stderr.txt
# stdout should have JSON without run_id; stderr should be empty (no EVENT/RESULT)
! grep -q 'run_id' "$tmp" && echo "standalone: no run_id ok"
! grep -q 'EVENT:\|RESULT:' /tmp/rr-stderr.txt && echo "standalone: no events ok"
rm -f "$tmp"

# 2. Engine mode: run_id present, events emitted
export ORCH_RUN_ID="test-run-002"
export ORCH_STARTED_AT="2026-04-13T00:00:00Z"
tmp=$(mktemp)
bash scripts/lifecycle/record-result.sh "$tmp" --milestone=M001 --phase=P01 --task=T01 --outcome=failure --error_kind=CONFIG 2>/tmp/rr-stderr.txt
grep -q '"run_id":"test-run-002"' "$tmp" && echo "engine: run_id present"
grep -q '"error_kind":"CONFIG"' "$tmp" && echo "engine: error_kind present"
grep -q 'EVENT:TASK_COMPLETE' /tmp/rr-stderr.txt && echo "engine: event emitted"
grep -q 'RESULT:' /tmp/rr-stderr.txt && echo "engine: result emitted"
rm -f "$tmp"

# 3. Verification helpers pass
bash scripts/verify/m004-p06-record-result-runid.sh
bash scripts/verify/m004-p06-record-result-errorkind.sh
```

## Must-Haves

### Truths

- record-result.sh sources lib/errors.sh and lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-errors.sh`
- record-result.sh adds run_id to JSONL entries when ORCH_RUN_ID is set
  - Check: `bash scripts/verify/m004-p06-record-result-runid.sh`
- record-result.sh adds error_kind to JSONL entries
  - Check: `bash scripts/verify/m004-p06-record-result-errorkind.sh`
- record-result.sh calls emit_result
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`
- record-result.sh calls emit_event
  - Check: `bash scripts/verify/m004-p06-emit-event.sh`

### Artifacts

- `scripts/lifecycle/record-result.sh` (min 100 lines, contains "run_id")

## Verification

Run from repo root:
1. `bash scripts/verify/m004-p06-record-result-runid.sh` -- PASS
2. `bash scripts/verify/m004-p06-record-result-errorkind.sh` -- PASS
3. `grep -q 'emit_result' scripts/lifecycle/record-result.sh` -- exits 0
4. `grep -q 'emit_event' scripts/lifecycle/record-result.sh` -- exits 0

## Inputs

### From Previous Tasks

- T01 must be complete (check-must-haves.sh fixed) so that phase-level verification can run correctly.

**API surface from T01:** No direct code dependency. T01 fixes check-must-haves.sh which is used by the orchestrator to verify this task's truths, but T02 does not import or call check-must-haves.sh.

### From Disk

- `scripts/lifecycle/record-result.sh` -- the file to modify. Currently 185 lines. Accepts `<execution-log>` positional arg + named flags. Outputs `RECORD:APPENDED <path>` on stdout. Exits 0 on success, 1 on invalid args.
- `scripts/lib/errors.sh` -- P02 library. Provides `emit_result <status> [error_kind] [detail]` and `orch_is_error_kind <value>`. Double-sourcing guarded.
- `scripts/lib/events.sh` -- P02 library. Provides `emit_event <TYPE> [key=value ...]`. Double-sourcing guarded.

## Constraints

- `RECORD:APPENDED <path>` stdout output must not change.
- All existing arguments must continue to work unchanged.
- Exit codes: 0 on success, 1 on invalid args.
- `run_id` field must NOT appear in JSONL when `ORCH_RUN_ID` is unset (standalone mode).
- `error_kind` field must NOT appear in JSONL when `--error_kind` is not provided.
- EVENT and RESULT lines go to stderr only, never stdout.

## Expected Output

- Modified `scripts/lifecycle/record-result.sh` with:
  - `lib/errors.sh` and `lib/events.sh` sourced near top
  - New `--error_kind=<KIND>` optional argument with taxonomy validation
  - `run_id` field in JSONL when ORCH_RUN_ID is set
  - `error_kind` field in JSONL when provided
  - EXIT trap emitting `emit_result` to stderr when ORCH_RUN_ID is set
  - `emit_event TASK_COMPLETE` to stderr after successful append when ORCH_RUN_ID is set
  - Identical standalone behavior

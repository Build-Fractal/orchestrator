---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M004"
name: "Integrate telemetry scripts (record-telemetry.sh + aggregate-metrics.sh)"
depends_on: [T01]
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# P02 libraries exist
test -f scripts/lib/errors.sh && echo "ok: errors.sh"
test -f scripts/lib/events.sh && echo "ok: events.sh"

# Target scripts exist
test -f scripts/telemetry/record-telemetry.sh && echo "ok: record-telemetry.sh"
test -f scripts/telemetry/aggregate-metrics.sh && echo "ok: aggregate-metrics.sh"

# T01 complete
grep -q 'emit_result' scripts/verify/check-must-haves.sh && echo "ok: T01 complete"
```

All must print `ok:`. If any fail, STOP.

## Description

Add engine integration to both telemetry scripts: `scripts/telemetry/record-telemetry.sh` and `scripts/telemetry/aggregate-metrics.sh`.

**record-telemetry.sh changes:**
1. Source `lib/errors.sh` and `lib/events.sh`.
2. When `ORCH_RUN_ID` is set, include a `"run_id"` field in the JSONL entry (US9/AS2).
3. Emit `TASK_COMPLETE stage=record_telemetry` event to stderr after successful append (engine mode only).
4. Emit `emit_result` to stderr via EXIT trap (engine mode only).
5. Preserve existing `TELEMETRY:RECORDED <path>` stdout output.

**aggregate-metrics.sh changes:**
1. Source `lib/errors.sh` and `lib/events.sh`.
2. Add `error_kind` grouping to both text and JSON output formats (US8/AS4). Read `error_kind` from dispatch entries in the JSONL (the field was added by T02's record-result.sh changes). Produce a "By Error Kind" section in text output and a `"by_error_kind"` object in JSON output.
3. Emit `TASK_COMPLETE stage=aggregate_metrics` event to stderr after aggregation (engine mode only).
4. Emit `emit_result` to stderr via EXIT trap (engine mode only).
5. Preserve all existing output formats, argument parsing, and exit codes.

## Cross-Cutting Constraints (verbatim from P06-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **Standalone safety (NFR-204)** -- wrap event/result calls in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`.
3. **Source libs near the top** -- after shebang + comment + set -euo pipefail.
4. **emit_result on exit via trap** -- result goes to stderr.
5. **emit_event at key points** -- TASK_COMPLETE after main work is done.
6. **No jq.**
7. **Do not modify P02 libraries or P05 scripts.**
8. **Existing test suites must not break.**

## Steps

### Step 1: Read both target scripts

Read `scripts/telemetry/record-telemetry.sh` (currently 98 lines) and `scripts/telemetry/aggregate-metrics.sh` (currently 418 lines) in full.

**record-telemetry.sh structure:**
- Arg parsing (lines 29-61): positional `<execution-log>` + named flags.
- Validation (lines 63-78): required unit-id, cost_source enum.
- JSON construction (lines 80-94): builds JSON string.
- File write (lines 96-98): mkdir -p + echo >> + "TELEMETRY:RECORDED" output.

**aggregate-metrics.sh structure:**
- Helpers json_str_val/json_num_val (lines 20-29).
- Arg parsing (lines 31-54): positional `<execution-log>` + --milestone= + --format=.
- Line-by-line accumulation loop (lines 56-246): reads JSONL, separates telemetry from dispatch entries, accumulates counts/sums into temp files.
- Derived metrics computation (lines 248-269).
- Model stats collection (lines 271-283).
- Milestone stats (lines 285-309).
- Output formatting (lines 311-418): JSON or text.

### Step 2: Integrate record-telemetry.sh

After `set -euo pipefail` (line 27), add library sourcing:

```bash
# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"
```

Add EXIT trap:

```bash
_RT_RESULT_EMITTED=0
_rt_final_result() {
  local rc=$?
  if [ "$_RT_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "telemetry recorded" >&2
    else
      emit_result error IO "record-telemetry failed rc=$rc" >&2
    fi
    _RT_RESULT_EMITTED=1
  fi
}
trap _rt_final_result EXIT
```

Add `run_id` to JSON construction. In the JSON building section (after the initial `json="{...}"` line), add:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  json="${json%\}},\"run_id\":\"${ORCH_RUN_ID}\"}"
fi
```

Actually, since the JSON is built incrementally and closes with `json="${json}}"`, insert the run_id field before the closing brace. The cleanest approach: add it right before `json="${json}}"`:

```bash
# run_id from engine context
if [ -n "${ORCH_RUN_ID:-}" ]; then
  json="${json},\"run_id\":\"${ORCH_RUN_ID}\""
fi
json="${json}}"
```

After the `echo "TELEMETRY:RECORDED $EXECUTION_LOG"` line, add event emission:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event TASK_COMPLETE stage=record_telemetry unit="$UNIT_ID" >&2
fi
```

### Step 3: Integrate aggregate-metrics.sh

After `set -euo pipefail` (line 17), add library sourcing:

```bash
# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"
```

Add EXIT trap (note: this script already has a `trap 'rm -rf ...' EXIT` for temp dirs, so the new trap must chain with it):

```bash
_AM_RESULT_EMITTED=0
_am_final_result() {
  local rc=$?
  if [ "$_AM_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "metrics aggregated" >&2
    else
      emit_result error IO "aggregate-metrics failed rc=$rc" >&2
    fi
    _AM_RESULT_EMITTED=1
  fi
}
```

Then modify the existing `trap` line (line 78) to chain:

```bash
trap 'rm -rf "$MODEL_TMPDIR" "$MILESTONE_TMPDIR"; _am_final_result' EXIT
```

Add error_kind tracking variables alongside the existing accumulation variables (near line 66):

```bash
# Error kind tracking (US8/AS4)
ERRORKIND_TMPDIR="$(mktemp -d)"
```

Update the trap to clean it up too:

```bash
trap 'rm -rf "$MODEL_TMPDIR" "$MILESTONE_TMPDIR" "$ERRORKIND_TMPDIR"; _am_final_result' EXIT
```

In the dispatch entry processing branch of the main loop (the `else` branch, around line 184), after the `outcome` extraction, add error_kind accumulation:

```bash
    # Error kind tracking
    ek_val="$(json_str_val "$line" "error_kind")"
    if [ -n "$ek_val" ]; then
      safe_ek="$(printf '%s' "$ek_val" | sed 's/[^a-zA-Z0-9._-]/_/g')"
      ek_file="${ERRORKIND_TMPDIR}/${safe_ek}"
      if [ -f "$ek_file" ]; then
        old_ek_count=$(cat "$ek_file")
      else
        old_ek_count=0
      fi
      printf '%d' "$((old_ek_count + 1))" > "$ek_file"
    fi
```

In the text output section, after the "By Cost Source" block, add:

```bash
  # By Error Kind (US8/AS4)
  ek_total=0
  ek_lines=""
  for ekfile in "$ERRORKIND_TMPDIR"/*; do
    [ -f "$ekfile" ] || continue
    ek_name="$(basename "$ekfile")"
    ek_count=$(cat "$ekfile")
    ek_total=$((ek_total + ek_count))
    if [ -n "$ek_lines" ]; then
      ek_lines="${ek_lines}
"
    fi
    ek_lines="${ek_lines}${ek_name}	${ek_count}"
  done
  if [ "$ek_total" -gt 0 ]; then
    echo ""
    echo "--- By Error Kind ---"
    printf '%s\n' "$ek_lines" | sort | while IFS='	' read -r ek_name ek_count; do
      printf '%-15s %d failures\n' "${ek_name}:" "$ek_count"
    done
  fi
```

In the JSON output section, before the final `json="${json}}"`, add:

```bash
  # Error kind breakdown
  json="${json},\"by_error_kind\":{"
  ek_json=""
  first_ek=1
  for ekfile in "$ERRORKIND_TMPDIR"/*; do
    [ -f "$ekfile" ] || continue
    ek_name="$(basename "$ekfile")"
    ek_count=$(cat "$ekfile")
    if [ $first_ek -eq 0 ]; then
      ek_json="${ek_json},"
    fi
    ek_json="${ek_json}\"${ek_name}\":${ek_count}"
    first_ek=0
  done
  json="${json}${ek_json}}"
```

After the final output (after the `fi` closing the format branch), add event emission:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event TASK_COMPLETE stage=aggregate_metrics dispatches="$total_dispatches" >&2
fi
```

### Step 4: Verify the changes

Run from repo root:

```bash
# 1. record-telemetry.sh standalone mode
unset ORCH_RUN_ID
tmp=$(mktemp)
bash scripts/telemetry/record-telemetry.sh "$tmp" --unit-id=M001/P01/T01 --model=test 2>/tmp/rt-stderr.txt
echo "stdout:"; cat "$tmp"
! grep -q 'run_id' "$tmp" && echo "standalone: no run_id"
! grep -q 'EVENT:\|RESULT:' /tmp/rt-stderr.txt && echo "standalone: no events"
rm -f "$tmp"

# 2. record-telemetry.sh engine mode
export ORCH_RUN_ID="test-run-003"
export ORCH_STARTED_AT="2026-04-13T00:00:00Z"
tmp=$(mktemp)
bash scripts/telemetry/record-telemetry.sh "$tmp" --unit-id=M001/P01/T01 --model=test 2>/tmp/rt-stderr.txt
grep -q '"run_id":"test-run-003"' "$tmp" && echo "engine: run_id present"
grep -q 'EVENT:TASK_COMPLETE' /tmp/rt-stderr.txt && echo "engine: event emitted"
grep -q 'RESULT:' /tmp/rt-stderr.txt && echo "engine: result emitted"
rm -f "$tmp"

# 3. aggregate-metrics.sh with error_kind data
tmp=$(mktemp)
echo '{"timestamp":"2026-04-13T00:00:00Z","unitId":"M001/P01/T01","milestone":"M001","outcome":"failure","error_kind":"CONFIG","attempt":1}' >> "$tmp"
echo '{"timestamp":"2026-04-13T00:00:01Z","unitId":"M001/P01/T02","milestone":"M001","outcome":"failure","error_kind":"STATE","attempt":1}' >> "$tmp"
echo '{"timestamp":"2026-04-13T00:00:02Z","unitId":"M001/P01/T03","milestone":"M001","outcome":"success","attempt":1}' >> "$tmp"
bash scripts/telemetry/aggregate-metrics.sh "$tmp" --format=text 2>/dev/null | grep -q 'Error Kind' && echo "text: error_kind section present"
bash scripts/telemetry/aggregate-metrics.sh "$tmp" --format=json 2>/dev/null | grep -q 'by_error_kind' && echo "json: by_error_kind present"
rm -f "$tmp"

# 4. Verification helpers
bash scripts/verify/m004-p06-aggregate-errorkind.sh
```

## Must-Haves

### Truths

- record-telemetry.sh sources lib/errors.sh and lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-errors.sh`
- record-telemetry.sh calls emit_result
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`
- record-telemetry.sh calls emit_event
  - Check: `bash scripts/verify/m004-p06-emit-event.sh`
- aggregate-metrics.sh sources lib/errors.sh and lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-events.sh`
- aggregate-metrics.sh groups failures by error_kind
  - Check: `bash scripts/verify/m004-p06-aggregate-errorkind.sh`
- aggregate-metrics.sh calls emit_result
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`

### Artifacts

- `scripts/telemetry/record-telemetry.sh` (min 50 lines, contains "emit_event")
- `scripts/telemetry/aggregate-metrics.sh` (min 200 lines, contains "error_kind")

## Verification

Run from repo root:
1. `bash scripts/verify/m004-p06-aggregate-errorkind.sh` -- PASS
2. `grep -q 'emit_result' scripts/telemetry/record-telemetry.sh` -- exits 0
3. `grep -q 'emit_event' scripts/telemetry/record-telemetry.sh` -- exits 0
4. `grep -q 'emit_result' scripts/telemetry/aggregate-metrics.sh` -- exits 0
5. `grep -q 'error_kind' scripts/telemetry/aggregate-metrics.sh` -- exits 0

## Inputs

### From Previous Tasks

- T01 must be complete (check-must-haves.sh fixed for verification).
- T02 adds `error_kind` to record-result.sh JSONL entries. aggregate-metrics.sh reads these entries, so the `error_kind` field format must match. However, T03 does not depend on T02 being complete at integration time -- aggregate-metrics.sh simply reads whatever fields are present in JSONL data. The `error_kind` field is optional in the JSONL schema.

**API surface from T02:** JSONL entries may contain `"error_kind":"<KIND>"` field (one of: CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO). aggregate-metrics.sh reads this via `json_str_val "$line" "error_kind"`.

### From Disk

- `scripts/telemetry/record-telemetry.sh` -- file to modify. Currently 98 lines.
- `scripts/telemetry/aggregate-metrics.sh` -- file to modify. Currently 418 lines.
- `scripts/lib/errors.sh` -- P02 library. Provides `emit_result`, `orch_is_error_kind`.
- `scripts/lib/events.sh` -- P02 library. Provides `emit_event`.

## Constraints

- `TELEMETRY:RECORDED <path>` stdout output from record-telemetry.sh must not change.
- Text and JSON output formats from aggregate-metrics.sh must be backward-compatible (new sections/fields are additive).
- `run_id` in JSONL must NOT appear when ORCH_RUN_ID is unset.
- Exit codes preserved: 0 success, 1 invalid args, 2 file not found (aggregate-metrics.sh).
- EVENT and RESULT lines go to stderr only.
- Both scripts must handle JSONL entries that do NOT have `error_kind` (backward compatibility with existing logs).

## Expected Output

- Modified `scripts/telemetry/record-telemetry.sh` with lib sourcing, run_id in JSONL (engine mode), EXIT trap, event emission.
- Modified `scripts/telemetry/aggregate-metrics.sh` with lib sourcing, error_kind grouping in text and JSON output, EXIT trap, event emission.

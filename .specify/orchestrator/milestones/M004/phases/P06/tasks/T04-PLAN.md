---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M004"
name: "Integrate classify-complexity.sh and phase-transition.sh"
depends_on: [T01]
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# P02 libraries exist
test -f scripts/lib/errors.sh && echo "ok: errors.sh"
test -f scripts/lib/events.sh && echo "ok: events.sh"

# Target scripts exist
test -f scripts/dispatch/classify-complexity.sh && echo "ok: classify-complexity.sh"
test -f scripts/lifecycle/phase-transition.sh && echo "ok: phase-transition.sh"

# T01 complete
grep -q 'emit_result' scripts/verify/check-must-haves.sh && echo "ok: T01 complete"
```

All must print `ok:`. If any fail, STOP.

## Description

Add engine integration to the two remaining scripts: `scripts/dispatch/classify-complexity.sh` and `scripts/lifecycle/phase-transition.sh`.

**classify-complexity.sh changes:**
1. Source `lib/errors.sh` and `lib/events.sh` near the top.
2. Emit `DISPATCH_START stage=classify_complexity` event to stderr at script start (engine mode only).
3. Emit `emit_result` to stderr via EXIT trap (engine mode only).
4. Preserve existing stdout output: a single line containing "heavy", "standard", or "light".
5. The script currently sources `scripts/lib/recipe-parser.sh` conditionally (only when `--routing-config` is provided). The lib sourcing for errors.sh/events.sh must be unconditional.

**phase-transition.sh changes:**
1. Source `lib/errors.sh` and `lib/events.sh` near the top.
2. Emit `PHASE_START stage=transition` event to stderr at script start (engine mode only).
3. Emit `PHASE_COMPLETE stage=transition` event to stderr before the final `TRANSITION:READY` output (engine mode only).
4. Emit `emit_result` to stderr via EXIT trap (engine mode only).
5. Preserve existing stdout output: key=value pairs + `TRANSITION:READY` or `TRANSITION:WRITTEN` or `TRANSITION:ERROR`.

Note: The roadmap references `scripts/state/phase-transition.sh` but the actual location is `scripts/lifecycle/phase-transition.sh`. This task uses the actual location.

## Cross-Cutting Constraints (verbatim from P06-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **Standalone safety (NFR-204)** -- wrap event/result calls in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`.
3. **Source libs near the top** -- after shebang + comment + set -euo pipefail.
4. **emit_result on exit via trap** -- result goes to stderr (stdout is data output).
5. **emit_event at key points** -- at least one event per script.
6. **No jq.**
7. **Do not modify P02 libraries or P05 scripts.**
8. **Existing test suites must not break.**

## Steps

### Step 1: Read both target scripts

Read `scripts/dispatch/classify-complexity.sh` (currently 130 lines) and `scripts/lifecycle/phase-transition.sh` (currently 233 lines) in full.

**classify-complexity.sh structure:**
- Arg parsing (lines 18-29): positional `<task-plan-file>` + optional `--routing-config`.
- Explicit complexity check in YAML frontmatter (lines 36-43).
- Content read + lowercase (line 45).
- Signal counting (lines 48-121): custom patterns from routing config OR built-in keywords.
- Tier selection (lines 123-129): pick tier with most signals.

Key: This script conditionally sources `scripts/lib/recipe-parser.sh` (line 58) only when `--routing-config` is provided. The lib/errors.sh and lib/events.sh sourcing must be unconditional and placed before the argument parsing section.

**phase-transition.sh structure:**
- Arg parsing (lines 27-58): positional `<milestone-dir> <phase-id>` + optional flags.
- External modification check (lines 79-83).
- Task summary reading loop (lines 85-172): iterates T*-SUMMARY.md files.
- Derived field output (lines 174-187): key=value lines to stdout.
- Optional write mode (lines 189-225): writes P##-SUMMARY.md.
- Roadmap sync (lines 227-231).
- Final status (line 233): `TRANSITION:READY phase=P## fields_derived=N`.

### Step 2: Integrate classify-complexity.sh

After `set -euo pipefail` (line 18), before the arg parsing, add library sourcing:

```bash
# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"
```

Add EXIT trap:

```bash
_CC_RESULT_EMITTED=0
_cc_final_result() {
  local rc=$?
  if [ "$_CC_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "complexity classified" >&2
    else
      emit_result error DISPATCH "classify-complexity failed rc=$rc" >&2
    fi
    _CC_RESULT_EMITTED=1
  fi
}
trap _cc_final_result EXIT
```

After the `TASK_PLAN` validation (line 34), add event emission:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event DISPATCH_START stage=classify_complexity task_plan="$(basename "$TASK_PLAN")" >&2
fi
```

### Step 3: Integrate phase-transition.sh

After `set -euo pipefail` (line 18), add library sourcing:

```bash
# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"
```

Add EXIT trap:

```bash
_PT_RESULT_EMITTED=0
_pt_final_result() {
  local rc=$?
  if [ "$_PT_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "phase transition ready" >&2
    else
      emit_result error STATE "phase-transition failed rc=$rc" >&2
    fi
    _PT_RESULT_EMITTED=1
  fi
}
trap _pt_final_result EXIT
```

After the `PHASE_DIR` and `TASKS_DIR` variable assignment (lines 60-61), after the directory existence check, add event emission:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event PHASE_START stage=transition milestone="$MILESTONE_ID" phase="$PHASE_ID" >&2
fi
```

Note: `MILESTONE_ID` is derived later (line 69), so the PHASE_START event must be placed AFTER the milestone ID derivation block (after line 76). Adjust placement accordingly.

Before the final `echo "TRANSITION:READY ..."` line (line 233), add:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event PHASE_COMPLETE stage=transition phase="$PHASE_ID" task_count="$task_count" >&2
fi
```

### Step 4: Verify the changes

Run from repo root:

```bash
# 1. classify-complexity.sh standalone mode
unset ORCH_RUN_ID
result=$(bash scripts/dispatch/classify-complexity.sh tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md 2>/tmp/cc-stderr.txt)
echo "result: $result"
! grep -q 'EVENT:\|RESULT:' /tmp/cc-stderr.txt && echo "standalone: no events"

# 2. classify-complexity.sh engine mode
export ORCH_RUN_ID="test-run-004"
export ORCH_STARTED_AT="2026-04-13T00:00:00Z"
result=$(bash scripts/dispatch/classify-complexity.sh tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md 2>/tmp/cc-stderr.txt)
echo "result: $result"
grep -q 'EVENT:DISPATCH_START' /tmp/cc-stderr.txt && echo "engine: event emitted"
grep -q 'RESULT:' /tmp/cc-stderr.txt && echo "engine: result emitted"

# 3. phase-transition.sh standalone mode
unset ORCH_RUN_ID
bash scripts/lifecycle/phase-transition.sh .specify/orchestrator/milestones/M004 P05 2>/tmp/pt-stderr.txt | head -3
! grep -q 'EVENT:\|RESULT:' /tmp/pt-stderr.txt && echo "standalone: no events"

# 4. phase-transition.sh engine mode
export ORCH_RUN_ID="test-run-004"
export ORCH_STARTED_AT="2026-04-13T00:00:00Z"
bash scripts/lifecycle/phase-transition.sh .specify/orchestrator/milestones/M004 P05 2>/tmp/pt-stderr.txt | head -3
grep -q 'EVENT:PHASE_START' /tmp/pt-stderr.txt && echo "engine: start event emitted"
grep -q 'EVENT:PHASE_COMPLETE' /tmp/pt-stderr.txt && echo "engine: complete event emitted"
grep -q 'RESULT:' /tmp/pt-stderr.txt && echo "engine: result emitted"

# 5. Verification helpers
bash scripts/verify/m004-p06-sources-errors.sh
bash scripts/verify/m004-p06-emit-result.sh
bash scripts/verify/m004-p06-emit-event.sh
```

## Must-Haves

### Truths

- classify-complexity.sh sources lib/errors.sh and lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-errors.sh`
- classify-complexity.sh calls emit_result
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`
- classify-complexity.sh calls emit_event
  - Check: `bash scripts/verify/m004-p06-emit-event.sh`
- phase-transition.sh sources lib/errors.sh and lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-events.sh`
- phase-transition.sh calls emit_result
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`
- phase-transition.sh calls emit_event
  - Check: `bash scripts/verify/m004-p06-emit-event.sh`

### Artifacts

- `scripts/dispatch/classify-complexity.sh` (min 80 lines, contains "emit_result")
- `scripts/lifecycle/phase-transition.sh` (min 120 lines, contains "emit_event")

## Verification

Run from repo root:
1. `grep -q 'emit_result' scripts/dispatch/classify-complexity.sh` -- exits 0
2. `grep -q 'emit_event' scripts/dispatch/classify-complexity.sh` -- exits 0
3. `grep -q 'emit_result' scripts/lifecycle/phase-transition.sh` -- exits 0
4. `grep -q 'emit_event' scripts/lifecycle/phase-transition.sh` -- exits 0
5. `grep -q 'lib/errors\.sh' scripts/dispatch/classify-complexity.sh` -- exits 0
6. `grep -q 'lib/errors\.sh' scripts/lifecycle/phase-transition.sh` -- exits 0

## Inputs

### From Previous Tasks

- T01 must be complete (check-must-haves.sh fixed for verification).
- No direct code dependency on T02 or T03. These scripts do not read or write JSONL.

**API surface:** None. classify-complexity.sh and phase-transition.sh are independent of the telemetry/result scripts.

### From Disk

- `scripts/dispatch/classify-complexity.sh` -- file to modify. Currently 130 lines. Outputs a tier name ("heavy", "standard", or "light") on stdout. Exits 0 on success, 1 on missing args.
- `scripts/lifecycle/phase-transition.sh` -- file to modify. Currently 233 lines. Outputs key=value pairs + TRANSITION:READY on stdout. Exits 0 on success, 1 on usage error.
- `scripts/lib/errors.sh` -- P02 library. Provides `emit_result`.
- `scripts/lib/events.sh` -- P02 library. Provides `emit_event`.
- `tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md` -- test fixture for classify-complexity.sh smoke test.

## Constraints

- classify-complexity.sh stdout: exactly one line containing "heavy", "standard", or "light". No other stdout.
- phase-transition.sh stdout: key=value lines + TRANSITION:READY/WRITTEN/ERROR. No changes to this format.
- Exit codes preserved for both scripts.
- EVENT and RESULT lines go to stderr only.
- classify-complexity.sh's conditional sourcing of recipe-parser.sh (only when --routing-config is provided) must be preserved. The lib/errors.sh and lib/events.sh sourcing is separate and unconditional.
- phase-transition.sh uses `[[ ]]` bash-isms; this is existing code and acceptable for Bash 3.2 since `[[` is supported. Do NOT convert to `[ ]` -- preserve existing style.

## Expected Output

- Modified `scripts/dispatch/classify-complexity.sh` with lib sourcing, EXIT trap, DISPATCH_START event. Identical standalone behavior.
- Modified `scripts/lifecycle/phase-transition.sh` with lib sourcing, EXIT trap, PHASE_START and PHASE_COMPLETE events. Identical standalone behavior.

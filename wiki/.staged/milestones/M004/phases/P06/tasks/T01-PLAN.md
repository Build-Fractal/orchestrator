---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M004"
name: "Fix and Integrate check-must-haves.sh"
depends_on: []
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# P02 libraries exist
test -f scripts/lib/errors.sh && echo "ok: errors.sh"
test -f scripts/lib/events.sh && echo "ok: events.sh"

# Target script exists
test -f scripts/verify/check-must-haves.sh && echo "ok: check-must-haves.sh"

# extension.yml exists at repo root (used as root marker)
test -f extension.yml && echo "ok: extension.yml"
```

All must print `ok:`. If any fail, STOP.

## Description

Fix a known bug in `scripts/verify/check-must-haves.sh` where the PROJECT_ROOT detection algorithm walks up from the phase directory until it finds a parent named `phases`, then takes that parent's parent as the project root. This works for test fixtures (`tests/fixtures/verify-pass/phases/P01`) but fails for real orchestrator phase directories (`<repo>/.specify/orchestrator/milestones/M004/phases/P06/`) because it resolves to the milestone directory (`<repo>/.specify/orchestrator/milestones/M004/`) rather than the actual repo root.

After fixing the bug, add engine integration: source `lib/errors.sh` and `lib/events.sh`, emit a `VERIFY_START` event at the beginning, a `VERIFY_COMPLETE` event at the end, and an `emit_result` call on exit. All engine integration is wrapped in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi` so the script works identically in standalone mode.

This task implements US4/AS1 (every engine-managed script emits at least one event), US8/AS2 (all engine-managed scripts source lib/errors.sh and use emit_result), and fixes the P02 summary's documented PROJECT_ROOT bug.

## Cross-Cutting Constraints (verbatim from P06-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **Standalone safety (NFR-204)** -- wrap event/result calls in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`.
3. **Source libs near the top** -- after shebang + comment + set -euo pipefail.
4. **emit_result on exit via trap** -- result goes to stderr (stdout is PASS/FAIL lines).
5. **emit_event at key points** -- VERIFY_START at beginning, VERIFY_COMPLETE at end.
6. **No jq.**
7. **Do not modify P02 libraries or P05 scripts.**
8. **Existing test suites must not break** -- PASS/FAIL output format, exit codes unchanged.

## Steps

### Step 1: Read the current check-must-haves.sh

Read `scripts/verify/check-must-haves.sh` in full. Understand the current PROJECT_ROOT detection (lines 42-59) and the overall structure.

### Step 2: Fix the PROJECT_ROOT detection bug

Replace the current walk-up algorithm (lines 42-59) with a root-marker algorithm that walks up from the phase directory looking for `extension.yml` or `.git` as repo root markers. The new algorithm:

```bash
# Resolve project root: walk up from phase dir to find extension.yml or .git
PROJECT_ROOT=""
candidate="$(cd "$PHASE_DIR" && pwd)"
while [ "$candidate" != "/" ]; do
  if [ -f "$candidate/extension.yml" ] || [ -d "$candidate/.git" ]; then
    PROJECT_ROOT="$candidate"
    break
  fi
  candidate="$(dirname "$candidate")"
done

if [ -z "$PROJECT_ROOT" ]; then
  # Fallback for test fixtures: use the old walk-up-to-phases-parent logic
  candidate="$(cd "$PHASE_DIR" && pwd)"
  while [ "$candidate" != "/" ]; do
    parent_name="$(basename "$(dirname "$candidate")")"
    if [ "$parent_name" = "phases" ]; then
      PROJECT_ROOT="$(dirname "$(dirname "$candidate")")"
      break
    fi
    candidate="$(dirname "$candidate")"
  done
fi

if [ -z "$PROJECT_ROOT" ]; then
  # Last-resort fallback
  PROJECT_ROOT="$(cd "$PHASE_DIR/../.." 2>/dev/null && pwd)"
fi
```

This resolves to the actual repo root for `.specify/orchestrator/milestones/M004/phases/P06/` paths (because `extension.yml` is at repo root), and falls back to the old behavior for test fixtures that do not have `extension.yml` or `.git`.

### Step 3: Add library sourcing

After the `set -euo pipefail` line (line 12) and before argument validation, add:

```bash
# Engine integration libraries (standalone-safe)
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"
```

### Step 4: Add result emission via EXIT trap

After the library sourcing block, add an EXIT trap that emits a result to stderr when running under the engine:

```bash
# --- Result emission on exit (stderr, not stdout) ---
_CMH_RESULT_EMITTED=0
_cmh_final_result() {
  local rc=$?
  if [ "$_CMH_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "must-haves verified" >&2
    else
      emit_result error VERIFY "check-must-haves failed rc=$rc" >&2
    fi
    _CMH_RESULT_EMITTED=1
  fi
}
trap _cmh_final_result EXIT
```

### Step 5: Add event emission

After the plan file is found and validated (after the existing "Find the P##-PLAN.md file" block), add:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event VERIFY_START stage=check_must_haves plan="$(basename "$PLAN_FILE")" >&2
fi
```

Before the final exit block (line 204-208), add:

```bash
if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event VERIFY_COMPLETE stage=check_must_haves failures="$FAILURES" >&2
fi
```

### Step 6: Verify the changes

Run from repo root:

```bash
# 1. Standalone mode still works (no EVENT/RESULT lines on stderr)
unset ORCH_RUN_ID
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M004/phases/P05 2>/tmp/cmh-stderr.txt
# Should produce PASS/FAIL lines on stdout, no EVENT/RESULT on stderr
! grep -q 'EVENT:\|RESULT:' /tmp/cmh-stderr.txt && echo "standalone mode ok"

# 2. Engine mode emits events
export ORCH_RUN_ID="test-001"
export ORCH_STARTED_AT="2026-04-13T00:00:00Z"
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M004/phases/P05 2>/tmp/cmh-stderr.txt || true
grep -q 'EVENT:VERIFY_START' /tmp/cmh-stderr.txt && echo "event emission ok"
grep -q 'RESULT:' /tmp/cmh-stderr.txt && echo "result emission ok"

# 3. Verification helper passes
bash scripts/verify/m004-p06-check-must-haves-root.sh
```

## Must-Haves

### Truths

- check-must-haves.sh resolves PROJECT_ROOT using extension.yml or .git markers
  - Check: `bash scripts/verify/m004-p06-check-must-haves-root.sh`
- check-must-haves.sh sources lib/errors.sh
  - Check: `bash scripts/verify/m004-p06-sources-errors.sh`
- check-must-haves.sh sources lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-events.sh`
- check-must-haves.sh calls emit_result
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`
- check-must-haves.sh calls emit_event
  - Check: `bash scripts/verify/m004-p06-emit-event.sh`

### Artifacts

- `scripts/verify/check-must-haves.sh` (min 100 lines, contains "emit_result")

## Verification

Run from repo root:
1. `bash scripts/verify/m004-p06-check-must-haves-root.sh` -- PASS
2. `grep -q 'emit_result' scripts/verify/check-must-haves.sh` -- exits 0
3. `grep -q 'emit_event' scripts/verify/check-must-haves.sh` -- exits 0
4. `grep -q 'extension\.yml\|\.git' scripts/verify/check-must-haves.sh` -- exits 0

## Inputs

### From Previous Tasks

None -- T01 has no task dependencies within P06.

### From Disk

- `scripts/verify/check-must-haves.sh` -- the file to modify. Currently 208 lines. Key structure: argument validation (lines 14-39), PROJECT_ROOT detection (lines 42-59), must-haves section parsing (lines 63-202), exit (lines 204-208).
- `scripts/lib/errors.sh` -- P02 library. Provides `emit_result <status> [error_kind] [detail]`. Double-sourcing guarded.
- `scripts/lib/events.sh` -- P02 library. Provides `emit_event <TYPE> [key=value ...]`. Double-sourcing guarded. Uses `ORCH_RUN_ID` and `ORCH_STARTED_AT` from environment.
- `extension.yml` -- repo root marker file (always present in spec-kit extensions).

## Constraints

- The PASS/FAIL output on stdout must not change format.
- Exit code 0 (all pass) / 1 (any fail) contract must be preserved.
- EVENT: and RESULT: lines go to stderr only.
- Test fixtures under `tests/` that do not have `extension.yml` or `.git` must still work via the fallback algorithm.

## Expected Output

- Modified `scripts/verify/check-must-haves.sh` with:
  - Fixed PROJECT_ROOT detection using repo root markers
  - `lib/errors.sh` and `lib/events.sh` sourced near top
  - EXIT trap emitting `emit_result` to stderr when ORCH_RUN_ID is set
  - `emit_event VERIFY_START` and `VERIFY_COMPLETE` events when ORCH_RUN_ID is set
  - All engine integration wrapped in ORCH_RUN_ID guards
  - Identical standalone behavior (no events/results when ORCH_RUN_ID is unset)

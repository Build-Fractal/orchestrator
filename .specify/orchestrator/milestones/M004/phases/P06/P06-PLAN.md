---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M004"
goal: "Integrate 5 remaining engine-path scripts with lib/errors.sh and lib/events.sh so they emit structured events and RESULT lines while preserving standalone behavior when ORCH_RUN_ID is unset"
demo_sentence: "All 8 engine-path scripts (build-context, compress-payload, select-model, check-must-haves, record-result, record-telemetry, aggregate-metrics, classify-complexity, phase-transition) source lib/errors.sh and lib/events.sh, emit at least one event, and emit a RESULT line — while continuing to work standalone when ORCH_RUN_ID is unset."
risk: "medium"
depends_on: [P02]
---

## Goal

Add structured event emission (`emit_event`) and result reporting (`emit_result`) to the 5 engine-path scripts that were not refactored in P05: `check-must-haves.sh`, `record-result.sh`, `record-telemetry.sh`, `aggregate-metrics.sh`, `classify-complexity.sh`, and `phase-transition.sh`. Also fix the known PROJECT_ROOT detection bug in `check-must-haves.sh` and add `run_id`/`error_kind` fields to `record-result.sh` JSONL output.

P05 already integrated the 3 dispatch scripts (`build-context.sh`, `compress-payload.sh`, `select-model.sh`) with the P02 library stack. This phase completes the integration for the remaining scripts, establishing the US4/US8/US9 contract: every engine-managed script sources `lib/errors.sh` and `lib/events.sh`, emits at least one event via `emit_event`, and emits a final `RESULT:{json}` line via `emit_result`.

All changes are wrapped in standalone detection (`if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`) so scripts continue to work identically when invoked outside the engine. NFR-204 is the governing requirement.

## Demo

From repo root, a developer can:

1. Run any of the 5 target scripts with `ORCH_RUN_ID` set and observe structured events:
   ```bash
   export ORCH_RUN_ID="test-run-001"
   export ORCH_STARTED_AT="2026-04-13T00:00:00Z"
   bash scripts/dispatch/classify-complexity.sh tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md 2>&1 | grep -E '^(EVENT:|RESULT:)'
   # EVENT:DISPATCH_START timestamp=2026-04-13T00:00:00Z run_id=test-run-001 stage=classify_complexity
   # RESULT:{"status":"ok","error_kind":"","detail":"classified as standard"}
   ```

2. Run the same script without `ORCH_RUN_ID` and see no events/results (original behavior):
   ```bash
   unset ORCH_RUN_ID
   bash scripts/dispatch/classify-complexity.sh tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md
   # standard
   ```

3. Run `record-result.sh` with `ORCH_RUN_ID` and observe `run_id` in the JSONL output:
   ```bash
   export ORCH_RUN_ID="test-run-001"
   tmp=$(mktemp)
   bash scripts/lifecycle/record-result.sh "$tmp" --milestone=M001 --phase=P01 --task=T01 --outcome=success --error_kind=
   grep -q '"run_id":"test-run-001"' "$tmp" && echo "run_id present"
   rm -f "$tmp"
   ```

## Must-Haves

### Truths

- All 5 target scripts source lib/errors.sh
  - Check: `bash scripts/verify/m004-p06-sources-errors.sh`
- All 5 target scripts source lib/events.sh
  - Check: `bash scripts/verify/m004-p06-sources-events.sh`
- All 5 target scripts call emit_result on at least one exit path
  - Check: `bash scripts/verify/m004-p06-emit-result.sh`
- All 5 target scripts call emit_event at least once
  - Check: `bash scripts/verify/m004-p06-emit-event.sh`
- All 5 target scripts use the ORCH_RUN_ID standalone detection pattern
  - Check: `bash scripts/verify/m004-p06-standalone-safe.sh`
- All 5 target scripts are Bash 3.2 compatible (no declare -A, readarray, mapfile)
  - Check: `bash scripts/verify/m004-p06-bash32-compat.sh`
- check-must-haves.sh resolves PROJECT_ROOT to the actual repo root using extension.yml or .git markers
  - Check: `bash scripts/verify/m004-p06-check-must-haves-root.sh`
- record-result.sh adds run_id to JSONL entries when ORCH_RUN_ID is set
  - Check: `bash scripts/verify/m004-p06-record-result-runid.sh`
- record-result.sh adds error_kind to JSONL entries
  - Check: `bash scripts/verify/m004-p06-record-result-errorkind.sh`
- aggregate-metrics.sh groups failures by error_kind
  - Check: `bash scripts/verify/m004-p06-aggregate-errorkind.sh`

### Artifacts

- scripts/verify/check-must-haves.sh (min 100 lines, contains "emit_result")
- scripts/lifecycle/record-result.sh (min 100 lines, contains "run_id")
- scripts/telemetry/record-telemetry.sh (min 50 lines, contains "emit_event")
- scripts/telemetry/aggregate-metrics.sh (min 200 lines, contains "error_kind")
- scripts/dispatch/classify-complexity.sh (min 80 lines, contains "emit_result")
- scripts/lifecycle/phase-transition.sh (min 120 lines, contains "emit_event")

### Key Links

- scripts/verify/check-must-haves.sh → scripts/lib/errors.sh
- scripts/verify/check-must-haves.sh → scripts/lib/events.sh
- scripts/lifecycle/record-result.sh → scripts/lib/errors.sh
- scripts/lifecycle/record-result.sh → scripts/lib/events.sh
- scripts/telemetry/record-telemetry.sh → scripts/lib/errors.sh
- scripts/telemetry/record-telemetry.sh → scripts/lib/events.sh
- scripts/telemetry/aggregate-metrics.sh → scripts/lib/errors.sh
- scripts/telemetry/aggregate-metrics.sh → scripts/lib/events.sh
- scripts/dispatch/classify-complexity.sh → scripts/lib/errors.sh
- scripts/dispatch/classify-complexity.sh → scripts/lib/events.sh
- scripts/lifecycle/phase-transition.sh → scripts/lib/errors.sh
- scripts/lifecycle/phase-transition.sh → scripts/lib/events.sh

## Cross-Cutting Constraints (apply to every task)

Every task in this phase MUST comply with the following. These are repeated in each task plan so that a fresh agent executing one task in isolation cannot miss them:

1. **Bash 3.2** -- no associative arrays (`declare -A`), no `readarray`, no `mapfile`, no process substitution (`<(...)`) as a redirect target in `while read` loops.
2. **Standalone safety (NFR-204)** -- all event emission and result reporting MUST be wrapped in `if [ -n "${ORCH_RUN_ID:-}" ]; then ... fi`. When `ORCH_RUN_ID` is unset, the script MUST behave identically to its pre-P06 version. Do NOT call `init_run_context` -- these scripts are downstream consumers of a run context set by the engine or the caller. They source `lib/errors.sh` and `lib/events.sh` unconditionally (the libs are safe to source without a run context), but only emit when `ORCH_RUN_ID` is set.
3. **Source libs near the top** -- after the existing shebang, comment, and any existing guards, add:
   ```bash
   _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   _LIB_DIR="$_SCRIPT_DIR/../../lib"  # adjust depth based on script location
   . "$_LIB_DIR/errors.sh"
   . "$_LIB_DIR/events.sh"
   ```
   For scripts in `scripts/verify/` and `scripts/lifecycle/`, the lib path is `../../lib`. For `scripts/telemetry/`, it is `../../lib`. For `scripts/dispatch/`, it is `../../lib` (but dispatch scripts are already done).
4. **emit_result on exit** -- use a `trap ... EXIT` pattern or explicit calls at every exit point. The result line goes to stderr for scripts that use stdout for data output. For scripts where stdout IS the structured output (e.g. record-result.sh prints "RECORD:APPENDED"), emit the RESULT line to stderr.
5. **emit_event at key points** -- emit at least one event at script start (e.g., `VERIFY_START`, `TASK_COMPLETE`) and optionally at significant internal milestones.
6. **No jq** -- all JSON construction and parsing must use printf/sed/grep/awk.
7. **Do not modify P02 libraries** (`scripts/lib/errors.sh`, `scripts/lib/events.sh`, `scripts/lib/run-context.sh`) or P05 scripts (`build-context.sh`, `compress-payload.sh`, `select-model.sh`).
8. **Existing test suites must not break** -- the scripts' argument parsing, exit codes, and stdout output format must be preserved. Only stderr gets new EVENT:/RESULT: lines.

## Tasks

### T01: Fix and Integrate check-must-haves.sh

Fix the PROJECT_ROOT detection bug (currently walks up to the parent of `phases/` instead of the repo root, causing all truth checks to fail when phase dirs are under `.specify/orchestrator/milestones/M###/phases/P##/`). Replace the walk-up algorithm with one that looks for `extension.yml` or `.git` directory as repo root markers. Then add lib/errors.sh + lib/events.sh sourcing, emit `VERIFY_START` event at start, emit `VERIFY_COMPLETE` at end, and emit `emit_result` on exit. Wrap all event/result emission in `ORCH_RUN_ID` guard.

### T02: Integrate record-result.sh with run_id and error_kind

Add lib/errors.sh + lib/events.sh sourcing. Add `--error_kind=<KIND>` optional argument. When `ORCH_RUN_ID` is set, include `run_id` and (if provided) `error_kind` fields in the JSONL output. Emit `TASK_COMPLETE` event on successful append. Emit `emit_result` on exit via trap. Preserve all existing argument parsing and output format.

### T03: Integrate telemetry scripts (record-telemetry.sh + aggregate-metrics.sh)

Add lib/errors.sh + lib/events.sh sourcing to both scripts. For `record-telemetry.sh`: include `run_id` in JSONL when set, emit event on record. For `aggregate-metrics.sh`: add `error_kind` grouping to both text and JSON output formats, emit result on completion. Both scripts must preserve existing output format and argument parsing.

### T04: Integrate classify-complexity.sh and phase-transition.sh

Add lib/errors.sh + lib/events.sh sourcing to both scripts. For `classify-complexity.sh`: emit `DISPATCH_START stage=classify_complexity` event, emit result with the classified tier. For `phase-transition.sh`: emit `PHASE_COMPLETE` event when transition is ready, emit result on exit. Both wrapped in ORCH_RUN_ID guard.

### T05: Phase Verification

Run all verification helper scripts to confirm phase-level truths pass. Verify that each target script still works correctly in standalone mode (ORCH_RUN_ID unset). Verify no regressions in existing test suites. This task is verification-only -- no code changes.

## Task Dependencies

```
T01 (check-must-haves.sh is used by verification of other tasks, fix it first)
T01 → T02  (record-result.sh is used to log results; schema changes may affect T03's aggregate-metrics)
T01 → T03  (aggregate-metrics needs error_kind from T02's JSONL schema; record-telemetry is independent)
T01 → T04  (phase-transition.sh reads task summaries; independent of T02/T03 but sequenced for safety)
T02 + T03 + T04 → T05  (verification runs after all integration is complete)
```

Sequential execution order: T01 -> T02 -> T03 -> T04 -> T05

## Files Likely Touched

- `scripts/verify/check-must-haves.sh` (modify -- fix PROJECT_ROOT bug + integrate)
- `scripts/lifecycle/record-result.sh` (modify -- add run_id, error_kind, events, result)
- `scripts/telemetry/record-telemetry.sh` (modify -- add events, result, run_id)
- `scripts/telemetry/aggregate-metrics.sh` (modify -- add error_kind grouping, events, result)
- `scripts/dispatch/classify-complexity.sh` (modify -- add events, result)
- `scripts/lifecycle/phase-transition.sh` (modify -- add events, result)
- `scripts/verify/m004-p06-*.sh` (create -- verification helper scripts)

No changes to `scripts/lib/*.sh` (P02 output), `scripts/dispatch/build-context.sh` / `compress-payload.sh` / `select-model.sh` (P05 output), or `scripts/engine/run.sh` (P03 output).

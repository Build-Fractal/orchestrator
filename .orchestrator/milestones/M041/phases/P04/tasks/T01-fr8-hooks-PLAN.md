---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M041"
name: "Wire auto/dispatch/verify hooks + doctor symptom specificity"
depends_on: []
---

## Prerequisites

- `scripts/diagnostics/detective-recommend.sh` exists (from P03) — the shared recommendation helper
- `scripts/lifecycle/auto-loop.sh`, `commands/verify.md`, `commands/dispatch.md`, `scripts/diagnostics/run-doctor.sh` all exist

## Description

Complete FR-8 by wiring the three recommendation hooks P03 deferred (auto, dispatch, verify), and improve doctor's existing hook to name the specific failing checks. Selective by design (NG-1): the hooks fire only on orchestrator-internal failures, never on user-project issues.

## Steps

1. **auto-loop.sh** (mechanical hook): At the unexpected-state `exit 12` seam (the `*)` case after `derive-phase.sh` returns an unknown state), call `detective-recommend.sh --symptom "auto-loop received unexpected state '<state>' from derive-phase.sh"`. Guard with `[ -f "$_detective_recommend" ]`. No `--path` — an unknown state is definitionally an orchestrator bug. Path: `$SCRIPT_DIR/../diagnostics/detective-recommend.sh`.

2. **commands/verify.md** (LLM guidance): Add a "Detective recommendation hook" subsection to Error Handling. Instruct: call `detective-recommend.sh --symptom "..." --path "<verifier-path>"` when a verifier script is missing/broken (orchestrator-internal), NOT when user code legitimately fails a check (that's `diagnose`, per NG-1).

3. **commands/dispatch.md** (LLM guidance): Same shape. Fire when `build-context.sh`/adapters error internally; do NOT fire on user-fixable preconditions (missing task plan, un-run `evaluate`).

4. **run-doctor.sh** (symptom specificity, addresses review finding B5): Add a `failed_check_names` accumulator; append each non-advisory failing check's name in `run_check`; change the hook symptom from `"doctor found N failing checks"` to `"doctor checks failed: ${failed_check_names}"`.

## Must-Haves

- auto-loop.sh references detective-recommend.sh at the unexpected-state seam, file-guarded
- verify.md + dispatch.md carry orchestrator-internal-scoped guidance distinguishing detective from diagnose
- run-doctor.sh emits specific failing-check names, not a generic count

## Verification

```bash
bash tools/verify/m041-p04-phase-suite.sh
```

## Inputs

### From Disk (Pre-existing)

- `scripts/diagnostics/detective-recommend.sh` (from P03) — `--symptom <text> [--path <error-path>]`; emits `RECOMMEND:` to stderr for orchestrator-internal paths; exit 0 always
- `scripts/lifecycle/auto-loop.sh` — `SCRIPT_DIR` is `scripts/lifecycle/`; helper is at `$SCRIPT_DIR/../diagnostics/detective-recommend.sh`
- `scripts/diagnostics/run-doctor.sh` — `run_check` tracks `checks_passed`/`checks_total`

## Constraints

- Bash 3.2+ compatible (CON-3)
- Hooks advisory only — never block the calling command
- Selective firing (NG-1): orchestrator-internal failures only, never user-project issues

## Expected Output

- 4 modified files (auto-loop.sh, verify.md, dispatch.md, run-doctor.sh)
- 5 verifiers under `tools/verify/m041-p04-*`
- Phase suite: `pass=4 fail=0`

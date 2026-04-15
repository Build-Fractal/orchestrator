---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M004"
goal: "Implement scripts/engine/run.sh and scripts/engine/checkpoint.sh — a mechanical pipeline coordinator that threads run context, emits structured events, enforces safety rails, dispatches hooks at 4 lifecycle points, and checkpoints after each task for crash recovery, composing the P02 libraries and existing dispatch/verify/lifecycle scripts"
demo_sentence: "Running `bash scripts/engine/run.sh --dry-run M004 P03` initializes a deterministic run context, emits SESSION_START, iterates pending tasks emitting TASK_START/TASK_COMPLETE per task, calls run_hooks at PRE_DISPATCH/POST_DISPATCH/POST_VERIFY/PRE_ADVANCE, blocks on guard_payload_sanity failures, writes a checkpoint at .specify/orchestrator/milestones/M004/engine-checkpoint.json after each task boundary, emits PHASE_COMPLETE + SESSION_END, and finishes with `RESULT:{\"status\":\"ok\",...}` — all without invoking a real agent."
risk: "high"
depends_on: [P02]
---

## Must-Haves

### Truths

- `scripts/engine/run.sh` exists and passes `bash -n` syntax check
  - Check: `bash -n scripts/engine/run.sh`
- `scripts/engine/checkpoint.sh` exists and passes `bash -n` syntax check
  - Check: `bash -n scripts/engine/checkpoint.sh`
- `scripts/engine/run.sh` has a double-sourcing / single-entry guard within the first 5 lines
  - Check: `head -5 scripts/engine/run.sh | grep -qE '_RUN_SH_SOURCED|_ENGINE_RUN_SOURCED|set -euo pipefail'`
- `scripts/engine/checkpoint.sh` has a double-sourcing guard within the first 5 lines
  - Check: `head -5 scripts/engine/checkpoint.sh | grep -q '_CHECKPOINT_SOURCED'`
- `scripts/engine/run.sh` sources all 5 P02 libraries (errors, events, run-context, guards, hooks)
  - Check: `for lib in errors events run-context guards hooks; do grep -q "lib/${lib}.sh" scripts/engine/run.sh || exit 1; done && echo PASS`
- `scripts/engine/checkpoint.sh` sources errors.sh and events.sh
  - Check: `grep -q 'lib/errors.sh' scripts/engine/checkpoint.sh && grep -q 'lib/events.sh' scripts/engine/checkpoint.sh`
- `scripts/engine/run.sh` calls `init_run_context` before any dispatch work
  - Check: `grep -q 'init_run_context' scripts/engine/run.sh`
- `scripts/engine/run.sh` emits SESSION_START, SESSION_END, TASK_START, TASK_COMPLETE, PHASE_COMPLETE events
  - Check: `for e in SESSION_START SESSION_END TASK_START TASK_COMPLETE PHASE_COMPLETE; do grep -q "emit_event ${e}" scripts/engine/run.sh || exit 1; done && echo PASS`
- `scripts/engine/run.sh` invokes `run_hooks` at all 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE)
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "run_hooks ${p}" scripts/engine/run.sh || exit 1; done && echo PASS`
- `scripts/engine/run.sh` calls guard_payload_sanity, guard_budget, guard_output_sanity, and guard_phase_complete
  - Check: `for g in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do grep -q "${g}" scripts/engine/run.sh || exit 1; done && echo PASS`
- `scripts/engine/run.sh` emits DISPATCH_START and VERIFY_START / VERIFY_COMPLETE events for observability
  - Check: `grep -q 'emit_event DISPATCH_START' scripts/engine/run.sh && grep -q 'emit_event VERIFY_COMPLETE' scripts/engine/run.sh`
- `scripts/engine/run.sh` calls `checkpoint_write` after each successful task boundary
  - Check: `grep -q 'checkpoint_write' scripts/engine/run.sh`
- `scripts/engine/run.sh` calls `checkpoint_detect` and `checkpoint_read` at session start for crash recovery
  - Check: `grep -q 'checkpoint_detect' scripts/engine/run.sh && grep -q 'checkpoint_read' scripts/engine/run.sh`
- `scripts/engine/run.sh` honors `--dry-run` via `orch_is_dry_run` and skips the actual agent invocation branch
  - Check: `grep -q 'orch_is_dry_run' scripts/engine/run.sh`
- `scripts/engine/run.sh` emits exactly one final `RESULT:` line via `emit_result`
  - Check: `grep -q 'emit_result' scripts/engine/run.sh`
- No script under `scripts/engine/` calls `date` inline (Principle IX)
  - Check: `! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/run.sh scripts/engine/checkpoint.sh`
- No script under `scripts/engine/` uses Bash 4-only syntax (associative arrays, readarray, mapfile)
  - Check: `! grep -rqE 'declare -A|readarray|mapfile' scripts/engine/`
- No script under `scripts/engine/` uses process substitution as a redirection target (AP-001)
  - Check: `! grep -rqE 'done[[:space:]]*<[[:space:]]*<\(' scripts/engine/`
- `scripts/engine/run.sh` exits non-zero with a usage message when invoked without required milestone/phase args and emits a `RESULT:` line with `error_kind":"CONFIG"`
  - Check: `out="$(bash scripts/engine/run.sh 2>&1 || true)"; echo "$out" | grep -q 'Usage' && echo "$out" | grep -q '"error_kind":"CONFIG"'`
- `scripts/engine/run.sh --dry-run M004 P03` exits 0 from the repo root
  - Check: `ORCH_RUN_SEED=p03-dry ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/tmp/p03-dry.out 2>&1`
- A dry-run invocation emits at least 4 `EVENT:` lines (session/task/phase lifecycle) to stdout
  - Check: `ORCH_RUN_SEED=p03-dry2 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep -c '^EVENT:' | awk '{ if ($1 >= 4) exit 0; else exit 1 }'`
- A dry-run invocation emits `SESSION_START` and `SESSION_END` events
  - Check: `ORCH_RUN_SEED=p03-dry3 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep -q '^EVENT:SESSION_START' && ORCH_RUN_SEED=p03-dry3b ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep -q '^EVENT:SESSION_END'`
- All EVENT lines from a single dry-run share the same `run_id` (deterministic seed)
  - Check: `ORCH_RUN_SEED=p03-same ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep '^EVENT:' | grep -oE 'run_id=[^ ]+' | sort -u | wc -l | tr -d ' ' | grep -q '^1$'`
- A dry-run execution writes a checkpoint file to `.specify/orchestrator/milestones/M004/engine-checkpoint.json`
  - Check: `ORCH_RUN_SEED=p03-cp ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/dev/null 2>&1; test -f .specify/orchestrator/milestones/M004/engine-checkpoint.json`
- The checkpoint file is valid JSON containing `run_id`, `milestone`, `phase`, and a `last_task` field
  - Check: `grep -q '"run_id"' .specify/orchestrator/milestones/M004/engine-checkpoint.json && grep -q '"milestone"' .specify/orchestrator/milestones/M004/engine-checkpoint.json && grep -q '"phase"' .specify/orchestrator/milestones/M004/engine-checkpoint.json && grep -q '"last_task"' .specify/orchestrator/milestones/M004/engine-checkpoint.json`
- Re-running the engine with an existing checkpoint emits a `CHECKPOINT_RESUME` event on stdout
  - Check: `ORCH_RUN_SEED=p03-resume ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep -q '^EVENT:CHECKPOINT_RESUME'`
- `checkpoint_write` writes atomically via temp-file-then-mv (M002 inherited convention)
  - Check: `grep -qE 'mv[[:space:]]+["$][^ ]+["$]?[[:space:]]+["$]' scripts/engine/checkpoint.sh || grep -qE 'mv .*\.tmp' scripts/engine/checkpoint.sh`

### Artifacts

- `scripts/engine/run.sh` (min 220 lines, contains "init_run_context")
- `scripts/engine/checkpoint.sh` (min 90 lines, contains "_CHECKPOINT_SOURCED")
- `.specify/orchestrator/milestones/M004/engine-checkpoint.json` (min 3 lines, contains "last_task")

### Key Links

- `scripts/engine/run.sh` → `scripts/lib/errors.sh` (engine sources errors for emit_result and taxonomy)
- `scripts/engine/run.sh` → `scripts/lib/events.sh` (engine sources events for emit_event across lifecycle)
- `scripts/engine/run.sh` → `scripts/lib/run-context.sh` (engine calls init_run_context and orch_now)
- `scripts/engine/run.sh` → `scripts/lib/guards.sh` (engine calls the 4 safety rails)
- `scripts/engine/run.sh` → `scripts/lib/hooks.sh` (engine calls run_hooks at 4 lifecycle points)
- `scripts/engine/run.sh` → `scripts/engine/checkpoint.sh` (engine sources checkpoint helpers)
- `scripts/engine/run.sh` → `scripts/dispatch/build-context.sh` (engine shells out for context assembly)
- `scripts/engine/run.sh` → `scripts/dispatch/compress-payload.sh` (engine shells out for compression)
- `scripts/engine/run.sh` → `scripts/dispatch/select-model.sh` (engine shells out for model routing)
- `scripts/engine/run.sh` → `scripts/verify/check-must-haves.sh` (engine invokes verification at task boundary)
- `scripts/engine/run.sh` → `scripts/lifecycle/record-result.sh` (engine appends JSONL result with run_id)
- `scripts/engine/checkpoint.sh` → `scripts/lib/errors.sh` (checkpoint emits emit_result on failure)
- `scripts/engine/checkpoint.sh` → `scripts/lib/events.sh` (checkpoint emits CHECKPOINT_WRITE / CHECKPOINT_RESUME)
- `scripts/engine/run.sh` → `.specify/memory/constitution.md` (implements Principles II, IX, XII and consumes them)

## Tasks

### T01: checkpoint.sh — Atomic Crash Recovery Library

Implement `scripts/engine/checkpoint.sh`, a Bash 3.2 sourced library that writes/reads/detects a JSON checkpoint at `.specify/orchestrator/milestones/<milestone>/engine-checkpoint.json`. Exposes `checkpoint_path`, `checkpoint_write`, `checkpoint_read`, `checkpoint_detect`, `checkpoint_clear`. Writes atomically (temp-file then `mv`). Emits `CHECKPOINT_WRITE` on write and `CHECKPOINT_RESUME` when an existing checkpoint is detected by the caller. Sources errors.sh + events.sh via relative `$(dirname "${BASH_SOURCE[0]}")`. Double-sourcing guard `_CHECKPOINT_SOURCED` on lines 3-4 per T01/P02 lesson. No `jq`, no inline `date`, no process substitution.

### T02: run.sh — Skeleton, Arg Parsing, Session Lifecycle, Task Iteration

Create `scripts/engine/run.sh` with shebang, `set -euo pipefail`, sourcing of all 5 P02 libraries + `scripts/engine/checkpoint.sh`, argument parsing (`<milestone> <phase>` positional, `--dry-run` / `--force` flags, `-h|--help`), run-context initialization, pending-task discovery from the phase plan's `tasks/` directory, SESSION_START emission, a minimal walking-skeleton task loop that emits TASK_START / TASK_COMPLETE for each task (NO dispatch, NO guards, NO context assembly yet — those arrive in T03/T04/T05), PHASE_COMPLETE emission, SESSION_END emission, final `emit_result ok`. Usage-on-no-args exits with `emit_result error CONFIG ...`. Calls `checkpoint_detect` / `checkpoint_read` at session start so `CHECKPOINT_RESUME` becomes observable once T05 wires resumption. Includes `run_hooks PRE_DISPATCH` at the minimum so hook integration is structurally in place. This task is the walking skeleton — T03/T04/T05 then thread the real pipeline into its loop.

### T03: Safety Rail Integration — Guards in the Task Loop

Edit `scripts/engine/run.sh` to wire the four P02 guards into the task loop at the correct precedence points: `guard_payload_sanity <payload_file>` and `guard_budget <cum_cost> <max_cost> <cum_dur> <max_dur>` before dispatch, `guard_output_sanity <output_file>` after dispatch, `guard_phase_complete <phase_dir>` before PHASE_COMPLETE emission. Each guard block path must be observable: if a guard returns non-zero, the engine emits a `TASK_COMPLETE outcome=blocked` (not success), records the result with outcome=blocked via record-result.sh, skips the task (continues the loop), and the overall run exit status is degraded. `ORCH_FORCE` is honored (guards already downgrade to `GUARD_WARNING` under force). Token/cost accumulators are introduced as shell integer variables (Bash 3.2 arithmetic — `$((a + b))`). In dry-run mode, payload/output files do not exist, so guards are short-circuited with a small explicit `if orch_is_dry_run; then ... else guard_* ...; fi` wrapper that still emits a `SAFETY_WARNING reason=dry_run_guard_skipped` event for auditability.

### T04: Context Assembly Pipeline Integration — Build / Compress / Select-Model

Edit `scripts/engine/run.sh` to call, per task, the three existing dispatch scripts: `scripts/dispatch/build-context.sh <orch-root> <milestone> <phase> <task-id>` → capture payload to a temp file; pipe payload through `scripts/dispatch/compress-payload.sh --budget <budget> --input <file>` → capture compressed payload; call `scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml` → parse "<model-id> <context-budget>" stdout. Emit `DISPATCH_START model=<id> tokens_estimated=<n> payload_bytes=<b>` before dispatch. In dry-run mode, emit `DISPATCH_START` with an additional `dry_run=1` key and SKIP the real agent call. Temp files are cleaned with a `trap` on EXIT. All operations are guarded: if `build-context.sh` exits non-zero, emit `emit_result error DISPATCH` and advance to the next task loop iteration. Failure to parse select-model.sh output is a `DISPATCH` error.

### T05: Verify / Record / Checkpoint Wiring + Dry-Run Path

Edit `scripts/engine/run.sh` to complete the pipeline: after dispatch (or the dry-run skip), call `VERIFY_START`, then `scripts/verify/check-must-haves.sh <phase-dir>` (running it from the repo root to avoid the P02-noted PROJECT_ROOT detection bug), then `VERIFY_COMPLETE result=<pass|fail>`. Call `run_hooks POST_VERIFY` after verification. Call `scripts/lifecycle/record-result.sh <execution-log> --milestone=M... --phase=P... --task=T... --outcome=<success|failure|blocked>` — threading ORCH_RUN_ID and the chosen model into the record. After each task boundary, call `checkpoint_write <milestone> <phase> <task-id> <outcome>`. After the final task, call `run_hooks PRE_ADVANCE`, then `guard_phase_complete`, then emit `PHASE_COMPLETE`. Emit `SESSION_END`. Call `checkpoint_clear` on full phase success. The `--dry-run` path must exercise every branch above except actual agent invocation. End of file: `trap '... ; emit_result ok "" "engine completed M$M P$P"' EXIT` or explicit `emit_result` at each exit path.

### T06: Crash Recovery End-to-End Verification

Add a small `scripts/engine/test-resume.sh` helper (or embed a self-test function in `run.sh --self-test`) plus a dedicated must-have check: start a dry-run, kill it mid-loop (simulated by forcing an early exit after task 1 via `ORCH_ENGINE_STOP_AFTER_TASK=T01`), verify checkpoint is present with `last_task=T01`, re-run the engine, confirm a `CHECKPOINT_RESUME` event is emitted and the loop picks up from T02. This is the only task that adds a verification script (not a library); it consolidates the crash-recovery behavior introduced by T01 and T05 into a single provable demo. If T01/T05 already expose `ORCH_ENGINE_STOP_AFTER_TASK`, this task only adds the verification harness. The test script must itself source errors.sh / events.sh and emit_result on completion.

## Task Dependencies

```
T01 (checkpoint.sh) ──┐
                      ├─→ T02 (run.sh skeleton) ─→ T03 (guards) ─→ T04 (dispatch) ─→ T05 (verify/record/checkpoint) ─→ T06 (resume E2E)
                      │
                      (T02 sources T01 at load time)
```

Linear chain. T01 is independent and can complete before T02 starts. T02 must import T01's interface before emitting events. T03/T04/T05 are sequential edits on the same `scripts/engine/run.sh` file — each builds on the prior agent's walking skeleton. T06 validates the crash-recovery path end-to-end after T05 has wired checkpoint_clear into the happy path.

The linear chain is chosen over a parallel DAG because T03/T04/T05 all edit the same file (`scripts/engine/run.sh`) and merging their independent edits would require conflict-resolution logic we do not have in this phase. Keeping them sequential trades parallelism for simpler verification.

## Files Likely Touched

- `scripts/engine/run.sh` (create in T02, edit in T03/T04/T05/T06)
- `scripts/engine/checkpoint.sh` (create in T01)
- `scripts/engine/test-resume.sh` (create in T06)
- `.specify/orchestrator/milestones/M004/engine-checkpoint.json` (created at runtime by T05/T06 verification — this is an output artifact, not a source file; listed here so scope checks do not flag it as out-of-scope)

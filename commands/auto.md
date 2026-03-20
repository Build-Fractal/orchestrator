---
description: "Use when running fully autonomous execution on a Tier C project. Acquires a lock, then loops: derive state → check budget/stuck → dispatch task → verify → record → advance, until the milestone completes, a blocker is encountered, or a pause is requested."
---

# speckit.orchestrator.auto

Run the autonomous dispatch loop for a Tier C milestone. This command owns the full execution cycle — it acquires a lock, dispatches tasks one at a time in fresh contexts with verification between each, handles pause/stuck/budget gates, and releases the lock on any exit path.

## Prerequisites

Before entering the autonomous loop, verify all preconditions:

### 1. Derive Current State

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

Auto mode is valid when the returned state is one of:
- `executing` — tasks are being dispatched and worked on
- `planning` — phase plans are being generated (auto will advance to executing)
- `summarizing` — active phase tasks are done, phase summary needed

If state is `complete`, report "Milestone already complete" and exit without acquiring a lock.

If state is `pre-planning`, `discussing`, or any state before a roadmap exists, report "Milestone is not ready for autonomous execution — run `speckit.orchestrator.evaluate` first" and exit.

### 2. Check for Existing Lock

```bash
bash scripts/lifecycle/lock-manager.sh status .specify/orchestrator/orchestrator.lock
```

- **LOCK:ACTIVE** — Another session owns execution. Report "Lock held by PID {pid} since {started_at} on unit {unit_id}. Autonomous mode cannot start while another session is active." and exit.
- **LOCK:STALE** — A previous session crashed. Report "Stale lock detected (PID {pid} not running). Run `speckit.orchestrator.resume` for crash recovery." and exit. Do NOT auto-break the lock — crash recovery via `resume` ensures no work is lost.
- **LOCK:NONE** — No lock exists, safe to proceed.

### 3. Verify Tier C

Read the orchestration tier from the roadmap:

```bash
bash scripts/state/read-roadmap.sh <roadmap-file> tier
```

Auto mode is only available for **Tier C** projects (FR-054). If the tier is B, report "Autonomous mode is only available for Tier C projects. Use `speckit.orchestrator.dispatch` for guided execution." and exit.

If the tier is A, report "Tier A projects do not use orchestrator dispatch. Use spec-kit commands directly." and exit.

## Lock Acquisition

Acquire the execution lock before entering the loop:

```bash
bash scripts/lifecycle/lock-manager.sh create .specify/orchestrator/orchestrator.lock "auto-dispatch" "<M###>/<active-phase>/<next-task>"
```

The lock file is stored at `.specify/orchestrator/orchestrator.lock` (per spec data model). It records:
- The current PID (for liveness detection)
- The operation type (`auto-dispatch`)
- The current unit being worked on
- A timestamp and git branch for crash recovery context

**Important:** The lock MUST be released on every exit path — normal completion, pause, error, or unexpected state. Structure all subsequent steps so that lock release is guaranteed.

## Autonomous Loop

The core loop repeats until the milestone completes, a blocker is encountered, or a pause is requested:

### Step A — Derive State

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

Determine the current phase and next task. The returned state drives loop behavior:

| State | Action |
|-------|--------|
| `executing` | Continue to budget/stuck checks, then dispatch next task |
| `summarizing` | Trigger phase summary (see Phase Transition below) |
| `validating` | Milestone validation gate — see Completion below |
| `completing` | Write milestone summary — see Completion below |
| `complete` | Release lock and report "Milestone complete" |
| Any other state | Log warning, release lock, and exit gracefully |

Identify the next task to dispatch:
- Read the active phase from `bash scripts/state/read-roadmap.sh <roadmap-file> active-phase`
- Scan `<milestone-dir>/phases/<P##>/tasks/` for the first `T##-PLAN.md` without a corresponding `T##-SUMMARY.md`
- If the next task already has a summary, skip it and advance to the following task (idempotency)

### Step B — Check Budget

```bash
bash scripts/lifecycle/budget-checker.sh <milestone-dir>/execution-log.jsonl --dispatch-budget <configured> --duration-budget <configured>
```

Read budget limits from the orchestrator config:

```bash
dispatch_limit=$(bash scripts/state/read-config.sh <root> dispatch_budget)
duration_limit=$(bash scripts/state/read-config.sh <root> duration_budget)
```

If the output is `BUDGET:EXCEEDED`:
1. Write a continue file following `templates/continue-file.md` with the current position and remaining work
2. Release the lock via `bash scripts/lifecycle/lock-manager.sh break .specify/orchestrator/orchestrator.lock`
3. Report "Budget exceeded ({current}/{limit} dispatches or duration). Autonomous execution paused. Review budget settings or run `speckit.orchestrator.resume` to continue with increased budget."
4. Exit cleanly

### Step C — Check Stuck

```bash
bash scripts/lifecycle/stuck-detector.sh <milestone-dir>/execution-log.jsonl "<M###>/<P##>/<T##>"
```

If the output is `STUCK:YES`:
1. Write a continue file with the stuck unit's diagnostic context
2. Release the lock
3. Report "Task {T##} appears stuck — dispatched {N} times without completion. Manual intervention needed. Review the execution log and task artifacts, then run `speckit.orchestrator.resume`."
4. Exit cleanly

### Step D — Build Context

Assemble the scope-filtered context payload for the next task:

```bash
bash scripts/dispatch/build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id>
```

This produces a payload following the `templates/dispatch-prompt.md` structure with:
- Task plan and phase excerpt
- Upstream summaries from dependency phases
- Scope-filtered knowledge and decisions
- Configuration values (verbosity, verification commands, budgets)

### Step E — Dispatch Task

Determine the dispatch method:

```bash
bash scripts/dispatch/detect-capabilities.sh
```

**If `subagent_dispatch=true`**: Spawn a fresh agent context with the assembled payload as the initial prompt. The fresh context starts with zero codebase knowledge and builds understanding entirely from the payload. This is the preferred method — it ensures context isolation per Constitution Principle 5 (Fresh Context Per Unit).

**If `subagent_dispatch=false`**: Provide the assembled payload directly in the current context and execute the task sequentially. This is the fallback for environments without subagent support.

### Step F — Verify Task

After the dispatched task completes, run verification:

Invoke `speckit.orchestrator.verify` on the completed task to confirm must-haves are met. This runs the 4-tier verification pipeline:
1. Static checks via `bash scripts/verify/check-must-haves.sh`
2. Command execution via `bash scripts/verify/run-commands.sh`
3. Behavioral review (agent-driven)
4. Human/UAT review (if applicable)

**On verification pass:** Continue to Step G.

**On verification failure (first attempt):** Retry the task dispatch once with diagnostic context from the verification report appended to the payload (per US3 AS5 — retry with diagnostic context). The retry payload should include:
- The specific verification checks that failed
- The failure messages from check-must-haves.sh
- The task summary (if produced) from the failed attempt

**On verification failure (second attempt):** Do NOT retry further. Instead:
1. Record the double failure in the execution log
2. Write a continue file with the failed verification details
3. Release the lock
4. Report "Task {T##} failed verification after retry. Failed checks: {list}. Manual intervention needed."
5. Exit cleanly

### Step G — Record Result

Append the dispatch result to the execution log:

```bash
echo '{"timestamp":"<ISO-8601>","milestone":"<M###>","phase":"<P##>","task":"<T##>","tier":"C","dispatch_method":"<subagent|sequential>","outcome":"<success|failure>","verification_result":"<pass|fail>","duration_seconds":<N>}' >> <milestone-dir>/execution-log.jsonl
```

### Step H — Update Lock

Update the lock file to reflect the completed unit:

```bash
bash scripts/lifecycle/lock-manager.sh update .specify/orchestrator/orchestrator.lock "<M###>/<P##>/<T##>"
```

This appends the completed unit to the lock file's `completedUnits` array, providing a record of work done in this autonomous session.

### Step I — Advance

Check whether the loop should continue, transition phases, or complete:

- **More tasks in current phase:** Loop back to Step A for the next task.
- **All tasks in current phase complete:** State derivation will return `summarizing` — see Phase Transition below.
- **All phases complete:** State derivation will return `validating` or `completing` — see Completion below.

## Pause Handling (FR-047)

The autonomous loop checks for a pause request at the top of each iteration:

### Pause Detection

Check for a pause signal before each dispatch:

```bash
if [ -f ".specify/orchestrator/pause-requested" ]; then
  # Pause requested — exit cleanly
fi
```

The developer can create the `.specify/orchestrator/pause-requested` file from a second terminal while auto mode runs.

### Pause Execution

When a pause is detected:

1. **Write continue file** following `templates/continue-file.md` with:
   - Current position: `<M###>/<P##>/<T##>` (the task that would have been dispatched next)
   - Completed work: list from the lock file's `completedUnits` array
   - Remaining tasks: derived from the roadmap minus completed units
   - Decisions made this session: from DECISIONS.md entries with the current timestamp range
   - Next action: "Resume autonomous execution from {next-task}"

2. **Release the lock**:
   ```bash
   bash scripts/lifecycle/lock-manager.sh break .specify/orchestrator/orchestrator.lock
   ```

3. **Remove the pause flag**:
   ```bash
   rm -f .specify/orchestrator/pause-requested
   ```

4. **Report**: "Autonomous execution paused at {position}. Continue file written. Run `speckit.orchestrator.resume` to resume."

5. **Exit cleanly** with exit code 0.

## Phase Transition

When `derive-phase.sh` returns `summarizing` (all tasks in the active phase are complete):

### Two-Stage Review (FR-015 / FR-059 / FR-060)

1. **Stage 1 — Verification**: Run `speckit.orchestrator.verify` on the phase to execute the full 4-tier verification pipeline.

2. **Stage 2 — Phase Summary**: If verification passes, produce the phase summary:
   - Read all task summaries from the phase
   - Synthesize a phase-level summary capturing: what was built, key decisions, patterns established, and verification results
   - Write to `<milestone-dir>/phases/<P##>/<P##>-SUMMARY.md`

3. **Advance**: After the phase summary is written, `derive-phase.sh` will return the next phase's state on the next loop iteration. If all phases are complete, it will return `validating`.

### Phase Verification Failure

If phase-level verification fails:
- Record the failure in the execution log
- Write a continue file with the failed verification details
- Release the lock
- Report "Phase {P##} failed verification. Review the verification report and address failures before resuming."
- Exit cleanly

## Completion

When `derive-phase.sh` returns a terminal state:

### `validating`

The milestone validation gate (Tier C only):
1. Run cross-phase validation — verify that boundary map produces/consumes are satisfied across all phases
2. Check that all phase summaries exist
3. If validation passes, the state transitions to `completing`
4. If validation fails, report the specific failures and exit

### `completing`

Write the milestone summary:
1. Synthesize from all phase summaries
2. Compress knowledge into milestone-scoped KNOWLEDGE.md entries
3. The state transitions to `complete`

### `complete`

Release the lock and report:
- "Milestone {M###} complete. {N} phases, {M} tasks dispatched across {D} dispatch cycles."
- Include total duration and budget usage from the execution log

### Lock Release on All Exit Paths

The lock MUST be released on every exit:
- Normal completion → release after reporting
- Pause requested → release after writing continue file
- Budget exceeded → release after writing continue file
- Stuck detected → release after writing continue file
- Verification failure → release after recording
- Unexpected state → release before exiting
- Error in lock operations → the lock file may be orphaned; `resume` handles stale locks

## Idempotency

- **Already complete**: If auto mode is invoked when the milestone state is `complete`, report "Milestone already complete" and exit without acquiring a lock.
- **Task already done**: If the next task already has a `T##-SUMMARY.md`, skip it and advance to the following task. This ensures re-running auto mode after a crash picks up where it left off without re-executing completed tasks.
- **Lock already held**: If a lock is already ACTIVE, refuse to start (prevents duplicate autonomous sessions).
- **Re-invocation safety**: Running auto mode, having it pause, then running it again will resume from the continue file's position — it will not re-dispatch completed tasks.

## Error Handling

### Task Dispatch Failure

If the dispatched task fails (agent crash, timeout, unexpected error):
- Record the failure in `execution-log.jsonl` with `"outcome":"failure"`
- Do NOT retry automatically — the stuck detector will catch repeated failures on the next loop iteration
- Continue to Step A for the next iteration (the same task will be attempted again since no summary was produced)

### Verification Failure After Task

- First failure: Retry once with diagnostic context appended to the dispatch payload
- Second failure: Pause with continue file and surface the specific failed checks

### Lock File Operations Failure

If `lock-manager.sh` returns a non-zero exit code during create, update, or break:
- Report "Lock operation failed: {error details}" to stderr
- Exit 1 immediately — lock integrity is critical for crash recovery

### Unexpected State from derive-phase.sh

If the state derivation returns an unrecognized state:
- Log a warning: "Unexpected state '{state}' from derive-phase.sh"
- Release the lock
- Exit gracefully with a recommendation to check the milestone directory

### Missing Scripts or Templates

If a required script is not found:
- Report "Required script not found: {path}. Orchestrator installation may be incomplete."
- Release the lock
- Exit 1

## Referenced Scripts

- `scripts/lifecycle/lock-manager.sh` — lock file lifecycle (create, status, break, update)
- `scripts/lifecycle/stuck-detector.sh` — stuck detection from execution log
- `scripts/lifecycle/budget-checker.sh` — budget enforcement (dispatch count and duration)
- `scripts/lifecycle/recovery-briefing.sh` — crash recovery context synthesis
- `scripts/state/derive-phase.sh` — state derivation from disk artifacts
- `scripts/state/read-roadmap.sh` — roadmap parsing (tier, phases, active phase)
- `scripts/state/read-config.sh` — configuration value resolution
- `scripts/dispatch/build-context.sh` — context payload assembly with scope filtering
- `scripts/dispatch/detect-capabilities.sh` — runtime capability detection
- `scripts/verify/check-must-haves.sh` — Tier 1 must-have verification
- `scripts/verify/check-boundary-map.sh` — Tier 1 boundary map verification
- `scripts/verify/run-commands.sh` — Tier 2 configured command execution

## Referenced Templates

- `templates/continue-file.md` — pause/budget/stuck continue file format
- `templates/dispatch-prompt.md` — dispatch payload structure

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

```bash
bash scripts/state/read-roadmap.sh <roadmap-file> tier
```

Auto mode is only available for **Tier C** projects (FR-054). If the tier is B, report "Autonomous mode is only available for Tier C projects. Use `speckit.orchestrator.dispatch` for guided execution." and exit.

If the tier is A, report "Tier A projects do not use orchestrator dispatch. Use spec-kit commands directly." and exit.

### 4. Worktree Isolation (FR-075)

If `git_isolation` is configured to `true`:

```bash
git_isolation=$(bash scripts/state/read-config.sh <root> git_isolation)
```

When `git_isolation=true`, dispatched tasks execute within a git worktree created by `scaffold.sh` at `.worktrees/<M###>`. This isolates orchestrator work from the main branch. The worktree is merged back during `speckit.orchestrator.consolidate`.

If `git_isolation=false` (default), tasks execute in the current working tree.

## Lock Acquisition

Acquire the execution lock before entering the loop:

```bash
bash scripts/lifecycle/lock-manager.sh create .specify/orchestrator/orchestrator.lock "auto-dispatch" "<M###>/<active-phase>/<next-task>"
```

The lock file records the current PID, operation type, current unit, timestamp, and git branch for crash recovery context.

**Important:** The lock MUST be released on every exit path — normal completion, pause, error, or unexpected state.

## Autonomous Loop

The loop uses `scripts/lifecycle/auto-loop.sh` to handle mechanical steps, with the agent performing dispatch and verification between calls.

### Iteration Pattern

Each iteration has three stages:

#### Stage 1 — Pre-Dispatch (mechanical)

```bash
output=$(bash scripts/lifecycle/auto-loop.sh <milestone-dir>)
```

Parse the output to get milestone, phase, task, and payload. The payload is written to stdout. Handle exit codes:
- **0 + AUTO:READY** → proceed to Stage 2
- **0 + AUTO:PHASE_COMPLETE** → handle phase transition (see below)
- **0 + AUTO:MILESTONE_VALIDATING** → handle milestone validation (see below)
- **2** → budget exceeded, release lock and exit
- **3** → stuck detected, release lock and exit
- **10** → milestone complete, release lock and exit
- **11** → pause requested, release lock and exit
- **12** → unexpected state, release lock and exit

#### Stage 2 — Dispatch + Verify (agent judgment)

**a. Dispatch**: Use the assembled payload to execute the task.

- If `agent_tool_available=true` (from `detect-capabilities.sh`): Use the Agent tool with the payload as prompt. See `templates/claude-code-appendix.md`.
- If `subagent_dispatch=true` but no agent tool: Use CLI subagent dispatch.
- If `subagent_dispatch=false`: Execute sequentially in current context.

**b. Verify**: Run `speckit.orchestrator.verify` on the completed task. Capture the verification report output.

- **Pass** → proceed to Stage 3 with `outcome=success`, `verification_result=pass`
- **Fail (first attempt)** → retry dispatch. Construct the retry payload by appending a verification failure section to the original dispatch payload:

  ```
  ## Verification Failure Context

  The previous attempt failed verification. Address these specific failures before proceeding:

  <captured verification report output — include specific failed checks, failure messages, and any task summary from the failed attempt>
  ```

  Dispatch again with this augmented payload. The retry uses `--attempt=2` when recording.
- **Fail (second attempt)** → record failure via `auto-loop.sh --step=G --task=T## --outcome=failure --verification_result=fail --attempt=2`, write continue file with the failed verification details, release lock, exit
- **Pass with concerns (DONE_WITH_CONCERNS)** → evaluate: correctness concerns block, observational concerns proceed (US3 AS6)

#### Stage 3 — Post-Dispatch (mechanical)

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=G \
  --task=T## --outcome=success --verification_result=pass --duration_s=N
```

Parse the output:
- **AUTO:ADVANCE next_task=T##** → loop back to Stage 1
- **AUTO:PHASE_COMPLETE phase=P##** → handle phase transition (see below)
- **AUTO:MILESTONE_VALIDATING** → handle milestone validation (see below)
- **AUTO:MILESTONE_COMPLETE** → release lock, report completion

## Pause Handling (FR-047)

The autonomous loop checks for a pause request via `auto-loop.sh` (exit code 11) at the top of each pre-dispatch iteration.

The developer can create the `.specify/orchestrator/pause-requested` file from a second terminal while auto mode runs.

When a pause is detected:

1. **Write continue file** following `templates/continue-file.md` with current position, completed work (from the lock file's `completedUnits`), remaining tasks, and next action.
2. **Release the lock**: `bash scripts/lifecycle/lock-manager.sh break .specify/orchestrator/orchestrator.lock`
3. **Report**: "Autonomous execution paused at {position}. Continue file written. Run `speckit.orchestrator.resume` to resume."
4. **Exit cleanly** with exit code 0.

## Phase Transition

When `auto-loop.sh` returns `AUTO:PHASE_COMPLETE` or `derive-phase.sh` returns `summarizing`:

### External Modification Check (FR-064)

```bash
bash scripts/verify/check-external-mods.sh .specify/orchestrator/orchestrator.lock --scope "<phase-scope-pattern>"
```

If `WARN` lines are returned, include them in the phase transition report. External modifications are informational — they do not block phase transition.

### Two-Stage Review (FR-015 / FR-059 / FR-060)

1. **Stage 1 — Verification**: Run `speckit.orchestrator.verify` on the phase to execute the full 4-tier verification pipeline.

2. **Stage 2 — Phase Summary**: If verification passes, produce the phase summary using `write-summary.sh`. Read all task summaries from the phase to derive field values, then run:

   ```bash
   bash scripts/knowledge/write-summary.sh phase <milestone-dir>/phases/<P##>/<P##>-SUMMARY.md \
     --id=P## \
     --parent=M### \
     --milestone=M### \
     --provides="<what this phase delivers — derive from task summaries>" \
     --requires="<upstream dependencies — derive from phase plan>" \
     --affects="<downstream phases — derive from roadmap>" \
     --key_files="<key files created/modified across all tasks>" \
     --key_decisions="<decision IDs from this phase>" \
     --patterns_established="<patterns established across tasks>" \
     --drill_down_paths="<paths to task summaries>" \
     --duration=<total phase duration from execution log> \
     --verification_result=pass \
     --completed_at=<ISO-8601 timestamp> \
     --observability_surfaces="<metrics or logs if applicable>" \
     --body="<synthesized summary: what was built, key decisions, patterns, verification results>"
   ```

   Do NOT write phase summaries freeform. The 16 frontmatter fields are required for downstream consumption by `consolidate-artifacts.sh` and knowledge compounding.

3. **Roadmap Reassessment (FR-009 / FR-061)**: After the phase summary is written, perform mandatory roadmap reassessment:
   - Check for deviations from the original plan
   - Check for new interfaces not in the boundary map
   - Check decisions register for entries that invalidate downstream assumptions
   - If no changes needed: log and proceed
   - If downstream phases affected: mark as stale (triggers `replanning`), record the reassessment in the decisions register using `append-decision.sh`:

     ```bash
     bash scripts/knowledge/append-decision.sh <orchestrator-root>/DECISIONS.md \
       "M###/P##" "scope" "Roadmap reassessment after P## completion" \
       "<what changed>" "<why it changed>" "No"
     ```

     Do NOT append to DECISIONS.md freeform.
   - Reassessment MUST NOT modify completed or just-finished phases

4. **Advance**: `derive-phase.sh` returns the next phase's state on the next loop iteration.

### Phase Verification Failure

If phase-level verification fails:
- Record the failure in the execution log
- Write a continue file with the failed verification details
- Release the lock
- Report and exit cleanly

## Completion

When `auto-loop.sh` returns a terminal state:

### `validating`

The milestone validation gate (Tier C only):
1. Run cross-phase validation — verify boundary map produces/consumes across all phases
2. Check that all phase summaries exist
3. If validation passes, state transitions to `completing`
4. If validation fails, report specific failures and exit

### `completing`

Write the milestone summary using `write-summary.sh`. Read all phase summaries to derive field values, then run:

```bash
bash scripts/knowledge/write-summary.sh milestone <milestone-dir>/<M###>-SUMMARY.md \
  --id=M### \
  --parent=<feature-ref> \
  --milestone=M### \
  --provides="<what this milestone delivers — derive from phase summaries>" \
  --requires="<external dependencies>" \
  --affects="<downstream milestones or systems>" \
  --key_files="<key files across all phases>" \
  --key_decisions="<arch-scoped and milestone-scoped decisions>" \
  --patterns_established="<patterns established across phases>" \
  --drill_down_paths="<paths to phase summaries>" \
  --duration=<total milestone duration from execution log> \
  --verification_result=pass \
  --completed_at=<ISO-8601 timestamp> \
  --observability_surfaces="<metrics or logs if applicable>" \
  --body="<synthesized summary: what was built across all phases, cross-cutting patterns, verification results>"
```

Do NOT write milestone summaries freeform. After writing, compress knowledge into milestone-scoped KNOWLEDGE.md entries using `append-knowledge.sh`. For each key pattern or lesson from the milestone, run:

```bash
bash scripts/knowledge/append-knowledge.sh <orchestrator-root>/KNOWLEDGE.md \
  "<knowledge entry text>" \
  "milestone:M###"
```

Do NOT append to KNOWLEDGE.md freeform. State transitions to `complete`.

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
- **Task already done**: If the next task already has a `T##-SUMMARY.md`, `auto-loop.sh` skips it and advances to the following task.
- **Lock already held**: If a lock is already ACTIVE, refuse to start (prevents duplicate autonomous sessions).
- **Re-invocation safety**: Running auto mode, having it pause, then running it again will resume from the continue file's position — it will not re-dispatch completed tasks.

## Error Handling

### Task Dispatch Failure

If the dispatched task fails (agent crash, timeout, unexpected error):
- Record the failure via `auto-loop.sh --step=G --outcome=failure`
- Do NOT retry automatically — the stuck detector will catch repeated failures
- Continue to Stage 1 for the next iteration

### Verification Failure After Task

- First failure: Retry once with diagnostic context appended to the dispatch payload
- Second failure: Pause with continue file and surface the specific failed checks

### Lock File Operations Failure

If `lock-manager.sh` returns a non-zero exit code:
- Report "Lock operation failed: {error details}" to stderr
- Exit 1 immediately — lock integrity is critical for crash recovery

### Unexpected State from derive-phase.sh

`auto-loop.sh` exits with code 12 for unrecognized states. Release the lock and exit gracefully.

### Missing Scripts or Templates

`auto-loop.sh` validates required scripts at startup. If any are missing, it exits 1 with a descriptive error.

## Gotchas

- **Only Tier C projects can use auto mode**: Tier B uses guided dispatch via `speckit.orchestrator.dispatch`. Tier A bypasses the orchestrator entirely.
- **Stale lock requires `resume`, not re-invocation**: Auto mode refuses to start with a stale lock — it does not auto-break it. Run `speckit.orchestrator.resume` for crash recovery to ensure no work is lost.
- **Pause detection is checked between tasks, not during**: A `pause-requested` file created while a task is executing will not take effect until that task completes and the loop returns to Stage 1.
- **DONE_WITH_CONCERNS evaluation**: Concerns affecting correctness or scope block advancement; observational concerns are noted in the task summary and the loop proceeds (US3 AS6).

## Referenced Scripts

- `scripts/lifecycle/auto-loop.sh` — mechanical loop driver (pre-dispatch + post-dispatch)
- `scripts/lifecycle/lock-manager.sh` — lock file lifecycle (create, status, break, update)
- `scripts/lifecycle/stuck-detector.sh` — stuck detection from execution log
- `scripts/lifecycle/budget-checker.sh` — budget enforcement (dispatch count and duration)
- `scripts/lifecycle/record-result.sh` — execution log recording
- `scripts/lifecycle/sync-roadmap.sh` — roadmap-to-disk state synchronization
- `scripts/lifecycle/recovery-briefing.sh` — crash recovery context synthesis
- `scripts/state/derive-phase.sh` — state derivation from disk artifacts
- `scripts/state/read-roadmap.sh` — roadmap parsing (tier, phases, active phase)
- `scripts/state/read-config.sh` — configuration value resolution
- `scripts/dispatch/build-context.sh` — context payload assembly with scope filtering
- `scripts/dispatch/detect-capabilities.sh` — runtime capability detection
- `scripts/knowledge/write-summary.sh` — structured summary generation (task, phase, milestone)
- `scripts/knowledge/append-knowledge.sh` — scoped knowledge entry appending (append-only)
- `scripts/knowledge/append-decision.sh` — decision register row appending (append-only)
- `scripts/verify/check-must-haves.sh` — Tier 1 must-have verification
- `scripts/verify/check-boundary-map.sh` — Tier 1 boundary map verification
- `scripts/verify/run-commands.sh` — Tier 2 configured command execution

## Referenced Templates

- `templates/continue-file.md` — pause/budget/stuck continue file format
- `templates/dispatch-prompt.md` — dispatch payload structure
- `templates/claude-code-appendix.md` — Claude Code-specific dispatch instructions
- `templates/claude-settings.json` — recommended project permissions

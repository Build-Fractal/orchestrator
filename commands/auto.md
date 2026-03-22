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

### 4. Permission Pre-Flight

Check that `.claude/settings.json` exists in the target project with orchestrator permissions. Without this, autonomous execution will be interrupted by permission prompts for every tool call.

```bash
test -f .claude/settings.json && echo "EXISTS" || echo "MISSING"
```

- **EXISTS**: Continue (permissions are already configured).
- **MISSING**: Copy the recommended permissions template to the project:

  ```bash
  mkdir -p .claude
  cp templates/claude-settings.json .claude/settings.json
  ```

  Report: "Created `.claude/settings.json` with orchestrator permissions. Review and adjust for your project's toolchain if needed."

The template at `templates/claude-settings.json` includes permissions for common build tools (npm, npx, node, tsc, eslint, jest, python, cargo, go, make) and shell utilities (grep, test, cat, wc, mkdir, find, etc.). For projects with custom toolchains, the developer should add project-specific patterns before starting auto mode.

### 5. Worktree Isolation (FR-075)

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

Parse the output to get milestone, phase, task, and payload file path. The `AUTO:READY` line includes `payload_file=<path>` pointing to the assembled dispatch payload on disk. Handle exit codes:
- **0 + AUTO:READY** → proceed to Stage 2
- **0 + AUTO:PHASE_COMPLETE** → handle phase transition (see below)
- **0 + AUTO:MILESTONE_VALIDATING** → handle milestone validation (see below)
- **0 + AUTO:PLANNING** → handle phase planning (see below)
- **2** → budget exceeded, release lock and exit
- **3** → stuck detected, release lock and exit
- **10** → milestone complete, release lock and exit
- **11** → pause requested, release lock and exit
- **12** → unexpected state, release lock and exit

#### Stage 2 — Dispatch + Verify (agent judgment)

**a. Dispatch**: Read the payload file from the `payload_file` path in the `AUTO:READY` output. Pass its contents directly as the Agent tool prompt — do NOT manually read task plans, upstream summaries, knowledge files, or decisions yourself. The payload is pre-assembled by `build-context.sh` with scope-filtered context.

**Capability self-check**: Check your own toolkit to determine the dispatch method:
- If you have the **Agent tool** available: Use it with the payload as prompt and `subagent_type='general-purpose'`. See `templates/claude-code-appendix.md`.
- If you have **CLI access** to `claude` or `cursor`: Use CLI subagent dispatch.
- If neither is available: Execute sequentially in current context.

Do NOT rely on `detect-capabilities.sh` for in-process tool detection — shell scripts cannot detect in-process agent tools. The script is useful only for detecting CLI-level capabilities (git, shell, worktree).

**b. Task-Level Verification**: After the task completes, run the **task plan's verification commands** (from the task plan's Verification / Must-Haves section). This is a quick Tier 1 check — grep patterns, line counts, command exit codes — NOT the full `speckit.orchestrator.verify` pipeline.

```bash
# Example: run the verification commands listed in the task plan
grep -q "expected_pattern" path/to/file.ts && echo "PASS" || echo "FAIL"
test -f path/to/expected-file.ts && echo "PASS" || echo "FAIL"
```

The full `speckit.orchestrator.verify` command (4-tier verification pipeline) runs only at **phase boundaries** — see the Phase Transition section below. Running it after every task would be wasteful.

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

## Phase Planning

When `auto-loop.sh` returns `AUTO:PLANNING phase=P## milestone=M###`, the active phase needs a plan before tasks can be dispatched. This is a first-class stage in the auto loop.

### Planning Dispatch

1. **Assemble planning context**: Run `build-context.sh` at the phase level to gather the roadmap, spec, upstream summaries, and decisions:

   ```bash
   bash scripts/dispatch/build-context.sh <orchestrator-root> <M###> <P##> PHASE_PLAN 2>/dev/null || true
   ```

   If `build-context.sh` does not support a `PHASE_PLAN` pseudo-task, assemble the context manually by reading:
   - The roadmap (`M###-ROADMAP.md`) for the phase's goal, demo, dependencies, and boundary map
   - Upstream phase summaries (`P##-SUMMARY.md` for each dependency)
   - The feature spec (`specs/{NNN}-{name}/spec.md`) for relevant requirements
   - The context draft (if it exists at `<orchestrator-root>/CONTEXT.md`)

2. **Dispatch planning**: Use the Agent tool (or equivalent) with a prompt that includes:
   - The assembled context from step 1
   - Instructions to follow the `speckit.orchestrator.plan-phase` command (reference `commands/plan-phase.md`)
   - The target phase ID and milestone directory path

   ```
   Agent(prompt="Plan phase P## for milestone M### following the speckit.orchestrator.plan-phase command.\n\n<assembled context>\n\nMilestone directory: <milestone-dir>", subagent_type="general-purpose")
   ```

3. **Verify planning completed**: After the planning agent returns, check that the phase plan and task plans exist:

   ```bash
   test -f <milestone-dir>/phases/P##/P##-PLAN.md && echo "PLAN_EXISTS" || echo "PLAN_MISSING"
   ls <milestone-dir>/phases/P##/tasks/T*-PLAN.md 2>/dev/null | wc -l
   ```

   If the plan exists and task plans were generated, loop back to Stage 1 — `derive-phase.sh` will now return `executing` and the normal dispatch flow resumes.

   If planning failed, write a continue file with the failure details, release the lock, and exit.

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

### Automated Field Derivation

Run `phase-transition.sh` to automate the mechanical parts of phase transition — external mod check, task summary synthesis, and roadmap sync:

```bash
output=$(bash scripts/lifecycle/phase-transition.sh <milestone-dir> <P##> --lock-file .specify/orchestrator/orchestrator.lock)
```

This script reads all task summaries from the completed phase and outputs key=value pairs for `write-summary.sh` fields: `provides`, `requires`, `affects`, `key_files`, `key_decisions`, `patterns_established`, `drill_down_paths`, `duration`, `completed_at`, and `task_count`. It also runs the external modification check and roadmap sync automatically.

Parse the output to extract the derived field values, then review them before writing the phase summary. The agent should review and potentially refine the values (especially `provides` and `body`) but should use the derived values as the starting point rather than reading all task summaries manually.

### Two-Stage Review (FR-015 / FR-059 / FR-060)

1. **Stage 1 — Phase Verification**: Run `speckit.orchestrator.verify` on the phase to execute the full 4-tier verification pipeline. This is the only point where the full verification command runs — NOT after individual tasks.

2. **Stage 2 — Phase Summary**: If verification passes, produce the phase summary using `write-summary.sh` with the field values derived by `phase-transition.sh`:

   ```bash
   bash scripts/knowledge/write-summary.sh phase <milestone-dir>/phases/<P##>/<P##>-SUMMARY.md \
     --id=<id from phase-transition.sh> \
     --parent=<parent from phase-transition.sh> \
     --milestone=<milestone from phase-transition.sh> \
     --provides="<provides from phase-transition.sh — review and refine>" \
     --requires="<requires from phase-transition.sh>" \
     --affects="<affects from phase-transition.sh>" \
     --key_files="<key_files from phase-transition.sh>" \
     --key_decisions="<key_decisions from phase-transition.sh>" \
     --patterns_established="<patterns_established from phase-transition.sh>" \
     --drill_down_paths="<drill_down_paths from phase-transition.sh>" \
     --duration=<duration from phase-transition.sh> \
     --verification_result=pass \
     --completed_at=<completed_at from phase-transition.sh> \
     --observability_surfaces="<metrics or logs if applicable>" \
     --body="<synthesized summary: what was built, key decisions, patterns, verification results>"
   ```

   The `--body` and `--observability_surfaces` fields still require agent judgment — `phase-transition.sh` provides the factual fields, the agent synthesizes the narrative.

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
- `scripts/lifecycle/phase-transition.sh` — phase boundary automation (field derivation, external mod check, roadmap sync)
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

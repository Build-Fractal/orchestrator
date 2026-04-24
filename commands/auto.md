---
description: "Use when running fully autonomous execution on a Tier C project. Acquires a lock, then loops: derive state → check budget/stuck → dispatch task → verify → record → advance, until the milestone completes, a blocker is encountered, or a pause is requested."
---

# orchestrator:auto

Run the autonomous dispatch loop for a Tier C milestone. This command owns the full execution cycle — it acquires a lock, dispatches tasks one at a time in fresh contexts with verification between each, handles pause/stuck/budget gates, and releases the lock on any exit path.

## Intensity Behavior

This command is an intensity-aware stage. At entry of every loop iteration, call:

```bash
bash scripts/engine/intensity-gate.sh --stage auto --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps                      | Behavior |
|-----------|---------------------------------------|----------|
| Quick     | dispatch,no-pause                     | Dispatch the next task and advance immediately after verification. No pause gates between tasks. Auto mode runs end-to-end without interruption. |
| Standard  | dispatch,standard-pause               | Dispatch + standard pause gates (pause on verification failure; pause on budget threshold; pause on explicit `pause_requested` file). |
| Full      | dispatch,strict-pause,human-review    | Dispatch + strict pause gates + human review gate. After each task summary, write a `pending_review` flag; auto loop waits until a human clears it before proceeding to the next task. High-risk stance for platform-level work. |

Intensity can be overridden mid-run via `bash scripts/engine/intensity-override.sh --metadata-file <path> --new-intensity <level>`. The next auto iteration reads the new value and scales accordingly; completed iterations are preserved.

## Prerequisites

Before entering the autonomous loop, verify all preconditions:

### 1. Find Active Milestone and Derive State

Use the milestone finder to identify the auto-eligible milestone and its state in a single script call:

```bash
bash scripts/state/find-active-milestone.sh .orchestrator
```

This returns one line: `M### <state> <tier>` for the first Tier C milestone in an auto-eligible state (executing, planning, summarizing, validating, completing).

- If output is `NONE` (exit 1), no eligible milestone exists. Report "No Tier C milestone eligible for auto mode" and exit.
- If a milestone is found, parse the milestone ID, state, and tier from the output.

To see all milestones: `bash scripts/state/find-active-milestone.sh .orchestrator --all`

**Explicit milestone targeting**: when the caller named a specific milestone (e.g. `orchestrator:auto milestone=M026`), pass it through to the finder so the default "first numerically-sorted planning milestone" heuristic doesn't pick a different one:

```bash
bash scripts/state/find-active-milestone.sh .orchestrator --milestone M026
```

The finder validates that `M026` exists, is tier C, and is in an auto-eligible state — and fails loud with a specific reason if any of those conditions is not met (rather than silently falling back to the next eligible milestone).

**State validation:**
- `executing`, `planning`, `summarizing`, `validating`, `completing` — valid, proceed
- `complete` — report "Milestone already complete" and exit without acquiring a lock
- `pre-planning`, `discussing` — report "Milestone is not ready for autonomous execution — run `speckit.orchestrator.evaluate` first" and exit

**Tier validation** (already handled by the finder, but for explicit invocation):

```bash
bash scripts/state/read-roadmap.sh <roadmap-file> tier
```

Auto mode is only available for **Tier C** (FR-054). Tier B → "Use `speckit.orchestrator.dispatch`". Tier A → "Use spec-kit commands directly."

**IMPORTANT — No compound bash:** Do NOT use `for` loops, `if/elif/else` chains, or `$()` substitution in inline bash commands. The harness safety heuristic (AD-19) flags these patterns and triggers interactive prompts that block unattended execution. Always use single-script invocations.

### 2. Check for Existing Lock

```bash
bash scripts/lifecycle/lock-manager.sh status .orchestrator/orchestrator.lock
```

- **LOCK:ACTIVE** — Another session owns execution. Report "Lock held by PID {pid} since {started_at} on unit {unit_id}. Autonomous mode cannot start while another session is active." and exit.
- **LOCK:STALE** — A previous session crashed. Report "Stale lock detected (PID {pid} not running). Run `speckit.orchestrator.resume` for crash recovery." and exit. Do NOT auto-break the lock — crash recovery via `resume` ensures no work is lost.
- **LOCK:NONE** — No lock exists, safe to proceed.

### 3. Verify Tier C

Already verified by `find-active-milestone.sh` in step 1. For explicit check:

```bash
bash scripts/state/read-roadmap.sh <roadmap-file> tier
```

Auto mode is only available for **Tier C** projects (FR-054). If the tier is B, report "Autonomous mode is only available for Tier C projects. Use `speckit.orchestrator.dispatch` for guided execution." and exit.

If the tier is A, report "Tier A projects do not use orchestrator dispatch. Use spec-kit commands directly." and exit.

### 4. Permission Pre-Flight

Check that the project has autonomy permissions wired up. Without them,
autonomous execution will be interrupted by permission prompts for every
tool call.

Use the single-script pre-flight check:

```bash
bash scripts/lifecycle/check-settings-state.sh .
```

This script handles the full conditional pipeline in one invocation:
- **SETTINGS:MISSING** — generates from project introspection (or template fallback) and writes `.claude/settings.json`
- **SETTINGS:ORCHESTRATOR** — regenerates to catch toolchain drift since last generation
- **SETTINGS:USER_AUTHORED** — merges orchestrator patterns into existing file (AD-13: user autonomy wins)
- **SETTINGS:EXISTS** — settings present, pipeline unavailable, continues as-is
- **SETTINGS:ERROR** — pre-flight failed, escalate and exit before acquiring the lock

The script also runs `check-permissions.sh` drift detection if available, reporting `DOCTOR:PERMISSIONS` output.

**Do NOT use inline `if/elif/else` for settings state detection.** The branching logic and multi-step pipeline (`generate → write → drift check`) contains compound bash patterns that trigger the harness safety heuristic (AD-19) and cause interactive prompts. The wrapper script encapsulates all of this.

### Known Limitations: Harness Safety Heuristics

Claude Code's bash permission system has two independent layers:

1. **The permission layer** — `.claude/settings.json` `defaultMode` plus
   allow/deny pattern matching. This is what `generate-permissions.sh`
   targets. Generating a comprehensive allow list from introspection
   eliminates the vast majority of unattended-mode prompts.

2. **The safety heuristic layer** — built-in checks in the harness that
   detect obfuscation-shaped commands and force a user prompt
   **regardless** of the allow list. This layer cannot be disabled from
   `settings.json`, is invisible to the orchestrator, and fires on
   command shape rather than command content. P07's generator does not
   and cannot eliminate this prompt class.

**Observed trigger classes** (from M004/P02 and M004/P05 task
verification; list grows as the harness evolves — treat as indicative,
not exhaustive):

- Brace expansion containing quote characters
- Complex `$variable` expansion inside compound blocks
- `bash -c '...'` with embedded quoted regex or character classes
- Plain `( ... )` subshell groups — **even without `&&`/`||`**
- `source` / `.` builtin with arguments inside a subshell
- Process substitution `<(...)` / `>(...)`
- `cmd <file` input redirection nested inside `$(...)` — e.g.
  `lines=$(wc -l < path/to/file)`
- `&&`/`||` outside a trivial two-token pair
- Command substitution `$(...)` containing pipes
- Compound `;`-separated statements chaining more than two commands
- Inline `for`/`while`/`if` blocks in a single command
- Heredocs feeding commands with further pipes/redirects

**Remedy**: write task plan Truth `Check:` commands and inline
verification blocks as **single-script-file invocations**. Instead of:

```bash
# FAILS harness heuristic (plain subshell + source + compound)
( . scripts/lib/errors.sh && emit_result ok "" "test" | grep -q RESULT: )
```

Write:

```bash
# PASSES harness heuristic (single-file invocation)
bash scripts/verify/check-must-haves.sh
```

The rationale is documented in AD-19 (see
`.orchestrator/milestones/M005/M005-CONTEXT.md`). Task plans
authored per `commands/plan-phase.md` follow this convention by default.
P06's `scripts/diagnostics/check-plans.sh` (advisory lint) flags task
plans that drift from the convention.

### 5. Worktree Isolation (FR-075)

If `git_isolation` is configured to `true`, check the config value via a single-script invocation — do NOT use command substitution `$(...)`:

```bash
bash scripts/state/read-config.sh git_isolation
```

Read the stdout output directly (it prints `true` or `false`). When it prints `true`, dispatched tasks execute within a git worktree created by `scaffold.sh` at `.worktrees/<M###>`. This isolates orchestrator work from the main branch. The worktree is merged back during `speckit.orchestrator.consolidate`.

If it prints `false` (default), tasks execute in the current working tree.

## Lock Acquisition

Acquire the execution lock before entering the loop:

```bash
bash scripts/lifecycle/lock-manager.sh create .orchestrator/orchestrator.lock "auto-dispatch" "<M###>/<active-phase>/<next-task>"
```

The lock file records the current PID, operation type, current unit, timestamp, and git branch for crash recovery context.

**Important:** The lock MUST be released on every exit path — normal completion, pause, error, or unexpected state.

## Autonomous Loop

The loop uses `scripts/lifecycle/auto-loop.sh` to handle mechanical steps, with the agent performing dispatch and verification between calls.

### Iteration Pattern

Each iteration has three stages:

#### Stage 1 — Pre-Dispatch (mechanical)

Run the pre-dispatch script with file-based output. Do NOT use command substitution `$(...)` — it triggers the harness safety heuristic (AD-19):

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --output-file=<milestone-dir>/auto-loop-result.txt
```

Then read `<milestone-dir>/auto-loop-result.txt` to get milestone, phase, task, and payload file path. The `AUTO:READY` line includes `payload_file=<path>` pointing to the assembled dispatch payload on disk. Handle exit codes:
- **0 + AUTO:READY** → proceed to Stage 2
- **0 + AUTO:PHASE_COMPLETE** → handle phase transition (see below), then context check
- **0 + AUTO:MILESTONE_VALIDATING** → handle milestone validation (see below)
- **0 + AUTO:PLANNING** → handle phase planning (see below)
- **2** → budget exceeded, release lock and exit
- **3** → stuck detected, release lock and exit
- **10** → milestone complete, release lock and exit
- **11** → pause requested, release lock and exit
- **12** → unexpected state, release lock and exit
- **14** → context rotation recommended, release lock and exit (from `--step=X`)

#### Stage 2 — Dispatch + Verify (agent judgment)

**a. Dispatch**: Read the payload file from the `payload_file` path in the `AUTO:READY` output. Pass its contents directly as the Agent tool prompt — do NOT manually read task plans, upstream summaries, knowledge files, or decisions yourself. The payload is pre-assembled by `build-context.sh` with scope-filtered context.

**Capability self-check**: Check your own toolkit to determine the dispatch method:
- If you have the **Agent tool** available: Use it with the payload as prompt and `subagent_type='general-purpose'`. See `templates/claude-code-appendix.md`.
- If you have **CLI access** to `claude` or `cursor`: Use CLI subagent dispatch.
- If neither is available: Execute sequentially in current context.

Do NOT rely on `detect-capabilities.sh` for in-process tool detection — shell scripts cannot detect in-process agent tools. The script is useful only for detecting CLI-level capabilities (git, shell, worktree).

**b. Task-Level Verification**: After the task completes, run mechanical verification via `auto-loop.sh --step=V`. Do NOT use command substitution — use file-based output:

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=V --phase=P## --task=T## --output-file=<milestone-dir>/verify-result.txt
```

Then read `<milestone-dir>/verify-result.txt` for the result. The script extracts verification commands from the task plan's Verification / Must-Haves section and runs each one. It reports `AUTO:VERIFY_PASS` or `AUTO:VERIFY_FAIL` with check counts.

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
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=G --task=T## --outcome=success --verification_result=pass --duration_s=N --output-file=<milestone-dir>/post-dispatch-result.txt
```

Then read `<milestone-dir>/post-dispatch-result.txt` for the result:
- **AUTO:RECORDED** → loop back to Stage 1 (pre-dispatch determines the next task)
- **AUTO:PHASE_COMPLETE phase=P##** is NOT emitted from post-dispatch; phase transitions are detected by pre-dispatch

## Phase Planning

When `auto-loop.sh` returns `AUTO:PLANNING phase=P## milestone=M###`, the active phase needs a plan before tasks can be dispatched. This is a first-class stage in the auto loop.

### Planning Dispatch

1. **Read planning context**: The `AUTO:PLANNING` output includes `payload_file=<path>` pointing to a pre-assembled planning payload on disk. Read this file directly — it contains the roadmap phase section, upstream summaries, feature spec, context draft, decisions, and knowledge, assembled by `build-context.sh` in `PHASE_PLAN` mode.

2. **Dispatch planning**: Use the Agent tool (or equivalent) with a prompt that includes:
   - The assembled context from step 1
   - Instructions to follow the `speckit.orchestrator.plan-phase` command (reference `commands/plan-phase.md`)
   - The target phase ID and milestone directory path

   ```
   Agent(prompt="Plan phase P## for milestone M### following the speckit.orchestrator.plan-phase command.\n\n<assembled context>\n\nMilestone directory: <milestone-dir>", subagent_type="general-purpose")
   ```

3. **Verify planning completed**: After the planning agent returns, check that the phase plan and task plans exist. Do NOT use compound boolean chains or pipe chains — use the dedicated helper script:

   ```bash
   bash scripts/util/check-plan-exists.sh <milestone-dir> P##
   ```

   This outputs `PLAN_EXISTS task_plans=<N>` or `PLAN_MISSING task_plans=0`. If the plan exists and task plans were generated (`task_plans > 0`), loop back to Stage 1 — `derive-phase.sh` will now return `executing` and the normal dispatch flow resumes.

   If planning failed, write a continue file with the failure details, release the lock, and exit.

## Pause Handling (FR-047)

The autonomous loop checks for a pause request via `auto-loop.sh` (exit code 11) at the top of each pre-dispatch iteration.

The developer can create the `.orchestrator/pause-requested` file from a second terminal while auto mode runs.

When a pause is detected:

1. **Write continue file** following `templates/continue-file.md` with current position, completed work (from the lock file's `completedUnits`), remaining tasks, and next action.
2. **Release the lock**: `bash scripts/lifecycle/lock-manager.sh break .orchestrator/orchestrator.lock`
3. **Report**: "Autonomous execution paused at {position}. Continue file written. Run `speckit.orchestrator.resume` to resume."
4. **Exit cleanly** with exit code 0.

## Phase Transition

When `auto-loop.sh` returns `AUTO:PHASE_COMPLETE` or `derive-phase.sh` returns `summarizing`:

### Automated Field Derivation

Run `phase-transition.sh` to automate the mechanical parts of phase transition — external mod check, task summary synthesis, and roadmap sync. Do NOT use command substitution — use file-based output:

```bash
bash scripts/lifecycle/phase-transition.sh <milestone-dir> <P##> --lock-file .orchestrator/orchestrator.lock --output-file=<milestone-dir>/transition-result.txt
```

Then read `<milestone-dir>/transition-result.txt` for the derived key=value pairs. The script reads all task summaries from the completed phase and outputs fields for `write-summary.sh`: `provides`, `requires`, `affects`, `key_files`, `key_decisions`, `patterns_established`, `drill_down_paths`, `duration`, `completed_at`, and `task_count`. It also runs the external modification check and roadmap sync automatically.

Parse the file to extract the derived field values, then review them before writing the phase summary. The agent should review and potentially refine the values (especially `provides` and `body`) but should use the derived values as the starting point rather than reading all task summaries manually.

### Two-Stage Review (FR-015 / FR-059 / FR-060)

1. **Stage 1 — Phase Verification**: Run `speckit.orchestrator.verify` on the phase to execute the full 4-tier verification pipeline. This is the only point where the full verification command runs — NOT after individual tasks.

2. **Stage 2 — Phase Summary**: If verification passes, produce the phase summary using `phase-transition.sh --write`. This derives all mechanical fields from task summaries and writes the summary in one call. Only `--body` and `--observability_surfaces` require agent judgment.

   First, write the body text to a file to avoid multiline quoted arguments (AD-19):

   ```bash
   # Use Write tool to create the body file — do NOT use heredoc or echo redirection
   ```

   Write to `<milestone-dir>/phases/<P##>/phase-body.txt` with the synthesized summary (what was built, key decisions, patterns, verification results).

   Then run the transition with `--body-file`:

   ```bash
   bash scripts/lifecycle/phase-transition.sh <milestone-dir> <P##> --lock-file .orchestrator/orchestrator.lock --write --body-file=<milestone-dir>/phases/<P##>/phase-body.txt --observability_surfaces=none --verification_result=pass
   ```

   Do NOT write phase summaries freeform or call `write-summary.sh` directly for phase transitions. The 16 frontmatter fields are required for downstream consumption by `consolidate-artifacts.sh` and knowledge compounding.

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

4. **Context Rotation Check** (FR-CONTEXT): Before advancing, check whether the orchestrator's own context is deep enough to warrant a fresh session. Do NOT use command substitution — use file-based output:

   ```bash
   bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=X --output-file=<milestone-dir>/context-check-result.txt
   ```

   Then read `<milestone-dir>/context-check-result.txt` for the result:
   - **Exit 0 + CONTEXT:OK** → context headroom is sufficient, advance to the next phase normally
   - **Exit 14 + CONTEXT:ROTATE** → context rotation recommended. Handle as follows:

   **On context rotation:**

   a. Parse the `CONTEXT:ROTATE` output to extract `weight`, `limit`, and `next_est` values.

   b. Count completed and remaining phases from the roadmap for the progress report.

   c. Write a continue file at `<milestone-dir>/continue.md` with `reason: context_rotation` in the frontmatter:
      - **Completed Work**: List all phases completed in this session (from the lock file's `completedUnits`)
      - **Remaining Work**: List remaining incomplete phases from the roadmap
      - **Context**: "Proactive context rotation — no errors. Session weight {weight}/{limit}, next phase estimated at {next_est} units."
      - **Next Action**: "Run `speckit.orchestrator.auto` to continue autonomous execution from the next incomplete phase."

   d. Release the lock: `bash scripts/lifecycle/lock-manager.sh break .orchestrator/orchestrator.lock`

   e. Report to the developer with a clear, actionable message:

      ```
      ✓ Phase {completed_phase} complete.
      ⚠ Context rotation — session weight at {weight}/{limit}. Next phase est. {next_est} units.
        Completed: {completed_count}/{total_count} phases in this session.
        Run `speckit.orchestrator.auto` to continue from {next_phase}.
      ```

   f. Exit cleanly. The developer runs `speckit.orchestrator.auto` again, which picks up seamlessly — `derive-phase.sh` identifies the next incomplete phase, task scanning finds the next incomplete task, and the loop resumes in a fresh context.

   **Note:** Context rotation is a proactive reliability measure, not an error. The orchestrator exits *between* phases (never mid-task), so all state is on disk and no work is lost. The continue file is informational — `auto` does not require it to resume because state derivation from disk is authoritative.

5. **Advance**: `derive-phase.sh` returns the next phase's state on the next loop iteration.

### Phase Verification Failure

If phase-level verification fails:
- Record the failure in the execution log
- Write a continue file with the failed verification details
- Release the lock
- Report and exit cleanly

## Completion

When `auto-loop.sh` returns a terminal state:

### `validating`

The milestone validation gate (Tier C only). Use the validation script:

```bash
bash scripts/verify/validate-milestone.sh <milestone-dir>
```

This runs all cross-phase checks in one invocation:
1. Verifies all phases in the roadmap have `P##-SUMMARY.md`
2. Runs `check-boundary-map.sh` for each phase's produces/consumes
3. Verifies key files from phase summaries exist on disk

Output: `VALIDATE: PASS — N/N checks passed` or `VALIDATE: FAIL` with details.

- If validation passes, write the validation marker using `mark-complete.sh`:
  ```bash
  bash scripts/lifecycle/mark-complete.sh .orchestrator <M###>
  ```
  State transitions to `completing`.
- If validation fails, report specific failures and exit.

**Do NOT use `for` loops to iterate over phases manually.** The validation script handles all iteration internally, avoiding harness safety heuristic prompts (AD-19).

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
  --observability_surfaces="<metrics or logs if applicable>" \
  --body="<synthesized summary: what was built across all phases, cross-cutting patterns, verification results>"
```

> **Note**: `--completed_at` is optional — omit it to default to the current UTC timestamp. Do NOT use `$(date ...)` or backtick substitution to generate timestamps. This triggers the harness command-substitution safety prompt and blocks autonomous execution.

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
- Context rotation → release after writing continue file (proactive, not error)
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
- `scripts/lifecycle/context-monitor.sh` — session context weight estimation for rotation decisions
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

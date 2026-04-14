---
description: "Use when checking progress — milestone/phase/task completion, blockers, next action. Read-only command that reports state from disk without modifying anything."
---

# speckit.orchestrator.status

Report the current progress of a milestone — state, phase/task completion, blockers, execution history, and recommended next action. This is a read-only command that never modifies state files.

## State Derivation

Determine the current orchestrator state:

1. **Run state derivation**: `bash scripts/state/derive-phase.sh <milestone-dir>`
2. **Report the current state** name and a brief description:
   - `pre-planning` — Milestone identified but no work started
   - `discussing` — Context draft in progress (Tier C)
   - `planning` — Roadmap or phase plans being generated
   - `replanning` — A phase has been marked stale, plan revision needed (Tier C)
   - `executing` — Tasks being dispatched and worked on
   - `summarizing` — All tasks in active phase done, phase summary needed
   - `validating` — All phases done, milestone validation gate (Tier C)
   - `completing` — Validation passed, milestone summary needed (Tier C)
   - `complete` — Milestone finished

See `references/state-machine.md` for full state descriptions and transition rules.

## Progress Overview

Report completion metrics (FR-038). This information should be retrievable in under 5 seconds (SC-013):

### Milestone Completion

1. **Count phases**: Run `bash scripts/state/read-roadmap.sh <roadmap-file> phases` to get the list of all phases.
2. **Count completed phases**: A phase is complete when its `P##-SUMMARY.md` exists.
3. **Report**: "Milestone: {completed}/{total} phases complete ({percentage}%)"

### Active Phase

1. **Identify active phase**: Run `bash scripts/state/read-roadmap.sh <roadmap-file> active-phase`.
2. **Report phase details**: Phase ID, title, risk level, dependencies.

### Task Completion (within active phase)

1. **Count task plans**: List `T##-PLAN.md` files in the active phase's `tasks/` directory.
2. **Count completed tasks**: A task is complete when its `T##-SUMMARY.md` exists alongside its plan.
3. **Report**: "Active phase {P##}: {completed}/{total} tasks complete ({percentage}%)"

### Overall Progress

Calculate a single progress percentage across all phases:
- Sum of completed tasks across all phases / total tasks across all phases
- Report: "Overall: {completed}/{total} tasks ({percentage}%)"

If no roadmap exists yet, report: "No roadmap generated. Run speckit.orchestrator.evaluate first."

## Blockers

Check for conditions that may block progress:

### Stale Lock File

1. Check for `<milestone-dir>/orchestrator.lock`.
2. If the lock file exists, read the PID from it and check liveness:
   - Local runtime: `kill -0 <pid>` — if the process is not running, the lock is stale.
   - CI runtime: check the workflow API if available.
3. If stale: report "⚠ Stale lock file detected (PID {pid} not running). Consider removing the lock to resume."

### Failed Verification

1. Find the most recent verification report (`P##-VERIFICATION.md`) in the active phase.
2. If its `overall_result` is `fail`, report: "⚠ Last verification failed for {P##}. Review the verification report and address failures before continuing."

### Stuck Detection

1. Read `execution-log.jsonl` entries for the current phase.
2. If the same task ID appears in two consecutive dispatch entries without a summary file created between them, report: "⚠ Task {T##} dispatched twice without completion. Possible stuck condition."

## Execution History

Read the execution log to provide operational context:

1. **Read `execution-log.jsonl`** from the milestone directory.
2. **Report metrics**:
   - Total dispatch count: number of entries in the log
   - Cumulative duration: sum of `duration_seconds` fields (if recorded)
   - Last dispatch: timestamp of the most recent entry
3. **Budget status**: If `dispatch_budget` or `duration_budget` is configured in the orchestrator config (read via `bash scripts/state/read-config.sh <root> dispatch_budget`):
   - Report: "Budget: {used}/{limit} dispatches" or "Budget: {used}/{limit} seconds"
   - If budget is exceeded, report: "⚠ Budget exceeded. Autonomous mode paused per budget_enforcement setting."

If no execution log exists, report: "No dispatch history yet."

## Telemetry Metrics

Surface aggregate execution telemetry from the execution log (FR-115):

1. **Run aggregate metrics**: `bash scripts/telemetry/aggregate-metrics.sh <execution-log> [--milestone=<M###>]`
   - If the active milestone is known, pass `--milestone=<M###>` to scope metrics to that milestone.
   - If no milestone filter is needed (e.g., showing overall progress), omit the flag.

2. **Report metrics** from the text output:
   - **Total cost**: cumulative estimated cost across all dispatches
   - **Avg cost/task**: average cost per dispatched task
   - **Avg duration**: average task duration in seconds
   - **Cache hit rate**: average prompt cache hit rate across telemetry entries
   - **Success rate**: percentage of dispatches with outcome=success
   - **By model**: breakdown of dispatch count and cost per model used
   - **By milestone**: cross-milestone comparison (dispatches, success rate, cost per milestone)

3. **Cross-milestone comparison**: When metrics exist for multiple milestones, show a comparison table:

   ```
   | Milestone | Tasks | Success | Cost    |
   |-----------|-------|---------|---------|
   | M001      | 24    | 95.8%   | $12.50  |
   | M002      | 18    | 100.0%  | $8.75   |
   ```

If no execution log exists or it is empty, report: "No telemetry data available yet."

If `scripts/telemetry/aggregate-metrics.sh` is unavailable, skip the telemetry section and report: "Telemetry aggregation unavailable (aggregate-metrics.sh not found)."

## Next Action

Based on the current state, recommend the next orchestrator command:

| Current State | Recommended Action |
|---------------|--------------------|
| `pre-planning` | Run `speckit.orchestrator.evaluate` to classify the project tier. |
| `discussing` | Run `speckit.orchestrator.discuss` to finalize the context draft. |
| `planning` | Run `speckit.orchestrator.roadmap` or `speckit.orchestrator.plan-phase` to generate the next plan. |
| `replanning` | Review and regenerate the stale phase plan via `speckit.orchestrator.plan-phase`. |
| `executing` | Run `speckit.orchestrator.dispatch` to execute the next task. |
| `summarizing` | Run `speckit.orchestrator.verify` and write the phase summary. |
| `validating` | Validate milestone success criteria across all phases. |
| `completing` | Write the milestone summary using `write-summary.sh`, then compress knowledge. |
| `complete` | Milestone complete. Consider `speckit.orchestrator.consolidate` for knowledge compression. |

## Concurrent Safety

The status command is read-only — it never modifies state files (FR-053):

- Safe to run from a second terminal while autonomous mode runs in another.
- Safe to run while another agent is executing a dispatched task.
- Does not acquire locks, write files, or update the execution log.
- All information is derived from existing files on disk.

## Idempotency

Status is inherently idempotent — it only reads from disk and computes derived values. Running it any number of times produces the same output for the same disk state. No special handling needed.

## Error Handling

- If the milestone directory doesn't exist, report: "No milestone directory found. Run speckit.orchestrator.evaluate to start."
- If the roadmap is missing, report progress as "No roadmap generated yet" and recommend evaluate.
- If `scripts/state/derive-phase.sh` is unavailable, report: "State derivation script not found. Orchestrator may not be properly installed."
- If `execution-log.jsonl` is malformed, skip the execution history section and report: "⚠ Execution log is malformed. History unavailable."

## Gotchas

- **Status is strictly read-only**: It never acquires locks, writes files, or updates logs. Safe to run concurrently with auto mode or dispatched tasks in another terminal.
- **Lock staleness uses PID checking (`kill -0`)**: False positives are possible if the OS has reused a PID. CI runtime liveness checks (GitHub API `run_id` lookup) are deferred to US7.
- **Malformed execution log skips history section**: If `execution-log.jsonl` contains invalid JSON lines, the execution history and budget status sections are omitted rather than failing the command.

## Reference Files

- `scripts/state/derive-phase.sh` — derives current orchestrator state from disk
- `scripts/state/read-roadmap.sh` — parses roadmap for phase list and active phase
- `scripts/state/read-config.sh` — resolves configuration values (budgets, enforcement)
- `references/state-machine.md` — state descriptions, transitions, and derivation rules
- `scripts/telemetry/aggregate-metrics.sh` — computes aggregate telemetry metrics from execution log

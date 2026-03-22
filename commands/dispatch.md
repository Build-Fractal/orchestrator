---
description: "Use when executing one task in a fresh context with constructed payload. Builds a minimal context from state, dispatches to a fresh agent context (or runs sequentially if subagent dispatch unavailable), and records the dispatch in the execution log."
---

# speckit.orchestrator.dispatch

Execute one task in a fresh context by assembling a scope-filtered context payload, dispatching execution, and recording the result.

## Prerequisites

Before dispatching, verify the orchestrator is in the correct state:

1. **Derive current state**: Run `bash scripts/state/derive-phase.sh <milestone-dir>` and confirm the output is `executing`.
2. **Check for stale lock**: If a lock file exists at `<milestone-dir>/orchestrator.lock`, check if the lock holder is still active. If stale (older than the configured duration budget), break the lock and log a warning.
3. **Identify the target task**: The task to dispatch is specified by the caller as `<milestone-id> <phase-id> <task-id>`.

## Context Construction

Assemble the dispatch payload using the context building pipeline:

```bash
bash scripts/dispatch/build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id> [--config-defaults <file>]
```

This script:
- Reads the task plan from `<root>/milestones/<M###>/phases/<P##>/tasks/<T##>-PLAN.md`
- Reads the phase plan excerpt (goal, demo, must-haves) from `<P##>-PLAN.md`
- Reads tier and dependency info from the roadmap via `scripts/state/read-roadmap.sh`
- Gathers upstream summaries from dependency phases
- Runs `scripts/dispatch/scope-filter.sh` on KNOWLEDGE.md and DECISIONS.md with the current M###/P## scope
- Reads config values via `scripts/state/read-config.sh`: context_verbosity, verification_commands, dispatch_budget, duration_budget, budget_enforcement
- Computes payload size and reports context budget percentage to stderr

The output follows the `templates/dispatch-prompt.md` template structure with all `{{placeholder}}` fields filled in.

### Context Verbosity Levels

The `context_verbosity` config key controls how much context is assembled:
- **minimal**: task plan + phase excerpt only (smallest payload)
- **standard**: adds roadmap excerpt, upstream summaries, filtered decisions/knowledge (default)
- **full**: adds all available context artifacts (largest payload)

### Scope Filtering

Context filtering is handled by `scripts/dispatch/scope-filter.sh`:
- For KNOWLEDGE.md: includes `[project]` entries + entries matching current milestone/phase; excludes entries scoped to other milestones or other phases
- For DECISIONS.md: includes rows matching current milestone, current phase, upstream dependencies, and `arch`-scoped rows (architectural — milestone-wide); excludes rows scoped to unrelated phases

## Dispatch Strategy

Check runtime capabilities to determine the dispatch method:

```bash
bash scripts/dispatch/detect-capabilities.sh
```

This reports:
- `subagent_dispatch`: whether a fresh agent context can be spawned
- `shell_execution`: whether shell commands are available
- `git_available` / `git_worktree`: whether git isolation is possible
- `runtime`: `local` or `ci-github`

### Dispatch Methods (in preference order)

1. **Subagent dispatch** (if `subagent_dispatch=true`): Spawn a new agent context with the assembled payload as the initial prompt. The fresh context starts with zero codebase knowledge and builds understanding entirely from the payload.
2. **Sequential execution** (if `subagent_dispatch=false`): Provide the assembled payload directly in the current context. This is the fallback for environments without subagent support.

### Git Isolation

If `git_worktree=true`, create a worktree for the task:
```bash
git worktree add .worktrees/<milestone-id>-<phase-id>-<task-id> HEAD
```
This prevents concurrent task executions from conflicting. Clean up the worktree after task completion.

## Execution Recording

After dispatching, record the execution using `record-result.sh`. Do NOT use inline echo to append to the execution log.

```bash
bash scripts/lifecycle/record-result.sh <milestone-dir>/execution-log.jsonl \
  --milestone=M### \
  --phase=P## \
  --task=T## \
  --outcome=success \
  --tier=<tier> \
  --dispatch_method=<subagent|sequential> \
  --attempt=1 \
  --duration_s=<elapsed-seconds>
```

The execution log is append-only (JSONL format) and provides the audit trail for dispatch history.

## Post-Dispatch

After the dispatched task completes:

1. **Run verification**: Invoke `speckit.orchestrator.verify` on the completed task to confirm must-haves are met.
2. **Record result**: Record the verification outcome using `record-result.sh` with `--verification_result=<pass|fail|skipped>` and `--outcome=<success|failure>`.
3. **State transition**: If verification passes, the task is marked complete. The orchestrator state may transition based on remaining incomplete tasks.

## Idempotency

If the target task already has a `<T##>-SUMMARY.md` file, the dispatch is skipped:
- Output: "Task <T##> already has a summary — skipping dispatch."
- The existing result is reported without re-execution.
- This ensures running dispatch twice with no intervening changes produces identical disk state (R012).

## Error Handling

- Missing required arguments → exit 1 with usage to stderr
- Missing task plan or phase plan → exit 1 with specific file path in error message
- Context budget exceeded (payload > 20% of total artifacts) → warn to stderr but continue (unless budget_enforcement=strict)
- Dispatch failure (subagent crashes, timeout) → record failure in execution log, do NOT retry automatically

## Claude Code Appendix

When running in Claude Code (detected via `CLAUDE_CODE` environment variable by `detect-capabilities.sh`), see `templates/claude-code-appendix.md` for platform-specific dispatch instructions including:

- Agent tool invocation pattern for fresh-context dispatch
- Mandatory `write-summary.sh` usage for structured summaries
- Mandatory `record-result.sh` usage for execution logging
- Recommended permission settings via `templates/claude-settings.json`

## Gotchas

- **Context budget exceeded is a warning unless budget_enforcement is "strict"**: The dispatch continues with an oversized payload by default. Set `budget_enforcement: strict` in orchestrator config to block dispatch when the payload exceeds the configured threshold.
- **Dispatch to a task with existing T##-SUMMARY.md is a no-op**: The task is skipped (idempotency), not treated as an error. No re-execution occurs and no new execution log entry is written.
- **No subagent support falls back to sequential execution**: If `detect-capabilities.sh` reports `subagent_dispatch=false`, the task runs in the current session with explicit context separation instructions. The task still executes — just without process isolation.

## Referenced Scripts

- `scripts/dispatch/build-context.sh` — assembles the context payload
- `scripts/dispatch/scope-filter.sh` — filters knowledge/decisions by scope
- `scripts/dispatch/detect-capabilities.sh` — detects runtime capabilities
- `scripts/state/derive-phase.sh` — derives current orchestrator state
- `scripts/state/read-roadmap.sh` — parses roadmap for tier and dependencies
- `scripts/state/read-config.sh` — resolves configuration values
- `scripts/lifecycle/record-result.sh` — execution log recording (append-only JSONL)

## Referenced Templates

- `templates/dispatch-prompt.md` — output template for the assembled payload

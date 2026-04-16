---
schema_version: "1.0"
type: platform-appendix
platform: claude-code
---

# Claude Code Dispatch Appendix

Platform-specific dispatch instructions for running the orchestrator inside Claude Code.

## Agent Tool Invocation

Use the Agent tool to dispatch tasks in fresh contexts. Pass the assembled dispatch payload as the prompt parameter with `subagent_type='general-purpose'`.

```
Agent(prompt=<assembled dispatch payload>, subagent_type="general-purpose")
```

Each dispatched task runs in a fresh context with zero prior codebase knowledge. The payload assembled by `build-context.sh` is the task's entire world.

## Summary Generation

After completing a task, generate a structured summary using `write-summary.sh`. Do NOT write summaries freeform.

### Task Summary (15 frontmatter fields + body)

```bash
bash scripts/knowledge/write-summary.sh task <output-file> \
  --id=T## \
  --parent=P## \
  --milestone=M### \
  --provides="what this task delivers" \
  --requires="from:P##/T## what:artifact-name" \
  --affects=P## \
  --key_files="scripts/path/to/file.sh" \
  --key_decisions="D###" \
  --patterns_established="pattern name" \
  --drill_down_paths="plans/T##.md" \
  --duration=25m \
  --verification_result=pass \
  --body="Summary body text describing what was done and why."
```

`--completed_at` is optional — omit it to default to the current UTC timestamp. Do NOT use `$(date ...)` or backtick substitution to generate timestamps; this triggers Claude Code's command-substitution safety prompt and blocks autonomous execution.

Auto-set fields: `schema_version` (1.0), `type` (task-summary).

### Phase/Milestone Summary (16 frontmatter fields + body)

Phase and milestone summaries add one additional field: `--observability_surfaces="metric or log name"`.

## Result Recording

After each task dispatch, record the result using `record-result.sh`. Do NOT use inline echo to log results.

```bash
bash scripts/lifecycle/record-result.sh <execution-log.jsonl> \
  --milestone=M### \
  --phase=P## \
  --task=T## \
  --outcome=success \
  --tier=C \
  --dispatch_method=subagent \
  --verification_result=pass \
  --attempt=1 \
  --duration_s=120
```

Valid outcomes: `success`, `failure`, `retry`, `blocked`, `timeout`, `stuck`.

## Autonomous Loop Mechanics

When running in autonomous mode (`speckit.orchestrator.auto`), the mechanical loop driver handles pre-dispatch and post-dispatch steps:

### Pre-Dispatch (Stage 1)

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --output-file=<milestone-dir>/auto-loop-result.txt
```

Then read `<milestone-dir>/auto-loop-result.txt`. Do NOT use `output=$(bash ...)` — command substitution triggers the harness safety prompt.

Outputs `AUTO:READY milestone=M### phase=P## task=T## payload_bytes=N payload_file=<path>` on success. The `payload_file` contains the fully assembled dispatch payload — read it and pass it directly as the Agent tool prompt. Do NOT manually assemble payloads by reading task plans, upstream summaries, knowledge, and decisions yourself.

Exit codes: 0 (ready), 2 (budget exceeded), 3 (stuck), 10 (milestone complete), 11 (pause requested), 12 (unexpected state).

### Post-Dispatch (Stage 3)

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=G \
  --task=T## --outcome=success --verification_result=pass --duration_s=N
```

Outputs `AUTO:RECORDED` followed by `AUTO:ADVANCE next_task=T##`, `AUTO:PHASE_COMPLETE phase=P##`, `AUTO:MILESTONE_VALIDATING`, or `AUTO:MILESTONE_COMPLETE`.

Do NOT call `record-result.sh` or `sync-roadmap.sh` directly during autonomous mode — `auto-loop.sh` wraps both.

## Roadmap Synchronization

After phase transitions, the roadmap is synchronized to disk state:

```bash
bash scripts/lifecycle/sync-roadmap.sh <roadmap-file> <milestone-dir> [--fix]
```

Outputs `SYNC:OK` when roadmap matches disk, or `SYNC:MISMATCH phase=P## roadmap=<state> disk=<state>`. Use `--fix` to auto-correct mismatches.

## Key Rules

1. **Do NOT write summaries freeform.** Always use `write-summary.sh` with all required fields.
2. **Do NOT skip verification.** The state machine requires `P##-VERIFICATION.md` before the phase can transition to summarizing.
3. **Do NOT use inline echo to log results.** Always use `record-result.sh` for the execution log.

## Capability Self-Check

The `scripts/dispatch/detect-capabilities.sh` script detects CLI-level capabilities (git, worktree, shell) but **cannot detect in-process agent tools** like the Agent tool in Claude Code. Shell scripts run in a subprocess and have no visibility into the agent's tool namespace.

When dispatching tasks in auto mode, check your own toolkit directly:
- **Agent tool available?** Check if `Agent` is in your available tools. If yes, use it for fresh-context dispatch.
- **Subagent CLI available?** Check if `claude` or `cursor` CLI is on PATH (detect-capabilities.sh handles this).

Do NOT rely on `agent_tool_available` from `detect-capabilities.sh` — it will always return `false` unless `SPECKIT_AGENT_TOOL=1` is set in the environment.

## Permissions

For recommended Claude Code project permissions, see `templates/claude-settings.json`. The auto command pre-flight check copies this to `.claude/settings.json` if it doesn't exist. The template includes common build tools (npm, npx, tsc, eslint, jest, python, cargo, go, make) and shell utilities. Add project-specific patterns as needed.

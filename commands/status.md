---
description: "Use when checking progress — milestone/phase/task completion, blockers, next action. Read-only command that reports state from disk without modifying anything."
---

# orchestrator:status

Report the current progress of a milestone — state, phase/task completion, blockers, execution history, and recommended next action. This is a read-only command that never modifies state files.

## Headline Block

> **FR-2 / SC-2 / Principle XI / AD-1 single-resolve.** The headline block is the first three non-blank lines of stdout. When invoked without `--format=json`, the headline renders before the existing flat sections; when invoked with `--format=json`, this block is skipped and `scripts/diagnostics/render-status-json.sh` takes over (FR-3, T04).
>
> **Resolution.** Read the resolver's env block at command entry: `eval "$(bash scripts/state/detect-invocation-context.sh)"`. The resolver returns three fields per AD-1 (`renderer`, `exit_code_scheme`, `default_provider`). When `renderer=json`, branch to the JSON renderer (FR-3) and skip the headline+flat-sections path entirely.
>
> **Field set + line packing** are documented in `references/status-headline-shape.md`. The implementation MUST emit lines matching the regex documented there byte-for-byte; SC-2 fails on any drift. The five fields packed into three non-blank lines:
>
> 1. Line 1: `M### <milestone-name>` (e.g., `M029 Roadmap Visibility & CLI UX`).
> 2. Line 2: `phase X/N (P##, K%)  |  lock: <state>` where `<state>` is `free` or `held by PID <pid> since <timestamp>`. Separator is exactly two spaces, pipe, two spaces.
> 3. Line 3: `last_dispatch: <Ns ago | Nm ago | Nh ago | Nd ago | none>  |  last_verify: <pass | fail | none>`. Same separator.
>
> **Embedded footer.** Under `efficiency_footer: true` (M027 default), the headline is followed by the `scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>` line verbatim. Under `efficiency_footer: false` or `--quiet`, the footer line disappears with no other side effect (CON-5 suppression-matrix inheritance from M027). M029 introduces NO new suppression knob — M027's resolution chain (env → local config → project config → defaults) governs the footer line.
>
> **Flat sections invariant.** Below the headline + blank line + footer line, the existing flat sections (Progress Overview, Blockers, Execution History, Telemetry Metrics, Efficiency Footer, Next Action) render byte-identical to today's pre-M029 output. The headline is additive; existing scrapers do not break.
>
> **Test-only seam.** The `M029_DISABLE_HEADLINE=1` environment variable is a TEST-ONLY hook used by the SC-2 baseline-capture path (`tests/m029-acceptance/p01-sc2-headline.sh`) to capture the pre-M029 flat-section rendering. Production callers MUST NOT set this var; it is not a documented end-user knob.

## Format Flag

> **FR-3 / SC-3 / AD-2 / AD-7.** The `--format=<format>` flag selects the rendering mode. Valid values: `tui` (default; the headline+flat-sections markdown path), `json` (the FR-3 JSON object), `plain` (markdown without ANSI; auto-selected by the resolver under non-TTY).
>
> **Resolution.** When `--format=json` is present, the resolver returns `renderer=json`; the headline+flat-sections markdown path is SKIPPED and `bash scripts/diagnostics/render-status-json.sh` is invoked. Its stdout becomes the command's stdout.
>
> **Schema.** The JSON output validates against `references/status-json-schema.md`. The top-level `schema_version` field is `"1.0"` per AD-7.
>
> **ANSI-strip rule (AD-2).** Every string under `sections` is ANSI-stripped unconditionally regardless of TTY. This applies even on interactive TTYs where `--format=json` is invoked manually — the JSON contract is for downstream tooling (`jq`, CI, `external-tool-adapters`), and stripping ANSI universally avoids contract migrations later.
>
> **Degraded state.** When `execution-log.jsonl` parses with errors, the JSON output includes `state: "degraded"` and a `parse_errors` array. The renderer never crashes on a corrupt JSONL stream.

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

If no roadmap exists yet, report: "No roadmap generated. Run `/orchestrator-evaluate` first."

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

## Efficiency Footer

After the telemetry block, render a one-block efficiency footer summarizing milestone-to-date cost + paired quality metrics from the M019 Tier 1 JSONL stream. The footer is governed by two suppression conditions; under EITHER, render NOTHING for this section and proceed directly to `## Next Action`.

### Suppression Conditions

The efficiency footer is suppressed (zero output for this section, output remains byte-identical to pre-M027 `orchestrator:status`) when ANY of:

1. The `--quiet` flag is passed to `orchestrator:status`.
2. The config knob `efficiency_footer` resolves to `false`. Resolution chain: env `ORCH_EFFICIENCY_FOOTER` -> local config -> project config -> defaults. Default is `true`.

Otherwise, render the footer.

### Render

Invoke the helper:

```bash
bash scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>
```

When no active milestone exists, fall back to the project-granularity rollup:

```bash
bash scripts/diagnostics/efficiency-footer.sh --project
```

The helper handles both forms — passing `--quiet` propagates the suppression to the helper. Helper output is a one-block efficiency footer (≤ 6 lines) prefixed with the literal title `Efficiency (Tier 1 rollup)`. When the JSONL stream is empty or absent, the helper emits a single-line `Efficiency: no Tier 1 records yet` (US-3 AS-3) — never an error, never a crash (CON-5 carry-forward).

### Read-Only

The efficiency footer is a read-only consumer of `execution-log.jsonl` — it never writes to or rewrites the log (FR-12 / CON-1). The helper is bash-only; zero LLM tokens (FR-21 / CON-6).

## Next Action

Based on the current state, recommend the next orchestrator command:

| Current State | Recommended Action |
|---------------|--------------------|
| `pre-planning` | Run `/orchestrator-evaluate` to classify the project tier. |
| `discussing` | Run `/orchestrator-discuss` to finalize the context draft. |
| `planning` | Run `/orchestrator-roadmap` or `/orchestrator-plan-phase` to generate the next plan. |
| `replanning` | Review and regenerate the stale phase plan via `/orchestrator-plan-phase`. |
| `executing` | Run `/orchestrator-dispatch` to execute the next task. |
| `summarizing` | Run `/orchestrator-verify` and write the phase summary. |
| `validating` | Validate milestone success criteria across all phases. |
| `completing` | Write the milestone summary using `write-summary.sh`, then compress knowledge. |
| `complete` | Milestone complete. Consider `/orchestrator-consolidate` for knowledge compression. |

## Concurrent Safety

The status command is read-only — it never modifies state files (FR-053):

- Safe to run from a second terminal while autonomous mode runs in another.
- Safe to run while another agent is executing a dispatched task.
- Does not acquire locks, write files, or update the execution log.
- All information is derived from existing files on disk.

## Idempotency

Status is inherently idempotent — it only reads from disk and computes derived values. Running it any number of times produces the same output for the same disk state. No special handling needed.

## Error Handling

- If the milestone directory doesn't exist, report: "No milestone directory found. Run `/orchestrator-evaluate` to start."
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
- `scripts/diagnostics/efficiency-footer.sh` — efficiency footer helper (M027/P02). Sources or forks `scripts/diagnostics/metrics-rollup.sh` for milestone-to-date paired cost+quality aggregates. Read-only.
- `scripts/state/detect-invocation-context.sh` — AD-1 single-resolve invocation-context resolver (M029/P01)
- `references/status-headline-shape.md` — FR-2 design contract (M029/P01)
- `references/status-json-schema.md` — FR-3 design contract (M029/P01; consumed by T04 `--format=json` path)
- `scripts/diagnostics/render-status-json.sh` — FR-3 JSON renderer (M029/P01; consumed by T04)

---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M002"
name: "Integrate Telemetry into Auto-Loop and Status Command"
depends_on: ["T02"]
---

## Prerequisites

T02 is complete. Both telemetry scripts are validated, hardened, and registered in extension.yml. The following scripts are confirmed working:
- `scripts/telemetry/record-telemetry.sh` — appends telemetry entries
- `scripts/telemetry/aggregate-metrics.sh` — computes aggregate metrics

## Description

Wire telemetry data flow into the two key integration points:

1. **auto-loop.sh Step G**: Extend the post-dispatch recording step to accept and pass through telemetry fields (`--model`, `--tokens-input`, `--tokens-output`, `--tokens-cache-read`, `--cost`, `--cache-hit-rate`) to `record-result.sh`. The auto.md command instructs the agent to provide these values when available, but auto-loop.sh currently ignores them.

2. **commands/status.md**: Add a Telemetry Metrics section that instructs the status command agent to run `aggregate-metrics.sh` and display the results. This closes FR-115 (aggregate metrics surfaced in /status).

## Steps

### Step 1: Add telemetry flag parsing to auto-loop.sh Step G

Open `scripts/lifecycle/auto-loop.sh`. Locate the Step G argument parsing section (near line 120-170 where `--task`, `--outcome`, `--verification_result`, `--duration_s` are parsed). Add parsing for these additional flags:

```
--model=*         MODEL_USED="${1#--model=}"
--tokens-input=*  TOKENS_INPUT="${1#--tokens-input=}"
--tokens-output=* TOKENS_OUTPUT="${1#--tokens-output=}"
--tokens-cache-read=* TOKENS_CACHE_READ="${1#--tokens-cache-read=}"
--cost=*          COST_ESTIMATED="${1#--cost=}"
--cache-hit-rate=* CACHE_HIT_RATE="${1#--cache-hit-rate=}"
```

Initialize these variables to empty strings alongside the existing variable initializations (near line 100-110):

```bash
MODEL_USED=""
TOKENS_INPUT=""
TOKENS_OUTPUT=""
TOKENS_CACHE_READ=""
COST_ESTIMATED=""
CACHE_HIT_RATE=""
```

### Step 2: Pass telemetry fields to record-result.sh in Step G

Locate the `record_args` array construction in Step G (near line 156-171). After the existing conditional appends for `VERIFICATION_RESULT` and `DURATION_S`, add conditional appends for the telemetry fields:

```bash
if [[ -n "$MODEL_USED" ]]; then
  record_args+=("--model=$MODEL_USED")
fi
if [[ -n "$TOKENS_INPUT" ]]; then
  record_args+=("--tokens-input=$TOKENS_INPUT")
fi
if [[ -n "$TOKENS_OUTPUT" ]]; then
  record_args+=("--tokens-output=$TOKENS_OUTPUT")
fi
if [[ -n "$TOKENS_CACHE_READ" ]]; then
  record_args+=("--tokens-cache-read=$TOKENS_CACHE_READ")
fi
if [[ -n "$COST_ESTIMATED" ]]; then
  record_args+=("--cost=$COST_ESTIMATED")
fi
if [[ -n "$CACHE_HIT_RATE" ]]; then
  record_args+=("--cache-hit-rate=$CACHE_HIT_RATE")
fi
```

This ensures that when the dispatching agent (auto.md) calls `auto-loop.sh --step=G` with telemetry data, the data flows through to `record-result.sh` and into the execution log. The fields are optional — if the agent does not provide them, the log entry omits them (same as today).

### Step 3: Update commands/status.md to surface telemetry

Open `commands/status.md`. After the existing "Execution History" section (approximately after the budget status reporting), add a new section:

```markdown
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
```

Also add `scripts/telemetry/aggregate-metrics.sh` to the "Reference Files" section at the bottom of status.md:

```markdown
- `scripts/telemetry/aggregate-metrics.sh` — computes aggregate telemetry metrics from execution log
```

### Step 4: Run integration verification scripts

```bash
bash scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh
bash scripts/verify/m002-p05-status-references-aggregate.sh
```

Both should print `PASS: <description>`.

### Step 5: Run all verification scripts to confirm no regressions

```bash
bash scripts/verify/m002-p05-record-telemetry-fields.sh
bash scripts/verify/m002-p05-cost-source-enum.sh
bash scripts/verify/m002-p05-aggregate-metrics-fields.sh
bash scripts/verify/m002-p05-aggregate-json-format.sh
bash scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh
bash scripts/verify/m002-p05-status-references-aggregate.sh
bash scripts/verify/m002-p05-extension-registration.sh
bash scripts/verify/m002-p05-bash32-compat.sh
bash scripts/verify/m002-p05-idempotent.sh
```

All 9 should print `PASS: <description>`.

## Must-Haves

- auto-loop.sh Step G passes telemetry-related flags (--model, --tokens-input, --tokens-output, --tokens-cache-read, --cost, --cache-hit-rate) through to record-result.sh when values are available
- commands/status.md references aggregate-metrics.sh for surfacing telemetry in the /status command output

## Verification

```
bash scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh
bash scripts/verify/m002-p05-status-references-aggregate.sh
```

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh` (from T01) — verification script checking that auto-loop.sh passes `--model`, `--tokens-input`, and `--cost` flags. Prints `PASS`/`FAIL`, exits 0/1.
- `scripts/verify/m002-p05-status-references-aggregate.sh` (from T01) — verification script checking that status.md references `aggregate-metrics`. Prints `PASS`/`FAIL`, exits 0/1.

### From Disk (Pre-existing)

- `scripts/lifecycle/auto-loop.sh` — autonomous loop driver. Step G (post-dispatch recording) starts at approximately line 155. It constructs a `record_args` array with `--milestone`, `--phase`, `--task`, `--outcome`, `--tier=C`, `--dispatch_method=subagent`, and conditionally appends `--verification_result` and `--duration_s`. It then calls `bash "$RECORD_RESULT" "${record_args[@]}"`. The script already has variables for the Step G arguments parsed from CLI flags: `TASK`, `OUTCOME`, `VERIFICATION_RESULT`, `DURATION_S`. New telemetry variables (`MODEL_USED`, `TOKENS_INPUT`, etc.) need to be added in the same pattern.
- `scripts/lifecycle/record-result.sh` — execution log recording (185 lines). Already accepts telemetry flags: `--model=<model-id>`, `--tokens-input=N`, `--tokens-output=N`, `--tokens-cache-read=N`, `--cost=<amount>`, `--cache-hit-rate=<rate>`. These are appended to the JSON entry when provided.
- `commands/status.md` — status command agent instructions (140 lines). Current sections: State Derivation, Progress Overview (Milestone Completion, Active Phase, Task Completion, Overall Progress), Blockers (Stale Lock, Failed Verification, Stuck Detection), Execution History (dispatch count, duration, budget status), Next Action. No telemetry section exists. Reference Files section at the end lists derive-phase.sh, read-roadmap.sh, read-config.sh, state-machine.md.
- `scripts/telemetry/aggregate-metrics.sh` — Interface: `aggregate-metrics.sh <execution-log> [--milestone=M###] [--format=text|json]`. Text output has sections: "=== Execution Telemetry ===", "--- By Model ---", "--- By Milestone ---", "--- By Cost Source ---". JSON output has keys: total_dispatches, success_count, success_rate, total_cost, avg_cost_per_task, avg_duration_s, cache_hit_rate, by_model, by_milestone, by_cost_source.

## Constraints

- auto-loop.sh modifications must be backward-compatible: existing calls without telemetry flags must continue to work identically
- status.md must not break existing status output — telemetry is an additive section
- Do NOT change the interface of record-result.sh — it already accepts the telemetry flags
- All bash modifications must be Bash 3.2 compatible

## Expected Output

- `scripts/lifecycle/auto-loop.sh` — modified to parse and pass through 6 telemetry flags in Step G
- `commands/status.md` — new "Telemetry Metrics" section + aggregate-metrics.sh added to Reference Files
- All 9 verification scripts pass

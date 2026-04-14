---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M002"
name: "End-to-End Telemetry Verification"
depends_on: ["T03"]
---

## Prerequisites

T01-T03 are complete. All telemetry scripts are validated, registered in extension.yml, wired into auto-loop.sh Step G, and referenced in commands/status.md. All 9 verification scripts should already be passing.

## Description

Prove the full telemetry pipeline end-to-end by creating a synthetic execution log with both dispatch and telemetry entries spanning two milestones, then running `aggregate-metrics.sh` in both text and JSON modes to verify all metrics compute correctly. This task confirms that:

1. `record-telemetry.sh` produces well-formed entries
2. `aggregate-metrics.sh` reads both entry types and computes correct metrics
3. `--milestone` filtering works for cross-milestone comparison
4. `--format=json` produces valid, parseable output
5. All 9 phase verification scripts pass

## Steps

### Step 1: Create synthetic execution log for testing

Create a temporary JSONL file with realistic dispatch and telemetry entries spanning two milestones (M001 and M002). The file should exercise all aggregation paths:

```bash
#!/usr/bin/env bash
# Create temp test log
TMPLOG=$(mktemp)
trap 'rm -f "$TMPLOG"' EXIT

# --- M001 entries ---
# Dispatch entry (success)
bash scripts/lifecycle/record-result.sh "$TMPLOG" \
  --milestone=M001 --phase=P01 --task=T01 --outcome=success \
  --tier=C --dispatch_method=subagent --verification_result=pass --duration_s=120

# Telemetry entry for M001/P01/T01
bash scripts/telemetry/record-telemetry.sh "$TMPLOG" \
  --unit-id=M001/P01/T01 \
  --model=claude-sonnet-4-20250514 \
  --tokens-input=5000 --tokens-output=1200 --tokens-cache-read=3000 \
  --cost=0.12 --cost-source=estimated \
  --cache-hit-rate=0.60 --payload-bytes=4096

# Another dispatch (success)
bash scripts/lifecycle/record-result.sh "$TMPLOG" \
  --milestone=M001 --phase=P01 --task=T02 --outcome=success \
  --tier=C --dispatch_method=subagent --verification_result=pass --duration_s=90

# Telemetry for T02
bash scripts/telemetry/record-telemetry.sh "$TMPLOG" \
  --unit-id=M001/P01/T02 \
  --model=claude-sonnet-4-20250514 \
  --tokens-input=4500 --tokens-output=800 --tokens-cache-read=2800 \
  --cost=0.09 --cost-source=estimated \
  --cache-hit-rate=0.62 --payload-bytes=3500

# Dispatch entry (failure)
bash scripts/lifecycle/record-result.sh "$TMPLOG" \
  --milestone=M001 --phase=P02 --task=T01 --outcome=failure \
  --tier=C --dispatch_method=subagent --verification_result=fail --duration_s=200

# Telemetry for failed task
bash scripts/telemetry/record-telemetry.sh "$TMPLOG" \
  --unit-id=M001/P02/T01 \
  --model=claude-opus-4-20250514 \
  --tokens-input=12000 --tokens-output=3500 --tokens-cache-read=8000 \
  --cost=0.85 --cost-source=estimated \
  --cache-hit-rate=0.67 --payload-bytes=9800

# --- M002 entries ---
# Dispatch entry (success)
bash scripts/lifecycle/record-result.sh "$TMPLOG" \
  --milestone=M002 --phase=P01 --task=T01 --outcome=success \
  --tier=C --dispatch_method=subagent --verification_result=pass --duration_s=150

# Telemetry for M002/P01/T01
bash scripts/telemetry/record-telemetry.sh "$TMPLOG" \
  --unit-id=M002/P01/T01 \
  --model=claude-sonnet-4-20250514 \
  --tokens-input=6000 --tokens-output=1500 --tokens-cache-read=4500 \
  --cost=0.15 --cost-source=reported \
  --cache-hit-rate=0.75 --payload-bytes=5200

# M002 dispatch (success)
bash scripts/lifecycle/record-result.sh "$TMPLOG" \
  --milestone=M002 --phase=P01 --task=T02 --outcome=success \
  --tier=C --dispatch_method=subagent --verification_result=pass --duration_s=110

# Telemetry for M002/P01/T02
bash scripts/telemetry/record-telemetry.sh "$TMPLOG" \
  --unit-id=M002/P01/T02 \
  --model=claude-sonnet-4-20250514 \
  --tokens-input=4000 --tokens-output=900 --tokens-cache-read=3000 \
  --cost=0.08 --cost-source=estimated \
  --cache-hit-rate=0.75 --payload-bytes=3200
```

### Step 2: Verify record-telemetry.sh output format

After creating the test log, inspect the telemetry entries to confirm well-formed JSON:

- Each telemetry line must contain `"type":"telemetry"`
- Each must contain a `"unitId"` field
- Numeric fields (tokens_input, cost_estimated, etc.) must be unquoted numbers
- String fields (model_used, cost_source) must be quoted strings

### Step 3: Run aggregate-metrics.sh in text mode

```bash
bash scripts/telemetry/aggregate-metrics.sh "$TMPLOG"
```

Expected output should include:
- `Dispatches: 5` (3 M001 + 2 M002)
- `Success rate: 80.0% (4/5)`
- `Total cost: $1.290` (0.12 + 0.09 + 0.85 + 0.15 + 0.08 = 1.29)
- `Avg cost/task: $0.258`
- `Avg duration: 134s` ((120+90+200+150+110)/5 = 134)
- `Cache hit rate: 67.8%` (mean of 0.60, 0.62, 0.67, 0.75, 0.75 = 0.678)
- By Model section showing claude-sonnet and claude-opus
- By Milestone section showing M001 (3 tasks) and M002 (2 tasks)
- By Cost Source section showing estimated (4 entries) and reported (1 entry)

### Step 4: Run aggregate-metrics.sh in JSON mode

```bash
bash scripts/telemetry/aggregate-metrics.sh "$TMPLOG" --format=json
```

Verify the JSON output is well-formed and contains:
- `"total_dispatches":5`
- `"success_count":4`
- `"by_model"` object with entries for both models
- `"by_milestone"` object with M001 and M002
- `"by_cost_source"` object with estimated and reported breakdowns

### Step 5: Test milestone filtering

```bash
bash scripts/telemetry/aggregate-metrics.sh "$TMPLOG" --milestone=M001
```

Expected: `Dispatches: 3`, `Success rate: 66.7%`, no By Milestone section (filtered to single milestone).

```bash
bash scripts/telemetry/aggregate-metrics.sh "$TMPLOG" --milestone=M002
```

Expected: `Dispatches: 2`, `Success rate: 100.0%`.

### Step 6: Test edge cases

Test with an empty log file:
```bash
empty_log=$(mktemp)
bash scripts/telemetry/aggregate-metrics.sh "$empty_log"
rm "$empty_log"
```

Expected: `Dispatches: 0`, `Success rate: N/A`, `Total cost: $0.000`.

Test with nonexistent file:
```bash
bash scripts/telemetry/aggregate-metrics.sh /tmp/nonexistent-log-file.jsonl 2>/dev/null
echo "Exit code: $?"
```

Expected: exit code 2 (file not found).

### Step 7: Run all 9 phase verification scripts

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

All 9 must print `PASS: <description>`.

### Step 8: Clean up temporary files

Remove any temporary test log files created during testing. No permanent test fixtures are needed for P05 since the telemetry scripts are well-established and the verification scripts perform static checks.

## Must-Haves

- All 9 phase verification scripts pass
- aggregate-metrics.sh text output shows correct metrics for multi-milestone data
- aggregate-metrics.sh JSON output is well-formed with by_model, by_milestone, by_cost_source breakdowns
- Milestone filtering produces correctly scoped results
- Edge cases (empty log, missing file) produce correct output and exit codes

## Verification

```
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

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p05-*.sh` (from T01) — 9 verification scripts. Each takes no arguments, prints `PASS: <message>` or `FAIL: <message>`, exits 0/1.
- `scripts/telemetry/record-telemetry.sh` (validated in T02) — Interface: `record-telemetry.sh <execution-log> --unit-id=M###/P##/T## [--model=<id>] [--tokens-input=N] [--tokens-output=N] [--tokens-cache-read=N] [--cost=<amount>] [--cost-source=<estimated|reported|unknown>] [--cache-hit-rate=<0.0-1.0>] [--payload-bytes=N]`. Outputs `TELEMETRY:RECORDED <log-file>`.
- `scripts/telemetry/aggregate-metrics.sh` (validated in T02) — Interface: `aggregate-metrics.sh <execution-log> [--milestone=M###] [--format=text|json]`. Text mode outputs formatted table with Dispatches, Success rate, Total cost, Avg cost/task, Avg duration, Cache hit rate, plus By Model/Milestone/Cost Source sections. JSON mode outputs `{total_dispatches, success_count, success_rate, total_cost, avg_cost_per_task, avg_duration_s, cache_hit_rate, by_model:{model:{count,cost}}, by_milestone:{ms:{dispatches,success_rate,cost}}, by_cost_source:{source:{count,cost}}}`.
- `scripts/lifecycle/auto-loop.sh` (modified in T03) — Step G now accepts `--model`, `--tokens-input`, `--tokens-output`, `--tokens-cache-read`, `--cost`, `--cache-hit-rate` and passes them through to record-result.sh.
- `scripts/lifecycle/record-result.sh` — Interface: `record-result.sh <execution-log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry|blocked|timeout|stuck|unchanged> [--model=<id>] [--tokens-input=N] [--tokens-output=N] [--tokens-cache-read=N] [--cost=<amount>] [--cache-hit-rate=<rate>] [--duration_s=N] [--verification_result=<pass|fail|pass_with_concerns|skipped>]`. Outputs `RECORD:APPENDED <log-file>`.

### From Disk (Pre-existing)

No additional pre-existing files needed beyond those listed under From Previous Tasks.

## Constraints

- Do NOT modify any scripts in this task — this is a verification-only task
- Temporary test files must be cleaned up; do not leave test fixtures on disk
- All verification must be reproducible (running twice produces the same pass/fail results)

## Expected Output

- All 9 verification scripts pass
- Confirmation that telemetry pipeline works end-to-end: record -> aggregate -> display
- No permanent files created or modified (verification-only task)

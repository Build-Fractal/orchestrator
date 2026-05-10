---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M002"
name: "Verification Scripts for All Must-Haves"
depends_on: []
---

## Prerequisites

P05 has no upstream phase dependencies. The following scripts already exist on disk from prior work:

- `scripts/telemetry/record-telemetry.sh` (98 lines) — appends telemetry JSON lines to execution-log.jsonl
- `scripts/telemetry/aggregate-metrics.sh` (419 lines) — computes aggregate metrics from execution log
- `scripts/lifecycle/record-result.sh` (185 lines) — appends dispatch result entries to execution-log.jsonl
- `scripts/lifecycle/auto-loop.sh` — autonomous loop driver with Step G that calls record-result.sh
- `commands/status.md` — status command agent instructions
- `extension.yml` — extension manifest listing commands, scripts, hooks

## Description

Create 9 verification scripts under `scripts/verify/m002-p05-*.sh` that mechanically check all P05 must-haves. Each script is a single-file invocation (per AD-19) that prints `PASS: <message>` on success or `FAIL: <message>` on failure, exiting 0 on pass and 1 on fail.

## Steps

### Step 1: Create `scripts/verify/m002-p05-record-telemetry-fields.sh`

Verifies that `record-telemetry.sh` appends JSON with `"type":"telemetry"` and supports all required optional fields.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '"type":"telemetry"' "$f" || grep -q '"telemetry"' "$f" || { echo "FAIL: does not produce type:telemetry entries"; exit 1; }
grep -q 'unitId\|unit.id\|unit_id\|UNIT_ID' "$f" || { echo "FAIL: missing unitId field"; exit 1; }
grep -q 'model_used\|MODEL_USED' "$f" || { echo "FAIL: missing model_used field handling"; exit 1; }
grep -q 'tokens_input\|TOKENS_INPUT' "$f" || { echo "FAIL: missing tokens_input field handling"; exit 1; }
grep -q 'tokens_output\|TOKENS_OUTPUT' "$f" || { echo "FAIL: missing tokens_output field handling"; exit 1; }
grep -q 'tokens_cache_read\|TOKENS_CACHE_READ' "$f" || { echo "FAIL: missing tokens_cache_read field handling"; exit 1; }
grep -q 'cost_estimated\|COST_ESTIMATED' "$f" || { echo "FAIL: missing cost_estimated field handling"; exit 1; }
grep -q 'cache_hit_rate\|CACHE_HIT_RATE' "$f" || { echo "FAIL: missing cache_hit_rate field handling"; exit 1; }
grep -q 'payload_bytes\|PAYLOAD_BYTES' "$f" || { echo "FAIL: missing payload_bytes field handling"; exit 1; }
echo "PASS: record-telemetry.sh handles all required telemetry fields"
```

### Step 2: Create `scripts/verify/m002-p05-cost-source-enum.sh`

Verifies that `record-telemetry.sh` validates the cost_source enum.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source\|COST_SOURCE' "$f" || { echo "FAIL: no cost_source field handling"; exit 1; }
grep -q 'estimated' "$f" || { echo "FAIL: cost_source enum missing estimated"; exit 1; }
grep -q 'reported' "$f" || { echo "FAIL: cost_source enum missing reported"; exit 1; }
grep -q 'unknown' "$f" || { echo "FAIL: cost_source enum missing unknown"; exit 1; }
grep -qE 'invalid.*cost_source|cost_source.*invalid' "$f" || { echo "FAIL: no validation error for invalid cost_source"; exit 1; }
echo "PASS: record-telemetry.sh validates cost_source enum (estimated|reported|unknown)"
```

### Step 3: Create `scripts/verify/m002-p05-aggregate-metrics-fields.sh`

Verifies that `aggregate-metrics.sh` computes all required aggregate fields.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'total_dispatches\|total.dispatches\|Dispatches' "$f" || { echo "FAIL: missing total dispatches metric"; exit 1; }
grep -q 'success_count\|success.count\|Success rate' "$f" || { echo "FAIL: missing success rate metric"; exit 1; }
grep -q 'total_cost\|Total cost' "$f" || { echo "FAIL: missing total cost metric"; exit 1; }
grep -q 'avg_cost\|Avg cost' "$f" || { echo "FAIL: missing avg cost per task metric"; exit 1; }
grep -q 'avg_duration\|Avg duration' "$f" || { echo "FAIL: missing avg duration metric"; exit 1; }
grep -q 'cache_hit\|Cache hit' "$f" || { echo "FAIL: missing cache hit rate metric"; exit 1; }
grep -q 'milestone\|Milestone' "$f" || { echo "FAIL: missing per-milestone comparison"; exit 1; }
echo "PASS: aggregate-metrics.sh computes all required aggregate fields"
```

### Step 4: Create `scripts/verify/m002-p05-aggregate-json-format.sh`

Verifies that `aggregate-metrics.sh` supports --format=json with structured output.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-format' "$f" || { echo "FAIL: missing --format flag"; exit 1; }
grep -q 'json' "$f" || { echo "FAIL: missing json format support"; exit 1; }
grep -q 'by_model\|by.model' "$f" || { echo "FAIL: missing by_model breakdown in JSON output"; exit 1; }
grep -q 'by_milestone\|by.milestone' "$f" || { echo "FAIL: missing by_milestone breakdown in JSON output"; exit 1; }
grep -q 'by_cost_source\|by.cost.source' "$f" || { echo "FAIL: missing by_cost_source breakdown in JSON output"; exit 1; }
echo "PASS: aggregate-metrics.sh supports --format=json with structured breakdowns"
```

### Step 5: Create `scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh`

Verifies that `auto-loop.sh` Step G can pass telemetry fields to record-result.sh.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/lifecycle/auto-loop.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'record-result\|RECORD_RESULT' "$f" || { echo "FAIL: auto-loop.sh does not reference record-result.sh"; exit 1; }
grep -qE '\-\-model=|\-\-model ' "$f" || { echo "FAIL: auto-loop.sh Step G does not pass --model to record-result.sh"; exit 1; }
grep -qE '\-\-tokens-input=|\-\-tokens.input' "$f" || { echo "FAIL: auto-loop.sh Step G does not pass --tokens-input to record-result.sh"; exit 1; }
grep -qE '\-\-cost=|\-\-cost ' "$f" || { echo "FAIL: auto-loop.sh Step G does not pass --cost to record-result.sh"; exit 1; }
echo "PASS: auto-loop.sh Step G passes telemetry fields to record-result.sh"
```

### Step 6: Create `scripts/verify/m002-p05-status-references-aggregate.sh`

Verifies that `commands/status.md` references aggregate-metrics.sh for telemetry display.

```bash
#!/usr/bin/env bash
set -eu
f="commands/status.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'aggregate-metrics' "$f" || { echo "FAIL: status.md does not reference aggregate-metrics.sh"; exit 1; }
grep -qi 'telemetry\|cost\|token' "$f" || { echo "FAIL: status.md does not mention telemetry metrics"; exit 1; }
echo "PASS: commands/status.md references aggregate-metrics.sh for telemetry display"
```

### Step 7: Create `scripts/verify/m002-p05-extension-registration.sh`

Verifies that `extension.yml` registers both telemetry scripts.

```bash
#!/usr/bin/env bash
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scripts/telemetry/record-telemetry.sh' "$f" || { echo "FAIL: record-telemetry.sh not registered in extension.yml"; exit 1; }
grep -q 'scripts/telemetry/aggregate-metrics.sh' "$f" || { echo "FAIL: aggregate-metrics.sh not registered in extension.yml"; exit 1; }
echo "PASS: extension.yml registers both telemetry scripts"
```

### Step 8: Create `scripts/verify/m002-p05-bash32-compat.sh`

Verifies that telemetry scripts do not use Bash 3.2-incompatible features.

```bash
#!/usr/bin/env bash
set -eu
files="scripts/telemetry/record-telemetry.sh scripts/telemetry/aggregate-metrics.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
grep -rlE 'declare -A|readarray|mapfile' $files && { echo "FAIL: Bash 3.2 incompatible constructs found"; exit 1; }
echo "PASS: all telemetry scripts are Bash 3.2 compatible"
```

### Step 9: Create `scripts/verify/m002-p05-idempotent.sh`

Verifies that aggregate-metrics.sh is read-only (no writes to log) and record-telemetry.sh appends without modifying existing entries.

```bash
#!/usr/bin/env bash
set -eu
# aggregate-metrics.sh should be read-only — it reads the log but never writes to it
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qE '>>\s*"\$EXECUTION_LOG"|>>\s*\$EXECUTION_LOG' "$f" && { echo "FAIL: aggregate-metrics.sh modifies the execution log"; exit 1; }
# record-telemetry.sh appends only
f2="scripts/telemetry/record-telemetry.sh"
test -f "$f2" || { echo "FAIL: $f2 missing"; exit 1; }
grep -q '>>' "$f2" || { echo "FAIL: record-telemetry.sh does not use append mode"; exit 1; }
grep -qE '>\s*"\$EXECUTION_LOG"[^>]|>\s*\$EXECUTION_LOG[^>]' "$f2" && { echo "FAIL: record-telemetry.sh uses overwrite instead of append"; exit 1; }
echo "PASS: telemetry operations are idempotent (aggregate is read-only, record appends)"
```

### Step 10: Make all scripts executable

```bash
chmod +x scripts/verify/m002-p05-*.sh
```

## Must-Haves

This task delivers all 9 verification scripts required by the phase plan. Every other task in this phase uses these scripts for mechanical verification.

## Verification

Run each verification script. Since T02 and T03 have not yet executed, some checks will fail. The following should pass immediately because the scripts already exist from prior work:

```
bash scripts/verify/m002-p05-record-telemetry-fields.sh
bash scripts/verify/m002-p05-cost-source-enum.sh
bash scripts/verify/m002-p05-aggregate-metrics-fields.sh
bash scripts/verify/m002-p05-aggregate-json-format.sh
bash scripts/verify/m002-p05-bash32-compat.sh
bash scripts/verify/m002-p05-idempotent.sh
```

Expected output for each: `PASS: <description>`

The following will fail until T02 and T03 complete:
```
bash scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh
bash scripts/verify/m002-p05-status-references-aggregate.sh
bash scripts/verify/m002-p05-extension-registration.sh
```

## Inputs

### From Previous Tasks

None — this is the first task in the phase.

### From Disk (Pre-existing)

- `scripts/telemetry/record-telemetry.sh` — telemetry recording script (98 lines). Accepts `--unit-id`, `--model`, `--tokens-input`, `--tokens-output`, `--tokens-cache-read`, `--cost`, `--cost-source`, `--cache-hit-rate`, `--payload-bytes`. Appends JSON with `"type":"telemetry"`. Validates cost_source enum. Outputs `TELEMETRY:RECORDED <log-file>`.
- `scripts/telemetry/aggregate-metrics.sh` — aggregate metrics script (419 lines). Accepts `<execution-log> [--milestone=M###] [--format=text|json]`. Reads both dispatch and telemetry entries. Outputs total dispatches, success rate, total cost, avg cost/task, avg duration, cache hit rate. JSON mode includes by_model, by_milestone, by_cost_source breakdowns.
- `scripts/lifecycle/auto-loop.sh` — autonomous loop driver. Step G calls record-result.sh with `--milestone`, `--phase`, `--task`, `--outcome`, `--tier`, `--dispatch_method`, and optionally `--verification_result`, `--duration_s`.
- `commands/status.md` — status command agent instructions (140 lines). Currently references execution-log.jsonl for dispatch count and duration but does NOT reference aggregate-metrics.sh.
- `extension.yml` — extension manifest. Currently does NOT list telemetry scripts under `provides.scripts`.

## Constraints

- All verification scripts must use single-script-file invocation shape per AD-19
- No compound bash, no subshells, no pipes inside $(), no inline for/if/while in Check: commands
- Each script must be independently executable: `bash scripts/verify/m002-p05-<name>.sh`
- Scripts must print PASS/FAIL and exit 0/1 respectively

## Expected Output

9 new files under `scripts/verify/`:
- `m002-p05-record-telemetry-fields.sh`
- `m002-p05-cost-source-enum.sh`
- `m002-p05-aggregate-metrics-fields.sh`
- `m002-p05-aggregate-json-format.sh`
- `m002-p05-autoloop-telemetry-passthrough.sh`
- `m002-p05-status-references-aggregate.sh`
- `m002-p05-extension-registration.sh`
- `m002-p05-bash32-compat.sh`
- `m002-p05-idempotent.sh`

All scripts are executable and follow the single-script-file shape convention.

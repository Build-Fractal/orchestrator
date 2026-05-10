---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M002"
name: "Validate, Harden, and Register Telemetry Scripts"
depends_on: ["T01"]
---

## Prerequisites

T01 is complete. All 9 verification scripts exist under `scripts/verify/m002-p05-*.sh`. The telemetry scripts exist on disk from prior work and need validation against the documented schema, hardening for edge cases, and registration in the extension manifest.

## Description

Review `record-telemetry.sh` and `aggregate-metrics.sh` against the documented JSONL schema in `references/file-formats.md`. Fix any gaps in field handling, error messaging, edge case handling, or Bash 3.2 compatibility. Register both scripts in `extension.yml` under `provides.scripts`. Update `references/file-formats.md` if the telemetry entry format documentation needs any corrections.

## Steps

### Step 1: Audit record-telemetry.sh against file-formats.md

Read `scripts/telemetry/record-telemetry.sh` and compare against the Telemetry Entry Format section in `references/file-formats.md` (lines 540-598).

Verify the following are correctly implemented:
- `timestamp` auto-generated with `date -u +"%Y-%m-%dT%H:%M:%SZ"`
- `type` always set to `"telemetry"`
- `unitId` is the required field (parsed from `--unit-id=M###/P##/T##`)
- All optional fields: `model_used` (string), `tokens_input` (number), `tokens_output` (number), `tokens_cache_read` (number), `cost_estimated` (number, null/absent = unknown, 0 = free), `cost_source` (enum: estimated|reported|unknown), `cache_hit_rate` (number, 0.0-1.0), `payload_bytes` (number)
- cost_source enum validation: rejects values not in {estimated, reported, unknown}
- Error on missing `--unit-id`

Fix any mismatches. The script should match the documented schema exactly.

### Step 2: Audit aggregate-metrics.sh

Read `scripts/telemetry/aggregate-metrics.sh` and verify:

**Input handling:**
- First positional arg is the execution log path (required)
- `--milestone=M###` filters to a specific milestone
- `--format=text|json` controls output format (default: text)
- Exit 1 on missing log path, exit 2 on file not found

**Metric computation from dispatch entries (lines without `"type":"telemetry"`):**
- `total_dispatches`: count of dispatch entries
- `success_count`: count where `outcome` = `"success"`
- `total_duration`: sum of `duration_s` fields
- `inline_cost_sum`: sum of `cost_estimated` from dispatch entries

**Metric computation from telemetry entries (lines with `"type":"telemetry"`):**
- `telemetry_cost_sum`: sum of `cost_estimated` from telemetry entries
- `cache_hit_sum` / `cache_hit_count`: for computing average cache hit rate
- Per-model tracking: count and cost per model_used value
- Cost source breakdown: per estimated/reported/unknown counts and costs

**Derived metrics:**
- `total_cost` = telemetry_cost_sum + inline_cost_sum
- `avg_cost` = total_cost / total_dispatches
- `success_pct` = (success_count / total_dispatches) * 100
- `avg_duration` = total_duration / duration_count
- `avg_cache_hit` = (cache_hit_sum / cache_hit_count) * 100

**JSON output (--format=json):**
- Top-level: total_dispatches, success_count, success_rate, total_cost, avg_cost_per_task, avg_duration_s, cache_hit_rate
- by_model: `{model_name: {count, cost}}`
- by_milestone: `{milestone_id: {dispatches, success_rate, cost}}`
- by_cost_source: `{estimated: {count, cost}, reported: {count, cost}, unknown: {count, cost}}`

**Text output (default):**
- Formatted human-readable table with headers "=== Execution Telemetry ==="
- "--- By Model ---" section
- "--- By Milestone ---" section
- "--- By Cost Source ---" section

Fix any computation bugs or edge cases (e.g., division by zero when no dispatches exist).

### Step 3: Verify Bash 3.2 compatibility

Check both telemetry scripts for Bash 3.2-incompatible constructs:
- No `declare -A` (associative arrays)
- No `readarray` or `mapfile`
- No `[[ ]]` where `[ ]` suffices for portability
- No `${var,,}` or `${var^^}` case manipulation
- No `|&` pipe-with-stderr
- No `&>` redirect-both

Both scripts currently use temp directories for model and milestone tracking instead of associative arrays, which is the correct Bash 3.2 pattern. Verify this pattern is used consistently.

### Step 4: Register telemetry scripts in extension.yml

Add both telemetry scripts to the `provides.scripts` section in `extension.yml`. Insert them after the existing `scripts/lifecycle/record-result.sh` entry (approximately line 125) to keep lifecycle and telemetry scripts near each other.

Add these two entries:

```yaml
    - file: scripts/telemetry/record-telemetry.sh
      executable: true
    - file: scripts/telemetry/aggregate-metrics.sh
      executable: true
```

### Step 5: Verify registration

Run the extension registration verification script:

```bash
bash scripts/verify/m002-p05-extension-registration.sh
```

Expected output: `PASS: extension.yml registers both telemetry scripts`

### Step 6: Run all passing verification scripts

```bash
bash scripts/verify/m002-p05-record-telemetry-fields.sh
bash scripts/verify/m002-p05-cost-source-enum.sh
bash scripts/verify/m002-p05-aggregate-metrics-fields.sh
bash scripts/verify/m002-p05-aggregate-json-format.sh
bash scripts/verify/m002-p05-extension-registration.sh
bash scripts/verify/m002-p05-bash32-compat.sh
bash scripts/verify/m002-p05-idempotent.sh
```

All should print `PASS: <description>`.

## Must-Haves

- record-telemetry.sh appends a JSON line with `"type":"telemetry"` containing unitId, and optional fields model_used, tokens_input, tokens_output, tokens_cache_read, cost_estimated, cost_source, cache_hit_rate, payload_bytes
- record-telemetry.sh validates cost_source enum (estimated|reported|unknown) and rejects invalid values
- aggregate-metrics.sh reads both dispatch entries and telemetry entries from execution-log.jsonl, computing total cost, avg cost/task, avg duration, cache hit rate, success rate, and per-milestone comparison
- aggregate-metrics.sh supports --format=json producing machine-readable output with by_model, by_milestone, and by_cost_source breakdowns
- extension.yml registers both scripts/telemetry/record-telemetry.sh and scripts/telemetry/aggregate-metrics.sh as executable scripts
- All telemetry scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)

## Verification

```
bash scripts/verify/m002-p05-record-telemetry-fields.sh
bash scripts/verify/m002-p05-cost-source-enum.sh
bash scripts/verify/m002-p05-aggregate-metrics-fields.sh
bash scripts/verify/m002-p05-aggregate-json-format.sh
bash scripts/verify/m002-p05-extension-registration.sh
bash scripts/verify/m002-p05-bash32-compat.sh
bash scripts/verify/m002-p05-idempotent.sh
```

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p05-*.sh` (from T01) — 9 verification scripts. Each takes no arguments, prints `PASS: <message>` or `FAIL: <message>`, exits 0/1. Used to verify must-haves after modifications.

### From Disk (Pre-existing)

- `scripts/telemetry/record-telemetry.sh` — telemetry recording script (98 lines). Interface: `record-telemetry.sh <execution-log> --unit-id=M###/P##/T## [--model=<id>] [--tokens-input=N] [--tokens-output=N] [--tokens-cache-read=N] [--cost=<amount>] [--cost-source=<estimated|reported|unknown>] [--cache-hit-rate=<0.0-1.0>] [--payload-bytes=N]`. Outputs `TELEMETRY:RECORDED <log-file>`. Exits 0 on success, 1 on error.
- `scripts/telemetry/aggregate-metrics.sh` — aggregate metrics script (419 lines). Interface: `aggregate-metrics.sh <execution-log> [--milestone=M###] [--format=text|json]`. Text mode outputs human-readable metrics table. JSON mode outputs a JSON object with top-level metrics and by_model/by_milestone/by_cost_source breakdowns. Exits 0 on success, 1 on invalid args, 2 on file not found.
- `references/file-formats.md` — documents the Telemetry Entry Format (lines 540-598). Fields: timestamp (auto), type ("telemetry"), unitId (required), model_used, tokens_input, tokens_output, tokens_cache_read, cost_estimated, cost_source (enum), cache_hit_rate, payload_bytes. Includes cost source enum definition (AD-2) and null-vs-zero distinction.
- `extension.yml` — extension manifest (271 lines). Currently lists 12 commands and ~40 scripts under `provides.scripts` but does NOT include `scripts/telemetry/record-telemetry.sh` or `scripts/telemetry/aggregate-metrics.sh`.

## Constraints

- Do NOT change the CLI interface of either telemetry script (argument names, output format) — downstream scripts and commands depend on the current interface
- Bash 3.2 compatibility: no associative arrays, no readarray, no mapfile
- jq must remain optional — all JSON parsing uses sed/awk/grep fallbacks (NFR-106)
- Idempotent operation: record-telemetry.sh appends; aggregate-metrics.sh is read-only

## Expected Output

- `scripts/telemetry/record-telemetry.sh` — validated and hardened (may have minor fixes)
- `scripts/telemetry/aggregate-metrics.sh` — validated and hardened (may have minor fixes)
- `extension.yml` — updated with two new script entries under `provides.scripts`
- All 7 verification scripts listed above print PASS

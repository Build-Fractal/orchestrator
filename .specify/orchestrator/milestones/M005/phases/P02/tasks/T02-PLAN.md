---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M005"
name: "Update aggregate-metrics.sh to group by cost_source"
depends_on: ["T01"]
---

## Description

Update `scripts/telemetry/aggregate-metrics.sh` to read the `cost_source`
field from telemetry entries, accumulate per-source counts and cost totals,
and include a `by_cost_source` breakdown in both text and JSON output.

The key semantic distinction (AD-2):
- An entry with no `cost_estimated` field and no `cost_source` field is
  counted as `unknown` (no cost data available).
- An entry with `cost_estimated` present but no `cost_source` field is
  counted as `estimated` (legacy entries before cost_source was added).
- An entry with `cost_estimated: 0` and `cost_source: reported` is
  counted as a zero-cost reported entry -- NOT conflated with unknown.
- An entry with `cost_source: unknown` is explicitly marked unknown
  regardless of whether `cost_estimated` is present.

The output adds a new section ("By Cost Source" in text, `by_cost_source`
in JSON) showing for each source: entry count and total cost.

## Steps

### Step 1 -- Add cost_source tracking variables

In `scripts/telemetry/aggregate-metrics.sh`, after the existing accumulator
variables (around line 66, near `cache_hit_count=0`), add:

```bash
# Cost source tracking (AD-2: estimated|reported|unknown)
cs_estimated_count=0
cs_estimated_cost=0
cs_reported_count=0
cs_reported_cost=0
cs_unknown_count=0
cs_unknown_cost=0
```

### Step 2 -- Extract and classify cost_source in the telemetry branch

In the telemetry entry processing block (inside the `if [ "$entry_type" =
"telemetry" ]` branch, around line 92), after the existing `cost_val`
extraction, add cost_source classification:

```bash
    # Cost source classification (AD-2)
    source_val="$(json_str_val "$line" "cost_source")"
    if [ -z "$source_val" ]; then
      # Legacy entry: infer source from presence of cost field
      if [ -n "$cost_val" ]; then
        source_val="estimated"
      else
        source_val="unknown"
      fi
    fi

    # Accumulate by source
    case "$source_val" in
      estimated)
        cs_estimated_count=$((cs_estimated_count + 1))
        if [ -n "$cost_val" ]; then
          cs_estimated_cost=$(awk "BEGIN { printf \"%.6f\", $cs_estimated_cost + $cost_val }")
        fi
        ;;
      reported)
        cs_reported_count=$((cs_reported_count + 1))
        if [ -n "$cost_val" ]; then
          cs_reported_cost=$(awk "BEGIN { printf \"%.6f\", $cs_reported_cost + $cost_val }")
        fi
        ;;
      unknown|*)
        cs_unknown_count=$((cs_unknown_count + 1))
        if [ -n "$cost_val" ]; then
          cs_unknown_cost=$(awk "BEGIN { printf \"%.6f\", $cs_unknown_cost + $cost_val }")
        fi
        ;;
    esac
```

### Step 3 -- Add by_cost_source to JSON output

In the JSON output block (around line 271, after the `by_milestone` section
and before the closing `}`), add:

```bash
  # Cost source breakdown
  json="${json},\"by_cost_source\":{"
  json="${json}\"estimated\":{\"count\":${cs_estimated_count},\"cost\":$(awk "BEGIN { printf \"%.3f\", $cs_estimated_cost }")}"
  json="${json},\"reported\":{\"count\":${cs_reported_count},\"cost\":$(awk "BEGIN { printf \"%.3f\", $cs_reported_cost }")}"
  json="${json},\"unknown\":{\"count\":${cs_unknown_count},\"cost\":$(awk "BEGIN { printf \"%.3f\", $cs_unknown_cost }")}"
  json="${json}}"
```

### Step 4 -- Add By Cost Source section to text output

In the text output block (after the "By Milestone" section, around line
354), add:

```bash
  cs_total=$((cs_estimated_count + cs_reported_count + cs_unknown_count))
  if [ "$cs_total" -gt 0 ]; then
    echo ""
    echo "--- By Cost Source ---"
    if [ "$cs_estimated_count" -gt 0 ]; then
      printf 'Estimated:   %d entries, $%s\n' "$cs_estimated_count" "$(awk "BEGIN { printf \"%.3f\", $cs_estimated_cost }")"
    fi
    if [ "$cs_reported_count" -gt 0 ]; then
      printf 'Reported:    %d entries, $%s\n' "$cs_reported_count" "$(awk "BEGIN { printf \"%.3f\", $cs_reported_cost }")"
    fi
    if [ "$cs_unknown_count" -gt 0 ]; then
      printf 'Unknown:     %d entries, $%s\n' "$cs_unknown_count" "$(awk "BEGIN { printf \"%.3f\", $cs_unknown_cost }")"
    fi
  fi
```

### Step 5 -- Smoke test

Create a test log with mixed cost_source values:

```bash
tmplog="$(mktemp)"
# Entry with estimated cost
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T01 --cost=0.12 --cost-source=estimated
# Entry with reported cost (zero = actually free)
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T02 --cost=0 --cost-source=reported
# Entry with unknown cost (no cost data)
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T03 --cost-source=unknown
# Legacy entry (no cost_source field, has cost)
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T04 --cost=0.50

# Text output
bash scripts/telemetry/aggregate-metrics.sh "$tmplog"
# Expected: "By Cost Source" section with estimated=2, reported=1, unknown=1

# JSON output
bash scripts/telemetry/aggregate-metrics.sh "$tmplog" --format=json
# Expected: by_cost_source with three keys

rm -f "$tmplog"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "aggregate-metrics.sh groups telemetry entries by cost_source",
  "aggregate-metrics.sh distinguishes null/missing cost from zero cost".
- **Artifacts**: `scripts/telemetry/aggregate-metrics.sh` (modify).

## Verification

Run the verification scripts:

```bash
bash scripts/verify/p02-aggregate-groups.sh
bash scripts/verify/p02-null-vs-zero.sh
```

Both should print PASS.

### Files Touched By This Task

- `scripts/telemetry/aggregate-metrics.sh` (modify)

## Inputs

### From Previous Tasks

- T01: `scripts/telemetry/record-telemetry.sh` must accept `--cost-source`
  so that verification smoke tests can produce JSONL entries with the
  `cost_source` field.

### From Disk (Pre-existing)

- `scripts/telemetry/aggregate-metrics.sh` -- the existing aggregation
  script. Current structure (356 lines):
  - Lines 1-16: header comment with usage documentation
  - Lines 18-29: helper functions `json_str_val` and `json_num_val`
  - Lines 31-55: argument parsing (log path, --milestone, --format)
  - Lines 57-205: main while-read loop processing each line:
    - Lines 72-91: milestone extraction and filter
    - Lines 92-142: telemetry entry processing (cost, cache, model tracking)
    - Lines 143-204: dispatch entry processing (count, success, duration, cost)
  - Lines 207-268: derived metric computation
  - Lines 270-320: JSON output format
  - Lines 322-355: text output format

  Key pattern for adding a new grouping:
  1. Add counter/accumulator variables before the while loop
  2. Extract the field value inside the appropriate branch (telemetry or dispatch)
  3. Accumulate into the counters using case/if
  4. Add output section in both JSON and text blocks

- `scripts/telemetry/record-telemetry.sh` (after T01 modifications) --
  needed for smoke testing. The script will write `cost_source` as a JSON
  string field when `--cost-source` is provided.

## Expected Output

After completing this task:

1. `bash scripts/telemetry/aggregate-metrics.sh <log> --format=json`
   includes a `by_cost_source` object with `estimated`, `reported`, and
   `unknown` sub-objects, each with `count` and `cost` fields.
2. `bash scripts/telemetry/aggregate-metrics.sh <log>` includes a
   "By Cost Source" text section.
3. A log with an entry that has `cost_estimated: 0` and
   `cost_source: reported` shows `reported: 1 entries` (not unknown).
4. A log with an entry that has no `cost_estimated` and no `cost_source`
   shows `unknown: 1 entries`.
5. A log with a legacy entry (cost present, no cost_source) shows
   `estimated: 1 entries` (inferred).
6. `bash scripts/verify/p02-aggregate-groups.sh` prints PASS.
7. `bash scripts/verify/p02-null-vs-zero.sh` prints PASS.
8. `git status` shows 1 modified file. Nothing else touched.

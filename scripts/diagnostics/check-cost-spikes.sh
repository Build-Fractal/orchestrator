#!/usr/bin/env bash
# scripts/diagnostics/check-cost-spikes.sh — Detect cost spike anomalies
# Flags tasks that cost significantly more than expected (>5x average).
#
# Bash 3.2 compatible. No jq dependency. Read-only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
root="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Find execution log
exec_log=""
for candidate in "$root/.specify/orchestrator/execution-log.jsonl" "$root/execution-log.jsonl"; do
    if [ -f "$candidate" ]; then
        exec_log="$candidate"
        break
    fi
done

if [ -z "$exec_log" ] || [ ! -f "$exec_log" ]; then
    echo "PASS: No execution log found (no telemetry data to check)"
    exit 0
fi

# Check if there are telemetry entries with cost data
cost_entries="$( { grep '"cost_estimated"' "$exec_log" 2>/dev/null || true; } | wc -l )"
cost_entries="$(echo "$cost_entries" | tr -d ' ')"
if [ "$cost_entries" -lt 2 ]; then
    echo "PASS: Not enough cost data for spike detection (need at least 2 entries, have $cost_entries)"
    exit 0
fi

# Compute average cost from all entries that have cost data
avg_cost="$( { grep '"cost_estimated"' "$exec_log" || true; } | sed 's/.*"cost_estimated"://' | sed 's/[,}].*//' | awk '{sum+=$1; count++} END {if(count>0) printf "%.4f", sum/count; else print "0"}')"

if [ "$avg_cost" = "0" ] || [ -z "$avg_cost" ]; then
    echo "PASS: No meaningful cost data"
    exit 0
fi

# Compute spike threshold (5x average)
spike_threshold="$(echo "$avg_cost" | awk '{printf "%.4f", $1 * 5}')"

# Extract cost lines to a temp file so we can read without a pipe subshell
tmp_lines="$(mktemp)"
{ grep '"cost_estimated"' "$exec_log" || true; } > "$tmp_lines"

spike_count=0

while IFS= read -r line; do
    cost="$(echo "$line" | sed 's/.*"cost_estimated"://' | sed 's/[,}].*//')"
    unit_id="$(echo "$line" | sed 's/.*"unitId":"//' | sed 's/".*//')"

    cost_int="$(echo "$cost" | awk '{printf "%d", $1 * 10000}')"
    threshold_int="$(echo "$spike_threshold" | awk '{printf "%d", $1 * 10000}')"

    if [ "$cost_int" -gt "$threshold_int" ]; then
        echo "WARNING: $unit_id cost \$$cost is >5x average (\$$avg_cost) — review for efficiency"
        spike_count=$((spike_count + 1))
    fi
done < "$tmp_lines"

rm -f "$tmp_lines"

if [ "$spike_count" -eq 0 ]; then
    echo "PASS: No cost spikes detected (threshold: 5x avg of \$$avg_cost)"
fi

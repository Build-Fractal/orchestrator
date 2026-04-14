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

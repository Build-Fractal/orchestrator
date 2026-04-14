#!/usr/bin/env bash
set -eu
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: aggregate-metrics.sh missing cost_source grouping"; exit 1; }
echo "PASS: aggregate-metrics.sh groups by cost_source"

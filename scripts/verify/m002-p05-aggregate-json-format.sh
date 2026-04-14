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

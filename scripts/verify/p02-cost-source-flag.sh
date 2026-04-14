#!/usr/bin/env bash
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost.source' "$f" || grep -q 'cost_source' "$f" || { echo "FAIL: no cost-source handling"; exit 1; }
grep -q 'COST_SOURCE' "$f" || { echo "FAIL: COST_SOURCE variable missing"; exit 1; }
echo "PASS: record-telemetry.sh accepts --cost-source flag"

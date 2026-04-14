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

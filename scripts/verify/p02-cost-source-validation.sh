#!/usr/bin/env bash
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'estimated|reported|unknown' "$f" || { echo "FAIL: cost_source enum validation missing"; exit 1; }
echo "PASS: record-telemetry.sh validates cost_source enum"

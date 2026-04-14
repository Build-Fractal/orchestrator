#!/usr/bin/env bash
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scripts/telemetry/record-telemetry.sh' "$f" || { echo "FAIL: record-telemetry.sh not registered in extension.yml"; exit 1; }
grep -q 'scripts/telemetry/aggregate-metrics.sh' "$f" || { echo "FAIL: aggregate-metrics.sh not registered in extension.yml"; exit 1; }
echo "PASS: extension.yml registers both telemetry scripts"

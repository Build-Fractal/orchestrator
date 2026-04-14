#!/usr/bin/env bash
set -eu
f="commands/status.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'aggregate-metrics' "$f" || { echo "FAIL: status.md does not reference aggregate-metrics.sh"; exit 1; }
grep -qi 'telemetry\|cost\|token' "$f" || { echo "FAIL: status.md does not mention telemetry metrics"; exit 1; }
echo "PASS: commands/status.md references aggregate-metrics.sh for telemetry display"

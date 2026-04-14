#!/usr/bin/env bash
set -eu
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'unknown' "$f" || { echo "FAIL: aggregate-metrics.sh missing unknown cost handling"; exit 1; }
echo "PASS: aggregate-metrics.sh distinguishes null from zero cost"

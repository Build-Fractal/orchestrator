#!/usr/bin/env bash
set -eu
# aggregate-metrics.sh should be read-only — it reads the log but never writes to it
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qE '>>\s*"\$EXECUTION_LOG"|>>\s*\$EXECUTION_LOG' "$f" && { echo "FAIL: aggregate-metrics.sh modifies the execution log"; exit 1; }
# record-telemetry.sh appends only
f2="scripts/telemetry/record-telemetry.sh"
test -f "$f2" || { echo "FAIL: $f2 missing"; exit 1; }
grep -q '>>' "$f2" || { echo "FAIL: record-telemetry.sh does not use append mode"; exit 1; }
grep -qE '>\s*"\$EXECUTION_LOG"[^>]|>\s*\$EXECUTION_LOG[^>]' "$f2" && { echo "FAIL: record-telemetry.sh uses overwrite instead of append"; exit 1; }
echo "PASS: telemetry operations are idempotent (aggregate is read-only, record appends)"

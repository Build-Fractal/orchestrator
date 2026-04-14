#!/usr/bin/env bash
# Verifies run-doctor.sh includes graph health check.
set -eu

f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-graph-health\.sh' "$f" || { echo "FAIL: $f does not call check-graph-health.sh"; exit 1; }
grep -q 'Graph Health' "$f" || { echo "FAIL: $f does not have Graph Health section"; exit 1; }
echo "PASS: run-doctor.sh includes graph health check"

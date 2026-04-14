#!/usr/bin/env bash
# Verifies scripts/diagnostics/run-doctor.sh references check-instructions.sh.
# Expected to FAIL until T02 integrates the check into the doctor runner.
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "check-instructions" "$f" || { echo "FAIL: $f does not reference check-instructions.sh (expected until T02)"; exit 1; }
echo "PASS: $f references check-instructions.sh"

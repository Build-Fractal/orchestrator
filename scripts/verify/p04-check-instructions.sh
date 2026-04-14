#!/usr/bin/env bash
# Verifies scripts/diagnostics/check-instructions.sh exists, is executable,
# and contains the DOCTOR:INSTRUCTIONS structured output marker.
set -eu
f="scripts/diagnostics/check-instructions.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f is not executable"; exit 1; }
grep -q "DOCTOR:INSTRUCTIONS" "$f" || { echo "FAIL: $f missing DOCTOR:INSTRUCTIONS marker"; exit 1; }
echo "PASS: $f exists, is executable, and emits DOCTOR:INSTRUCTIONS"

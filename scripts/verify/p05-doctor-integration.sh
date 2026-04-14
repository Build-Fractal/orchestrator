#!/usr/bin/env bash
# Verifies run-doctor.sh includes a call to check-providers.sh.
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-providers.sh' "$f" || { echo "FAIL: run-doctor.sh does not reference check-providers.sh"; exit 1; }
echo "PASS: run-doctor.sh includes provider conformance check"

#!/usr/bin/env bash
# Verify check-docs.sh uses DOCTOR: output protocol.
set -eu
f="scripts/diagnostics/check-docs.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'DOCTOR:' "$f" || { echo "FAIL: check-docs.sh does not use DOCTOR: output protocol"; exit 1; }
echo "PASS: check-docs.sh uses DOCTOR: output protocol"

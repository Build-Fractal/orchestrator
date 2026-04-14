#!/usr/bin/env bash
# Verify scripts/diagnostics/check-docs.sh exists and is executable.
set -eu
f="scripts/diagnostics/check-docs.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f is not executable"; exit 1; }
echo "PASS: scripts/diagnostics/check-docs.sh exists and is executable"

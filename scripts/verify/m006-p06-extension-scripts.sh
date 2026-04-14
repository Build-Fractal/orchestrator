#!/usr/bin/env bash
# Verify check-docs.sh is registered in extension.yml.
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scripts/diagnostics/check-docs.sh' "$f" || { echo "FAIL: check-docs.sh not registered in extension.yml"; exit 1; }
echo "PASS: check-docs.sh is registered in extension.yml"

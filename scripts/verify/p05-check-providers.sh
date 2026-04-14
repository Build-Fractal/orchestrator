#!/usr/bin/env bash
# Verifies scripts/diagnostics/check-providers.sh exists with expected structure.
set -eu
f="scripts/diagnostics/check-providers.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
grep -q 'DOCTOR:PROVIDERS' "$f" || { echo "FAIL: DOCTOR:PROVIDERS output missing"; exit 1; }
lines="$(wc -l < "$f" | tr -d ' ')"
test "$lines" -ge 40 || { echo "FAIL: expected at least 40 lines, found $lines"; exit 1; }
echo "PASS: check-providers.sh exists with DOCTOR:PROVIDERS output ($lines lines)"

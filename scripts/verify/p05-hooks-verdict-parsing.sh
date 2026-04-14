#!/usr/bin/env bash
# Verifies hooks.sh has been updated to capture and parse VERDICT lines.
set -eu
f="scripts/lib/hooks.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'VERDICT' "$f" || { echo "FAIL: hooks.sh does not reference VERDICT"; exit 1; }
grep -q 'verdicts.sh' "$f" || { echo "FAIL: hooks.sh does not source verdicts.sh"; exit 1; }
grep -q 'parse_verdict' "$f" || { echo "FAIL: hooks.sh does not call parse_verdict"; exit 1; }
echo "PASS: hooks.sh captures and parses VERDICT lines"

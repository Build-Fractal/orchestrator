#!/usr/bin/env bash
# Verify scripts/AGENTS.md documents testing patterns.
set -eu
f="scripts/AGENTS.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "testing\|test.*pattern" "$f" || { echo "FAIL: missing testing patterns section"; exit 1; }
grep -q "pass()" "$f" || { echo "FAIL: missing pass() function documentation"; exit 1; }
grep -q "fail()" "$f" || { echo "FAIL: missing fail() function documentation"; exit 1; }
grep -q "PASS:" "$f" || { echo "FAIL: missing PASS: output format documentation"; exit 1; }
grep -q "FAIL:" "$f" || { echo "FAIL: missing FAIL: output format documentation"; exit 1; }
grep -qi "fixture" "$f" || { echo "FAIL: missing fixture convention documentation"; exit 1; }
echo "PASS: scripts/AGENTS.md testing patterns documentation"

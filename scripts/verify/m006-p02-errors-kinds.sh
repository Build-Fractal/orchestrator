#!/usr/bin/env bash
# Verify references/errors.md documents all 6 error kinds with examples.
set -eu
f="references/errors.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
for kind in CONFIG STATE DISPATCH VERIFY BUDGET IO; do
  grep -q "$kind" "$f" || { echo "FAIL: missing error kind $kind"; exit 1; }
done
echo "PASS: errors.md documents all 6 error kinds"

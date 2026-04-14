#!/usr/bin/env bash
# Verify references/hooks.md documents verdict protocol and snapshot isolation.
set -eu
f="references/hooks.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
for v in PASS BLOCK WARN NEEDS_REVIEW; do
  grep -q "$v" "$f" || { echo "FAIL: missing verdict $v"; exit 1; }
done
grep -qi "snapshot" "$f" || { echo "FAIL: missing snapshot isolation documentation"; exit 1; }
grep -q "HOOK_VIOLATION" "$f" || { echo "FAIL: missing HOOK_VIOLATION documentation"; exit 1; }
echo "PASS: hooks.md verdict protocol and snapshot isolation"

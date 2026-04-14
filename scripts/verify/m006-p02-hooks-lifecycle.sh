#!/usr/bin/env bash
# Verify references/hooks.md documents all 4 lifecycle points.
set -eu
f="references/hooks.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
for lp in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do
  grep -q "$lp" "$f" || { echo "FAIL: missing lifecycle point $lp"; exit 1; }
done
echo "PASS: hooks.md documents all 4 lifecycle points"

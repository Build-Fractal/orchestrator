#!/usr/bin/env sh
# m045-p03-legacy-golden.sh (SC-4)
# The un-armed rotation-exit directive is byte-identical to the pinned golden.
set -eu
GOLD="tests/fixtures/m045-rotation-exit-legacy.golden"
ACTUAL="$(bash scripts/lifecycle/self-continue-branch.sh --monitor-status 'CONTEXT:ROTATE weight=9 limit=3' --armed false --headless true)"
EXPECT="$(cat "$GOLD")"
[ "$ACTUAL" = "$EXPECT" ] || { echo "FAIL: un-armed output drifted from golden"; echo " expect: $EXPECT"; echo " actual: $ACTUAL"; exit 1; }
echo "PASS: golden matches ($EXPECT)"

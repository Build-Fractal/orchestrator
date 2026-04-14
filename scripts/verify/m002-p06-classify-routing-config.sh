#!/usr/bin/env bash
set -eu
f="scripts/dispatch/classify-complexity.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-routing-config' "$f" || { echo "FAIL: does not accept --routing-config flag"; exit 1; }
grep -q 'ROUTING_CONFIG' "$f" || { echo "FAIL: no ROUTING_CONFIG variable handling"; exit 1; }
echo "PASS: classify-complexity.sh accepts --routing-config flag"

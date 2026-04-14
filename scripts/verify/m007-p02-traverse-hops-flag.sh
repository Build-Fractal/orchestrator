#!/usr/bin/env bash
# Verifies traverse-graph.sh supports --hops flag as alias for --max-depth.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-hops' "$f" || { echo "FAIL: $f does not support --hops flag"; exit 1; }
# Verify --hops and --max-depth share the same handler
grep -q '\-\-max-depth|\-\-hops' "$f" || { echo "FAIL: $f does not alias --hops to --max-depth"; exit 1; }
echo "PASS: traverse-graph.sh supports --hops flag"

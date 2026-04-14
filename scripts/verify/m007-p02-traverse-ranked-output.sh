#!/usr/bin/env bash
# Verifies traverse-graph.sh supports --ranked flag for scored output.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-ranked' "$f" || { echo "FAIL: $f does not support --ranked flag"; exit 1; }
grep -q 'ranked=true' "$f" || { echo "FAIL: $f missing ranked mode logic"; exit 1; }
# Verify the ranking formula uses confidence and depth
grep -q 'confidence.*1\.0.*depth\|confidence.*depth' "$f" || { echo "FAIL: $f missing path-distance ranking formula"; exit 1; }
echo "PASS: traverse-graph.sh supports --ranked output with path-distance scoring"

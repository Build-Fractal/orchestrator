#!/usr/bin/env bash
# Verifies traverse-graph.sh queries both edge directions (source_id and target_id).
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
# The CTE base case must query both directions
grep -q 'source_id.*AND edge_type' "$f" || { echo "FAIL: $f missing source_id direction in CTE"; exit 1; }
grep -q 'target_id.*AND edge_type' "$f" || { echo "FAIL: $f missing target_id direction in CTE"; exit 1; }
# Verify both directions appear in the recursive step as well
source_count="$(grep -c 'source_id' "$f")"
target_count="$(grep -c 'target_id' "$f")"
test "$source_count" -ge 2 || { echo "FAIL: $f has fewer than 2 source_id references (need base + recursive)"; exit 1; }
test "$target_count" -ge 2 || { echo "FAIL: $f has fewer than 2 target_id references (need base + recursive)"; exit 1; }
echo "PASS: traverse-graph.sh queries both edge directions for bidirectional traversal"

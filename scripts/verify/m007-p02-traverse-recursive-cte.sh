#!/usr/bin/env bash
# Verifies traverse-graph.sh uses a recursive CTE instead of Bash BFS.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'WITH RECURSIVE' "$f" || { echo "FAIL: $f does not contain recursive CTE"; exit 1; }
grep -q 'db_query' "$f" || { echo "FAIL: $f does not use db_query"; exit 1; }
# Verify old BFS artifacts are gone
if grep -q 'mktemp' "$f"; then
  echo "FAIL: $f still uses mktemp (BFS remnant)"; exit 1
fi
if grep -q 'current_frontier' "$f"; then
  echo "FAIL: $f still uses frontier variables (BFS remnant)"; exit 1
fi
echo "PASS: traverse-graph.sh uses recursive CTE, no BFS remnants"

#!/usr/bin/env bash
# Verifies both traverse-graph.sh and scope-filter.sh source graph-db.sh.
set -eu

t="scripts/knowledge/traverse-graph.sh"
s="scripts/dispatch/scope-filter.sh"

test -f "$t" || { echo "FAIL: $t missing"; exit 1; }
test -f "$s" || { echo "FAIL: $s missing"; exit 1; }

grep -q 'graph-db.sh' "$t" || { echo "FAIL: $t does not source graph-db.sh"; exit 1; }
grep -q 'graph-db.sh' "$s" || { echo "FAIL: $s does not source graph-db.sh"; exit 1; }
grep -q 'db_query' "$t" || { echo "FAIL: $t does not use db_query"; exit 1; }
grep -q 'db_query' "$s" || { echo "FAIL: $s does not use db_query"; exit 1; }
echo "PASS: both scripts source graph-db.sh and use db_query()"

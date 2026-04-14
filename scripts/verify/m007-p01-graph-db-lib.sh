#!/usr/bin/env bash
# Verifies scripts/knowledge/lib/graph-db.sh exists with double-sourcing guard,
# get_db_path, db_query, and db_init functions.
set -eu

f="scripts/knowledge/lib/graph-db.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_GRAPH_DB_SOURCED' "$f" || { echo "FAIL: $f missing double-sourcing guard"; exit 1; }
grep -q 'get_db_path' "$f" || { echo "FAIL: $f missing get_db_path function"; exit 1; }
grep -q 'db_query' "$f" || { echo "FAIL: $f missing db_query function"; exit 1; }
grep -q 'db_init' "$f" || { echo "FAIL: $f missing db_init function"; exit 1; }
grep -q 'db_insert_entry' "$f" || { echo "FAIL: $f missing db_insert_entry function"; exit 1; }
grep -q 'db_insert_edge' "$f" || { echo "FAIL: $f missing db_insert_edge function"; exit 1; }
grep -q 'db_insert_scope_tag' "$f" || { echo "FAIL: $f missing db_insert_scope_tag function"; exit 1; }
echo "PASS: graph-db.sh exists with guard and all required functions"

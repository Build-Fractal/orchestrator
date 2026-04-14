#!/usr/bin/env bash
# Verifies rebuild-index.sh populates knowledge.db alongside the flat index.
set -eu

f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'graph-db.sh' "$f" || { echo "FAIL: $f does not source graph-db.sh"; exit 1; }
grep -q 'knowledge.db' "$f" || { echo "FAIL: $f does not reference knowledge.db"; exit 1; }
grep -q 'db_init' "$f" || { echo "FAIL: $f does not call db_init"; exit 1; }
grep -q 'db_insert_entry' "$f" || { echo "FAIL: $f does not call db_insert_entry"; exit 1; }
echo "PASS: rebuild-index.sh populates knowledge.db"

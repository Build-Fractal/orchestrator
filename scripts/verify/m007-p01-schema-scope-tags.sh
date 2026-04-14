#!/usr/bin/env bash
# Verifies SQL schema defines scope_tags table for normalized tag-to-entry
# mapping.
set -eu

f="scripts/knowledge/lib/graph-db.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'CREATE TABLE.*scope_tags' "$f" || { echo "FAIL: $f missing scope_tags table definition"; exit 1; }
grep -q 'entry_id' "$f" || { echo "FAIL: scope_tags table missing entry_id column"; exit 1; }
grep -q 'tag' "$f" || { echo "FAIL: scope_tags table missing tag column"; exit 1; }
echo "PASS: scope_tags table schema includes entry_id and tag columns"

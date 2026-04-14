#!/usr/bin/env bash
# Verifies SQL schema defines entries table with all frontmatter columns
# plus a NULL vector column for future sqlite-vec integration.
set -eu

f="scripts/knowledge/lib/graph-db.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'CREATE TABLE.*entries' "$f" || { echo "FAIL: $f missing entries table definition"; exit 1; }
grep -q 'id ' "$f" || { echo "FAIL: entries table missing id column"; exit 1; }
grep -q 'category' "$f" || { echo "FAIL: entries table missing category column"; exit 1; }
grep -q 'confidence' "$f" || { echo "FAIL: entries table missing confidence column"; exit 1; }
grep -q 'created_at' "$f" || { echo "FAIL: entries table missing created_at column"; exit 1; }
grep -q 'last_verified' "$f" || { echo "FAIL: entries table missing last_verified column"; exit 1; }
grep -q 'hit_count' "$f" || { echo "FAIL: entries table missing hit_count column"; exit 1; }
grep -q 'vector' "$f" || { echo "FAIL: entries table missing vector column for sqlite-vec"; exit 1; }
echo "PASS: entries table schema includes all frontmatter fields and vector column"

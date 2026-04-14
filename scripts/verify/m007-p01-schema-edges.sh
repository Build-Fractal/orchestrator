#!/usr/bin/env bash
# Verifies SQL schema defines edges table for relates_to and supersedes
# relationships as directed edges.
set -eu

f="scripts/knowledge/lib/graph-db.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'CREATE TABLE.*edges' "$f" || { echo "FAIL: $f missing edges table definition"; exit 1; }
grep -q 'source_id' "$f" || { echo "FAIL: edges table missing source_id column"; exit 1; }
grep -q 'target_id' "$f" || { echo "FAIL: edges table missing target_id column"; exit 1; }
grep -q 'edge_type' "$f" || { echo "FAIL: edges table missing edge_type column"; exit 1; }
echo "PASS: edges table schema includes source_id, target_id, and edge_type columns"

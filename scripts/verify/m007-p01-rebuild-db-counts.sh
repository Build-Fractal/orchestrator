#!/usr/bin/env bash
# Verifies rebuild-index.sh reports entry, edge, and scope_tag counts for
# the database rebuild.
set -eu

f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'knowledge.db' "$f" || { echo "FAIL: $f does not reference knowledge.db"; exit 1; }
grep -q 'entries' "$f" || { echo "FAIL: $f does not report entry count"; exit 1; }
grep -q 'edges' "$f" || { echo "FAIL: $f does not report edge count"; exit 1; }
grep -q 'scope_tags\|scope tags\|tags' "$f" || { echo "FAIL: $f does not report scope_tag count"; exit 1; }
grep -q 'REBUILT.*knowledge.db' "$f" || { echo "FAIL: $f missing REBUILT output line for knowledge.db"; exit 1; }
echo "PASS: rebuild-index.sh reports database entry/edge/scope_tag counts"

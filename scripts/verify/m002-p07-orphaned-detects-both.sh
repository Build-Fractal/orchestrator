#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-orphaned.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'index-utils.sh' "$f" || { echo "FAIL: does not source index-utils.sh"; exit 1; }
grep -q 'index_has_entry' "$f" || { echo "FAIL: does not check for detail files without index entries"; exit 1; }
grep -q 'knowledge_dir' "$f" || grep -q 'knowledge/' "$f" || { echo "FAIL: does not scan knowledge directory for detail files"; exit 1; }
grep -q 'index_path' "$f" || grep -q 'INDEX' "$f" || { echo "FAIL: does not read index for entry scanning"; exit 1; }
grep -q 'WARNING.*no detail file\|WARNING.*Index entry' "$f" || { echo "FAIL: missing warning for index entries without detail files"; exit 1; }
grep -q 'WARNING.*no index entry\|WARNING.*Detail file' "$f" || { echo "FAIL: missing warning for detail files without index entries"; exit 1; }
echo "PASS: check-orphaned.sh detects both orphan directions"

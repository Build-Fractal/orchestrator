#!/usr/bin/env bash
# Verifies --provenance mode uses a recursive CTE on supersedes/superseded_by.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'WITH RECURSIVE' "$f" || { echo "FAIL: $f does not contain recursive CTE"; exit 1; }
grep -q 'supersedes' "$f" || { echo "FAIL: $f does not reference supersedes column"; exit 1; }
grep -q 'superseded_by' "$f" || { echo "FAIL: $f does not reference superseded_by column"; exit 1; }
grep -q 'backward' "$f" || { echo "FAIL: $f missing backward CTE for predecessor walk"; exit 1; }
grep -q 'forward' "$f" || { echo "FAIL: $f missing forward CTE for successor walk"; exit 1; }
echo "PASS: --provenance mode uses recursive CTE on supersedes/superseded_by"

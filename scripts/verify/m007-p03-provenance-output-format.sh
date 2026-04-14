#!/usr/bin/env bash
# Verifies --provenance output format matches specification.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'PROVENANCE:' "$f" || { echo "FAIL: $f missing PROVENANCE: header output"; exit 1; }
grep -q 'chain length' "$f" || { echo "FAIL: $f missing chain length in header"; exit 1; }
grep -q 'origin' "$f" || { echo "FAIL: $f missing origin label"; exit 1; }
grep -q 'current' "$f" || { echo "FAIL: $f missing current label"; exit 1; }
grep -q 'superseded' "$f" || { echo "FAIL: $f missing superseded label"; exit 1; }
grep -q 'sole entry' "$f" || { echo "FAIL: $f missing sole entry label"; exit 1; }
echo "PASS: --provenance output format matches specification"

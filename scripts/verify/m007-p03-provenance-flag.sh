#!/usr/bin/env bash
# Verifies traverse-graph.sh supports --provenance flag for supersession
# chain queries. Checks that the flag is parsed and triggers provenance mode.
set -eu

f="scripts/knowledge/traverse-graph.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-provenance' "$f" || { echo "FAIL: $f does not support --provenance flag"; exit 1; }
grep -q 'provenance=true' "$f" || { echo "FAIL: $f missing provenance mode variable"; exit 1; }
grep -q 'provenance=false' "$f" || { echo "FAIL: $f missing provenance default initialization"; exit 1; }
echo "PASS: traverse-graph.sh supports --provenance flag"

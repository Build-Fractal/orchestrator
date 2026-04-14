#!/usr/bin/env bash
# Verifies scope-filter.sh supports --graph mode.
set -eu

f="scripts/dispatch/scope-filter.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-graph' "$f" || { echo "FAIL: $f does not support --graph flag"; exit 1; }
grep -q 'GRAPH_MODE' "$f" || { echo "FAIL: $f missing GRAPH_MODE variable"; exit 1; }
grep -q 'filter_knowledge_graph' "$f" || { echo "FAIL: $f missing filter_knowledge_graph function"; exit 1; }
echo "PASS: scope-filter.sh supports --graph mode"

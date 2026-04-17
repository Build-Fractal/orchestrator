#!/usr/bin/env bash
# scripts/verify/m011-p05-spec-story-graph-delegates.sh
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/scripts/knowledge/spec-story-graph.sh"

if ! grep -q "traverse-graph.sh" "$SCRIPT"; then
  echo "FAIL: spec-story-graph.sh does not reference traverse-graph.sh"
  exit 1
fi

# Ensure it does NOT contain direct sqlite3 SELECT on the edges table
if grep -q "sqlite3" "$SCRIPT"; then
  echo "FAIL: spec-story-graph.sh invokes sqlite3 directly (should delegate)"
  exit 1
fi

echo "PASS: spec-story-graph.sh delegates edge traversal"

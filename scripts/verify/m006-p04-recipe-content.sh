#!/usr/bin/env bash
# Verify docs/recipe-authoring.md documents recipe creation, overrides, and compression.
set -eu
f="docs/recipe-authoring.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "source" "$f" || { echo "FAIL: missing source field documentation"; exit 1; }
grep -qi "compression\|compress" "$f" || { echo "FAIL: missing compression documentation"; exit 1; }
grep -qi "override\|per-phase\|per phase" "$f" || { echo "FAIL: missing override/per-phase documentation"; exit 1; }
grep -qi "task" "$f" || { echo "FAIL: missing resolution order task level"; exit 1; }
grep -qi "milestone" "$f" || { echo "FAIL: missing resolution order milestone level"; exit 1; }
grep -qi "default" "$f" || { echo "FAIL: missing resolution order default level"; exit 1; }
grep -q "recipes.md" "$f" || { echo "FAIL: missing cross-link to recipes.md"; exit 1; }
grep -qi "troubleshoot" "$f" || { echo "FAIL: missing troubleshooting section"; exit 1; }
echo "PASS: recipe-authoring.md content documentation"

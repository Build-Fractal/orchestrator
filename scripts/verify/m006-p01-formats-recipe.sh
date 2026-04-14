#!/usr/bin/env bash
# Verify references/file-formats.md documents context-recipe.yaml format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "context-recipe.yaml" "$f" || { echo "FAIL: missing context-recipe.yaml documentation"; exit 1; }
grep -q "sections:" "$f" || { echo "FAIL: missing sections block documentation"; exit 1; }
grep -q "compression:" "$f" || { echo "FAIL: missing compression block documentation"; exit 1; }
grep -q "priority" "$f" || { echo "FAIL: missing priority field documentation"; exit 1; }
echo "PASS: file-formats.md documents context-recipe.yaml"

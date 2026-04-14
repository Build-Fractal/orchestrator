#!/usr/bin/env bash
# Verify references/architecture.md includes a file layout tree.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "## File Layout" "$f" || { echo "FAIL: missing File Layout section"; exit 1; }
grep -q "scripts/" "$f" || { echo "FAIL: missing scripts/ in layout"; exit 1; }
grep -q "commands/" "$f" || { echo "FAIL: missing commands/ in layout"; exit 1; }
grep -q "templates/" "$f" || { echo "FAIL: missing templates/ in layout"; exit 1; }
grep -q "references/" "$f" || { echo "FAIL: missing references/ in layout"; exit 1; }
grep -q ".specify/orchestrator/" "$f" || { echo "FAIL: missing .specify/orchestrator/ in layout"; exit 1; }
echo "PASS: architecture.md file layout tree"

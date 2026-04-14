#!/usr/bin/env bash
# Verify docs/knowledge-management.md documents entry lifecycle, staleness, graphs, consolidation.
set -eu
f="docs/knowledge-management.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "create.entry\|create entry\|creating entries" "$f" || { echo "FAIL: missing entry creation documentation"; exit 1; }
grep -qi "staleness\|stale" "$f" || { echo "FAIL: missing staleness documentation"; exit 1; }
grep -qi "graph\|relationship" "$f" || { echo "FAIL: missing graph relationship documentation"; exit 1; }
grep -qi "scope.*filter\|scope filter\|filtering" "$f" || { echo "FAIL: missing scope filtering documentation"; exit 1; }
grep -qi "consolidat" "$f" || { echo "FAIL: missing consolidation documentation"; exit 1; }
grep -qi "update" "$f" || { echo "FAIL: missing update lifecycle operation"; exit 1; }
grep -qi "promote" "$f" || { echo "FAIL: missing promote lifecycle operation"; exit 1; }
grep -qi "archive" "$f" || { echo "FAIL: missing archive lifecycle operation"; exit 1; }
grep -qi "supersede" "$f" || { echo "FAIL: missing supersede lifecycle operation"; exit 1; }
grep -q "file-formats.md" "$f" || { echo "FAIL: missing cross-link to file-formats.md"; exit 1; }
echo "PASS: knowledge-management.md content documentation"

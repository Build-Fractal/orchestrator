#!/usr/bin/env bash
# Verify scripts/AGENTS.md includes compliance and PR review checklists.
set -eu
f="scripts/AGENTS.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "compliance.*checklist\|checklist.*compliance\|constitution.*checklist\|compliance" "$f" || { echo "FAIL: missing compliance checklist section"; exit 1; }
grep -qi "PR.*review\|review.*checklist\|pull request.*review" "$f" || { echo "FAIL: missing PR review checklist section"; exit 1; }
# Count checklist-style items (lines with - [ ], numbered items, or bulleted items in checklist sections)
item_count=$(grep -c "^[0-9]\. \|^- \[.\] \|^- " "$f" 2>/dev/null || true)
test "$item_count" -ge 10 || { echo "FAIL: fewer than 10 checklist items (found $item_count)"; exit 1; }
echo "PASS: scripts/AGENTS.md compliance and PR review checklists"

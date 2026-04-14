#!/usr/bin/env bash
# Verify cross-links between P05 docs and to reference docs.
set -eu

agents="scripts/AGENTS.md"
walkthrough="references/constitution-walkthrough.md"

test -f "$agents" || { echo "FAIL: $agents missing"; exit 1; }
test -f "$walkthrough" || { echo "FAIL: $walkthrough missing"; exit 1; }

# scripts/AGENTS.md cross-links
grep -q "constitution-walkthrough\.md" "$agents" || { echo "FAIL: AGENTS.md missing link to constitution-walkthrough.md"; exit 1; }
grep -q "architecture\.md" "$agents" || { echo "FAIL: AGENTS.md missing link to architecture.md"; exit 1; }
grep -q "ANTIPATTERNS\.md" "$agents" || { echo "FAIL: AGENTS.md missing link to ANTIPATTERNS.md"; exit 1; }

# references/constitution-walkthrough.md cross-links
grep -q "constitution\.md" "$walkthrough" || { echo "FAIL: constitution-walkthrough.md missing link to constitution.md"; exit 1; }
grep -qi "AGENTS\.md" "$walkthrough" || { echo "FAIL: constitution-walkthrough.md missing link to AGENTS.md"; exit 1; }
grep -q "architecture\.md" "$walkthrough" || { echo "FAIL: constitution-walkthrough.md missing link to architecture.md"; exit 1; }
grep -q "ANTIPATTERNS\.md" "$walkthrough" || { echo "FAIL: constitution-walkthrough.md missing link to ANTIPATTERNS.md"; exit 1; }

# Verify no absolute paths in cross-links (only relative)
if grep -qE '\]\(/[A-Za-z]' "$agents"; then
  echo "FAIL: AGENTS.md contains absolute path cross-links"
  exit 1
fi
if grep -qE '\]\(/[A-Za-z]' "$walkthrough"; then
  echo "FAIL: constitution-walkthrough.md contains absolute path cross-links"
  exit 1
fi

echo "PASS: P05 cross-links validated (relative paths, all targets referenced)"

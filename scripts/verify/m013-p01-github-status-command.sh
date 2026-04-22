#!/usr/bin/env bash
# scripts/verify/m013-p01-github-status-command.sh — gate for the
# commands/github-status.md markdown file (MEM012 structure).
#
# Asserts 15+ structural properties of the command document.
# Single-script-file (AD-19) shape.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${REPO_ROOT}/commands/github-status.md"

fail_count=0
assert_ok() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
  else
    echo "FAIL: $2 (rc=$1)"
    fail_count=$((fail_count + 1))
  fi
}

# 1. File exists
if [ -f "$CMD" ]; then
  echo "PASS: command markdown exists"
else
  echo "FAIL: command markdown exists"
  fail_count=$((fail_count + 1))
fi

# 2. Opens with YAML frontmatter
head -1 "$CMD" | grep -q '^---$'
assert_ok $? "opens with YAML frontmatter delimiter"

# 3. Frontmatter has description
grep -q '^description:' "$CMD"
assert_ok $? "frontmatter has description field"

# 4. Description mentions read-only semantics
grep -q -i 'read-only' "$CMD"
assert_ok $? "description mentions read-only"

# 5. Title heading present
grep -q '^# speckit.orchestrator.github-status' "$CMD"
assert_ok $? "has title heading"

# 6. Prerequisites section
grep -q '^## Prerequisites' "$CMD"
assert_ok $? "has Prerequisites section"

# 7. Core Workflow section
grep -q '^## Core Workflow' "$CMD"
assert_ok $? "has Core Workflow section"

# 8. Output section
grep -q '^## Output' "$CMD"
assert_ok $? "has Output section"

# 9. Idempotency section
grep -q '^## Idempotency' "$CMD"
assert_ok $? "has Idempotency section"

# 10. Error Handling section
grep -q '^## Error Handling' "$CMD"
assert_ok $? "has Error Handling section"

# 11. Referenced Scripts section
grep -q '^## Referenced Scripts' "$CMD"
assert_ok $? "has Referenced Scripts section"

# 12. References github-status.sh by path
grep -q 'scripts/integrations/github-status.sh' "$CMD"
assert_ok $? "references github-status.sh by path"

# 13. References sidecar-init-pending.sh (T01 upstream)
grep -q 'scripts/integrations/sidecar-init-pending.sh' "$CMD"
assert_ok $? "references sidecar-init-pending.sh"

# 14. Mentions the three STATUS outcomes
grep -q 'STATUS: absent' "$CMD"
assert_ok $? "documents STATUS: absent"
grep -q 'STATUS: pending-operator-complete' "$CMD"
assert_ok $? "documents STATUS: pending-operator-complete"
grep -q 'STATUS: configured' "$CMD"
assert_ok $? "documents STATUS: configured"

# 15. Mentions the sidecar path
grep -q '\.orchestrator/integrations/github\.json' "$CMD"
assert_ok $? "names sidecar path .orchestrator/integrations/github.json"

# 16. Documents --init-pending flag
grep -q '\-\-init-pending' "$CMD"
assert_ok $? "documents --init-pending flag"

# 17. Documents exit codes
grep -q 'exit 1' "$CMD"
assert_ok $? "documents exit 1 (schema-mismatch)"
grep -q 'exit 2' "$CMD"
assert_ok $? "documents exit 2 (bad flag)"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-github-status-command.sh"
  exit 0
fi
echo "FAIL: m013-p01-github-status-command.sh ($fail_count failures)"
exit 1

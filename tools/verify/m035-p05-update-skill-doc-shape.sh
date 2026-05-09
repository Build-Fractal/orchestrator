#!/usr/bin/env bash
# tools/verify/m035-p05-update-skill-doc-shape.sh
#
# M035 P05 T02 — Asserts commands/update.md carries the rollback section
# documented per the spec amendment + #Q-G8 verbatim advisory.
#
#   1. ## Rollback heading present
#   2. verbatim symlink-mode advisory present (the wording T05 acceptance
#      test pattern-matches identically)
#   3. .orchestrator/.previous-version reference present
#   4. .orchestrator/.rollback/ reference present
#   5. SKIP statement for npm/homebrew rollback present
#
# AD-19 single-script-file shape. Bash 3.2 + POSIX-sh per CON-2.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DOC="$REPO/commands/update.md"

pass=0
fail=0

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC missing"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi

# 1. ## Rollback heading
if grep -qE '^## Rollback$' "$DOC"; then
  echo "PASS: ## Rollback heading present"
  pass=$((pass + 1))
else
  echo "FAIL: ## Rollback heading missing"
  fail=$((fail + 1))
fi

# 2. Verbatim symlink-mode advisory.
if grep -qF 'rollback not available for symlink-mode installs' "$DOC"; then
  echo "PASS: verbatim symlink-mode advisory present"
  pass=$((pass + 1))
else
  echo "FAIL: verbatim symlink-mode advisory missing"
  fail=$((fail + 1))
fi

# 3. .orchestrator/.previous-version reference.
if grep -qF '.orchestrator/.previous-version' "$DOC"; then
  echo "PASS: .orchestrator/.previous-version reference present"
  pass=$((pass + 1))
else
  echo "FAIL: .orchestrator/.previous-version reference missing"
  fail=$((fail + 1))
fi

# 4. .orchestrator/.rollback/ reference.
if grep -qF '.orchestrator/.rollback/' "$DOC"; then
  echo "PASS: .orchestrator/.rollback/ reference present"
  pass=$((pass + 1))
else
  echo "FAIL: .orchestrator/.rollback/ reference missing"
  fail=$((fail + 1))
fi

# 5. SKIP statement for npm/homebrew rollback.
if grep -qF 'SKIP: rollback not yet implemented for source=' "$DOC"; then
  echo "PASS: SKIP statement for npm/homebrew rollback present"
  pass=$((pass + 1))
else
  echo "FAIL: SKIP statement for npm/homebrew rollback missing"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]

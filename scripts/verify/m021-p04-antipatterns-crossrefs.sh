#!/usr/bin/env bash
# scripts/verify/m021-p04-antipatterns-crossrefs.sh -- Asserts T04.b cross-refs landed.
#
# Checks ANTIPATTERNS.md contains Cross-Refs blocks under AP-005..AP-009 naming
# scripts/hooks/pre-bash-shape-guard.sh and tests/fixtures/m021-prompt-corpus.txt.
# AP-001..AP-004 headings remain present and unmodified at the heading level.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AP="${REPO_ROOT}/ANTIPATTERNS.md"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$AP" ]; then
  fail "ANTIPATTERNS.md exists" "not found at $AP"
  echo "FAIL: m021-p04-antipatterns-crossrefs.sh (1 failures)"
  exit 1
fi
pass "ANTIPATTERNS.md exists at $AP"

# AP-001..AP-009 headings all present.
for ap in AP-001 AP-002 AP-003 AP-004 AP-005 AP-006 AP-007 AP-008 AP-009; do
  if grep -qE "^## $ap:" "$AP"; then
    pass "$ap heading present"
  else
    fail "$ap heading" "missing"
  fi
done

# For AP-005..AP-009, extract the content block from its heading to the next
# heading (or EOF) and assert both cross-ref paths appear.
_tmp="$(mktemp -d)"

for ap in AP-005 AP-006 AP-007 AP-008 AP-009; do
  awk -v tgt="$ap" '
    /^## AP-/ {
      if (active) { active=0 }
      if ($0 ~ "^## " tgt ":") { active=1; next }
    }
    active { print }
  ' "$AP" > "$_tmp/${ap}.txt"

  if grep -qF 'scripts/hooks/pre-bash-shape-guard.sh' "$_tmp/${ap}.txt"; then
    pass "$ap section references pre-bash-shape-guard.sh"
  else
    fail "$ap section references pre-bash-shape-guard.sh" "not found"
  fi
  if grep -qF 'tests/fixtures/m021-prompt-corpus.txt' "$_tmp/${ap}.txt"; then
    pass "$ap section references m021-prompt-corpus.txt"
  else
    fail "$ap section references m021-prompt-corpus.txt" "not found"
  fi
done

rm -rf "$_tmp"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-antipatterns-crossrefs.sh"
  exit 0
fi
echo "FAIL: m021-p04-antipatterns-crossrefs.sh ($fail_count failures)"
exit 1

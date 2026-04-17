#!/usr/bin/env bash
# scripts/verify/m011-p07-conversus-doc-structure.sh
#
# Asserts commands/conversus-gate.md follows MEM012 structure and
# references the canonical adapter + preset + gate-result template.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="${REPO_ROOT}/commands/conversus-gate.md"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  echo "PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "FAIL: $1"
}

# --- existence ---

if [ -f "$DOC" ]; then
  pass "doc exists"
else
  fail "doc missing at $DOC"
  echo "SUMMARY: pass=$PASS fail=$FAIL"
  exit 1
fi

# --- line count >= 90 ---

LC="$(wc -l < "$DOC" | tr -d ' ')"
if [ "$LC" -ge 90 ]; then
  pass "doc has $LC lines (>= 90)"
else
  fail "doc has $LC lines (< 90)"
fi

# --- frontmatter description ---

if grep -Eq '^description:' "$DOC"; then
  pass "frontmatter has description: field"
else
  fail "frontmatter missing description:"
fi

# --- content tokens ---

for tok in 'source-advocate' 'target-advocate' 'normalize-fidelity' 'PASS' 'BLOCK'; do
  if grep -Fq -- "$tok" "$DOC"; then
    pass "contains token: $tok"
  else
    fail "missing token: $tok"
  fi
done

# --- MEM012 section headings ---

for heading in 'Prerequisites' 'Usage' 'Workflow' 'Idempotency' 'Error Handling' 'Reference Files'; do
  if grep -Eq "^## ${heading}\$" "$DOC"; then
    pass "heading present: ## ${heading}"
  else
    fail "heading missing: ## ${heading}"
  fi
done

# --- referenced files ---

for tok in 'scripts/dispatch/adapters/tool/conversus.sh' 'templates/conversus-presets/normalize-fidelity.yml' 'templates/gate-result.md'; do
  if grep -Fq -- "$tok" "$DOC"; then
    pass "references file: $tok"
  else
    fail "does not reference file: $tok"
  fi
done

# --- summary ---

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
exit 1

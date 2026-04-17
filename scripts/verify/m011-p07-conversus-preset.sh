#!/usr/bin/env bash
# scripts/verify/m011-p07-conversus-preset.sh
#
# Asserts templates/conversus-presets/normalize-fidelity.yml shape.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRESET="${REPO_ROOT}/templates/conversus-presets/normalize-fidelity.yml"

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

if [ -f "$PRESET" ]; then
  pass "preset exists"
else
  fail "preset missing at $PRESET"
  echo "SUMMARY: pass=$PASS fail=$FAIL"
  exit 1
fi

# --- line count >= 40 ---

LC="$(wc -l < "$PRESET" | tr -d ' ')"
if [ "$LC" -ge 40 ]; then
  pass "preset has $LC lines (>= 40)"
else
  fail "preset has $LC lines (< 40)"
fi

# --- frontmatter ---

if grep -Eq '^schema_version:' "$PRESET"; then
  pass "frontmatter has schema_version:"
else
  fail "frontmatter missing schema_version:"
fi

if grep -Eq '^type: conversus-preset' "$PRESET"; then
  pass "frontmatter has type: conversus-preset"
else
  fail "frontmatter missing type: conversus-preset"
fi

# --- agent entries ---

for tok in 'source-advocate' 'target-advocate'; do
  if grep -Fq -- "$tok" "$PRESET"; then
    pass "agent entry present: $tok"
  else
    fail "agent entry missing: $tok"
  fi
done

# --- arbiter grounding ---

if grep -Fq -- '.orchestrator/memory/constitution.md' "$PRESET"; then
  pass "references constitution as arbiter grounding"
else
  fail "does not reference .orchestrator/memory/constitution.md"
fi

# --- output template reference ---

if grep -Fq -- 'templates/gate-result.md' "$PRESET"; then
  pass "references templates/gate-result.md as output template"
else
  fail "does not reference templates/gate-result.md"
fi

# --- summary ---

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
exit 1

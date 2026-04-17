#!/usr/bin/env bash
# scripts/verify/m011-p07-gate-result-template.sh
#
# Asserts templates/gate-result.md frontmatter + body shape.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/templates/gate-result.md"

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

if [ -f "$TEMPLATE" ]; then
  pass "template exists"
else
  fail "template missing at $TEMPLATE"
  echo "SUMMARY: pass=$PASS fail=$FAIL"
  exit 1
fi

# --- line count >= 25 ---

LC="$(wc -l < "$TEMPLATE" | tr -d ' ')"
if [ "$LC" -ge 25 ]; then
  pass "template has $LC lines (>= 25)"
else
  fail "template has $LC lines (< 25)"
fi

# --- frontmatter required fields ---

if grep -Eq '^schema_version:' "$TEMPLATE"; then
  pass "frontmatter has schema_version"
else
  fail "frontmatter missing schema_version"
fi

if grep -Eq '^type: gate-result' "$TEMPLATE"; then
  pass "frontmatter has type: gate-result"
else
  fail "frontmatter missing type: gate-result"
fi

for field in 'preset:' 'artifact:' 'verdict:' 'timestamp:' 'source_hash:'; do
  if grep -Eq "^${field}" "$TEMPLATE"; then
    pass "frontmatter has ${field} field"
  else
    fail "frontmatter missing ${field} field"
  fi
done

# --- body section headings ---

for heading in 'Verdict' 'Disputes' 'Rationale'; do
  if grep -Eq "^## ${heading}\$" "$TEMPLATE"; then
    pass "body has ## ${heading} heading"
  else
    fail "body missing ## ${heading} heading"
  fi
done

# --- placeholder per MEM013 ---

if grep -Fq -- '{{verdict}}' "$TEMPLATE"; then
  pass "body uses {{verdict}} placeholder"
else
  fail "body does not use {{verdict}} placeholder"
fi

# --- summary ---

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
exit 1

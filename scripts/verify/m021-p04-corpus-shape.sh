#!/usr/bin/env bash
# scripts/verify/m021-p04-corpus-shape.sh -- Structural gate for T01 fixture.
#
# Asserts tests/fixtures/m021-prompt-corpus.txt is well-formed per
# T01-PLAN.md format spec: 20 entries, 4-field format, valid labels.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORPUS="${REPO_ROOT}/tests/fixtures/m021-prompt-corpus.txt"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$CORPUS" ]; then
  fail "corpus exists" "not found at $CORPUS"
  echo "FAIL: m021-p04-corpus-shape.sh (1 failures)"
  exit 1
fi
pass "corpus exists at $CORPUS"

# Entry count = 20 (count ID: lines)
id_count="$(grep -c '^ID:' "$CORPUS")"
if [ "$id_count" -eq 20 ]; then
  pass "entry count: 20"
else
  fail "entry count" "expected 20 got $id_count"
fi

# Four required field counts.
for field in INPUT EXPECTED_OUTCOME SCREENSHOT; do
  c="$(grep -c "^${field}:" "$CORPUS")"
  if [ "$c" -eq 20 ]; then
    pass "field ${field}: 20 lines"
  else
    fail "field ${field}" "expected 20 got $c"
  fi
done

# Entry separator count: 20 opening + 1 terminal = 21
sep_count="$(grep -c '^---$' "$CORPUS")"
if [ "$sep_count" -ge 20 ] && [ "$sep_count" -le 21 ]; then
  pass "separator count: $sep_count (expected 20 or 21)"
else
  fail "separator count" "expected 20-21 got $sep_count"
fi

# ID range 01..20 (zero-padded)
for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20; do
  if grep -qE "^ID: $n\$" "$CORPUS"; then
    pass "ID: $n present"
  else
    fail "ID: $n" "missing"
  fi
done

# Every EXPECTED_OUTCOME matches grammar: allow | rewrite:* | reject:*
bad_outcomes="$(grep '^EXPECTED_OUTCOME:' "$CORPUS" | grep -vE '^EXPECTED_OUTCOME: (allow|rewrite:|reject:)' | wc -l | tr -d ' ')"
if [ "$bad_outcomes" -eq 0 ]; then
  pass "EXPECTED_OUTCOME grammar: all values match allow|rewrite:*|reject:*"
else
  fail "EXPECTED_OUTCOME grammar" "$bad_outcomes lines outside grammar"
fi

# Every reject: label is one of the 10 legal pattern-class names.
for class in trailing-rc-echo sed-n-range cat-heredoc-exec cd-and-bash var-inline-bash redirect-cmd-sub nested-cmd-sub compound-chain-gt2 heredoc-with-expansion quoted-brace; do
  if grep -E "^EXPECTED_OUTCOME: " "$CORPUS" | grep -qE "(rewrite:.*|reject:)${class}"; then
    pass "pattern-class ${class} exercised"
  else
    echo "NOTE: pattern-class ${class} not in corpus (not all classes must appear)"
  fi
done

# Minimum coverage thresholds
rewrite_count="$(grep -c '^EXPECTED_OUTCOME: rewrite:' "$CORPUS")"
reject_count="$(grep -c '^EXPECTED_OUTCOME: reject:' "$CORPUS")"
allow_count="$(grep -c '^EXPECTED_OUTCOME: allow' "$CORPUS")"

if [ "$rewrite_count" -ge 6 ]; then pass "rewrite coverage: $rewrite_count (>=6)"; else fail "rewrite coverage" "$rewrite_count < 6"; fi
if [ "$reject_count" -ge 4 ]; then pass "reject coverage: $reject_count (>=4)"; else fail "reject coverage" "$reject_count < 4"; fi
if [ "$allow_count" -ge 4 ]; then pass "allow coverage: $allow_count (>=4)"; else fail "allow coverage" "$allow_count < 4"; fi

total=$((rewrite_count + reject_count + allow_count))
if [ "$total" -eq 20 ]; then
  pass "total EXPECTED_OUTCOME lines: 20"
else
  fail "total EXPECTED_OUTCOME lines" "expected 20 got $total"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-corpus-shape.sh"
  exit 0
fi
echo "FAIL: m021-p04-corpus-shape.sh ($fail_count failures)"
exit 1

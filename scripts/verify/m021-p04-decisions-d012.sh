#!/usr/bin/env bash
# scripts/verify/m021-p04-decisions-d012.sh -- Asserts T04.a decision entry landed.
#
# Checks .orchestrator/DECISIONS.md contains D012 row with required substrings,
# and D001..D011 rows remain present.
#
# Exit 0 on all-pass; 1 otherwise. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEC="${REPO_ROOT}/.orchestrator/DECISIONS.md"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

if [ ! -f "$DEC" ]; then
  fail "DECISIONS.md exists" "not found at $DEC"
  echo "FAIL: m021-p04-decisions-d012.sh (1 failures)"
  exit 1
fi
pass "DECISIONS.md exists at $DEC"

# D001..D011 still present.
for d in D001 D002 D003 D004 D005 D006 D007 D008 D009 D010 D011; do
  if grep -qE "^\| $d \|" "$DEC"; then
    pass "$d row present"
  else
    fail "$d row" "missing"
  fi
done

# D012 present with required substrings.
if grep -qE "^\| D012 \|" "$DEC"; then
  pass "D012 row present"
  d012_line="$(grep -E "^\| D012 \|" "$DEC" | head -n 1)"
  for needle in 'sequencing' 'M019' 'M021' 'zero-prompt'; do
    if printf '%s' "$d012_line" | grep -qF "$needle"; then
      pass "D012 row contains [$needle]"
    else
      fail "D012 row contains [$needle]" "missing"
    fi
  done
else
  fail "D012 row" "missing"
fi

# Only one D012 row (no duplicates).
d012_count="$(grep -cE "^\| D012 \|" "$DEC")"
if [ "$d012_count" -eq 1 ]; then
  pass "D012 row count: 1"
else
  fail "D012 row count" "expected 1 got $d012_count"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p04-decisions-d012.sh"
  exit 0
fi
echo "FAIL: m021-p04-decisions-d012.sh ($fail_count failures)"
exit 1

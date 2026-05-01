#!/usr/bin/env bash
# tools/verify/m031-p02-tier-a-plus-input-shape.sh
#
# M031/P02/T01 verifier: asserts that
# tests/m031-acceptance/fixtures/tier-a-plus-input.txt exists, is
# non-empty, contains a 30-80 word feature-request body, and does NOT
# contain any of the structural markers that would push the input out
# of the Tier A+ band (^## heading, Given/When/Then triple, ^- FR-
# bullet) — so the fixture truly classifies as `tier_a_plus` rather than
# `fragment` or `paragraph`.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# No mapfile/readarray, no declare -A, no process substitution.
#
# Output: per-check PASS/FAIL lines + a single final stdout line
#   SUMMARY: m031-p02-tier-a-plus-input-shape.sh pass=N fail=M
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fixture="$PROJECT_ROOT/tests/m031-acceptance/fixtures/tier-a-plus-input.txt"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

# Check 1: fixture exists.
if [ -f "$fixture" ]; then
    check_pass "tier-a-plus-input.txt exists at $fixture"
else
    check_fail "tier-a-plus-input.txt missing at $fixture"
    echo "SUMMARY: m031-p02-tier-a-plus-input-shape.sh pass=$pass fail=$fail"
    exit 1
fi

# Check 2: fixture is non-empty.
if [ -s "$fixture" ]; then
    check_pass "tier-a-plus-input.txt is non-empty"
else
    check_fail "tier-a-plus-input.txt is empty"
fi

# Check 3: word count in [30, 80].
words=$(wc -w < "$fixture" | tr -d ' ')
if [ "$words" -ge 30 ] && [ "$words" -le 80 ]; then
    check_pass "tier-a-plus-input.txt word count $words is in [30, 80]"
else
    check_fail "tier-a-plus-input.txt word count $words is NOT in [30, 80]"
fi

# Check 4: no `^##` heading line.
if grep -qE '^##' "$fixture"; then
    check_fail "tier-a-plus-input.txt contains a ^## heading line (would classify as fragment)"
else
    check_pass "tier-a-plus-input.txt has no ^## heading line"
fi

# Check 5: no `^- FR-` bullet line.
if grep -qE '^-[[:space:]]+FR-' "$fixture"; then
    check_fail "tier-a-plus-input.txt contains a ^- FR- bullet line (would classify as fragment)"
else
    check_pass "tier-a-plus-input.txt has no ^- FR- bullet line"
fi

# Check 6: no Given/When/Then triple. Check each separately and only
# fail if all three are present (matches shape-detect.sh's gwt logic).
has_given=0
has_when=0
has_then=0
if grep -qiE '\bGiven\b' "$fixture"; then has_given=1; fi
if grep -qiE '\bWhen\b' "$fixture"; then has_when=1; fi
if grep -qiE '\bThen\b' "$fixture"; then has_then=1; fi
gwt_sum=$((has_given + has_when + has_then))
if [ "$gwt_sum" -lt 3 ]; then
    check_pass "tier-a-plus-input.txt has no full Given/When/Then triple ($gwt_sum/3 markers)"
else
    check_fail "tier-a-plus-input.txt contains full Given/When/Then triple (would classify as fragment)"
fi

echo "SUMMARY: m031-p02-tier-a-plus-input-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

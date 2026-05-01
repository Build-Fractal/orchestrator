#!/usr/bin/env bash
# tools/verify/m031-p02-classifier-extension-shape.sh
#
# M031/P02/T01 verifier: asserts that scripts/intake/shape-detect.sh and
# scripts/intake/paragraph-classify.sh have been extended with the
# `tier_a_plus` verdict (FR-6) additively to the M024 surface, and that
# the four pre-existing verdict tokens still appear in shape-detect.sh
# (no regression on the existing enum, AD-2 / CON-3).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# No mapfile/readarray, no declare -A, no process substitution.
#
# Output: per-check PASS/FAIL lines + a single final stdout line
#   SUMMARY: m031-p02-classifier-extension-shape.sh pass=N fail=M
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

shape_detect="$PROJECT_ROOT/scripts/intake/shape-detect.sh"
paragraph_classify="$PROJECT_ROOT/scripts/intake/paragraph-classify.sh"

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

# Check 1: shape-detect.sh exists.
if [ -f "$shape_detect" ]; then
    check_pass "shape-detect.sh exists at $shape_detect"
else
    check_fail "shape-detect.sh missing at $shape_detect"
    echo "SUMMARY: m031-p02-classifier-extension-shape.sh pass=$pass fail=$fail"
    exit 1
fi

# Check 2: paragraph-classify.sh exists.
if [ -f "$paragraph_classify" ]; then
    check_pass "paragraph-classify.sh exists at $paragraph_classify"
else
    check_fail "paragraph-classify.sh missing at $paragraph_classify"
fi

# Check 3: shape-detect.sh contains the literal substring `tier_a_plus`.
if grep -q 'tier_a_plus' "$shape_detect"; then
    check_pass "shape-detect.sh contains literal tier_a_plus"
else
    check_fail "shape-detect.sh missing literal tier_a_plus"
fi

# Check 4: shape-detect.sh contains the verdict surface
# `input_shape=tier_a_plus` literal.
if grep -q 'input_shape=tier_a_plus' "$shape_detect"; then
    check_pass "shape-detect.sh contains literal input_shape=tier_a_plus"
else
    check_fail "shape-detect.sh missing literal input_shape=tier_a_plus"
fi

# Check 5: paragraph-classify.sh contains the literal substring
# `tier_a_plus` (annotation only — see file body).
if [ -f "$paragraph_classify" ] && grep -q 'tier_a_plus' "$paragraph_classify"; then
    check_pass "paragraph-classify.sh contains literal tier_a_plus"
else
    check_fail "paragraph-classify.sh missing literal tier_a_plus"
fi

# Check 6-10: all five pre-existing M024 verdict tokens still appear in
# shape-detect.sh (no regression on the existing enum). The five tokens
# are: idea, paragraph, fragment, spec, empty.
for tok in idea paragraph fragment spec empty; do
    if grep -q "input_shape=$tok" "$shape_detect"; then
        check_pass "shape-detect.sh retains pre-existing verdict input_shape=$tok"
    else
        check_fail "shape-detect.sh dropped pre-existing verdict input_shape=$tok"
    fi
done

echo "SUMMARY: m031-p02-classifier-extension-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

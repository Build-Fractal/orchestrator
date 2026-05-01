#!/usr/bin/env bash
# tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
#
# M031/P02/T01 verifier: asserts that
# tests/m031-acceptance/test-tier-a-plus-classifier.sh exists, is
# executable, and contains the SC-5 / tier_a_plus / FIXTURE-PROVENANCE
# tokens required by the M031 P02 Truth #8 (SC-5 contract).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# No mapfile/readarray, no declare -A, no process substitution.
#
# Output: per-check PASS/FAIL lines + a single final stdout line
#   SUMMARY: m031-p02-test-tier-a-plus-classifier-shape.sh pass=N fail=M
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

sc5_test="$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-classifier.sh"

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

# Check 1: SC-5 test file exists.
if [ -f "$sc5_test" ]; then
    check_pass "test-tier-a-plus-classifier.sh exists at $sc5_test"
else
    check_fail "test-tier-a-plus-classifier.sh missing at $sc5_test"
    echo "SUMMARY: m031-p02-test-tier-a-plus-classifier-shape.sh pass=$pass fail=$fail"
    exit 1
fi

# Check 2: SC-5 test file is executable.
if [ -x "$sc5_test" ]; then
    check_pass "test-tier-a-plus-classifier.sh is executable"
else
    check_fail "test-tier-a-plus-classifier.sh is not executable"
fi

# Check 3-5: required literal tokens — SC-5, tier_a_plus,
# FIXTURE-PROVENANCE.
for tok in SC-5 tier_a_plus FIXTURE-PROVENANCE; do
    if grep -q "$tok" "$sc5_test"; then
        check_pass "test-tier-a-plus-classifier.sh contains literal $tok"
    else
        check_fail "test-tier-a-plus-classifier.sh missing literal $tok"
    fi
done

echo "SUMMARY: m031-p02-test-tier-a-plus-classifier-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

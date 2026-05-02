#!/usr/bin/env bash
# tools/verify/p00-ordering-verifier-shape.sh
#
# M031 P00 verifier: tests/m031-acceptance/verify-baseline-ordering.sh shape.
#
# Checks (per T03 plan):
#   1. file exists + executable
#   2. header declares AD-12
#   3. body implements both Option A and Option B (literal text)
#   4. invokable, exits 0 (Option B pass OR Option A protocol-note)
#   5. SC13-OPTION.md exists and records the selected option (A or B)
#
# Output:
#   PASS:/FAIL: lines per check; final SUMMARY: line.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

target="tests/m031-acceptance/verify-baseline-ordering.sh"
sc13_option="tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md"

pass=0
fail=0

check_pass() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
check_fail() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

# Check 1: exists + executable
if [ -f "$target" ] && [ -x "$target" ]; then
    check_pass "ordering verifier exists + executable at $target"
else
    check_fail "ordering verifier missing or not executable at $target"
fi

# Check 2: header names AD-12
if [ -f "$target" ] && grep -q 'AD-12' "$target"; then
    check_pass "header declares AD-12"
else
    check_fail "header missing AD-12 reference"
fi

# Check 3: both Option A and Option B literal text present
option_a_present=0
option_b_present=0
if [ -f "$target" ]; then
    if grep -q 'Option A' "$target"; then
        option_a_present=1
    fi
    if grep -q 'Option B' "$target"; then
        option_b_present=1
    fi
fi
if [ "$option_a_present" -eq 1 ] && [ "$option_b_present" -eq 1 ]; then
    check_pass "implements both Option A and Option B"
else
    check_fail "missing Option A and/or Option B literal text"
fi

# Check 4: invokable, exits 0
if [ -f "$target" ] && [ -x "$target" ]; then
    if bash "$target" >/dev/null 2>&1; then
        check_pass "ordering verifier invokable, exits 0"
    else
        check_fail "ordering verifier exited non-zero"
    fi
else
    check_fail "ordering verifier not invokable"
fi

# Check 5: SC13-OPTION.md exists and selects option A or B.
selected_option_present=0
if [ -f "$sc13_option" ]; then
    if grep -qE '^## Selected: Option [AB]' "$sc13_option"; then
        selected_option_present=1
    fi
fi
if [ "$selected_option_present" -eq 1 ]; then
    check_pass "SC13-OPTION.md exists and records selected option"
else
    check_fail "SC13-OPTION.md missing or does not declare 'Selected: Option <A|B>'"
fi

printf 'SUMMARY: p00-ordering-verifier-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi

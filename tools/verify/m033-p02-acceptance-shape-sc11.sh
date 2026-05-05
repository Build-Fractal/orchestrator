#!/usr/bin/env bash
# m033-p02-acceptance-shape-sc11.sh
#
# Verifier for M033/P02/T04: asserts the SC-11 acceptance script
# (tests/m033-acceptance/p07-grilling-shell.sh) exists, is executable, and
# carries the documented load-bearing tokens covering FR-17 / FR-18 / MIT-007.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p02-acceptance-shape-sc11.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

acceptance="$PROJECT_ROOT/tests/m033-acceptance/p07-grilling-shell.sh"

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

# Check 1: acceptance script exists.
if [ ! -f "$acceptance" ]; then
    echo "FAIL: tests/m033-acceptance/p07-grilling-shell.sh missing at $acceptance"
    echo "SUMMARY: m033-p02-acceptance-shape-sc11.sh pass=0 fail=1"
    exit 1
fi
check_pass "tests/m033-acceptance/p07-grilling-shell.sh exists"

# Check 2: executable bit set.
if [ -x "$acceptance" ]; then
    check_pass "acceptance script is executable"
else
    check_fail "acceptance script is NOT executable"
fi

# Check 3: SC-11 token present.
if grep -qF 'SC-11' "$acceptance"; then
    check_pass "acceptance carries SC-11 reference"
else
    check_fail "acceptance missing SC-11 reference"
fi

# Check 4: FR-17 token present.
if grep -qF 'FR-17' "$acceptance"; then
    check_pass "acceptance carries FR-17 reference"
else
    check_fail "acceptance missing FR-17 reference"
fi

# Check 5: FR-18 token present.
if grep -qF 'FR-18' "$acceptance"; then
    check_pass "acceptance carries FR-18 reference"
else
    check_fail "acceptance missing FR-18 reference"
fi

# Check 6: MIT-007 token present.
if grep -qF 'MIT-007' "$acceptance"; then
    check_pass "acceptance carries MIT-007 reference"
else
    check_fail "acceptance missing MIT-007 reference"
fi

# Check 7: cross-reference to grilling-shell.sh.
if grep -qF 'grilling-shell.sh' "$acceptance"; then
    check_pass "acceptance references scripts/lifecycle/grilling-shell.sh"
else
    check_fail "acceptance missing grilling-shell.sh cross-reference"
fi

# Check 8: load-bearing token recommendation: present.
if grep -qF 'recommendation:' "$acceptance"; then
    check_pass "acceptance asserts load-bearing token recommendation:"
else
    check_fail "acceptance missing recommendation: token"
fi

# Check 9: load-bearing token answer: present.
if grep -qF 'answer:' "$acceptance"; then
    check_pass "acceptance asserts load-bearing token answer:"
else
    check_fail "acceptance missing answer: token"
fi

# Check 10: load-bearing token contradiction: present.
if grep -qF 'contradiction:' "$acceptance"; then
    check_pass "acceptance asserts load-bearing token contradiction:"
else
    check_fail "acceptance missing contradiction: token"
fi

# Check 11: glossary.md cross-reference.
if grep -qF 'glossary.md' "$acceptance"; then
    check_pass "acceptance references glossary.md"
else
    check_fail "acceptance missing glossary.md reference"
fi

# Check 12: SUMMARY: line emitted.
if grep -qF 'SUMMARY:' "$acceptance"; then
    check_pass "acceptance emits SUMMARY: line"
else
    check_fail "acceptance missing SUMMARY: emission"
fi

echo ""
echo "SUMMARY: m033-p02-acceptance-shape-sc11.sh pass=$pass fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

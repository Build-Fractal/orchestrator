#!/usr/bin/env bash
# m033-p02-acceptance-shape-sc12.sh
#
# T02 verifier: shape of the SC-12 acceptance script
# tests/m033-acceptance/p07-resume-on-partial-state.sh.
#
# Asserts:
#   - The acceptance script exists and is executable.
#   - The literal 'SC-12' and 'FR-20' tokens appear (spec ref discipline).
#   - Cross-reference to start-state-markers.sh appears.
#   - The load-bearing tokens 'resuming from' and '--no-resume' appear.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m033-acceptance/p07-resume-on-partial-state.sh"

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

if [ ! -f "$target" ]; then
    echo "FAIL: SC-12 acceptance script missing at $target"
    echo "SUMMARY: m033-p02-acceptance-shape-sc12.sh pass=0 fail=1"
    exit 1
fi
check_pass "p07-resume-on-partial-state.sh exists at $target"

if [ ! -x "$target" ]; then
    check_fail "p07-resume-on-partial-state.sh not executable: $target"
else
    check_pass "p07-resume-on-partial-state.sh is executable"
fi

# Token: SC-12.
if grep -F -q 'SC-12' "$target"; then
    check_pass "'SC-12' spec-reference token present"
else
    check_fail "'SC-12' spec-reference token missing"
fi

# Token: FR-20.
if grep -F -q 'FR-20' "$target"; then
    check_pass "'FR-20' spec-reference token present"
else
    check_fail "'FR-20' spec-reference token missing"
fi

# Cross-reference: start-state-markers.sh.
if grep -F -q 'start-state-markers.sh' "$target"; then
    check_pass "cross-reference to start-state-markers.sh present"
else
    check_fail "cross-reference to start-state-markers.sh missing"
fi

# Token: 'resuming from'.
if grep -F -q 'resuming from' "$target"; then
    check_pass "'resuming from' diagnostic token present"
else
    check_fail "'resuming from' diagnostic token missing"
fi

# Token: --no-resume.
if grep -F -q -- '--no-resume' "$target"; then
    check_pass "'--no-resume' escape-valve token present"
else
    check_fail "'--no-resume' escape-valve token missing"
fi

# Token: start-state:.
if grep -F -q 'start-state:' "$target"; then
    check_pass "'start-state:' load-bearing token present"
else
    check_fail "'start-state:' load-bearing token missing"
fi

echo "SUMMARY: m033-p02-acceptance-shape-sc12.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

#!/usr/bin/env bash
# m033-p03-cross-phase-regression.sh
#
# AD-15 cross-phase regression verifier for M033/P03. Asserts:
#   - tools/verify/m033-p01-phase-suite.sh exits 0 (P01 surface preserved).
#   - tools/verify/m033-p02-phase-suite.sh exits 0 (P02 surface preserved).
#
# Mirrors the AD-15 cross-phase regression precedent established by
# P02/T02 + P02/T05.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p03-cross-phase-regression.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

P01_SUITE="$PROJECT_ROOT/tools/verify/m033-p01-phase-suite.sh"
P02_SUITE="$PROJECT_ROOT/tools/verify/m033-p02-phase-suite.sh"

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

# Run P01 phase-suite.
if [ -f "$P01_SUITE" ]; then
    p01_out=$(mktemp)
    rc=0
    bash "$P01_SUITE" > "$p01_out" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        check_pass "m033-p01-phase-suite.sh exits 0 (P01 surface preserved)"
    else
        check_fail "m033-p01-phase-suite.sh exits $rc (P01 regression)"
        echo "    --- P01 phase-suite tail ---"
        tail -20 "$p01_out" | sed 's/^/    /'
    fi
    rm -f "$p01_out"
else
    check_fail "P01 phase-suite missing: $P01_SUITE"
fi

# Run P02 phase-suite.
if [ -f "$P02_SUITE" ]; then
    p02_out=$(mktemp)
    rc=0
    bash "$P02_SUITE" > "$p02_out" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        check_pass "m033-p02-phase-suite.sh exits 0 (P02 surface preserved)"
    else
        check_fail "m033-p02-phase-suite.sh exits $rc (P02 regression — AD-15)"
        echo "    --- P02 phase-suite tail ---"
        tail -20 "$p02_out" | sed 's/^/    /'
    fi
    rm -f "$p02_out"
else
    check_fail "P02 phase-suite missing: $P02_SUITE"
fi

echo "SUMMARY: m033-p03-cross-phase-regression.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

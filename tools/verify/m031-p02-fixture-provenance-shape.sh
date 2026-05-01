#!/usr/bin/env bash
# tools/verify/m031-p02-fixture-provenance-shape.sh
#
# M031/P02/T01 verifier: asserts that
# tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md exists, is
# non-empty, contains the AD-16 grounding tokens, and cites at least one
# <milestone>/<phase>/<task> historical unit_close record per the
# normative requirement.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# No mapfile/readarray, no declare -A, no process substitution.
#
# Output: per-check PASS/FAIL lines + a single final stdout line
#   SUMMARY: m031-p02-fixture-provenance-shape.sh pass=N fail=M
# Exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

provenance="$PROJECT_ROOT/tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md"

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

# Check 1: FIXTURE-PROVENANCE.md exists.
if [ -f "$provenance" ]; then
    check_pass "FIXTURE-PROVENANCE.md exists at $provenance"
else
    check_fail "FIXTURE-PROVENANCE.md missing at $provenance"
    echo "SUMMARY: m031-p02-fixture-provenance-shape.sh pass=$pass fail=$fail"
    exit 1
fi

# Check 2: file is non-empty (>= 25 lines).
line_count=$(wc -l < "$provenance" | tr -d ' ')
if [ "$line_count" -ge 25 ]; then
    check_pass "FIXTURE-PROVENANCE.md has $line_count lines (>= 25)"
else
    check_fail "FIXTURE-PROVENANCE.md only $line_count lines (< 25 required)"
fi

# Check 3-6: required literal tokens — tier_a_plus, unit_close, rationale,
# AD-16. These four tokens are the AD-16 grounding contract surface.
for tok in tier_a_plus unit_close rationale AD-16; do
    if grep -q "$tok" "$provenance"; then
        check_pass "FIXTURE-PROVENANCE.md contains literal $tok"
    else
        check_fail "FIXTURE-PROVENANCE.md missing literal $tok"
    fi
done

# Check 7: at least one <milestone>/<phase>/<task> provenance pattern.
if grep -qE 'M[0-9][0-9][0-9]/P[0-9][0-9]/T[0-9][0-9]' "$provenance"; then
    check_pass "FIXTURE-PROVENANCE.md contains at least one M###/P##/T## provenance"
else
    check_fail "FIXTURE-PROVENANCE.md missing M###/P##/T## provenance pattern"
fi

echo "SUMMARY: m031-p02-fixture-provenance-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

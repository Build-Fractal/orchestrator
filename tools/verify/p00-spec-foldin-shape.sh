#!/usr/bin/env bash
# p00-spec-foldin-shape.sh
#
# Verifier for M031/P00/T01 spec-foldin: asserts that the
# AD-1..AD-20 fold-in landed in specs/034-right-sized-entry/spec.md
# per the T01 plan and the M031-CONTEXT.md authoritative source.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A,
# no process substitution, no &>, no ${var^^}.
#
# Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/p00-spec-foldin-shape.sh
#   bash tools/verify/p00-spec-foldin-shape.sh path/to/spec.md
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

file="${1:-specs/034-right-sized-entry/spec.md}"

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

# ---------------------------------------------------------------------------
# Check 1: spec file exists
# ---------------------------------------------------------------------------
if [ ! -f "$file" ]; then
    echo "FAIL: spec.md missing at $file"
    echo "SUMMARY: p00-spec-foldin-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "spec.md exists at $file"

# ---------------------------------------------------------------------------
# Check 2: AD section header present
# ---------------------------------------------------------------------------
if grep -q '^## Architectural Decisions (folded post-discuss 2026-05-01)$' "$file"; then
    check_pass "AD section header present"
else
    check_fail "AD section header missing: '## Architectural Decisions (folded post-discuss 2026-05-01)'"
fi

# ---------------------------------------------------------------------------
# Check 3: AD-1 through AD-20 sub-headers all present (### AD-N. prefix)
# ---------------------------------------------------------------------------
ad_missing=""
ad_found=0
i=1
while [ $i -le 20 ]; do
    if grep -q "^### AD-$i\\." "$file"; then
        ad_found=$((ad_found + 1))
    else
        ad_missing="$ad_missing AD-$i"
    fi
    i=$((i + 1))
done
if [ "$ad_found" -eq 20 ]; then
    check_pass "all 20 AD sub-headers present (### AD-1. through ### AD-20.)"
else
    check_fail "AD sub-headers missing: $ad_missing (found $ad_found / 20)"
fi

# ---------------------------------------------------------------------------
# Check 4: SC-15 list-item present
# ---------------------------------------------------------------------------
if grep -q '^- \*\*SC-15' "$file"; then
    check_pass "SC-15 list-item present"
else
    check_fail "SC-15 list-item missing (expected '- **SC-15' prefix)"
fi

# ---------------------------------------------------------------------------
# Check 5: SC-16 list-item present
# ---------------------------------------------------------------------------
if grep -q '^- \*\*SC-16' "$file"; then
    check_pass "SC-16 list-item present"
else
    check_fail "SC-16 list-item missing (expected '- **SC-16' prefix)"
fi

# ---------------------------------------------------------------------------
# Check 6: SC-14 declares N >= 15 (or N >= 14 under Option A)
# ---------------------------------------------------------------------------
if grep -qE 'N ≥ 1[45]' "$file"; then
    check_pass "SC-14 declares N >= 15 (or N >= 14 under Option A)"
else
    check_fail "SC-14 must declare 'N ≥ 15' (or 'N ≥ 14' under Option A)"
fi

# ---------------------------------------------------------------------------
# Check 7: AD-13 / SC-2 amendment landed — INVERTED POLARITY
#
# This check is intentionally inverted. The pre-amendment SC-2 contained
# the literal '±20%' substring as a contradictory tolerance-band clause.
# AD-13 explicitly drops it. We assert the literal is GONE from the entire
# spec body — including audit-trail sections — by redacting the literal in
# the gate-findings preservation. A future maintainer reading this should
# NOT 'fix' the inversion as a typo: the polarity is correct.
# ---------------------------------------------------------------------------
if grep -q '±20%' "$file"; then
    check_fail "AD-13 amendment incomplete: literal '±20%' still appears in spec.md (must be dropped per AD-13)"
else
    check_pass "AD-13 amendment landed: literal '±20%' is gone from spec.md"
fi

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo "SUMMARY: p00-spec-foldin-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

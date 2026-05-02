#!/usr/bin/env bash
# p00-runtime-assumptions-foldin.sh
#
# Verifier for M031/P00/T02 RUNTIME-ASSUMPTIONS fold-in: asserts the
# AD-17 "M018 Tier-1 inline_threshold_tokens" section landed in
# references/RUNTIME-ASSUMPTIONS.md with the threshold value, source
# citation, and SC/AD references.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/p00-runtime-assumptions-foldin.sh
#   bash tools/verify/p00-runtime-assumptions-foldin.sh path/to/RUNTIME-ASSUMPTIONS.md
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

file="${1:-references/RUNTIME-ASSUMPTIONS.md}"

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

# Check 1: file exists
if [ ! -f "$file" ]; then
    echo "FAIL: RUNTIME-ASSUMPTIONS.md missing at $file"
    echo "SUMMARY: p00-runtime-assumptions-foldin.sh pass=0 fail=1"
    exit 1
fi
check_pass "RUNTIME-ASSUMPTIONS.md exists at $file"

# Check 2: contains the M018 Tier-1 section header
if grep -q '^## M018 Tier-1 inline_threshold_tokens' "$file"; then
    check_pass "M018 Tier-1 inline_threshold_tokens section header present"
else
    check_fail "missing '## M018 Tier-1 inline_threshold_tokens' section header"
fi

# Check 3: contains the threshold value 1500
if grep -q '1500' "$file"; then
    check_pass "threshold value 1500 cited"
else
    check_fail "threshold value 1500 not cited"
fi

# Check 4: cites templates/orchestrator-config-default.yml as the source
if grep -q 'templates/orchestrator-config-default.yml' "$file"; then
    check_pass "templates/orchestrator-config-default.yml cited as source"
else
    check_fail "templates/orchestrator-config-default.yml not cited as source"
fi

# Check 5: cites SC-3 and AD-17
ref_missing=""
if ! grep -q 'SC-3' "$file"; then ref_missing="$ref_missing [SC-3]"; fi
if ! grep -q 'AD-17' "$file"; then ref_missing="$ref_missing [AD-17]"; fi
if [ -z "$ref_missing" ]; then
    check_pass "SC-3 and AD-17 both referenced"
else
    check_fail "SC/AD references missing:$ref_missing"
fi

# Final summary
echo "SUMMARY: p00-runtime-assumptions-foldin.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

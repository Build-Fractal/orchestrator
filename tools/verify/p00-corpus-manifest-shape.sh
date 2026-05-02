#!/usr/bin/env bash
# p00-corpus-manifest-shape.sh
#
# Verifier for M031/P00/T02 corpus manifest: asserts the AD-15
# stratified 20-task corpus manifest exists with required frontmatter
# fields, body stratification declarations, and ≥20 entry rows.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/p00-corpus-manifest-shape.sh
#   bash tools/verify/p00-corpus-manifest-shape.sh path/to/CORPUS-MANIFEST.md
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

file="${1:-tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md}"

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

# Check 1: file exists + frontmatter contains required keys
if [ ! -f "$file" ]; then
    echo "FAIL: CORPUS-MANIFEST.md missing at $file"
    echo "SUMMARY: p00-corpus-manifest-shape.sh pass=0 fail=1"
    exit 1
fi
fm_missing=""
fm_keys="schema_version: \"1.0\"|type: empirical-baseline-corpus|milestone: \"M031\"|phase: \"P00\"|created_at|stratification_constraint: \"AD-15\""
# Iterate keys via simple positional parsing on the | separator.
old_ifs="$IFS"
IFS='|'
for key in $fm_keys; do
    if ! grep -qE "^${key}" "$file"; then
        fm_missing="$fm_missing [${key}]"
    fi
done
IFS="$old_ifs"
if [ -z "$fm_missing" ]; then
    check_pass "frontmatter declares all required M031/P00/AD-15 keys"
else
    check_fail "frontmatter missing keys:$fm_missing"
fi

# Check 2: body declares the AD-15 stratification (5 historical / 5 synthetic / 10 spread)
strat_missing=""
if ! grep -q '5 historical' "$file"; then strat_missing="$strat_missing [5 historical]"; fi
if ! grep -q '5 synthetic' "$file"; then strat_missing="$strat_missing [5 synthetic]"; fi
if ! grep -q '10 spread' "$file"; then strat_missing="$strat_missing [10 spread]"; fi
if [ -z "$strat_missing" ]; then
    check_pass "body declares AD-15 stratification (5 historical / 5 synthetic / 10 spread)"
else
    check_fail "stratification declaration missing:$strat_missing"
fi

# Check 3: count of pipe-separated entry rows is ≥20
row_count=$(grep -c '^| task-' "$file")
if [ "$row_count" -ge 20 ]; then
    check_pass "entry table has ≥20 rows (count=$row_count)"
else
    check_fail "entry table has only $row_count rows (need ≥20)"
fi

# Check 4: each historical row carries a real <milestone>/<phase>/<task> triple
# (i.e. matches Mddd/Pdd/Tdd shape inside its provenance cell).
hist_rows=$(grep -E '^\| task-(0[1-5])\s' "$file")
hist_bad=""
old_ifs="$IFS"
IFS='
'
for line in $hist_rows; do
    # Provenance cell is the 4th pipe-delimited cell (index 4 after leading pipe).
    if ! echo "$line" | grep -qE 'M[0-9]{3}/P[0-9]{2}/T[0-9]{2}'; then
        first=$(echo "$line" | awk -F '|' '{print $2}')
        hist_bad="$hist_bad [$first]"
    fi
done
IFS="$old_ifs"
if [ -z "$hist_bad" ]; then
    check_pass "historical rows (task-01..task-05) carry real <milestone>/<phase>/<task> provenance triples"
else
    check_fail "historical rows missing provenance triple:$hist_bad"
fi

# Final summary
echo "SUMMARY: p00-corpus-manifest-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

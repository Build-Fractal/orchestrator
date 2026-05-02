#!/usr/bin/env bash
# p00-corpus-population.sh
#
# Verifier for M031/P00/T02 corpus population: asserts the AD-15
# 20-task fixture-input directory contains exactly 20 task-NN.txt
# files (no more, no fewer).
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no
# process substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/p00-corpus-population.sh
#   bash tools/verify/p00-corpus-population.sh path/to/empirical-baseline-dir
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

dir="${1:-tests/m031-acceptance/fixtures/empirical-baseline}"

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

# Check 1: directory exists
if [ ! -d "$dir" ]; then
    echo "FAIL: corpus directory missing at $dir"
    echo "SUMMARY: p00-corpus-population.sh pass=0 fail=1"
    exit 1
fi
check_pass "corpus directory exists at $dir"

# Check 2: count of task-*.txt files is exactly 20
# Avoid $(...) containing pipe — use a tmp file per AP-009.
tmp_list=$(mktemp -t p00-corpus-population.XXXXXX)
find "$dir" -maxdepth 1 -name 'task-*.txt' -type f > "$tmp_list"
file_count=$(wc -l < "$tmp_list")
# wc -l may pad with leading spaces on macOS; trim.
file_count=$(echo "$file_count" | tr -d ' ')
rm -f "$tmp_list"
if [ "$file_count" -eq 20 ]; then
    check_pass "exactly 20 task-*.txt fixture files (count=$file_count)"
else
    check_fail "expected exactly 20 task-*.txt files, found $file_count"
fi

# Final summary
echo "SUMMARY: p00-corpus-population.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

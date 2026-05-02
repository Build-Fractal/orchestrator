#!/usr/bin/env bash
# tools/verify/p00-pre-baseline-jsonl-population.sh
#
# M031 P00 verifier: tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl
# population shape.
#
# Checks (per T03 plan):
#   1. file exists
#   2. line count is exactly 20
#   3. every line contains "path":"pre-m031" (stub provenance — no live
#      dispatch records leaked into the frozen baseline)
#   4. every line contains "knowledge_section_tokens":0 (pre-M031 by
#      definition injects zero knowledge)
#
# Output:
#   PASS:/FAIL: lines per check; final SUMMARY: line.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No process
# substitution; uses while-read against the file directly.

set -u

target="tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl"

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

# Check 1: file exists
if [ -f "$target" ]; then
    check_pass "pre-m031-baseline.jsonl exists at $target"
else
    check_fail "pre-m031-baseline.jsonl missing at $target"
    printf 'SUMMARY: p00-pre-baseline-jsonl-population.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# Check 2: exactly 20 lines (wc -l with stdin redirect — no $() with pipe).
line_count=$(wc -l < "$target")
# Strip whitespace.
line_count=$(printf '%s' "$line_count" | tr -d ' ')
if [ "$line_count" -eq 20 ]; then
    check_pass "exactly 20 JSONL records"
else
    check_fail "expected 20 records, got $line_count"
fi

# Check 3: every line contains "path":"pre-m031".
path_violations=0
while IFS= read -r line; do
    if ! printf '%s' "$line" | grep -q '"path":"pre-m031"'; then
        path_violations=$(( path_violations + 1 ))
    fi
done < "$target"
if [ "$path_violations" -eq 0 ]; then
    check_pass "every record carries \"path\":\"pre-m031\""
else
    check_fail "$path_violations record(s) missing \"path\":\"pre-m031\""
fi

# Check 4: every line contains "knowledge_section_tokens":0.
knowledge_violations=0
while IFS= read -r line; do
    if ! printf '%s' "$line" | grep -q '"knowledge_section_tokens":0'; then
        knowledge_violations=$(( knowledge_violations + 1 ))
    fi
done < "$target"
if [ "$knowledge_violations" -eq 0 ]; then
    check_pass "every record carries \"knowledge_section_tokens\":0"
else
    check_fail "$knowledge_violations record(s) missing \"knowledge_section_tokens\":0"
fi

printf 'SUMMARY: p00-pre-baseline-jsonl-population.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi

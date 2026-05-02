#!/usr/bin/env bash
# tools/verify/p00-baseline-harness-shape.sh
#
# M031 P00 verifier: tests/m031-acceptance/empirical-baseline.sh shape.
#
# Checks (per T03 plan):
#   1. file exists + executable
#   2. header declares FR-18 ownership
#   3. header declares AD-14 single-window discipline
#   4. body supports the --post-m031-emitter CLI flag
#   5. body supports the --compare mode and emits COMPARE: line shape
#   6. invokable in capture mode against the corpus, emits BASELINE: line
#
# Output:
#   PASS:/FAIL: lines per check; final SUMMARY: line.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

target="tests/m031-acceptance/empirical-baseline.sh"

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
    check_pass "harness exists + executable at $target"
else
    check_fail "harness missing or not executable at $target"
fi

# Check 2: header names FR-18
if [ -f "$target" ] && grep -q 'FR-18' "$target"; then
    check_pass "header declares FR-18 ownership"
else
    check_fail "header missing FR-18 reference"
fi

# Check 3: header names AD-14
if [ -f "$target" ] && grep -q 'AD-14' "$target"; then
    check_pass "header declares AD-14 single-window discipline"
else
    check_fail "header missing AD-14 reference"
fi

# Check 4: --post-m031-emitter literal present
if [ -f "$target" ] && grep -q -- '--post-m031-emitter' "$target"; then
    check_pass "supports --post-m031-emitter CLI flag"
else
    check_fail "missing --post-m031-emitter CLI flag"
fi

# Check 5: --compare and COMPARE: shape both present
compare_flag_present=0
compare_line_present=0
if [ -f "$target" ]; then
    if grep -q -- '--compare' "$target"; then
        compare_flag_present=1
    fi
    if grep -q 'COMPARE:' "$target"; then
        compare_line_present=1
    fi
fi
if [ "$compare_flag_present" -eq 1 ] && [ "$compare_line_present" -eq 1 ]; then
    check_pass "supports --compare mode + COMPARE: line shape"
else
    check_fail "missing --compare mode and/or COMPARE: line shape"
fi

# Check 6: invokable in capture mode, emits BASELINE: line.
# We re-run the harness — it is idempotent (truncates --out-pre and
# the stub is deterministic). We capture stdout to a temp file and
# scan for the BASELINE: line.
tmp_out="/tmp/p00-baseline-harness-shape.$$.out"
if [ -f "$target" ] && [ -x "$target" ]; then
    if bash "$target" > "$tmp_out" 2>/dev/null; then
        if grep -q '^BASELINE:' "$tmp_out"; then
            check_pass "harness invokable in capture mode + emits BASELINE: line"
        else
            check_fail "harness ran but emitted no BASELINE: line"
        fi
    else
        check_fail "harness invocation exited non-zero"
    fi
    rm -f "$tmp_out"
else
    check_fail "harness not invokable (missing or not executable)"
fi

printf 'SUMMARY: p00-baseline-harness-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
    exit 0
else
    exit 1
fi

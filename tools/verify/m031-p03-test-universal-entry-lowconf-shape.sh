#!/usr/bin/env bash
# tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
#
# M031/P03/T02 shape verifier for the SC-8 acceptance test at
# tests/m031-acceptance/test-universal-entry-lowconf.sh.
#
# Asserts:
#   1) the test exists, is executable, and is >= 60 lines.
#   2) the test contains the required literal substrings:
#        SC-8, Tier A, Tier B, chosen_shape, do-entry.sh, --no-prompt-mode.
#   3) the test does NOT invoke the orchestration command names
#        orchestrator:auto, orchestrator:roadmap, orchestrator:consolidate
#      (CON-4 invariant -- the universal-entry surface MUST NOT trigger
#      auto-loop / roadmap / consolidate flows).
#   4) the test does NOT embed the CON-7 scaffold-placeholder
#      bracket-TODO byte pattern (D020 token hygiene).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-lowconf.sh"

pass=0
fail=0

ok() {
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$1"
}
ng() {
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$1"
}

if [ -f "$target" ]; then
    ok "test-universal-entry-lowconf.sh exists at $target"
else
    ng "test-universal-entry-lowconf.sh missing at $target"
    printf 'SUMMARY: m031-p03-test-universal-entry-lowconf-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

if [ -x "$target" ]; then
    ok "test-universal-entry-lowconf.sh is executable"
else
    ng "test-universal-entry-lowconf.sh is not executable"
fi

target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 60 ]; then
    ok "test-universal-entry-lowconf.sh has $target_lines lines (>= 60)"
else
    ng "test-universal-entry-lowconf.sh has $target_lines lines (< 60 floor)"
fi

for lit in 'SC-8' 'Tier A' 'Tier B' 'chosen_shape' 'do-entry.sh' '--no-prompt-mode'; do
    if grep -F -q -e "$lit" "$target"; then
        ok "SC-8 test contains required literal: $lit"
    else
        ng "SC-8 test missing required literal: $lit"
    fi
done

for forbidden in 'orchestrator:auto' 'orchestrator:roadmap' 'orchestrator:consolidate'; do
    if grep -F -q -e "$forbidden" "$target"; then
        ng "SC-8 test invokes forbidden command: $forbidden (CON-4 violation)"
    else
        ok "SC-8 test clean of forbidden command: $forbidden"
    fi
done

verifier_scaffold=$(printf '\133TODO: ')
if grep -F -q -e "$verifier_scaffold" "$target"; then
    ng "SC-8 test contains forbidden CON-7 scaffold-placeholder byte pattern"
else
    ok "SC-8 test clean of CON-7 scaffold-placeholder byte pattern"
fi

printf 'SUMMARY: m031-p03-test-universal-entry-lowconf-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

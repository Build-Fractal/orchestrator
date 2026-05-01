#!/usr/bin/env bash
# tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
#
# M031/P02/T04 shape verifier for the SC-6 acceptance test at
# tests/m031-acceptance/test-tier-a-plus-flow.sh.
#
# Asserts:
#   1) the test exists, is executable, and is >= 60 lines.
#   2) the test contains the required literal substrings:
#        - SC-6
#        - tier_a_plus_role
#        - research
#        - plan
#        - build
#        - aborted
#        - --yes
#   3) the test does NOT embed the CON-7 scaffold-placeholder
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

target="$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-flow.sh"

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
    ok "test-tier-a-plus-flow.sh exists at $target"
else
    ng "test-tier-a-plus-flow.sh missing at $target"
    printf 'SUMMARY: m031-p02-test-tier-a-plus-flow-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

if [ -x "$target" ]; then
    ok "test-tier-a-plus-flow.sh is executable"
else
    ng "test-tier-a-plus-flow.sh is not executable"
fi

target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 60 ]; then
    ok "test-tier-a-plus-flow.sh has $target_lines lines (>= 60)"
else
    ng "test-tier-a-plus-flow.sh has $target_lines lines (< 60 floor)"
fi

for lit in 'SC-6' 'tier_a_plus_role' 'research' 'plan' 'build' 'aborted' '--yes'; do
    if grep -F -q -e "$lit" "$target"; then
        ok "SC-6 test contains required literal: $lit"
    else
        ng "SC-6 test missing required literal: $lit"
    fi
done

verifier_scaffold=$(printf '\133TODO: ')
if grep -F -q "$verifier_scaffold" "$target"; then
    ng "SC-6 test contains forbidden CON-7 scaffold-placeholder byte pattern"
else
    ok "SC-6 test clean of CON-7 scaffold-placeholder byte pattern"
fi

printf 'SUMMARY: m031-p02-test-tier-a-plus-flow-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

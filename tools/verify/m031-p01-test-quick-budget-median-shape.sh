#!/usr/bin/env bash
# tools/verify/m031-p01-test-quick-budget-median-shape.sh
#
# M031/P01/T03 shape verifier for
# tests/m031-acceptance/test-quick-budget-median.sh.
#
# Asserts:
#   1) the SC-15 acceptance script exists and is executable,
#   2) the script body carries the literal substrings "SC-15",
#      "AD-18", "median", "quick_knowledge_token_budget" (file-header
#      schema commitment per the task plan must-haves),
#   3) the script exits 0 on invocation.
#
# Single-script Truth Check shape per AD-19. Bash 3.2 compatible.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/test-quick-budget-median.sh"

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
    ok "SC-15 script exists at $target"
else
    ng "SC-15 script missing at $target"
    printf 'SUMMARY: m031-p01-test-quick-budget-median-shape.sh pass=%d fail=%d\n' \
        "$pass" "$fail"
    exit 1
fi
if [ -x "$target" ]; then
    ok "SC-15 script is executable"
else
    ng "SC-15 script is not executable"
fi

for lit in "SC-15" "AD-18" "median" "quick_knowledge_token_budget"; do
    if grep -q "$lit" "$target"; then
        ok "SC-15 script contains literal $lit"
    else
        ng "SC-15 script missing literal $lit"
    fi
done

bash "$target" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    ok "SC-15 script exits 0"
else
    ng "SC-15 script exited rc=$rc"
fi

printf 'SUMMARY: m031-p01-test-quick-budget-median-shape.sh pass=%d fail=%d\n' \
    "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0

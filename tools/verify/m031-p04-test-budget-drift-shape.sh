#!/usr/bin/env bash
# tools/verify/m031-p04-test-budget-drift-shape.sh
#
# M031/P04/T03 shape verifier (project-owned, slug-bearing under
# tools/verify/) for the AD-19 acceptance test
# tests/m031-acceptance/test-budget-drift-warning.sh.
#
# Asserts:
#   1) test-budget-drift-warning.sh exists and is executable.
#   2) Required literal substrings present:
#        - AD-19
#        - QUICK_BUDGET_DRIFT
#        - efficiency-footer.sh
#        - ORCH_EFFICIENCY_FOOTER_INPUT
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# Output: per-check PASS/FAIL lines + final SUMMARY: line; exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/test-budget-drift-warning.sh"

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

# 1) Existence.
if [ -f "$target" ]; then
    ok "test-budget-drift-warning.sh exists at $target"
else
    ng "test-budget-drift-warning.sh missing at $target"
    printf 'SUMMARY: m031-p04-test-budget-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Executable bit.
if [ -x "$target" ]; then
    ok "test-budget-drift-warning.sh is executable"
else
    ng "test-budget-drift-warning.sh is not executable"
fi

# 3) Required literal substrings.
check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "AD-19" "AD-19"
check_literal "QUICK_BUDGET_DRIFT" "QUICK_BUDGET_DRIFT"
check_literal "efficiency-footer.sh" "efficiency-footer.sh"
check_literal "ORCH_EFFICIENCY_FOOTER_INPUT" "ORCH_EFFICIENCY_FOOTER_INPUT"

printf 'SUMMARY: m031-p04-test-budget-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1

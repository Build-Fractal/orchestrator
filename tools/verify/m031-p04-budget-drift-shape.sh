#!/usr/bin/env bash
# tools/verify/m031-p04-budget-drift-shape.sh
#
# M031/P04/T03 shape verifier (project-owned, slug-bearing under
# tools/verify/) for the AD-19 QUICK_BUDGET_DRIFT amendment in
# scripts/diagnostics/efficiency-footer.sh.
#
# Asserts:
#   1) scripts/diagnostics/efficiency-footer.sh exists.
#   2) Required literal substrings present:
#        - QUICK_BUDGET_DRIFT
#        - quick_knowledge_token_budget
#        - knowledge_section_tokens
#        - ORCH_EFFICIENCY_FOOTER_INPUT
#        - m031_quick_budget_drift_check
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
# Output: per-check PASS/FAIL lines + final SUMMARY: line; exit 0 iff fail=0.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/diagnostics/efficiency-footer.sh"

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
    ok "scripts/diagnostics/efficiency-footer.sh exists at $target"
else
    ng "scripts/diagnostics/efficiency-footer.sh missing at $target"
    printf 'SUMMARY: m031-p04-budget-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Required literal substrings.
check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "QUICK_BUDGET_DRIFT" "QUICK_BUDGET_DRIFT"
check_literal "quick_knowledge_token_budget" "quick_knowledge_token_budget"
check_literal "knowledge_section_tokens" "knowledge_section_tokens"
check_literal "ORCH_EFFICIENCY_FOOTER_INPUT" "ORCH_EFFICIENCY_FOOTER_INPUT"
check_literal "m031_quick_budget_drift_check" "m031_quick_budget_drift_check"

printf 'SUMMARY: m031-p04-budget-drift-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1

#!/usr/bin/env bash
# tools/verify/m031-p04-test-scope-guard-shape.sh
#
# M031/P04/T04 shape verifier (project-owned, slug-bearing under
# tools/verify/) for tests/m031-acceptance/scope-guard.sh -- the
# milestone-grain SC-12 scope-guard.
#
# Asserts:
#   1) tests/m031-acceptance/scope-guard.sh exists and is >= 80 lines.
#   2) the file body contains required literal substrings:
#        - SC-12
#        - knowledge/
#        - scripts/cost
#        - scripts/dispatch/adapters/router
#        - scripts/auto/loop
#        - block_list_violations
#        - .orchestrator/observability
#        - .orchestrator/tier-a-plus
#        - is_mem_hitcount_only_carveout
#   3) the script is executable (chmod +x applied).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/scope-guard.sh"

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
    ok "tests/m031-acceptance/scope-guard.sh exists at $target"
else
    ng "tests/m031-acceptance/scope-guard.sh missing at $target"
    printf 'SUMMARY: m031-p04-test-scope-guard-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Line count >= 80.
target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 80 ]; then
    ok "scope-guard.sh has $target_lines lines (>= 80)"
else
    ng "scope-guard.sh has $target_lines lines (< 80)"
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

check_literal "SC-12"                            "SC-12"
check_literal "knowledge/ block-list pattern"    "knowledge/"
check_literal "scripts/cost block-list pattern"  "scripts/cost"
check_literal "scripts/dispatch/adapters/router" "scripts/dispatch/adapters/router"
check_literal "scripts/auto/loop"                "scripts/auto/loop"
check_literal "block_list_violations counter"    "block_list_violations"
check_literal ".orchestrator/observability"      ".orchestrator/observability"
check_literal ".orchestrator/tier-a-plus"        ".orchestrator/tier-a-plus"
check_literal "MEM hit_count carve-out helper"   "is_mem_hitcount_only_carveout"

# 4) Executability.
if [ -x "$target" ]; then
    ok "scope-guard.sh is executable"
else
    ng "scope-guard.sh is not executable (chmod +x missing)"
fi

printf 'SUMMARY: m031-p04-test-scope-guard-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1

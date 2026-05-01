#!/usr/bin/env bash
# tools/verify/m031-p04-battery-shape.sh
#
# M031/P04/T04 shape verifier (project-owned, slug-bearing under
# tools/verify/) for tests/m031-acceptance/run-acceptance-battery.sh --
# the SC-14 acceptance battery aggregator.
#
# Asserts:
#   1) tests/m031-acceptance/run-acceptance-battery.sh exists and is >= 60 lines.
#   2) the file body contains the BATTERY: envelope literal.
#   3) the file references every required SC sub-gate path:
#        - test-quick-injects-knowledge.sh   (SC-1)
#        - test-build-context-profile.sh     (SC-2)
#        - test-compression-applies-to-quick.sh (SC-3)
#        - test-tier-a-plus-classifier.sh    (SC-5)
#        - test-tier-a-plus-flow.sh          (SC-6)
#        - test-tier-a-plus-prompt-ux.sh     (SC-16)
#        - test-universal-entry-trivial.sh   (SC-7)
#        - test-universal-entry-lowconf.sh   (SC-8)
#        - doc-drift-verifier.sh             (SC-9)
#        - test-auto-proceed-default.sh      (SC-10)
#        - scope-guard.sh                    (SC-12)
#        - test-doctor-compound-change.sh    (AD-9)
#        - test-budget-drift-warning.sh      (AD-19)
#        - test-quick-budget-median.sh       (SC-15)
#        - empirical-baseline.sh             (SC-11)
#   4) the file uses the run_sc helper invocation shape (AD-19).
#   5) the script is executable.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/run-acceptance-battery.sh"

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
    ok "run-acceptance-battery.sh exists at $target"
else
    ng "run-acceptance-battery.sh missing at $target"
    printf 'SUMMARY: m031-p04-battery-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Line count >= 60.
target_lines=$(awk 'END {print NR}' "$target")
if [ "$target_lines" -ge 60 ]; then
    ok "run-acceptance-battery.sh has $target_lines lines (>= 60)"
else
    ng "run-acceptance-battery.sh has $target_lines lines (< 60)"
fi

# 3) Required literal substrings (BATTERY envelope + every SC sub-gate path + run_sc helper).
check_literal() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_literal "BATTERY envelope"             "BATTERY:"
check_literal "run_sc helper"                "run_sc"
check_literal "SC-1 (quick-injects-knowledge)"        "test-quick-injects-knowledge.sh"
check_literal "SC-2 (build-context-profile)"          "test-build-context-profile.sh"
check_literal "SC-3 (compression-applies-to-quick)"   "test-compression-applies-to-quick.sh"
check_literal "SC-5 (tier-a-plus-classifier)"         "test-tier-a-plus-classifier.sh"
check_literal "SC-6 (tier-a-plus-flow)"               "test-tier-a-plus-flow.sh"
check_literal "SC-16 (tier-a-plus-prompt-ux)"         "test-tier-a-plus-prompt-ux.sh"
check_literal "SC-7 (universal-entry-trivial)"        "test-universal-entry-trivial.sh"
check_literal "SC-8 (universal-entry-lowconf)"        "test-universal-entry-lowconf.sh"
check_literal "SC-9 (doc-drift-verifier)"             "doc-drift-verifier.sh"
check_literal "SC-10 (auto-proceed-default)"          "test-auto-proceed-default.sh"
check_literal "SC-12 (scope-guard)"                   "scope-guard.sh"
check_literal "AD-9 (doctor-compound-change)"         "test-doctor-compound-change.sh"
check_literal "AD-19 (budget-drift-warning)"          "test-budget-drift-warning.sh"
check_literal "SC-15 (quick-budget-median)"           "test-quick-budget-median.sh"
check_literal "SC-11 (empirical-baseline)"            "empirical-baseline.sh"

# 4) Executability.
if [ -x "$target" ]; then
    ok "run-acceptance-battery.sh is executable"
else
    ng "run-acceptance-battery.sh is not executable (chmod +x missing)"
fi

printf 'SUMMARY: m031-p04-battery-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1

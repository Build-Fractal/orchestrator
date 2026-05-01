#!/usr/bin/env bash
# tools/verify/m031-p04-doctor-compound-change-shape.sh
#
# M031/P04/T02 shape verifier (project-owned, slug-bearing under
# tools/verify/) for scripts/diagnostics/run-doctor.sh post-amend.
#
# Asserts the doctor script carries the AD-9 compound-change comms
# function + call site + test-only env override + the operator-facing
# literal substrings the SC test greps for.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"

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
    ok "scripts/diagnostics/run-doctor.sh exists at $target"
else
    ng "scripts/diagnostics/run-doctor.sh missing at $target"
    printf 'SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Required literal substrings.
check_present() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_present "M031 marker" "M031"
check_present "quick_knowledge_token_budget knob" "quick_knowledge_token_budget"
check_present "auto_proceed knob" "auto_proceed"
check_present "m031_compound_change_check function" "m031_compound_change_check"
check_present "ORCH_DOCTOR_CONFIG_PATH env override" "ORCH_DOCTOR_CONFIG_PATH"

printf 'SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1

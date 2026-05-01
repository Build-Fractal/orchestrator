#!/usr/bin/env bash
# tools/verify/m031-p04-test-doctor-compound-change-shape.sh
#
# M031/P04/T02 shape verifier (project-owned, slug-bearing under
# tools/verify/) for tests/m031-acceptance/test-doctor-compound-change.sh.
#
# Asserts the SC test exists, is executable, and references the artifacts
# under test (run-doctor.sh + ORCH_DOCTOR_CONFIG_PATH env seam +
# quick_knowledge_token_budget knob + AD-9 envelope).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Output:
#   per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 iff fail=0

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/tests/m031-acceptance/test-doctor-compound-change.sh"

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
    ok "test-doctor-compound-change.sh exists at $target"
else
    ng "test-doctor-compound-change.sh missing at $target"
    printf 'SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2) Executable bit.
if [ -x "$target" ]; then
    ok "test-doctor-compound-change.sh is executable"
else
    ng "test-doctor-compound-change.sh is not executable"
fi

# 3) Required literal substrings.
check_present() {
    local label="$1"
    local needle="$2"
    if grep -qF -- "$needle" "$target"; then
        ok "$label literal present"
    else
        ng "$label literal missing ($needle)"
    fi
}

check_present "AD-9 envelope" "AD-9"
check_present "run-doctor.sh reference" "run-doctor.sh"
check_present "ORCH_DOCTOR_CONFIG_PATH env seam" "ORCH_DOCTOR_CONFIG_PATH"
check_present "quick_knowledge_token_budget knob" "quick_knowledge_token_budget"

printf 'SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1

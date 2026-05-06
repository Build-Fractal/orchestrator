#!/usr/bin/env bash
# tools/verify/m029-p03-sc8-shape.sh
#
# M029 / P03 / T04 shape verifier for the SC-8 acceptance script at
# tests/m029-acceptance/p03-sc8-auto-preflight.sh.
#
# AD-19 single-script-file straight-line bash. MEM004 carve-out applies
# inside helper bodies. MEM001 bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET="tests/m029-acceptance/p03-sc8-auto-preflight.sh"

pass=0
fail=0

_assert_present() {
    _file="$1"; _needle="$2"; _label="$3"
    if grep -F -q -e "$_needle" "$_file"; then
        pass=$(( pass + 1 ))
        printf 'PASS: %s\n' "$_label"
    else
        fail=$(( fail + 1 ))
        printf 'FAIL: %s (missing in %s)\n' "$_label" "$_file"
    fi
}

if [ -f "$TARGET" ]; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s exists\n' "$TARGET"
else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s missing\n' "$TARGET"
fi
if [ -x "$TARGET" ]; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s is executable\n' "$TARGET"
else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s not executable\n' "$TARGET"
fi

_assert_present "$TARGET" 'SC-8' 'p03-sc8-auto-preflight.sh references SC-8'
_assert_present "$TARGET" 'predicted_cost' 'p03-sc8-auto-preflight.sh references predicted_cost label'
_assert_present "$TARGET" 'cost_standard_usd' 'p03-sc8-auto-preflight.sh references cost_standard_usd byte-identity field'
_assert_present "$TARGET" 'predictive-surface.sh' 'p03-sc8-auto-preflight.sh names predictive-surface.sh oracle'
_assert_present "$TARGET" 'summarize-milestone.sh' 'p03-sc8-auto-preflight.sh names summarize-milestone.sh oracle wrapper'
_assert_present "$TARGET" 'auto-preflight-standard.fixture' 'p03-sc8-auto-preflight.sh references SC-8 fixture'
_assert_present "$TARGET" 'commands/auto.md' 'p03-sc8-auto-preflight.sh asserts against commands/auto.md contract surface'
_assert_present "$TARGET" 'phase_count' 'p03-sc8-auto-preflight.sh asserts phase_count label is documented'
_assert_present "$TARGET" 'dispatch_count_estimate' 'p03-sc8-auto-preflight.sh asserts dispatch_count_estimate label is documented'
_assert_present "$TARGET" 'Preflight Summary' 'p03-sc8-auto-preflight.sh asserts Preflight Summary header is documented'
_assert_present "$TARGET" '--intensity standard' 'p03-sc8-auto-preflight.sh invokes oracle at --intensity standard'

printf 'SUMMARY: m029-p03-sc8-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1

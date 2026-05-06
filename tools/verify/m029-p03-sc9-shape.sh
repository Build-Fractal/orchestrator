#!/usr/bin/env bash
# tools/verify/m029-p03-sc9-shape.sh
#
# M029 / P03 / T04 shape verifier for the SC-9 acceptance script at
# tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh.
#
# AD-19 single-script-file straight-line bash. MEM004 carve-out applies
# inside helper bodies. MEM001 bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET="tests/m029-acceptance/p03-sc9-auto-quick-no-preflight.sh"

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

_assert_present "$TARGET" 'SC-9' 'p03-sc9-auto-quick-no-preflight.sh references SC-9'
_assert_present "$TARGET" 'Preflight Summary' 'p03-sc9-auto-quick-no-preflight.sh references Preflight Summary literal'
_assert_present "$TARGET" 'Quick' 'p03-sc9-auto-quick-no-preflight.sh references Quick intensity'
_assert_present "$TARGET" 'AUTO:READY' 'p03-sc9-auto-quick-no-preflight.sh references AUTO:READY token'
_assert_present "$TARGET" 'auto-preflight-quick.fixture' 'p03-sc9-auto-quick-no-preflight.sh references SC-9 fixture'
_assert_present "$TARGET" 'commands/auto.md' 'p03-sc9-auto-quick-no-preflight.sh asserts against commands/auto.md'
_assert_present "$TARGET" 'Quick intensity suppresses' 'p03-sc9-auto-quick-no-preflight.sh asserts the documented Quick-suppression clause'
_assert_present "$TARGET" 'intensity: "quick"' 'p03-sc9-auto-quick-no-preflight.sh asserts fixture EVALUATION declares intensity: quick'
_assert_present "$TARGET" 'predictive-surface.sh' 'p03-sc9-auto-quick-no-preflight.sh names predictive-surface.sh oracle'
_assert_present "$TARGET" '--intensity quick' 'p03-sc9-auto-quick-no-preflight.sh invokes oracle at --intensity quick'

printf 'SUMMARY: m029-p03-sc9-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1

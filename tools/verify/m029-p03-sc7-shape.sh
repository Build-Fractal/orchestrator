#!/usr/bin/env bash
# tools/verify/m029-p03-sc7-shape.sh
#
# M029 / P03 / T04 shape verifier for the SC-7 acceptance script at
# tests/m029-acceptance/p03-sc7-live-tail.sh.
#
# AD-19 single-script-file straight-line bash. MEM004 carve-out applies
# inside helper bodies. MEM001 bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET="tests/m029-acceptance/p03-sc7-live-tail.sh"

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

_assert_absent() {
    _file="$1"; _needle="$2"; _label="$3"
    if grep -F -q -e "$_needle" "$_file"; then
        fail=$(( fail + 1 ))
        printf 'FAIL: %s (forbidden token present in %s)\n' "$_label" "$_file"
    else
        pass=$(( pass + 1 ))
        printf 'PASS: %s\n' "$_label"
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

_assert_present "$TARGET" 'SC-7' 'p03-sc7-live-tail.sh references SC-7'
_assert_present "$TARGET" '▽ saved' 'p03-sc7-live-tail.sh asserts canonical compact savings marker'
_assert_present "$TARGET" '1 second' 'p03-sc7-live-tail.sh references 1 second budget label'
_assert_present "$TARGET" '--live' 'p03-sc7-live-tail.sh invokes renderer with --live'
_assert_present "$TARGET" 'render-position.sh' 'p03-sc7-live-tail.sh names render-position.sh entry point'
_assert_present "$TARGET" 'mktemp' 'p03-sc7-live-tail.sh uses mktemp -d (CON-1 read-only)'
_assert_present "$TARGET" 'tier1_savings_tokens' 'p03-sc7-live-tail.sh appends synthetic dispatch_usage record with savings field'
_assert_present "$TARGET" 'measure-live-tail-latency.sh' 'p03-sc7-live-tail.sh delegates p95 to latency harness'
_assert_present "$TARGET" 'pkill -TERM' 'p03-sc7-live-tail.sh uses kill cascade for renderer shutdown'

# Negative assertion: forbidden #Q-G8 verbose-suffix marker form.
# Verifier code names the literal token in this assertion string while
# the deliverable body must NOT contain it (negative-assertion verifier
# discipline from P02 / T03 SUMMARY). The SC-7 acceptance script
# legitimately greps for the same forbidden token in the renderer's
# OUTPUT to verify the renderer doesn't emit it -- that grep is part of
# a negative grep, so the script body DOES contain the literal. We
# therefore do NOT assert absence at the script-body level; instead we
# assert the script names the literal in a negative-grep context.
_assert_present "$TARGET" 'via tier1 cache reuse' 'p03-sc7-live-tail.sh names #Q-G8 forbidden verbose-suffix in negative-grep assertion'

printf 'SUMMARY: m029-p03-sc7-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1

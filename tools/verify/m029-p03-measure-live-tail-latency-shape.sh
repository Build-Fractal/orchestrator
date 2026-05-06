#!/usr/bin/env bash
# tools/verify/m029-p03-measure-live-tail-latency-shape.sh
#
# M029 / P03 / T04 shape verifier for the #Q-G9 latency-measurement
# harness at tests/m029-acceptance/measure-live-tail-latency.sh.
#
# AD-19 single-script-file straight-line bash. MEM004 carve-out: helper
# function bodies use grep pipes; AD-19 applies at Check: command level.
# MEM001 bash 3.2 compatible (parallel scalars, no associative arrays,
# no herestring).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET="tests/m029-acceptance/measure-live-tail-latency.sh"

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

# Existence + executability.
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

# Content invariants -- the harness must reference its load-bearing
# tokens.
_assert_present "$TARGET" '#Q-G9' 'measure-live-tail-latency.sh references #Q-G9'
_assert_present "$TARGET" 'p50' 'measure-live-tail-latency.sh computes p50'
_assert_present "$TARGET" 'p95' 'measure-live-tail-latency.sh computes p95'
_assert_present "$TARGET" 'p99' 'measure-live-tail-latency.sh computes p99'
_assert_present "$TARGET" '1000' 'measure-live-tail-latency.sh enforces 1.0s (1000ms) p95 budget'
_assert_present "$TARGET" '1500' 'measure-live-tail-latency.sh references 1.5s (1500ms) drift trigger'
_assert_present "$TARGET" 'tail -f' 'measure-live-tail-latency.sh consumes renderer tail -f live mode (CON-2)'
_assert_present "$TARGET" '--live' 'measure-live-tail-latency.sh invokes renderer with --live'
_assert_present "$TARGET" 'render-position.sh' 'measure-live-tail-latency.sh names render-position.sh entry point'
_assert_present "$TARGET" 'TRIALS' 'measure-live-tail-latency.sh declares TRIALS variable'
_assert_present "$TARGET" 'mktemp' 'measure-live-tail-latency.sh uses mktemp -d for fixture (CON-1 read-only)'
_assert_present "$TARGET" 'sort -n' 'measure-live-tail-latency.sh uses sort -n for percentile pick (bash 3.2 safe)'
_assert_present "$TARGET" 'VERDICT' 'measure-live-tail-latency.sh emits VERDICT line'
_assert_present "$TARGET" 'SUMMARY: measure-live-tail-latency.sh' 'measure-live-tail-latency.sh emits SUMMARY line'
_assert_present "$TARGET" 'RISK:' 'measure-live-tail-latency.sh emits RISK callout for p95 drift trigger'
_assert_present "$TARGET" 'pkill -TERM' 'measure-live-tail-latency.sh uses kill cascade for renderer shutdown (T01 caution)'

printf 'SUMMARY: m029-p03-measure-live-tail-latency-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1

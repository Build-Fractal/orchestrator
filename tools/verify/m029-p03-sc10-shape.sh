#!/usr/bin/env bash
# tools/verify/m029-p03-sc10-shape.sh
#
# M029 / P03 / T04 shape verifier for the SC-10 acceptance script at
# tests/m029-acceptance/p03-sc10-auto-chain.sh.
#
# AD-19 single-script-file straight-line bash. MEM004 carve-out applies
# inside helper bodies. MEM001 bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TARGET="tests/m029-acceptance/p03-sc10-auto-chain.sh"

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

_assert_present "$TARGET" 'SC-10' 'p03-sc10-auto-chain.sh references SC-10'
_assert_present "$TARGET" 'evaluate.complete' 'p03-sc10-auto-chain.sh references evaluate.complete marker'
_assert_present "$TARGET" 'discuss.complete' 'p03-sc10-auto-chain.sh references discuss.complete marker'
_assert_present "$TARGET" 'roadmap.complete' 'p03-sc10-auto-chain.sh references roadmap.complete marker'
_assert_present "$TARGET" 'plan-phase.complete' 'p03-sc10-auto-chain.sh references plan-phase.complete marker'
_assert_present "$TARGET" 'resume' 'p03-sc10-auto-chain.sh exercises resume path'
_assert_present "$TARGET" 'AUTO_CHAIN_STAGE_STUB' 'p03-sc10-auto-chain.sh sets AUTO_CHAIN_STAGE_STUB env var'
_assert_present "$TARGET" 'auto-chain-greenfield.fixture' 'p03-sc10-auto-chain.sh references SC-10 fixture'
_assert_present "$TARGET" '--auto-chain' 'p03-sc10-auto-chain.sh invokes start.sh --auto-chain'
_assert_present "$TARGET" 'start.sh' 'p03-sc10-auto-chain.sh names start.sh entry point'
_assert_present "$TARGET" 'mktemp' 'p03-sc10-auto-chain.sh uses mktemp -d for fresh project copy (CON-1 read-only)'
_assert_present "$TARGET" 'SKIP:' 'p03-sc10-auto-chain.sh asserts SKIP: token on resume'
_assert_present "$TARGET" 'OK:' 'p03-sc10-auto-chain.sh asserts OK: token on stage success'
_assert_present "$TARGET" 'START_AUTO_CHAIN_COMPLETE' 'p03-sc10-auto-chain.sh asserts chain-complete token'
_assert_present "$TARGET" 'mtime' 'p03-sc10-auto-chain.sh asserts unchanged mtime on idempotent skip'

printf 'SUMMARY: m029-p03-sc10-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1

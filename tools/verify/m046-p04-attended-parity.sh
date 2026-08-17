#!/usr/bin/env sh
# m046-p04-attended-parity.sh (M046 P04 phase Truth 8 / FR-17 / CON-2)
#
# The FR-17 regression oracle for the P04 envelope wiring: the ATTENDED driver
# path (no --unattended) must stay behaviorally identical to the P02-hardened
# driver. Runs the four P02 driver verifiers against the now-envelope-bearing
# scripts/lifecycle/self-continue-drive.sh and fails if any regresses:
#   m046-p02-legacy-parity.sh        -- M045 byte-parity golden
#   m046-p02-child-abort.sh          -- CHILD_ABORT truth table (kill/crash/stall)
#   m046-p02-driver-continue-class.sh-- continue-class re-spawn vs terminal
#   m046-p02-injection-reject.sh     -- charset gate rejects injection
# Straight-line invocation per AD-19 (four literal `bash <path>` calls, no
# loop-over-array); cd to REPO_ROOT first per the P02 suite precedent.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0

emit_member_result() {
  rc="$1"
  name="$2"
  if [ "$rc" -eq 0 ]; then
    pass=$(( pass + 1 ))
    printf 'MEMBER: %s PASS\n' "$name"
  else
    fail=$(( fail + 1 ))
    printf 'MEMBER: %s FAIL\n' "$name"
  fi
}

bash tools/verify/m046-p02-legacy-parity.sh
rc=$?
emit_member_result "$rc" "m046-p02-legacy-parity.sh"

bash tools/verify/m046-p02-child-abort.sh
rc=$?
emit_member_result "$rc" "m046-p02-child-abort.sh"

bash tools/verify/m046-p02-driver-continue-class.sh
rc=$?
emit_member_result "$rc" "m046-p02-driver-continue-class.sh"

bash tools/verify/m046-p02-injection-reject.sh
rc=$?
emit_member_result "$rc" "m046-p02-injection-reject.sh"

printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

#!/usr/bin/env sh
# tools/verify/m046-p02-phase-suite.sh — M046 P02 phase-close gate suite.
#
# Aggregates the seven m046-p02 verifiers plus the four M045 driver
# regression verifiers (11 members) and emits one SUITE: line per member
# and a final aggregate SUMMARY line; exits 0 iff 11/11 pass. Milestone-
# prefixed name per the P00-clobber lesson; modeled on
# tools/verify/m046-p01-phase-suite.sh. Straight-line invocation per AD-19
# — eleven literal `bash <path>` calls, no loop-over-array.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0

emit_suite_result() {
  rc="$1"
  name="$2"
  if [ "$rc" -eq 0 ]; then
    pass=$(( pass + 1 ))
    printf 'SUITE: %s PASS\n' "$name"
  else
    fail=$(( fail + 1 ))
    printf 'SUITE: %s FAIL\n' "$name"
  fi
}

# --- P02 verifiers ---

bash tools/verify/m046-p02-marker-unit.sh
rc=$?
emit_suite_result "$rc" "m046-p02-marker-unit.sh"

bash tools/verify/m046-p02-legacy-parity.sh
rc=$?
emit_suite_result "$rc" "m046-p02-legacy-parity.sh"

bash tools/verify/m046-p02-injection-reject.sh
rc=$?
emit_suite_result "$rc" "m046-p02-injection-reject.sh"

bash tools/verify/m046-p02-driver-continue-class.sh
rc=$?
emit_suite_result "$rc" "m046-p02-driver-continue-class.sh"

bash tools/verify/m046-p02-marker-exit-contract.sh
rc=$?
emit_suite_result "$rc" "m046-p02-marker-exit-contract.sh"

bash tools/verify/m046-p02-child-abort.sh
rc=$?
emit_suite_result "$rc" "m046-p02-child-abort.sh"

bash tools/verify/m046-p02-atomic-write-discipline.sh
rc=$?
emit_suite_result "$rc" "m046-p02-atomic-write-discipline.sh"

# --- M045 driver regression verifiers ---

bash tools/verify/m045-p03-driver-terminal.sh
rc=$?
emit_suite_result "$rc" "m045-p03-driver-terminal.sh"

bash tools/verify/m045-p03-driver-cap.sh
rc=$?
emit_suite_result "$rc" "m045-p03-driver-cap.sh"

bash tools/verify/m045-p03-legacy-golden.sh
rc=$?
emit_suite_result "$rc" "m045-p03-legacy-golden.sh"

bash tools/verify/m045-p04-stall.sh
rc=$?
emit_suite_result "$rc" "m045-p04-stall.sh"

printf 'SUMMARY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

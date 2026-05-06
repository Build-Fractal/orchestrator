#!/usr/bin/env bash
# tools/verify/m029-p03-auto-chain-shape.sh -- M029 P03 / T03 shape verifier
# for the FR-10 --auto-chain flag in commands/start.md +
# scripts/lifecycle/start.sh.
#
# AD-19 single-script-file straight-line bash verifier. MEM004 carve-out:
# the _assert_present_in / _assert_absent_in helper bodies use grep
# pipes / function definitions; the AD-19 rule applies only at Check:
# command level (the verifier is invoked as `bash <abs-path>`). MEM001
# bash 3.2 compatible (parallel scalars, no declare -A, no herestring).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

pass=0
fail=0

_assert_present_in() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -F -q -e "$needle" "$file"; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$label"
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s (missing in %s)\n' "$label" "$file"
  fi
}

_assert_absent_in() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -F -q -e "$needle" "$file"; then
    fail=$(( fail + 1 ))
    printf 'FAIL: %s (forbidden token in %s)\n' "$label" "$file"
  else
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$label"
  fi
}

# Existence pre-checks
for f in commands/start.md scripts/lifecycle/start.sh; do
  if [ ! -f "$f" ]; then
    printf 'FAIL: %s missing\n' "$f"
    fail=$(( fail + 1 ))
  fi
done

# commands/start.md content assertions
_assert_present_in 'commands/start.md' '--auto-chain' 'commands/start.md documents --auto-chain flag'
_assert_present_in 'commands/start.md' 'FR-10' 'commands/start.md references FR-10'
_assert_present_in 'commands/start.md' 'evaluate' 'commands/start.md names evaluate stage'
_assert_present_in 'commands/start.md' 'discuss' 'commands/start.md names discuss stage'
_assert_present_in 'commands/start.md' 'roadmap' 'commands/start.md names roadmap stage'
_assert_present_in 'commands/start.md' 'plan-phase' 'commands/start.md names plan-phase stage'
_assert_present_in 'commands/start.md' '.orchestrator/start-state/' 'commands/start.md names marker dir'
_assert_present_in 'commands/start.md' '.complete' 'commands/start.md names .complete marker suffix'
_assert_present_in 'commands/start.md' 'M029_AUTOCHAIN_NEEDS_CONFIRMATION' 'commands/start.md names byte-stable refusal'
_assert_present_in 'commands/start.md' '#Q-3' 'commands/start.md references #Q-3'

# scripts/lifecycle/start.sh content assertions
_assert_present_in 'scripts/lifecycle/start.sh' '--auto-chain' 'start.sh wires --auto-chain flag'
_assert_present_in 'scripts/lifecycle/start.sh' 'AUTO_CHAIN' 'start.sh declares AUTO_CHAIN var'
_assert_present_in 'scripts/lifecycle/start.sh' 'evaluate.complete' 'start.sh references evaluate.complete marker shape'
_assert_present_in 'scripts/lifecycle/start.sh' 'discuss.complete' 'start.sh references discuss.complete marker shape'
_assert_present_in 'scripts/lifecycle/start.sh' 'roadmap.complete' 'start.sh references roadmap.complete marker shape'
_assert_present_in 'scripts/lifecycle/start.sh' 'plan-phase.complete' 'start.sh references plan-phase.complete marker shape'
_assert_present_in 'scripts/lifecycle/start.sh' 'FR-10' 'start.sh references FR-10'
_assert_present_in 'scripts/lifecycle/start.sh' 'START_STATE_DIR' 'start.sh declares START_STATE_DIR'
_assert_present_in 'scripts/lifecycle/start.sh' '#Q-3' 'start.sh references #Q-3'
_assert_present_in 'scripts/lifecycle/start.sh' 'M029_AUTOCHAIN_NEEDS_CONFIRMATION' 'start.sh emits byte-stable refusal token'
_assert_present_in 'scripts/lifecycle/start.sh' 'START_AUTO_CHAIN_COMPLETE' 'start.sh emits chain-complete token'

# USAGE-string check
_assert_present_in 'scripts/lifecycle/start.sh' '[--auto-chain]' 'start.sh USAGE includes [--auto-chain]'

# Negative assertion -- #Q-3 forbids `.failed` marker writes.
_assert_absent_in 'scripts/lifecycle/start.sh' '.failed' 'start.sh does NOT write .failed marker (#Q-3)'

printf 'SUMMARY: m029-p03-auto-chain-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1

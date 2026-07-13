#!/usr/bin/env bash
# tools/verify/m046-p01-phase-suite.sh — M046 P01 phase-close gate suite.
#
# Aggregates the four m046-p01 verifiers and emits a single aggregate
# SUMMARY line; exits 0 iff 4/4 pass. Milestone-prefixed name per the
# P00-clobber lesson; M045/M031 suite pattern. Bash 3.2 compatible.
# Straight-line invocation per AD-19 — four literal `bash <path>` calls.
set -u

pass=0
fail=0

emit_gate_result() {
  rc="$1"
  name="$2"
  if [ "$rc" -eq 0 ]; then
    pass=$(( pass + 1 ))
    printf 'PASS: %s\n' "$name"
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n' "$name"
  fi
}

bash tools/verify/m046-p01-viability-evidence.sh
rc=$?
emit_gate_result "$rc" "m046-p01-viability-evidence.sh"

bash tools/verify/m046-p01-hook-deny-proof.sh
rc=$?
emit_gate_result "$rc" "m046-p01-hook-deny-proof.sh"

bash tools/verify/m046-p01-install-matrix.sh
rc=$?
emit_gate_result "$rc" "m046-p01-install-matrix.sh"

bash tools/verify/m046-p01-cadence-log.sh
rc=$?
emit_gate_result "$rc" "m046-p01-cadence-log.sh"

printf 'SUMMARY: m046-p01-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

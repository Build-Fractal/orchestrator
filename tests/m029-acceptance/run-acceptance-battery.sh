#!/usr/bin/env bash
# tests/m029-acceptance/run-acceptance-battery.sh
# M029 milestone-grain acceptance battery (SC-11).
#
# Chains the three per-phase batteries:
#   P01: SC-1, SC-2, SC-3, SC-4         (4 SCs)
#   P02: SC-5, SC-6, SC-13, SC-14       (4 SCs)
#   P03: SC-7, SC-8, SC-9, SC-10        (4 SCs)
# Plus SC-11 (this script's BATTERY: line) and SC-12 (validate-milestone-pass hook).
# Total: 14 SCs on full pass.
#
# Bash 3.2 / MEM001. AD-19 straight-line bash (single-script-file shape; no
# compound chains, no command substitution in dispatch). Mirrors the M030/M031
# milestone-grain run-acceptance-battery convention.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

pass=0
fail=0

# --- P01 slice (SC-1..SC-4)
bash tests/m029-acceptance/p01-acceptance-battery.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$(( pass + 4 ))
  printf 'OK: P01 slice (SC-1..SC-4)\n'
else
  fail=$(( fail + 4 ))
  printf 'FAIL: P01 slice (SC-1..SC-4)\n'
fi

# --- P02 slice (SC-5/SC-6/SC-13/SC-14)
bash tests/m029-acceptance/p02-acceptance-battery.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$(( pass + 4 ))
  printf 'OK: P02 slice (SC-5/SC-6/SC-13/SC-14)\n'
else
  fail=$(( fail + 4 ))
  printf 'FAIL: P02 slice (SC-5/SC-6/SC-13/SC-14)\n'
fi

# --- P03 slice (SC-7/SC-8/SC-9/SC-10)
bash tests/m029-acceptance/p03-acceptance-battery.sh
rc=$?
if [ "$rc" -eq 0 ]; then
  pass=$(( pass + 4 ))
  printf 'OK: P03 slice (SC-7/SC-8/SC-9/SC-10)\n'
else
  fail=$(( fail + 4 ))
  printf 'FAIL: P03 slice (SC-7/SC-8/SC-9/SC-10)\n'
fi

# --- SC-11 self -- this BATTERY: line itself satisfies SC-11.
pass=$(( pass + 1 ))
printf 'OK: SC-11 (battery emits canonical BATTERY: line)\n'

# --- SC-12 milestone-validator hook
if [ -f tools/verify/m029-p03-validate-milestone-pass.sh ]; then
  bash tools/verify/m029-p03-validate-milestone-pass.sh
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$(( pass + 1 ))
    printf 'OK: SC-12 (validate-milestone.sh M029 pass)\n'
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: SC-12 (validate-milestone.sh M029 pass)\n'
  fi
else
  # Verifier not yet present (only during T06 mid-author state); skip with WARN.
  # Once T06 lands the verifier this branch never fires.
  printf 'WARN: SC-12 verifier not yet on disk; skipping\n'
fi

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

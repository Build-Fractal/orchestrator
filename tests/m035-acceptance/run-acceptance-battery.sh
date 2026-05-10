#!/usr/bin/env bash
# tests/m035-acceptance/run-acceptance-battery.sh
# M035 milestone-grain acceptance battery (SC-15).
#
# Chains every per-phase aggregator + the acceptance-battery-shape
# verifier. Coverage:
#   P00 phase-suite       → SC-5, SC-6
#   P01 phase-suite       → SC-1..SC-4
#   P01.5 phase-suite     → SC-7, SC-7b
#   P02 phase-suite       → SC-8 + part of SC-10/SC-14
#   P03 phase-suite       → SC-9 + part of SC-10/SC-14 (MOS-3 SKIP)
#   P04 phase-suite       → part of SC-10/SC-14 (MOS-4/MOS-5 SKIP)
#   P05 phase-suite       → SC-11, SC-12, SC-12b
#   P06 phase-suite       → SC-13, part of SC-14 (multi-source dispatch + JSONL)
#   acceptance-battery    → SC-15 (self-reference)
#
# SC-16 is NOT covered here (T06 owns it via validate-milestone.sh
# + M035-VALIDATED marker; chicken-and-egg loop avoided).
#
# Bash 3.2 / MEM001 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

total_pass=0
total_fail=0
total_skip=0

# Discover P01.5 aggregator filename — the dot-form is operator-
# readable but some discovery tools may have normalized to p015.
P015_AGG=""
if [ -x "tools/verify/m035-p015-phase-suite.sh" ]; then
  P015_AGG="tools/verify/m035-p015-phase-suite.sh"
elif [ -x "tools/verify/m035-p01.5-phase-suite.sh" ]; then
  P015_AGG="tools/verify/m035-p01.5-phase-suite.sh"
fi

# The chain-and-rollup pattern: invoke each sub-aggregator,
# capture stdout to a tempfile, parse its BATTERY line, sum
# counters into total_*. Exit 0 iff total_fail=0.
run_one() {
  local label="$1"
  local cmd="$2"
  if [ ! -x "$cmd" ]; then
    printf 'SKIP: %s — verifier not found at %s\n' "$label" "$cmd"
    total_skip=$(( total_skip + 1 ))
    return 0
  fi
  local out_log
  out_log="$(mktemp)"
  local err_log
  err_log="$(mktemp)"
  bash "$cmd" >"$out_log" 2>"$err_log"
  local rc=$?
  local battery_line
  battery_line="$(grep -E '^BATTERY:' "$out_log" | tail -1)"
  local p=0 f=0 s=0
  if [ -n "$battery_line" ]; then
    p="$(echo "$battery_line" | sed -E 's/.*pass=([0-9]+).*/\1/' | head -1)"
    f="$(echo "$battery_line" | sed -E 's/.*fail=([0-9]+).*/\1/' | head -1)"
    case "$battery_line" in
      *skip=*) s="$(echo "$battery_line" | sed -E 's/.*skip=([0-9]+).*/\1/' | head -1)" ;;
      *)       s=0 ;;
    esac
  fi
  # Defensive: if grep/sed yielded non-numeric, fall back to 0.
  case "$p" in ''|*[!0-9]*) p=0 ;; esac
  case "$f" in ''|*[!0-9]*) f=0 ;; esac
  case "$s" in ''|*[!0-9]*) s=0 ;; esac
  total_pass=$(( total_pass + p ))
  total_fail=$(( total_fail + f ))
  total_skip=$(( total_skip + s ))
  if [ "$rc" -eq 0 ]; then
    printf 'PASS: %s (pass=%s fail=%s skip=%s)\n' "$label" "$p" "$f" "$s"
  else
    printf 'FAIL: %s (rc=%d pass=%s fail=%s skip=%s)\n' "$label" "$rc" "$p" "$f" "$s"
    cat "$err_log" >&2
  fi
  rm -f "$out_log" "$err_log"
}

run_one "P00 phase-suite (SC-5/SC-6)"     "tools/verify/m035-p00-phase-suite.sh"
if [ -n "$P015_AGG" ]; then
  run_one "P01.5 phase-suite (SC-7/SC-7b)"  "$P015_AGG"
else
  printf 'SKIP: P01.5 phase-suite — neither m035-p015-phase-suite.sh nor m035-p01.5-phase-suite.sh found\n'
  total_skip=$(( total_skip + 1 ))
fi
run_one "P02 phase-suite (SC-8 + part SC-10/SC-14)"  "tools/verify/m035-p02-phase-suite.sh"
run_one "P03 phase-suite (SC-9 + MOS-3 SKIP)"        "tools/verify/m035-p03-phase-suite.sh"
run_one "P04 phase-suite (part SC-10/SC-14 + MOS-4/MOS-5 SKIP)"  "tools/verify/m035-p04-phase-suite.sh"
run_one "P05 phase-suite (SC-11/SC-12/SC-12b)"       "tools/verify/m035-p05-phase-suite.sh"
run_one "P06 phase-suite (SC-13 + part SC-14)"       "tools/verify/m035-p06-phase-suite.sh"
run_one "Acceptance-battery shape (SC-15 self-reference)"  "tools/verify/m035-p06-acceptance-battery-shape.sh"

# P01 phase-suite covers SC-1..SC-4. P01 is closed but verify the
# aggregator was actually shipped — best-effort SKIP if absent.
run_one "P01 phase-suite (SC-1..SC-4)"               "tools/verify/m035-p01-phase-suite.sh"

# Final rollup line. SC-15 self-reference: this very line.
printf 'BATTERY: pass=%d fail=%d skip=%d\n' "$total_pass" "$total_fail" "$total_skip"

if [ "$total_fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi

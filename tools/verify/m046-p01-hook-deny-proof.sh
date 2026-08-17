#!/usr/bin/env bash
# tools/verify/m046-p01-hook-deny-proof.sh
# M046 P01: deny-drive.log proves live default-DENY semantics — the three
# deny vectors + fail-closed all exit 2, both allowlisted cases exit 0,
# every case result=PASS. Written against the actual T01 log shape
# (six 'case=' result lines + one live-e2e deferral line). Bash 3.2.
set -u
LOG=".orchestrator/milestones/M046/phases/P01/spike/hook/deny-drive.log"

if [ ! -f "$LOG" ]; then
  echo "FAIL: deny-drive log missing at $LOG"
  exit 1
fi

fail=0

check_case() {
  name="$1"
  expected="$2"
  if ! grep -q "^case=$name expected=$expected actual=$expected result=PASS$" "$LOG"; then
    echo "FAIL: case=$name expected=$expected actual=$expected result=PASS not found in $LOG"
    fail=1
  fi
}

check_case oos-write 2
check_case oos-bash-gitpush 2
check_case oos-mcp 2
check_case policy-missing-failclosed 2
check_case allowed-write 0
check_case allowed-bash 0

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: deny-drive log shows 3 deny vectors + fail-closed (exit 2) and 2 allowlisted passes (exit 0), all result=PASS"
exit 0

#!/usr/bin/env bash
# drive-hook-case.sh -- M046/P01/T01 THROWAWAY SPIKE direct-drive harness.
#
# Drives fixture payloads through unattended-deny-probe.sh via the real
# hook contract (stdin JSON -> exit code) and records the outcome.
#
# Usage:
#   bash drive-hook-case.sh --all
#       Truncates deny-drive.log, runs the six T01 cases, appends the
#       step-6 skip record `live-e2e=deferred-to-SC-5` as the final
#       line (keeps the log deterministic across re-runs), exits 0
#       only when every case PASSes.
#   bash drive-hook-case.sh <case-name> <expected-exit> <payload.json> [policy-file]
#       Runs a single case (appends to the log; no truncate). Policy
#       defaults to policy.txt beside this script.
#
# Log line shape (fixed by the T01 plan):
#   case=<name> expected=<e> actual=<a> result=PASS|FAIL
#
# Bash 3.2 compatible. No jq. No process substitution.

set -u

SPIKE_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SPIKE_DIR/unattended-deny-probe.sh"
LOG="$SPIKE_DIR/deny-drive.log"
POLICY_DEFAULT="$SPIKE_DIR/policy.txt"
FIXTURES="$SPIKE_DIR/fixtures"

FAILURES=0

run_case() {
  # $1=case-name $2=expected-exit $3=payload-file $4=policy-file
  _name="$1"
  _expected="$2"
  _payload="$3"
  _policy="$4"

  if [ ! -f "$_payload" ]; then
    echo "case=$_name expected=$_expected actual=missing-fixture result=FAIL" >> "$LOG"
    echo "case=$_name expected=$_expected actual=missing-fixture result=FAIL"
    FAILURES=$((FAILURES + 1))
    return 0
  fi

  _stderr_file="$SPIKE_DIR/.last-stderr"
  DENY_PROBE_POLICY="$_policy" bash "$HOOK" < "$_payload" > /dev/null 2> "$_stderr_file"
  _actual=$?

  if [ "$_actual" -eq "$_expected" ]; then
    _result="PASS"
  else
    _result="FAIL"
    FAILURES=$((FAILURES + 1))
  fi

  echo "case=$_name expected=$_expected actual=$_actual result=$_result" >> "$LOG"
  echo "case=$_name expected=$_expected actual=$_actual result=$_result"
  # Console-only visibility of the deny reason (not part of the log contract).
  if [ -s "$_stderr_file" ]; then
    sed -e 's/^/    reason: /' "$_stderr_file"
  fi
  rm -f "$_stderr_file"
}

if [ "${1:-}" = "--all" ]; then
  : > "$LOG"
  run_case oos-write                2 "$FIXTURES/oos-write.json"                "$POLICY_DEFAULT"
  run_case oos-bash-gitpush         2 "$FIXTURES/oos-bash-gitpush.json"         "$POLICY_DEFAULT"
  run_case oos-mcp                  2 "$FIXTURES/oos-mcp.json"                  "$POLICY_DEFAULT"
  run_case allowed-write            0 "$FIXTURES/allowed-write.json"            "$POLICY_DEFAULT"
  run_case allowed-bash             0 "$FIXTURES/allowed-bash.json"             "$POLICY_DEFAULT"
  run_case policy-missing-failclosed 2 "$FIXTURES/policy-missing-failclosed.json" "$SPIKE_DIR/nonexistent-policy-file.txt"
  # T01 step 6 skipped by dispatch instruction: record the deferral.
  echo "live-e2e=deferred-to-SC-5" >> "$LOG"
  if [ "$FAILURES" -eq 0 ]; then
    echo "DRIVE: all cases PASS"
    exit 0
  fi
  echo "DRIVE: $FAILURES case(s) FAILED" >&2
  exit 1
fi

if [ $# -lt 3 ]; then
  echo "usage: drive-hook-case.sh --all | <case-name> <expected-exit> <payload.json> [policy-file]" >&2
  exit 1
fi

run_case "$1" "$2" "$3" "${4:-$POLICY_DEFAULT}"
if [ "$FAILURES" -eq 0 ]; then
  exit 0
fi
exit 1

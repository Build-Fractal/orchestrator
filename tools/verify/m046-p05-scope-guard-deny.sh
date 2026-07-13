#!/usr/bin/env bash
# tools/verify/m046-p05-scope-guard-deny.sh -- M046/P05/T01 unit verifier.
#
# Drives fixture hook-payloads through the PRODUCTION scope guard
# scripts/hooks/unattended-scope-guard.sh via the real Claude Code hook
# contract (stdin JSON -> exit code) and asserts the expected exit for:
#
#   * the env-gate (D017): with ORCHESTRATOR_UNATTENDED UNSET the hook is a
#     pure no-op (exit 0) for even clearly out-of-scope calls -- the
#     operator's interactive session is never constrained. SAFETY-CRITICAL.
#   * the enforcing deny/pass matrix under ORCHESTRATOR_UNATTENDED=1
#     (out-of-scope Write / git push / network / MCP denied; read-class,
#     in-allow_path Write, allow_bash-matched command passed).
#   * the readonly_path (FR-20 / CON-7) create-vs-overwrite distinction:
#     Edit on a protected surface denied, Write over an EXISTING protected
#     file denied, Write to a NOT-YET-EXISTING protected path passed.
#   * fail-closed on a missing/unreadable policy (deny all except read-class).
#
# Structure models the P01 spike drive-hook-case.sh harness. Single-script,
# AD-19 compliant. Bash 3.2. No jq. No process substitution.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

HOOK="scripts/hooks/unattended-scope-guard.sh"
FX="tools/verify/fixtures/m046-p05"
POL="$FX/policy.txt"
MISSING_POL="$FX/nonexistent-policy-file.txt"

PASS=0
FAIL=0

# Overwrite fixture prep: the readonly-edit case must target an EXISTING file
# so the "deny Edit on readonly surface" leg is exercised, and the
# readonly-write-new case must target a NON-EXISTING path so the "create-new
# passes" leg is exercised. Isolated /tmp scratch -- never the repo tree.
mkdir -p /tmp/m046p05/ro
: > /tmp/m046p05/ro/harness.sh
rm -f /tmp/m046p05/ro/brand-new.sh

# case_expect <fixture> <expected-exit> <UNATT:1|0> [policy-file]
#   Runs the hook against $FX/<fixture>. When UNATT=1 the child-env var is
#   exported; when UNATT=0 the hook is invoked with ORCHESTRATOR_UNATTENDED
#   truly unset (separate branch -- not set to empty inline). Policy defaults
#   to $POL.
case_expect() {
  _fx="$1"
  _expected="$2"
  _unatt="$3"
  _policy="${4:-$POL}"
  _payload="$FX/$_fx"

  if [ ! -f "$_payload" ]; then
    echo "case=$_fx unatt=$_unatt expected=$_expected actual=missing-fixture result=FAIL"
    FAIL=$((FAIL + 1))
    return 0
  fi

  _stderr_file="/tmp/m046p05/.last-stderr"
  if [ "$_unatt" -eq 1 ]; then
    ORCHESTRATOR_UNATTENDED=1 ORCHESTRATOR_UNATTENDED_POLICY="$_policy" \
      bash "$HOOK" < "$_payload" > /dev/null 2> "$_stderr_file"
    _actual=$?
  else
    # ORCHESTRATOR_UNATTENDED deliberately UNSET: attended fast no-op path.
    ORCHESTRATOR_UNATTENDED_POLICY="$_policy" \
      bash "$HOOK" < "$_payload" > /dev/null 2> "$_stderr_file"
    _actual=$?
  fi

  if [ "$_actual" -eq "$_expected" ]; then
    _result="PASS"
    PASS=$((PASS + 1))
  else
    _result="FAIL"
    FAIL=$((FAIL + 1))
  fi

  echo "case=$_fx unatt=$_unatt expected=$_expected actual=$_actual result=$_result"
  if [ "$_result" = "FAIL" ] && [ -s "$_stderr_file" ]; then
    sed -e 's/^/    reason: /' "$_stderr_file"
  fi
  rm -f "$_stderr_file"
}

# -----------------------------------------------------------------------------
# Enforcing leg (ORCHESTRATOR_UNATTENDED=1) -- deny/pass matrix.
# -----------------------------------------------------------------------------
case_expect oos-write.json          2 1
case_expect allowed-write.json      0 1
case_expect readonly-edit.json      2 1
case_expect readonly-write-new.json 0 1
case_expect oos-bash-gitpush.json   2 1
case_expect oos-bash-curl.json      2 1
case_expect allowed-bash.json       0 1
case_expect oos-mcp.json            2 1
case_expect read-glob.json          0 1

# -----------------------------------------------------------------------------
# Env-gate leg (ORCHESTRATOR_UNATTENDED unset) -- SAFETY-CRITICAL: the hook
# must no-op (exit 0) for even clearly out-of-scope calls.
# -----------------------------------------------------------------------------
case_expect oos-write.json          0 0
case_expect oos-bash-gitpush.json   0 0
case_expect oos-mcp.json            0 0

# -----------------------------------------------------------------------------
# Fail-closed leg (ORCHESTRATOR_UNATTENDED=1, policy points at a missing file):
# non-read-class denied (policy-missing), read-class still passes.
# -----------------------------------------------------------------------------
case_expect oos-write.json 2 1 "$MISSING_POL"
case_expect read-glob.json 0 1 "$MISSING_POL"

echo "SUMMARY: pass=$PASS fail=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  exit 0
fi
exit 1

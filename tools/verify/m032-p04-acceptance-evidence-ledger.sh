#!/usr/bin/env bash
# tools/verify/m032-p04-acceptance-evidence-ledger.sh
# M032/P04/T05 — asserts M032-ACCEPTANCE-EVIDENCE.md present with
# BATTERY transcription + per-SC roll-up + back-link to runner per the
# M030/M031 evidence-ledger convention. Single-script-file shape per
# AD-19. Bash 3.2.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

LEDGER=".orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

if [ ! -f "$LEDGER" ]; then
  say_fail "evidence ledger missing at $LEDGER"
  printf 'SUMMARY: m032-p04-acceptance-evidence-ledger.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "ledger file present at $LEDGER"

# Required content tokens (one PASS per token, all must be present).
for _tok in 'BATTERY:' 'SC-1' 'SC-11' 'SC-13' 'run-acceptance-battery.sh' 'VALIDATE:'; do
  if grep -qF "$_tok" "$LEDGER"; then
    say_pass "ledger contains '$_tok'"
  else
    say_fail "ledger missing '$_tok'"
  fi
done

printf 'SUMMARY: m032-p04-acceptance-evidence-ledger.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

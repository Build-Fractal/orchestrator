#!/usr/bin/env bash
# tools/verify/m032-p04-validate-milestone.sh
# M032/P04/T05 — asserts validate-milestone.sh M032 reports VALIDATE: PASS
# per MIT-004 + SC-13. Single-script-file shape per AD-19. Bash 3.2.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

_out="${TMPDIR:-/tmp}/m032-p04-validate-$$.out"
bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M032/ > "$_out" 2>&1
_rc=$?
if [ "$_rc" -eq 0 ] && grep -q '^VALIDATE: PASS' "$_out"; then
  _line="$(grep '^VALIDATE: PASS' "$_out" | tail -1)"
  say_pass "validate-milestone.sh M032 final line: $_line"
else
  _tail="$(tail -3 "$_out" | tr '\n' ' ')"
  say_fail "validate-milestone.sh M032 rc=$_rc; tail=$_tail"
fi
rm -f "$_out"

printf 'SUMMARY: m032-p04-validate-milestone.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

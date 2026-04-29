#!/usr/bin/env bash
# scripts/verify/m028/p05-run-all-clean.sh -- M028/P05/T03 sub-gate clean
# verifier (P05-scoped sibling of p04-run-all-clean.sh).
#
# Invokes scripts/verify/m028/run-all.sh and asserts:
#   1. exit 0.
#   2. summary contains "M028: 7/7 findings verified".
#   3. skipped: 0 in the summary line.
#   4. No FAIL: lines.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
RUN_ALL="${script_dir}/run-all.sh"

if [ ! -f "$RUN_ALL" ]; then
  echo "FAIL: run-all.sh not found at $RUN_ALL" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT
bash "$RUN_ALL" > "$tmp_out" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then pass "run-all exit 0"; else fail "run-all exit" "rc=$rc"; fi

if grep -q 'M028: 7/7 findings verified' "$tmp_out"; then
  pass "run-all summary 7/7 findings verified"
else
  fail "run-all summary" "missing M028: 7/7 findings verified"
fi

if grep -q 'skipped: 0' "$tmp_out"; then
  pass "run-all skipped: 0"
else
  fail "run-all skip count" "skipped: 0 absent"
fi

if grep -q '^FAIL:' "$tmp_out"; then
  fail "run-all no FAIL lines" "FAIL lines present"
else
  pass "run-all no FAIL lines"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p05-run-all-clean.sh"
  exit 0
fi
echo "FAIL: p05-run-all-clean.sh ($fail_count failures)"
exit 1

#!/usr/bin/env bash
# scripts/verify/m028/p04-run-all-clean.sh -- M028 P04/T05 close-out gate.
#
# Runs `bash scripts/verify/m028/run-all.sh` and asserts:
#   1. exit 0.
#   2. Summary line contains "M028: 7/7 findings verified".
#   3. No "FAIL:" lines in output.
#   4. Skip count is 0 (post-P04 state -- D and E are no longer P04 deliverables).
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
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

out_tmp="$(mktemp)"
bash "$RUN_ALL" > "$out_tmp" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  pass "run-all.sh exit 0"
else
  fail "run-all.sh exit" "rc=$rc"
fi

if grep -q '^M028: 7/7 findings verified' "$out_tmp"; then
  pass "run-all.sh summary 7/7"
else
  fail "run-all.sh summary 7/7" "missing summary line"
fi

if grep -q '^FAIL:' "$out_tmp"; then
  fail "run-all.sh no failures" "FAIL lines present"
else
  pass "run-all.sh no failures"
fi

# Skip count check -- the summary line carries (skipped: <N>, failed: <M>).
if grep -qE 'skipped: 0' "$out_tmp"; then
  pass "run-all.sh skip count 0"
else
  fail "run-all.sh skip count" "non-zero skip count"
fi

rm -f "$out_tmp"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-run-all-clean.sh"
  exit 0
fi
echo "FAIL: p04-run-all-clean.sh ($fail_count failures)"
exit 1

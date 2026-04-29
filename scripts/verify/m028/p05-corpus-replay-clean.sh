#!/usr/bin/env bash
# scripts/verify/m028/p05-corpus-replay-clean.sh -- M028/P05/T03 sub-gate
# clean verifier.
#
# Invokes tests/run-prompt-corpus-replay.sh and asserts the canonical
# clean-pass shape: exit 0 + WOULD_PROMPT=0/27 + no FAIL: lines.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
HARNESS="${REPO_ROOT}/tests/run-prompt-corpus-replay.sh"

if [ ! -f "$HARNESS" ]; then
  echo "FAIL: harness not found at $HARNESS" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)" >&2; fail_count=$((fail_count + 1)); }

tmp_out="$(mktemp)"
trap 'rm -f "$tmp_out"' EXIT
bash "$HARNESS" > "$tmp_out" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then pass "corpus-replay exit 0"; else fail "corpus-replay exit" "rc=$rc"; fi

if grep -q '^WOULD_PROMPT=0/27$' "$tmp_out"; then
  pass "corpus-replay WOULD_PROMPT=0/27"
else
  fail "corpus-replay summary" "missing WOULD_PROMPT=0/27 line"
fi

if grep -q '^FAIL:' "$tmp_out"; then
  fail "corpus-replay no FAIL lines" "FAIL lines present"
else
  pass "corpus-replay no FAIL lines"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p05-corpus-replay-clean.sh"
  exit 0
fi
echo "FAIL: p05-corpus-replay-clean.sh ($fail_count failures)"
exit 1

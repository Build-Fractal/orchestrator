#!/usr/bin/env bash
# scripts/verify/m028/p05-downstream-fixture-clean.sh -- M028/P05/T02
# cross-cutting Truth-Check.
#
# Invokes tests/run-downstream-fixture.sh, captures output, and asserts
# the canonical clean-pass shape: exit 0 + WOULD_PROMPT=0/<N> + no
# 'command not found' + at least one PASS line.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"
HARNESS="${REPO_ROOT}/tests/run-downstream-fixture.sh"

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

if [ "$rc" -eq 0 ]; then
  pass "harness exit 0"
else
  fail "harness exit" "rc=$rc"
fi

if grep -qE '^WOULD_PROMPT=0/[0-9]+$' "$tmp_out"; then
  pass "harness summary WOULD_PROMPT=0/<N>"
else
  fail "harness summary" "missing canonical WOULD_PROMPT=0/<N> line"
fi

if grep -q 'command not found' "$tmp_out"; then
  fail "no 'command not found'" "command-not-found substring present"
else
  pass "no 'command not found' substring"
fi

if grep -q '^PASS:' "$tmp_out"; then
  pass "harness emitted PASS lines"
else
  fail "harness PASS lines" "no PASS lines in output"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p05-downstream-fixture-clean.sh"
  exit 0
fi
echo "FAIL: p05-downstream-fixture-clean.sh ($fail_count failures)"
exit 1

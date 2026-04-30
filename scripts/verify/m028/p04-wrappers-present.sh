#!/usr/bin/env bash
# scripts/verify/m028/p04-wrappers-present.sh -- M028 P04/T05 cross-cutting verifier.
#
# Asserts each of the 4 investigation-pattern wrappers exists under
# scripts/util/ and produces a usage-error diagnostic on no-args invocation
# (exit code 2 + diagnostic on stderr).
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "${script_dir}/../../.." && pwd -P)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

WRAPPERS="grep-files.sh cleanup-stale-results.sh node-eval.sh peek-files.sh"

for w in $WRAPPERS; do
  path="${REPO_ROOT}/scripts/util/${w}"
  if [ ! -f "$path" ]; then
    fail "$w exists" "missing $path"
    continue
  fi
  pass "$w exists at $path"
  # Usage error on no args -> exit 2 + diagnostic on stderr.
  err_tmp="$(mktemp)"
  bash "$path" 2>"$err_tmp" >/dev/null
  rc=$?
  err_text="$(cat "$err_tmp")"
  rm -f "$err_tmp"
  if [ "$rc" -eq 2 ] && [ -n "$err_text" ]; then
    pass "$w usage-error rc=2 + stderr diagnostic"
  else
    fail "$w usage-error" "rc=$rc stderr=[$err_text]"
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-wrappers-present.sh"
  exit 0
fi
echo "FAIL: p04-wrappers-present.sh ($fail_count failures)"
exit 1

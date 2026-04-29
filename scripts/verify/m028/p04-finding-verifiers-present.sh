#!/usr/bin/env bash
# scripts/verify/m028/p04-finding-verifiers-present.sh -- M028 P04/T05 cross-cutting verifier.
#
# Asserts each of the 7 per-finding verifiers (plus the wrapper-side G axis)
# exists under scripts/verify/m028/ AND is named in the run-all.sh VERIFIERS
# list.
#
# AD-19 single-script-file flat shape. Bash 3.2 + POSIX-sh-safe. No jq.

set -u

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
M028_DIR="$script_dir"
RUN_ALL="${M028_DIR}/run-all.sh"

if [ ! -f "$RUN_ALL" ]; then
  echo "FAIL: run-all.sh not found at $RUN_ALL" >&2
  exit 1
fi

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

VERIFIERS="finding-A-verifier.sh finding-B-verifier.sh finding-C-verifier.sh finding-D-verifier.sh finding-E-verifier.sh finding-F-verifier.sh finding-G-classifier-verifier.sh finding-G-wrapper-verifier.sh"

for v in $VERIFIERS; do
  path="${M028_DIR}/${v}"
  if [ ! -f "$path" ]; then
    fail "$v exists" "missing $path"
    continue
  fi
  pass "$v exists at $path"
  if grep -q "$v" "$RUN_ALL"; then
    pass "$v listed in run-all.sh"
  else
    fail "$v in run-all.sh" "not named in VERIFIERS list"
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: p04-finding-verifiers-present.sh"
  exit 0
fi
echo "FAIL: p04-finding-verifiers-present.sh ($fail_count failures)"
exit 1

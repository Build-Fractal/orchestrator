#!/usr/bin/env bash
# tools/verify/m032-p02-seam-a-shape.sh — T05 verifier.
#
# Asserts the Seam-A paired-launch script exists, is executable, and
# contains the load-bearing literals that pin its semantic contract:
#   Seam-A, project_assets:, M033, source=, target=, mode=
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
F="$PROJECT_ROOT/tests/paired-m032-m033/seam-A.sh"

pass=0
fail=0

check() {
  desc="$1"; rc="$2"
  if [ "$rc" -eq 0 ]; then
    printf 'PASS: %s\n' "$desc"; pass=$((pass + 1))
  else
    printf 'FAIL: %s\n' "$desc"; fail=$((fail + 1))
  fi
}

[ -f "$F" ]; check "Seam-A script exists at $F" $?
[ -x "$F" ]; check "Seam-A script is executable" $?

grep -q 'Seam-A' "$F"; check "Seam-A literal present in script" $?
grep -q 'project_assets:' "$F"; check "project_assets: schema reference present" $?
grep -q 'M033' "$F"; check "M033 paired-launch reference present" $?
grep -q 'source=wiki/' "$F"; check "wiki/ tuple presence assertion present" $?
grep -q 'source=' "$F"; check "source= field reference present" $?
grep -q 'target=' "$F"; check "target= field reference present" $?
grep -q 'mode=' "$F"; check "mode= field reference present" $?

printf 'SUMMARY: m032-p02-seam-a-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0

#!/usr/bin/env bash
# tools/verify/m032-p02-seam-c-shape.sh — T05 verifier.
#
# Asserts the Seam-C paired-launch script exists, is executable, and contains
# the load-bearing literals that pin its semantic contract:
#   Seam-C, wiki/glossary.md, format invariant, ###, alphabetized
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
F="$PROJECT_ROOT/tests/paired-m032-m033/seam-C.sh"

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

[ -f "$F" ]; check "Seam-C script exists at $F" $?
[ -x "$F" ]; check "Seam-C script is executable" $?

grep -q 'Seam-C' "$F"; check "Seam-C literal present in script" $?
grep -q 'wiki/glossary.md' "$F"; check "wiki/glossary.md path reference present" $?
grep -q 'format invariant' "$F"; check "format invariant literal present in script" $?
grep -q '###' "$F"; check "### TERM heading reference present" $?
grep -q 'alphabetized' "$F"; check "alphabetized literal present in script" $?

printf 'SUMMARY: m032-p02-seam-c-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0

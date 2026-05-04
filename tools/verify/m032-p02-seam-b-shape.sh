#!/usr/bin/env bash
# tools/verify/m032-p02-seam-b-shape.sh — T05 verifier.
#
# Asserts the Seam-B paired-launch script exists, is executable, and contains
# the load-bearing literals that pin its semantic contract:
#   Seam-B, FR-11, MIT-011, M032_WIKI_INIT_FORCE_EXIT, init-complete, wiki-pending
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
F="$PROJECT_ROOT/tests/paired-m032-m033/seam-B.sh"

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

[ -f "$F" ]; check "Seam-B script exists at $F" $?
[ -x "$F" ]; check "Seam-B script is executable" $?

grep -q 'Seam-B' "$F"; check "Seam-B literal present in script" $?
grep -q 'FR-11' "$F"; check "FR-11 literal present in script" $?
grep -q 'MIT-011' "$F"; check "MIT-011 literal present in script" $?
grep -q 'M032_WIKI_INIT_FORCE_EXIT' "$F"; check "M032_WIKI_INIT_FORCE_EXIT env-var injection literal present" $?
grep -q 'init-complete, wiki-pending' "$F"; check "init-complete, wiki-pending diagnostic literal present" $?
grep -q -- '--with-wiki' "$F"; check "--with-wiki flag literal present" $?
grep -q 'M033-MIT-001\|M033/P01..P04' "$F"; check "M033 stub-mode compatibility reference present" $?

printf 'SUMMARY: m032-p02-seam-b-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0

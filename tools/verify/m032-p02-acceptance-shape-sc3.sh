#!/usr/bin/env bash
# tools/verify/m032-p02-acceptance-shape-sc3.sh — T05 verifier.
#
# Asserts the SC-3 acceptance script exists, is executable, and contains
# the load-bearing literals that pin its semantic contract:
#   SC-3, FR-5, FR-6, FR-12, wiki-serve.sh, MIT-001
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
F="$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-init-default-scope.sh"

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

[ -f "$F" ]; check "SC-3 acceptance script exists at $F" $?
[ -x "$F" ]; check "SC-3 acceptance script is executable" $?

grep -q 'SC-3' "$F"; check "SC-3 literal present in script" $?
grep -q 'FR-5' "$F"; check "FR-5 literal present in script" $?
grep -q 'FR-6' "$F"; check "FR-6 literal present in script" $?
grep -q 'FR-12' "$F"; check "FR-12 literal present in script" $?
grep -q 'wiki-serve' "$F"; check "wiki-serve probe reference present in script" $?
grep -q 'MIT-001' "$F"; check "MIT-001 SKIP semantics literal present in script" $?
grep -q 'SKIP_REASON' "$F"; check "SKIP_REASON token present (exit-77 contract)" $?
grep -q 'exit 77' "$F"; check "exit 77 present (POSIX skip code)" $?

printf 'SUMMARY: m032-p02-acceptance-shape-sc3.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0

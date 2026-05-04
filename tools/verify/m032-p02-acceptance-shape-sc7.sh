#!/usr/bin/env bash
# tools/verify/m032-p02-acceptance-shape-sc7.sh — T05 verifier.
#
# Asserts the SC-7 acceptance script exists, is executable, and contains
# the load-bearing literals that pin its semantic contract:
#   SC-7, FR-15, FR-16, MIT-010, --profile=quick, gloss-foo
#
# Bash 3.2 compatible (MEM001).

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
F="$PROJECT_ROOT/tests/m032-acceptance/p02-glossary-surface.sh"

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

[ -f "$F" ]; check "SC-7 acceptance script exists at $F" $?
[ -x "$F" ]; check "SC-7 acceptance script is executable" $?

grep -q 'SC-7' "$F"; check "SC-7 literal present in script" $?
grep -q 'FR-15' "$F"; check "FR-15 literal present in script" $?
grep -q 'FR-16' "$F"; check "FR-16 literal present in script" $?
grep -q 'MIT-010' "$F"; check "MIT-010 literal present in script" $?
grep -q -- '--profile=quick' "$F"; check "--profile=quick token present" $?
grep -q -- '--profile=standard' "$F"; check "--profile=standard token present" $?
grep -q 'gloss-foo' "$F"; check "gloss-foo token present (Quick+task-desc check)" $?
grep -q 'safe-default-no-terms\|safe-default' "$F"; check "MIT-010 safe-default reference present" $?

printf 'SUMMARY: m032-p02-acceptance-shape-sc7.sh pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0

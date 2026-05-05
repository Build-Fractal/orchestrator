#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc6.sh — SC-6 artifact-shape guard.
#
# Asserts the SC-6 acceptance script exists, is executable, and contains
# the load-bearing tokens that pin its FR-14 + MIT-005 contract.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh"

pass=0
fail=0

say_pass() {
  pass=$((pass + 1))
  printf 'PASS: %s\n' "$1"
}

say_fail() {
  fail=$((fail + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

if [ ! -x "$ACC" ]; then
  say_fail "$ACC absent or non-executable"
  printf 'SUMMARY: m032-p03-acceptance-shape-sc6 pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

for tok in 'SC-6' 'FR-14' 'MIT-005' 'auto-nav' 'custom-nav' \
           'M012-P01 nav' 'Migrated' 'byte-identical'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-6 contains: $tok"
  else
    say_fail "SC-6 missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-acceptance-shape-sc6 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

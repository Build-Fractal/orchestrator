#!/usr/bin/env bash
# tools/verify/p07-corpus-block.sh — M030/P07/T01
#
# Asserts shadow-compare.sh against tests/m030-acceptance/corpus-block.jsonl
# (60 records, 20/class — count<50 per class drives all classes unstable)
# emits flip_recommendation=block (D-A1 verdict closed-enum value 3 of 4).
#
# Bash 3.2 compatible. AD-19 single-script-file shape: tmp-file
# intermediate instead of pipes-in-command-substitution.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SHADOW_COMPARE="$PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh"
CORPUS="$PROJECT_ROOT/tests/m030-acceptance/corpus-block.jsonl"

pass=0
fail=0

if [ ! -f "$CORPUS" ]; then
  printf 'FAIL: corpus missing: %s — run tests/m030-acceptance/shadow-corpus-fixtures.sh first\n' "$CORPUS"
  printf 'SUMMARY: p07-corpus-block.sh pass=0 fail=1\n'
  exit 1
fi

out_tmp="/tmp/p07-corpus-block-$$.out"
rm -f "$out_tmp" 2>/dev/null

bash "$SHADOW_COMPARE" --corpus "$CORPUS" > "$out_tmp" 2>/dev/null
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: shadow-compare.sh exited %d (expected 0)\n' "$rc"
fi

grep -q '^flip_recommendation=block$' "$out_tmp"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: expected flip_recommendation=block; got:\n'
  cat "$out_tmp"
fi

rm -f "$out_tmp" 2>/dev/null

printf 'SUMMARY: p07-corpus-block.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

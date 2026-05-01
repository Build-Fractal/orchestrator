#!/usr/bin/env bash
# tools/verify/p07-corpus-zero-evidence-insufficient.sh — M030/P07/T01
#
# Asserts shadow-compare.sh against tests/m030-acceptance/corpus-zero.jsonl
# (empty corpus) emits flip_recommendation=evidence_insufficient
# (D-A1 verdict closed-enum value 4 of 4 — FR-8 floor: total_count==0).
#
# Bash 3.2 compatible. AD-19 single-script-file shape: tmp-file
# intermediate instead of pipes-in-command-substitution.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SHADOW_COMPARE="$PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh"
CORPUS="$PROJECT_ROOT/tests/m030-acceptance/corpus-zero.jsonl"

pass=0
fail=0

if [ ! -f "$CORPUS" ]; then
  printf 'FAIL: corpus missing: %s — run tests/m030-acceptance/shadow-corpus-fixtures.sh first\n' "$CORPUS"
  printf 'SUMMARY: p07-corpus-zero-evidence-insufficient.sh pass=0 fail=1\n'
  exit 1
fi

out_tmp="/tmp/p07-corpus-zero-evidence-insufficient-$$.out"
rm -f "$out_tmp" 2>/dev/null

bash "$SHADOW_COMPARE" --corpus "$CORPUS" > "$out_tmp" 2>/dev/null
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: shadow-compare.sh exited %d (expected 0)\n' "$rc"
fi

grep -q '^flip_recommendation=evidence_insufficient$' "$out_tmp"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: expected flip_recommendation=evidence_insufficient; got:\n'
  cat "$out_tmp"
fi

rm -f "$out_tmp" 2>/dev/null

printf 'SUMMARY: p07-corpus-zero-evidence-insufficient.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

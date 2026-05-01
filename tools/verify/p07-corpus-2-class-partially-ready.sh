#!/usr/bin/env bash
# tools/verify/p07-corpus-2-class-partially-ready.sh — M030/P07/T01
#
# Asserts shadow-compare.sh against tests/m030-acceptance/corpus-2-class-only.jsonl
# (50 mechanical + 50 standard, 0 novel) emits:
#   - flip_recommendation=partially_ready (D-A1 verdict closed-enum value 2)
#   - withheld_classes=novel             (D-A3 conservative-construction enumeration:
#                                          the under-threshold class with default
#                                          tier=`smart`)
#
# Note: shadow-compare.sh emits the per-class enumeration line as
# `withheld_classes=<csv>` listing the under-threshold (withheld) classes
# — NOT the flippable ones. The plan's prose phrased the gate as
# "flippable-classes enumeration"; per the plan's amendment guidance
# (`shadow-compare.sh` is the contract), this verifier asserts against
# the actual emitted shape.
#
# Bash 3.2 compatible. AD-19 single-script-file shape: tmp-file
# intermediate instead of pipes-in-command-substitution.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SHADOW_COMPARE="$PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh"
CORPUS="$PROJECT_ROOT/tests/m030-acceptance/corpus-2-class-only.jsonl"

pass=0
fail=0

if [ ! -f "$CORPUS" ]; then
  printf 'FAIL: corpus missing: %s — run tests/m030-acceptance/shadow-corpus-fixtures.sh first\n' "$CORPUS"
  printf 'SUMMARY: p07-corpus-2-class-partially-ready.sh pass=0 fail=1\n'
  exit 1
fi

out_tmp="/tmp/p07-corpus-2-class-partially-ready-$$.out"
rm -f "$out_tmp" 2>/dev/null

bash "$SHADOW_COMPARE" --corpus "$CORPUS" > "$out_tmp" 2>/dev/null
rc=$?

if [ "$rc" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: shadow-compare.sh exited %d (expected 0)\n' "$rc"
fi

grep -q '^flip_recommendation=partially_ready$' "$out_tmp"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: expected flip_recommendation=partially_ready; got:\n'
  cat "$out_tmp"
fi

# Per-class enumeration: under-threshold class (novel) is withheld
# because its routing-table default is `smart` (D-A3 safety gate).
grep -q '^withheld_classes=novel$' "$out_tmp"
if [ $? -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'FAIL: expected withheld_classes=novel; got:\n'
  cat "$out_tmp"
fi

rm -f "$out_tmp" 2>/dev/null

printf 'SUMMARY: p07-corpus-2-class-partially-ready.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1

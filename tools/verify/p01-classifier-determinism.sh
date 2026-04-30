#!/usr/bin/env bash
# tools/verify/p01-classifier-determinism.sh -- SC-1 byte-equality gate.
#
# Two consecutive runs of scripts/dispatch/classify-task.sh against the same
# plan path MUST produce byte-identical stdout.
#
# Output contract: stdout final line is
#   SUMMARY: p01-classifier-determinism.sh pass=N fail=M
# Exit 0 iff fail=0.
#
# Bash 3.2 compatible. AD-19 single-script-file shape (no compound chains
# beyond trivial pairs, no $() with pipes feeding compound operators, no
# process substitution).

set -uo pipefail

CLASSIFIER="scripts/dispatch/classify-task.sh"
LABELS="tests/fixtures/m030-classifier-corpus/labels.yml"

PLAN_PATH="${1:-}"

pass=0
fail=0

if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: $CLASSIFIER not found"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-determinism.sh pass=$pass fail=$fail"
  exit 1
fi

if [ -z "$PLAN_PATH" ]; then
  if [ ! -f "$LABELS" ]; then
    echo "FAIL: cannot derive default plan -- $LABELS missing"
    fail=$((fail + 1))
    echo "SUMMARY: p01-classifier-determinism.sh pass=$pass fail=$fail"
    exit 1
  fi
  PLAN_PATH=$(grep -E '^  - plan_path:' "$LABELS" | head -1 | sed 's/^  - plan_path:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
fi

if [ ! -f "$PLAN_PATH" ]; then
  echo "FAIL: plan path not found: $PLAN_PATH"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-determinism.sh pass=$pass fail=$fail"
  exit 1
fi

OUT_A="/tmp/p01-determinism-a.out"
OUT_B="/tmp/p01-determinism-b.out"
DIFF_OUT="/tmp/p01-determinism-diff.out"

bash "$CLASSIFIER" "$PLAN_PATH" > "$OUT_A" 2>/dev/null
rc_a=$?
bash "$CLASSIFIER" "$PLAN_PATH" > "$OUT_B" 2>/dev/null
rc_b=$?

if [ "$rc_a" -ne 0 ] || [ "$rc_b" -ne 0 ]; then
  echo "FAIL: classifier exited non-zero (rc_a=$rc_a rc_b=$rc_b) on $PLAN_PATH"
  fail=$((fail + 1))
  rm -f "$OUT_A" "$OUT_B" "$DIFF_OUT"
  echo "SUMMARY: p01-classifier-determinism.sh pass=$pass fail=$fail"
  exit 1
fi

# Byte-equality check.
diff "$OUT_A" "$OUT_B" > "$DIFF_OUT" 2>&1
rc_diff=$?

if [ "$rc_diff" -eq 0 ]; then
  echo "OK: classifier output byte-identical across two runs ($PLAN_PATH)"
  pass=$((pass + 1))
else
  echo "FAIL: classifier output diverges across two runs"
  echo "----- run A -----"
  cat "$OUT_A"
  echo "----- run B -----"
  cat "$OUT_B"
  echo "----- diff -----"
  cat "$DIFF_OUT"
  fail=$((fail + 1))
fi

# Shape check: each run produced exactly two lines matching the closed enums.
line_count_a=$(wc -l < "$OUT_A" | tr -d ' ')
if [ "$line_count_a" -ne 2 ]; then
  echo "FAIL: run A produced $line_count_a lines, expected 2"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

line1=$(sed -n '1p' "$OUT_A")
line2=$(sed -n '2p' "$OUT_A")

if printf '%s\n' "$line1" | grep -q -E '^character=(mechanical|standard|novel)$'; then
  echo "OK: line 1 matches character closed enum"
  pass=$((pass + 1))
else
  echo "FAIL: line 1 does not match ^character=(mechanical|standard|novel)\$ -- got: $line1"
  fail=$((fail + 1))
fi

if printf '%s\n' "$line2" | grep -q -E '^confidence=(high|medium|low)$'; then
  echo "OK: line 2 matches confidence closed enum"
  pass=$((pass + 1))
else
  echo "FAIL: line 2 does not match ^confidence=(high|medium|low)\$ -- got: $line2"
  fail=$((fail + 1))
fi

rm -f "$OUT_A" "$OUT_B" "$DIFF_OUT"

echo "SUMMARY: p01-classifier-determinism.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi

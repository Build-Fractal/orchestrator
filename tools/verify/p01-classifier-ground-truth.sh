#!/usr/bin/env bash
# tools/verify/p01-classifier-ground-truth.sh -- SC-10 >=85% agreement gate.
#
# For every entry in tests/fixtures/m030-classifier-corpus/labels.yml, run
# scripts/dispatch/classify-task.sh and compare the emitted character to the
# human-applied label. Compute total agreement and per-class breakdown.
# Assert agree * 100 / total >= 85 (for total=40, threshold is 34).
#
# Output contract: stdout final line is
#   SUMMARY: p01-classifier-ground-truth.sh pass=N fail=M
# Exit 0 iff fail=0 (i.e., agreement >= 85%).
#
# YAML parsing: pure shell case statements over each line; no jq.
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -uo pipefail

CLASSIFIER="scripts/dispatch/classify-task.sh"
LABELS="${1:-tests/fixtures/m030-classifier-corpus/labels.yml}"
THRESHOLD_PCT=85

pass=0
fail=0

if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL: $CLASSIFIER not found"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-ground-truth.sh pass=$pass fail=$fail"
  exit 1
fi

if [ ! -f "$LABELS" ]; then
  echo "FAIL: $LABELS not found"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-ground-truth.sh pass=$pass fail=$fail"
  exit 1
fi

agree=0
disagree=0
mech_agree=0; mech_total=0
std_agree=0;  std_total=0
nov_agree=0;  nov_total=0
disagreements=""

current_path=""

while IFS= read -r line; do
  case "$line" in
    "  - plan_path: "*)
      val="${line#  - plan_path: }"
      val="${val#\"}"
      val="${val%\"}"
      current_path="$val"
      ;;
    "    character: "*)
      val="${line#    character: }"
      val="${val#\"}"
      val="${val%\"}"
      current_label="$val"
      if [ -z "$current_path" ]; then
        continue
      fi
      if [ ! -f "$current_path" ]; then
        echo "FAIL: plan path missing on disk: $current_path"
        fail=$((fail + 1))
        continue
      fi
      out=$(bash "$CLASSIFIER" "$current_path" 2>/dev/null)
      got=$(printf '%s\n' "$out" | grep '^character=' | head -1 | sed 's/^character=//')
      case "$current_label" in
        mechanical) mech_total=$((mech_total + 1)) ;;
        standard)   std_total=$((std_total + 1)) ;;
        novel)      nov_total=$((nov_total + 1)) ;;
      esac
      if [ "$got" = "$current_label" ]; then
        agree=$((agree + 1))
        case "$current_label" in
          mechanical) mech_agree=$((mech_agree + 1)) ;;
          standard)   std_agree=$((std_agree + 1)) ;;
          novel)      nov_agree=$((nov_agree + 1)) ;;
        esac
      else
        disagree=$((disagree + 1))
        disagreements="${disagreements}DIS: $current_path expected=$current_label got=$got
"
      fi
      ;;
  esac
done < "$LABELS"

total=$((agree + disagree))

printf 'mechanical: %d/%d agree\n' "$mech_agree" "$mech_total"
printf 'standard:   %d/%d agree\n' "$std_agree" "$std_total"
printf 'novel:      %d/%d agree\n' "$nov_agree" "$nov_total"

if [ "$total" -le 0 ]; then
  echo "FAIL: zero entries scored"
  fail=$((fail + 1))
  echo "SUMMARY: p01-classifier-ground-truth.sh pass=$pass fail=$fail"
  exit 1
fi

# Compute agreement percentage (integer).
pct=$((agree * 100 / total))
# Threshold: ceil(THRESHOLD_PCT * total / 100).
need=$(( (THRESHOLD_PCT * total + 99) / 100 ))

printf 'TOTAL:      %d/%d = %d%% (threshold: %d agreements = %d%%)\n' "$agree" "$total" "$pct" "$need" "$THRESHOLD_PCT"

if [ "$agree" -ge "$need" ]; then
  echo "OK: agreement $agree/$total ($pct%) meets >=$THRESHOLD_PCT% threshold"
  pass=$((pass + 1))
else
  echo "FAIL: agreement $agree/$total ($pct%) below $THRESHOLD_PCT% threshold (need $need)"
  printf '%s' "$disagreements"
  fail=$((fail + 1))
fi

echo "SUMMARY: p01-classifier-ground-truth.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi

#!/usr/bin/env bash
# tests/fixtures/m030-p06/synthesize-corpus.sh
# Emits five fixture corpora (regression-mechanical.jsonl, regression-standard.jsonl,
# regression-novel.jsonl, no-regression.jsonl, below-min-sample.jsonl) to siblings of
# this script. Idempotent — re-running produces byte-identical output.
#
# Schema mirrors the post-P04 shadow-on dispatch_usage record shape with the additive
# `character` field that M030/P06/T02 will introduce on dispatch-interface.sh. T01
# carries the field forward-compatibly so the T02 verifiers have valid input.
#
# Layout per file:
#   regression-mechanical.jsonl — 20 records character=mechanical (12 fail / 8 pass)
#   regression-standard.jsonl   — 20 records character=standard   (12 fail / 8 pass)
#   regression-novel.jsonl      — 20 records character=novel      (12 fail / 8 pass)
#   no-regression.jsonl         — 60 records (20 per class, 4 fail / 16 pass each)
#   below-min-sample.jsonl      — 5 mechanical records (3 fail / 2 pass)

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Tier resolution mirrors templates/model-routing.yml default routing.
tier_for_class() {
  case "$1" in
    mechanical) echo "fast" ;;
    standard) echo "balanced" ;;
    novel) echo "smart" ;;
  esac
}

model_for_tier() {
  case "$1" in
    fast) echo "claude-haiku-4-5" ;;
    balanced) echo "claude-sonnet-4-7" ;;
    smart) echo "claude-opus-4-7" ;;
  esac
}

emit_record() {
  # $1 task-suffix (e.g., "T01"); $2 character; $3 escalation_count;
  # $4 escalation_reason; $5 ts.
  local task_n="$1"
  local character="$2"
  local esc_count="$3"
  local esc_reason="$4"
  local ts="$5"
  local tier
  tier="$(tier_for_class "$character")"
  local model
  model="$(model_for_tier "$tier")"
  printf '{"record_type":"dispatch_usage","unitId":"M999/P01/%s","milestone":"M999","phase":"P01","task":"%s","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":512,"estimated_cost_usd":0.01536000,"pricing_version":"2026-04-17","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"high","model_routed":"%s","model_used":"%s","partial_flip_active":false,"withheld_classes":"","override_source":"none","escalation_count":%s,"escalation_reason":"%s","character":"%s"}\n' \
    "$task_n" "$task_n" "$model" "$ts" "$tier" "$model" "$esc_count" "$esc_reason" "$character"
}

# regression-<class>.jsonl: 20 records per class; first 12 fail, last 8 pass.
synthesize_regression_corpus() {
  local character="$1"
  local out="$SCRIPT_DIR/regression-$character.jsonl"
  : > "$out"
  local n=1
  local task_n
  while [ "$n" -le 12 ]; do
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 1 "verifier_fail" "2026-04-30T11:$(printf '%02d' "$n"):00Z" >> "$out"
    n=$((n + 1))
  done
  while [ "$n" -le 20 ]; do
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 0 "" "2026-04-30T11:$(printf '%02d' "$n"):00Z" >> "$out"
    n=$((n + 1))
  done
}

synthesize_regression_corpus mechanical
synthesize_regression_corpus standard
synthesize_regression_corpus novel

# no-regression.jsonl: 60 records; per class 4 fail / 16 pass (pass_rate=0.80).
out="$SCRIPT_DIR/no-regression.jsonl"
: > "$out"
class_idx=0
for character in mechanical standard novel; do
  base=$((class_idx * 20))
  i=1
  while [ "$i" -le 4 ]; do
    n=$((base + i))
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 1 "verifier_fail" "2026-04-30T12:$(printf '%02d' "$n"):00Z" >> "$out"
    i=$((i + 1))
  done
  while [ "$i" -le 20 ]; do
    n=$((base + i))
    task_n="$(printf 'T%02d' "$n")"
    emit_record "$task_n" "$character" 0 "" "2026-04-30T12:$(printf '%02d' "$n"):00Z" >> "$out"
    i=$((i + 1))
  done
  class_idx=$((class_idx + 1))
done

# below-min-sample.jsonl: 5 mechanical records (3 fail / 2 pass).
out="$SCRIPT_DIR/below-min-sample.jsonl"
: > "$out"
n=1
while [ "$n" -le 3 ]; do
  task_n="$(printf 'T%02d' "$n")"
  emit_record "$task_n" "mechanical" 1 "verifier_fail" "2026-04-30T13:$(printf '%02d' "$n"):00Z" >> "$out"
  n=$((n + 1))
done
while [ "$n" -le 5 ]; do
  task_n="$(printf 'T%02d' "$n")"
  emit_record "$task_n" "mechanical" 0 "" "2026-04-30T13:$(printf '%02d' "$n"):00Z" >> "$out"
  n=$((n + 1))
done

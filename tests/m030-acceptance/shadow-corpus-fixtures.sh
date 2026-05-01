#!/usr/bin/env bash
# tests/m030-acceptance/shadow-corpus-fixtures.sh — M030/P07/T01
#
# Idempotent acceptance-corpus synthesizer for M030/P07.
# Generates four corpora exercising the four shadow-compare.sh verdicts
# at acceptance scale:
#
#   corpus-50-per-class.jsonl   (150 records, 50/class) -> ready
#   corpus-zero.jsonl           (0 records)             -> evidence_insufficient
#   corpus-2-class-only.jsonl   (100 records, 50 mech + 50 std, 0 novel)
#                                                       -> partially_ready
#   corpus-block.jsonl          (60 records, 20/class)  -> block
#                               (count<50 per class drives instability)
#
# Idempotent: re-running produces byte-identical output. Deterministic
# timestamps via loop-index; no `date`-derived fields.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$SCRIPT_DIR"
mkdir -p "$OUT_DIR"

# emit_record — emit one dispatch_usage JSON line.
# Record shape mirrors scripts/dispatch/dispatch-interface.sh shadow-on
# happy-path emit (line 630), with the `character` additive field.
# Args:
#   $1 unitId       $2 milestone   $3 phase    $4 task
#   $5 character    $6 model_routed (fast|balanced|smart)
#   $7 model_used   $8 classifier_confidence (high|medium|low)
#   $9 timestamp_iso8601
emit_record() {
  printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":0,"estimated_cost_usd":0.01536000,"pricing_version":"2026-04-17","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":false,"withheld_classes":"","character":"%s"}\n' \
    "$1" "$2" "$3" "$4" "$7" "$9" "$8" "$6" "$7" "$5"
}

# format_ts — deterministic timestamp formatter.
# Args: $1 minute-offset (0..1439)
format_ts() {
  local m="$1"
  printf '2026-04-30T%02d:%02d:00Z' $((m / 60)) $((m % 60))
}

# emit_class_records — N records of a given class, deterministic timestamps.
# Args: $1 class  $2 count  $3 model_routed  $4 confidence  $5 base_minute
emit_class_records() {
  local class="$1" count="$2" routed="$3" conf="$4" base_minute="$5"
  local i=0
  local minute
  local ts
  local unit_suffix
  while [ "$i" -lt "$count" ]; do
    minute=$((base_minute + i))
    ts="$(format_ts "$minute")"
    unit_suffix="$(printf 'T%03d' "$i")"
    emit_record \
      "M999/P01/${unit_suffix}" "M999" "P01" "$unit_suffix" \
      "$class" "$routed" "$routed" "$conf" "$ts"
    i=$((i + 1))
  done
}

# emit_block_class_records — same as emit_class_records but uses a
# different unit-id namespace (M999/P02/...) so the block corpus does
# not collide with the per-class records' identifiers when corpora are
# concatenated downstream.
# Args: $1 class  $2 count  $3 model_routed  $4 confidence  $5 base_minute
emit_block_class_records() {
  local class="$1" count="$2" routed="$3" conf="$4" base_minute="$5"
  local i=0
  local minute
  local ts
  local unit_suffix
  while [ "$i" -lt "$count" ]; do
    minute=$((base_minute + i))
    ts="$(format_ts "$minute")"
    unit_suffix="$(printf 'T%03d' "$i")"
    emit_record \
      "M999/P02/${unit_suffix}" "M999" "P02" "$unit_suffix" \
      "$class" "$routed" "$routed" "$conf" "$ts"
    i=$((i + 1))
  done
}

# ---------- corpus-50-per-class.jsonl (drives ready) ----------
# 150 records, 50/class, all confidence=high.
# Each class meets count >= 50 AND variance < 0.10 -> all stable -> ready.
{
  emit_class_records "mechanical" 50 "fast"     "high" 0
  emit_class_records "standard"   50 "balanced" "high" 50
  emit_class_records "novel"      50 "smart"    "high" 100
} > "$OUT_DIR/corpus-50-per-class.jsonl"

# ---------- corpus-zero.jsonl (drives evidence_insufficient) ----------
# Empty file: total_count=0 -> evidence_insufficient.
: > "$OUT_DIR/corpus-zero.jsonl"

# ---------- corpus-2-class-only.jsonl (drives partially_ready) ----------
# 100 records, 50 mechanical + 50 standard, 0 novel.
# Mechanical & standard stable; novel under-threshold (count=0).
# Novel's routing-table default is `smart` (D-A3 conservative gate)
# -> partially_ready, withheld_classes=novel.
{
  emit_class_records "mechanical" 50 "fast"     "high" 0
  emit_class_records "standard"   50 "balanced" "high" 50
} > "$OUT_DIR/corpus-2-class-only.jsonl"

# ---------- corpus-block.jsonl (drives block) ----------
# 60 records, 20/class. Each class has count=20 < CLASS_COVERAGE_MIN=50,
# so every class is unstable. stable_count=0, so verdict logic falls
# through partially_ready (which requires stable_count>=2) and emits
# block. Confidence values are not load-bearing here — count alone
# drives the verdict — but we set them deterministically anyway.
{
  emit_block_class_records "mechanical" 20 "fast"     "high" 0
  emit_block_class_records "standard"   20 "balanced" "high" 20
  emit_block_class_records "novel"      20 "smart"    "high" 40
} > "$OUT_DIR/corpus-block.jsonl"

echo "SYNTHESIZED: corpus-50-per-class.jsonl corpus-zero.jsonl corpus-2-class-only.jsonl corpus-block.jsonl"

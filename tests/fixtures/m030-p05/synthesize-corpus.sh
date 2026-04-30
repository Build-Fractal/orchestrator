#!/usr/bin/env bash
# tests/fixtures/m030-p05/synthesize-corpus.sh — M030/P05/T01 live-routed
# corpus synthesizer.
#
# Idempotent fixture-data generator. Re-running produces byte-identical
# JSONL output (timestamps are deterministic minute-slot values, not
# wall-clock). The committed live-routed-corpus.jsonl in this directory
# is the canonical fixture; this script is committed alongside so future
# maintainers can rebuild from scratch when the schema evolves.
#
# Output:
#   live-routed-corpus.jsonl  — 23 records (14 fast / 7 balanced / 2 smart)
#                               post-P04 dispatch_usage schema, all carry
#                               model_routed + model_used + the M030
#                               additive fields (override_source=none,
#                               escalation_count=0, escalation_reason="",
#                               classifier_confidence=high,
#                               partial_flip_active=false,
#                               withheld_classes="").
#
# Per-tier distribution (14 / 7 / 2) gives the SC-8 dispatch-count gate
# non-trivial integers and the cost-aggregation gate variance across all
# three cost_rates: tiers.
#
# Strategy A capture pattern (per T01 plan): the goldens are captured
# against tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl using
# ORCHESTRATOR_ROOT carve-out for the footer. This corpus is consumed by
# T02's --by-model verifiers (not by the SC-11 byte-equality gates).
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out applies (this
# script is fixture-data SSOT, not a verifier — pipes / awk / printf
# expansions permitted). Verifiers downstream remain strict AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/live-routed-corpus.jsonl"
: > "$OUT"

emit_record() {
  # $1 = sequential record number (1..23)
  # $2 = symbolic tier (fast | balanced | smart)
  # $3 = resolved model id (claude-haiku-4-5 | claude-sonnet-4-7 | claude-opus-4-7)
  # $4 = ISO8601 timestamp
  local n="$1"
  local tier="$2"
  local model_id="$3"
  local ts="$4"
  printf '{"record_type":"dispatch_usage","unitId":"M999/P01/T%02d","milestone":"M999","phase":"P01","task":"T%02d","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":512,"estimated_cost_usd":0.01536000,"pricing_version":"2026-04-17","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"high","model_routed":"%s","model_used":"%s","partial_flip_active":false,"withheld_classes":"","override_source":"none","escalation_count":0,"escalation_reason":""}\n' \
    "$n" "$n" "$model_id" "$ts" "$tier" "$model_id" >> "$OUT"
}

n=1
# 14 fast records (T01..T14)
while [ "$n" -le 14 ]; do
  emit_record "$n" "fast" "claude-haiku-4-5" "2026-04-30T10:$(printf '%02d' "$n"):00Z"
  n=$((n + 1))
done

# 7 balanced records (T15..T21)
while [ "$n" -le 21 ]; do
  emit_record "$n" "balanced" "claude-sonnet-4-7" "2026-04-30T10:$(printf '%02d' "$n"):00Z"
  n=$((n + 1))
done

# 2 smart records (T22..T23)
while [ "$n" -le 23 ]; do
  emit_record "$n" "smart" "claude-opus-4-7" "2026-04-30T10:$(printf '%02d' "$n"):00Z"
  n=$((n + 1))
done

# Print a one-line confirmation to stderr so callers see something happened.
printf 'synthesized %s with %s records\n' "$OUT" "$(wc -l < "$OUT" | tr -d '[:space:]')" 1>&2

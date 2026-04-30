#!/usr/bin/env bash
# tests/fixtures/m030-p04/synthesize-corpora.sh -- M030/P04/T01 shadow-corpus synth.
#
# Idempotent fixture-data generator. Re-running produces byte-identical
# JSONL output (timestamps are deterministic ascending values, not
# wall-clock). The committed JSONL files in this directory are the
# canonical fixture; this script is committed alongside so future
# maintainers can rebuild from scratch when the schema evolves.
#
# Outputs:
#   shadow-corpus-ready.jsonl              - 165 records (3 classes x 55), all stable
#   shadow-corpus-partially-ready.jsonl    - 135 records (mech 55 + std 55 + novel 25)
#   shadow-corpus-empty.jsonl              - 0 bytes
#
# Verdict expected from scripts/diagnostics/shadow-compare.sh --corpus <path>:
#   ready              (all 3 classes count >=50, variance <0.10)
#   partially_ready    (novel under-threshold; novel default-tier is smart -> D-A3 safe)
#   evidence_insufficient (zero records)
#
# Bash 3.2 compatible. MEM004 emitter-internal carve-out: pipes / awk /
# $() permitted in this script's body (it's a fixture-data SSOT, not a
# verifier). The verifiers that consume the output remain strict AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
READY="$SCRIPT_DIR/shadow-corpus-ready.jsonl"
PARTIAL="$SCRIPT_DIR/shadow-corpus-partially-ready.jsonl"
EMPTY="$SCRIPT_DIR/shadow-corpus-empty.jsonl"

: > "$READY"
: > "$PARTIAL"
: > "$EMPTY"

_emit_records() {
  # $1 = output file
  # $2 = class (mechanical | standard | novel) -- documented but unused (records are tier-tagged)
  # $3 = tier (fast | balanced | smart) -- emitted as model_routed
  # $4 = count of records to emit
  # $5 = classifier_confidence value (high | medium | low)
  local out="$1"
  local class="$2"
  local tier="$3"
  local count="$4"
  local conf="$5"
  local i=1
  while [ "$i" -le "$count" ]; do
    # Pad index for stable sort and deterministic timestamp seconds slot.
    # Each record is 1 second apart in the synthetic timestamp; class label
    # appears in the unitId comment field (task=T<NN>) for reader-friendliness.
    printf '{"record_type":"dispatch_usage","unitId":"M999/P01/T%02d","milestone":"M999","phase":"P01","task":"T%02d","backend":"stub","input_tokens_estimate":1024,"output_tokens_estimate":0,"estimated_cost_usd":0.0001,"pricing_version":"2026-04-30","filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"model":"claude-opus-4-7","source":"estimate","emission_point":"dispatch-interface","timestamp":"2026-04-30T00:00:%02dZ","classifier_confidence":"%s","model_routed":"%s","model_used":"claude-opus-4-7","partial_flip_active":false,"withheld_classes":"","override_source":"none"}\n' "$i" "$i" "$i" "$conf" "$tier" >> "$out"
    i=$((i + 1))
  done
  # class arg is documented for reader; reference here so set -u doesn't trip
  # if the var is later read in a future extension.
  : "$class"
}

# Ready corpus: 55 records per class, all confidence=high (variance=0 stable).
# 55 > 50 (CLASS_COVERAGE_MIN) and variance 0 < 0.10 -> all 3 stable -> ready.
_emit_records "$READY" mechanical fast 55 high
_emit_records "$READY" standard balanced 55 high
_emit_records "$READY" novel smart 55 high

# Partially-ready corpus: mechanical + standard at 55 (stable);
# novel at 25 (below CLASS_COVERAGE_MIN=50; under-threshold).
# Novel's routing-table default is smart -> D-A3 safety holds ->
# verdict resolves to partially_ready with withheld_classes=novel.
_emit_records "$PARTIAL" mechanical fast 55 high
_emit_records "$PARTIAL" standard balanced 55 high
_emit_records "$PARTIAL" novel smart 25 high

# Empty corpus: zero bytes (already truncated above; left as-is).

ready_lines=$(wc -l < "$READY" | tr -d '[:space:]')
partial_lines=$(wc -l < "$PARTIAL" | tr -d '[:space:]')
empty_lines=$(wc -l < "$EMPTY" | tr -d '[:space:]')

printf 'synthesized: ready=%s, partial=%s, empty=%s\n' "$ready_lines" "$partial_lines" "$empty_lines"

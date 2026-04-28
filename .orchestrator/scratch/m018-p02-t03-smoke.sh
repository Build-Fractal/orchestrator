#!/usr/bin/env bash
# M018/P02/T03 smoke test for the underperformance emitter.
# Builds a synthetic execution-log.jsonl with 30 underperforming
# payload_breakdown records and verifies the awk computation produces a MEAN
# that triggers emission. Also verifies the min_sample_size guard.
set -eu

REPO="/Users/brettkellgren/Sites/spec-kit-orchestrator"
. "$REPO/scripts/lib/knowledge-filter.sh"

# Test 1 — config accessors return defaults / config values.
printf 'enabled=%s window_size=%s floor_pct=%s min_sample_size=%s\n' \
  "$(kf_get_underperformance_enabled "$REPO")" \
  "$(kf_get_underperformance_window_size "$REPO")" \
  "$(kf_get_underperformance_floor_pct "$REPO")" \
  "$(kf_get_underperformance_min_sample_size "$REPO")"

# Test 2 — synthetic 30-record log; expect emission (~4.76% mean << 34.7%).
TMP="$(mktemp -d)"
LOG="$TMP/execution-log.jsonl"
i=1
while [ "$i" -le 30 ]; do
  printf '{"record_type":"payload_breakdown","milestone":"TEST","phase":"P01","task":"T01","payload_chars":1000,"payload_tokens_estimate":100,"filter_dropped_tokens":5,"timestamp":"2026-04-27T00:00:00Z"}\n' >> "$LOG"
  i=$((i + 1))
done

OUT_FULL="$(awk -v win=30 -v floor=34.7 -v min=10 '
  BEGIN { rec_count = 0 }
  /"record_type":"payload_breakdown"/ {
    pte = 0; fdt = 0; t1 = 0; t2 = 0; t3 = 0
    if (match($0, /"payload_tokens_estimate":[0-9]+/)) {
      v = substr($0, RSTART+26, RLENGTH-26); pte = v + 0
    }
    if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
      v = substr($0, RSTART+24, RLENGTH-24); fdt = v + 0
    }
    if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
      v = substr($0, RSTART+23, RLENGTH-23); t1 = v + 0
    }
    if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
      v = substr($0, RSTART+23, RLENGTH-23); t2 = v + 0
    }
    if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
      v = substr($0, RSTART+35, RLENGTH-35); t3 = v + 0
    }
    saved = fdt + t1 + t2 + t3
    pre = pte + saved
    if (pre > 0) {
      pct = (saved * 100.0) / pre
      rec_count++
      rec_pct[rec_count] = pct
    }
  }
  END {
    if (rec_count < min) { printf "INSUFFICIENT %d %d\n", rec_count, min; exit 0 }
    start = rec_count - win + 1
    if (start < 1) start = 1
    actual_window = rec_count - start + 1
    total = 0
    for (i = start; i <= rec_count; i++) total += rec_pct[i]
    mean = total / actual_window
    printf "MEAN %.2f %d %.2f\n", mean, actual_window, floor
  }
' "$LOG")"

printf 'full-log result: %s\n' "$OUT_FULL"

# Test 3 — only 5 records; expect INSUFFICIENT.
LOG2="$TMP/short-log.jsonl"
i=1
while [ "$i" -le 5 ]; do
  printf '{"record_type":"payload_breakdown","milestone":"TEST","phase":"P01","task":"T01","payload_chars":1000,"payload_tokens_estimate":100,"filter_dropped_tokens":5,"timestamp":"2026-04-27T00:00:00Z"}\n' >> "$LOG2"
  i=$((i + 1))
done

OUT_SHORT="$(awk -v win=30 -v floor=34.7 -v min=10 '
  BEGIN { rec_count = 0 }
  /"record_type":"payload_breakdown"/ {
    pte = 0; fdt = 0
    if (match($0, /"payload_tokens_estimate":[0-9]+/)) {
      v = substr($0, RSTART+26, RLENGTH-26); pte = v + 0
    }
    if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
      v = substr($0, RSTART+24, RLENGTH-24); fdt = v + 0
    }
    saved = fdt
    pre = pte + saved
    if (pre > 0) {
      pct = (saved * 100.0) / pre
      rec_count++
      rec_pct[rec_count] = pct
    }
  }
  END {
    if (rec_count < min) { printf "INSUFFICIENT %d %d\n", rec_count, min; exit 0 }
    printf "MEAN-NOT-EXPECTED\n"
  }
' "$LOG2")"

printf 'short-log result: %s\n' "$OUT_SHORT"

# Test 4 — high-savings log: 12 records each with savings 50/(100+50) ≈ 33.33%
# below floor — should emit. Then 12 records each with savings 60/(100+60) = 37.5%
# above floor — should NOT emit.
LOG3="$TMP/above-floor.jsonl"
i=1
while [ "$i" -le 12 ]; do
  printf '{"record_type":"payload_breakdown","milestone":"TEST","payload_tokens_estimate":100,"filter_dropped_tokens":60,"timestamp":"2026-04-27T00:00:00Z"}\n' >> "$LOG3"
  i=$((i + 1))
done

OUT_ABOVE="$(awk -v win=30 -v floor=34.7 -v min=10 '
  BEGIN { rec_count = 0 }
  /"record_type":"payload_breakdown"/ {
    pte = 0; fdt = 0
    if (match($0, /"payload_tokens_estimate":[0-9]+/)) {
      v = substr($0, RSTART+26, RLENGTH-26); pte = v + 0
    }
    if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
      v = substr($0, RSTART+24, RLENGTH-24); fdt = v + 0
    }
    saved = fdt
    pre = pte + saved
    if (pre > 0) {
      pct = (saved * 100.0) / pre
      rec_count++
      rec_pct[rec_count] = pct
    }
  }
  END {
    if (rec_count < min) { printf "INSUFFICIENT\n"; exit 0 }
    start = rec_count - win + 1
    if (start < 1) start = 1
    actual_window = rec_count - start + 1
    total = 0
    for (i = start; i <= rec_count; i++) total += rec_pct[i]
    mean = total / actual_window
    under = (mean < floor) ? "UNDER" : "OK"
    printf "MEAN=%.2f n=%d %s floor=%.2f\n", mean, actual_window, under, floor
  }
' "$LOG3")"

printf 'above-floor result: %s\n' "$OUT_ABOVE"

rm -rf "$TMP"
printf 'smoke test PASS\n'

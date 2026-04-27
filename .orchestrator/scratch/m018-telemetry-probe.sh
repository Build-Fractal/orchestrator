#!/usr/bin/env bash
# M018 kickoff telemetry probe — aggregate payload_breakdown section_tokens
# across all milestones to identify which sections dominate token spend.
# Read-only. Output: stdout report.
set -euo pipefail

ROOT=".orchestrator/milestones"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2
  exit 2
fi

PB_FILE="$TMP/payload_breakdowns.jsonl"
DU_FILE="$TMP/dispatch_usage.jsonl"
UC_FILE="$TMP/unit_close.jsonl"

: > "$PB_FILE"
: > "$DU_FILE"
: > "$UC_FILE"

for log in "$ROOT"/*/execution-log.jsonl; do
  [ -r "$log" ] || continue
  grep -h '"record_type":"payload_breakdown"' "$log" >> "$PB_FILE" || true
  grep -h '"record_type":"dispatch_usage"' "$log" >> "$DU_FILE" || true
  grep -h '"record_type":"unit_close"' "$log" >> "$UC_FILE" || true
done

PB_COUNT=$(wc -l < "$PB_FILE" | tr -d ' ')
DU_COUNT=$(wc -l < "$DU_FILE" | tr -d ' ')
UC_COUNT=$(wc -l < "$UC_FILE" | tr -d ' ')

echo "=== M018 Telemetry Probe ==="
echo "Records found: payload_breakdown=$PB_COUNT  dispatch_usage=$DU_COUNT  unit_close=$UC_COUNT"
echo ""

if [ "$PB_COUNT" -eq 0 ]; then
  echo "No payload_breakdown records found — cannot continue." >&2
  exit 0
fi

echo "=== Payload size distribution (payload_tokens_estimate) ==="
jq -r '.payload_tokens_estimate // 0' "$PB_FILE" \
  | sort -n \
  | awk '
    {a[NR]=$1; s+=$1}
    END {
      n=NR
      if (n==0) {print "no data"; exit}
      printf "  count=%d  total_tokens=%d  mean=%.0f\n", n, s, s/n
      printf "  min=%d  p25=%d  p50=%d  p75=%d  p90=%d  p95=%d  max=%d\n", \
        a[1], a[int(n*0.25)+1], a[int(n*0.50)+1], a[int(n*0.75)+1], \
        a[int(n*0.90)+1], a[int(n*0.95)+1], a[n]
    }
  '
echo ""

echo "=== Section-token aggregates (sum across all dispatches) ==="
SEC_TMP="$TMP/sections.tsv"
jq -r '.section_tokens // {} | to_entries[] | "\(.key)\t\(.value)"' "$PB_FILE" \
  | awk -F'\t' '{sum[$1]+=$2; count[$1]++}
    END {for (k in sum) printf "%d\t%d\t%s\n", sum[k], count[k], k}' \
  > "$SEC_TMP"

TOTAL=$(awk -F'\t' '{s+=$1} END {print s+0}' "$SEC_TMP")
printf "  %-28s %12s %8s %12s\n" "section" "total_tokens" "n" "pct_of_total"
printf "  %-28s %12s %8s %12s\n" "----------------------------" "------------" "--------" "------------"
sort -t$'\t' -k1,1 -nr "$SEC_TMP" \
  | awk -F'\t' -v total="$TOTAL" '
    {pct = (total>0) ? 100.0*$1/total : 0
     printf "  %-28s %12d %8d %11.1f%%\n", $3, $1, $2, pct}'
printf "  %-28s %12d\n" "TOTAL" "$TOTAL"
echo ""

echo "=== Per-milestone payload-token totals ==="
MS_TMP="$TMP/milestones.tsv"
jq -r '"\(.milestone)\t\(.payload_tokens_estimate // 0)"' "$PB_FILE" \
  | awk -F'\t' '{sum[$1]+=$2; n[$1]++}
    END {for (k in sum) printf "%s\t%d\t%d\n", k, sum[k], n[k]}' \
  > "$MS_TMP"

printf "  %-10s %12s %8s %12s\n" "milestone" "total_tok" "dispatch" "mean_tok"
printf "  %-10s %12s %8s %12s\n" "----------" "------------" "--------" "------------"
sort -t$'\t' -k1,1 "$MS_TMP" \
  | awk -F'\t' '{m=($3>0)?$2/$3:0; printf "  %-10s %12d %8d %12.0f\n", $1, $2, $3, m}'
echo ""

echo "=== Largest single dispatches (top 10 by payload_tokens_estimate) ==="
jq -r '"\(.payload_tokens_estimate // 0)\t\(.unitId)\t\(.payload_chars // 0)"' "$PB_FILE" \
  | sort -t$'\t' -k1,1 -nr \
  | head -10 \
  | awk -F'\t' '{printf "  %8d tok  %8d chars  %s\n", $1, $3, $2}'
echo ""

if [ "$DU_COUNT" -gt 0 ]; then
  echo "=== Dispatch usage (estimated cost) ==="
  jq -r '"\(.estimated_cost_usd // 0)\t\(.input_tokens_estimate // 0)\t\(.output_tokens_estimate // 0)\t\(.unitId)"' "$DU_FILE" \
    | awk -F'\t' '
      {cost+=$1; in_tok+=$2; out_tok+=$3; n++}
      END {
        if (n==0) {print "no data"; exit}
        printf "  dispatches=%d  total_in_tok=%d  total_out_tok=%d  total_cost_usd=%.4f\n", \
          n, in_tok, out_tok, cost
        printf "  mean per dispatch: in=%.0f  out=%.0f  cost=$%.4f\n", \
          in_tok/n, out_tok/n, cost/n
      }
    '
  echo ""
fi

echo "Probe complete."

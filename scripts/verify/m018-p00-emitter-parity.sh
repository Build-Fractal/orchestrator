#!/usr/bin/env bash
# scripts/verify/m018-p00-emitter-parity.sh — M018/P00 emitter parity gate.
#
# Asserts that `dispatch_usage` JSONL records fire on real dispatches at
# parity >= threshold% with `payload_breakdown` records over the most
# recent `--window N` payload_breakdown records.
#
# Background: the M018 telemetry probe surfaced a 1.2% parity ratio
# (169 payload_breakdown vs 2 dispatch_usage in the historical log). The
# fix lands a co-located dispatch_usage emitter inside build-context.sh
# (alongside payload_breakdown) so every dispatch path that emits one
# also emits the other. This verifier mechanically asserts the parity.
#
# Usage:
#   m018-p00-emitter-parity.sh [--window N] [--threshold P] [--root <dir>]
#
#   --window N    -- count parity over the most-recent N payload_breakdown
#                    records and the dispatch_usage records that share their
#                    time window. Default: 20. Integer >= 1.
#   --threshold P -- minimum parity percent (0..100, integer). Exit 0 when
#                    parity >= threshold; exit 1 otherwise. Default: 95.
#   --root <dir>  -- override the milestones root for fixture testing.
#                    Default: .orchestrator/milestones.
#
# Output:
#   PASS: dispatch_usage parity over recent <N> payload_breakdown records:
#         <DU> dispatch_usage / <PB> payload_breakdown = <P>%
#   FAIL: dispatch_usage parity below threshold ...
#
# Exit 0 on >= threshold, 1 on below threshold or missing inputs.
#
# AD-19 single-script-file shape -- no compound chains > 2, no inline
# (...), no $(... | ...) chained substitutions. MEM004 carve-out: simple
# pipes/$()/awk permitted in verifier internals.
# Bash 3.2 compatible. CON-5 additivity: the verifier does not require the
# `emission_point` field; pre-M018 records are counted equally.

set -u

WINDOW=20
THRESHOLD=95
ROOT_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --window)
      WINDOW="${2:-20}"
      shift 2
      ;;
    --threshold)
      THRESHOLD="${2:-95}"
      shift 2
      ;;
    --root)
      ROOT_OVERRIDE="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

# Validate numeric inputs (defensive — no octal interpretation per MEM028).
case "$WINDOW" in
  ''|*[!0-9]*)
    printf 'FAIL: m018-p00-emitter-parity.sh invalid-window=%s\n' "$WINDOW" >&2
    exit 1
    ;;
esac
case "$THRESHOLD" in
  ''|*[!0-9]*)
    printf 'FAIL: m018-p00-emitter-parity.sh invalid-threshold=%s\n' "$THRESHOLD" >&2
    exit 1
    ;;
esac

W=$((10#$WINDOW))
T=$((10#$THRESHOLD))

if [ "$W" -lt 1 ]; then
  printf 'FAIL: m018-p00-emitter-parity.sh window-too-small=%d (need >=1)\n' "$W" >&2
  exit 1
fi
if [ "$T" -lt 0 ] || [ "$T" -gt 100 ]; then
  printf 'FAIL: m018-p00-emitter-parity.sh threshold-out-of-range=%d (need 0..100)\n' "$T" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -n "$ROOT_OVERRIDE" ]; then
  ROOT="$ROOT_OVERRIDE"
else
  ROOT="$REPO_ROOT/.orchestrator/milestones"
fi

if [ ! -d "$ROOT" ]; then
  printf 'FAIL: m018-p00-emitter-parity.sh milestones-root-missing path=%s\n' "$ROOT" >&2
  exit 1
fi

TMPDIR_P="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_P"' EXIT INT TERM

PB_ALL="$TMPDIR_P/pb.jsonl"
DU_ALL="$TMPDIR_P/du.jsonl"
: > "$PB_ALL"
: > "$DU_ALL"

# Aggregate across all milestones. The probe pattern from
# .orchestrator/scratch/m018-telemetry-probe.sh is reused: per-log grep,
# tolerant of missing logs. Bash 3.2 safe.
for log in "$ROOT"/*/execution-log.jsonl; do
  if [ ! -r "$log" ]; then
    continue
  fi
  grep -h '"record_type":"payload_breakdown"' "$log" >> "$PB_ALL" 2>/dev/null || true
  grep -h '"record_type":"dispatch_usage"' "$log" >> "$DU_ALL" 2>/dev/null || true
done

PB_TOTAL=$(wc -l < "$PB_ALL" | tr -d ' ')
DU_TOTAL=$(wc -l < "$DU_ALL" | tr -d ' ')

# Quick exit when no payload_breakdown records exist anywhere.
if [ "$PB_TOTAL" -eq 0 ]; then
  printf 'FAIL: m018-p00-emitter-parity.sh no-payload_breakdown-records-found root=%s\n' "$ROOT" >&2
  exit 1
fi

# Sort payload_breakdown by timestamp (ISO-8601 sorts lexically). Take the
# last $W records. Find the timestamp of the lower-bound record (the Nth-
# from-last). Then count dispatch_usage records whose timestamp >= that
# lower bound.
PB_SORTED="$TMPDIR_P/pb.sorted"
DU_SORTED="$TMPDIR_P/du.sorted"

# Extract a "<timestamp>\t<line>" prefix using awk, sort by ts, drop prefix.
awk '
  {
    ts = ""
    n = split($0, parts, "\"")
    for (i = 1; i <= n; i++) {
      if (parts[i] == "timestamp" && i + 2 <= n) {
        ts = parts[i + 2]
        break
      }
    }
    if (ts == "") { ts = "0000-00-00T00:00:00Z" }
    printf "%s\t%s\n", ts, $0
  }
' "$PB_ALL" > "$PB_SORTED.raw"
sort -t$'\t' -k1,1 "$PB_SORTED.raw" > "$PB_SORTED"

awk '
  {
    ts = ""
    n = split($0, parts, "\"")
    for (i = 1; i <= n; i++) {
      if (parts[i] == "timestamp" && i + 2 <= n) {
        ts = parts[i + 2]
        break
      }
    }
    if (ts == "") { ts = "0000-00-00T00:00:00Z" }
    printf "%s\t%s\n", ts, $0
  }
' "$DU_ALL" > "$DU_SORTED.raw"
sort -t$'\t' -k1,1 "$DU_SORTED.raw" > "$DU_SORTED"

# Number of payload_breakdown records to consider: min(W, PB_TOTAL).
PB_WINDOW_N="$W"
if [ "$PB_TOTAL" -lt "$W" ]; then
  PB_WINDOW_N="$PB_TOTAL"
fi

# Lower-bound timestamp: timestamp at line (PB_TOTAL - PB_WINDOW_N + 1) of
# the sorted file. tail -n PB_WINDOW_N gets the trailing window; head -n 1
# selects the earliest in the window.
LB_TS="$(tail -n "$PB_WINDOW_N" "$PB_SORTED" | head -n 1 | cut -f1)"

if [ -z "$LB_TS" ]; then
  printf 'FAIL: m018-p00-emitter-parity.sh lower-bound-empty pb_total=%d window=%d\n' "$PB_TOTAL" "$W" >&2
  exit 1
fi

# PB count in window = PB_WINDOW_N (by construction).
# DU count in window = dispatch_usage records with timestamp >= LB_TS.
DU_WINDOW=$(awk -F'\t' -v lb="$LB_TS" '$1 >= lb {n++} END {print n+0}' "$DU_SORTED")

# Parity percent = floor(100 * DU_WINDOW / PB_WINDOW_N).
PCT=$(awk -v du="$DU_WINDOW" -v pb="$PB_WINDOW_N" 'BEGIN { if (pb == 0) print 0; else printf "%d", (100 * du) / pb }')

if [ "$PCT" -ge "$T" ]; then
  printf 'PASS: dispatch_usage parity over recent %d payload_breakdown records: %d dispatch_usage / %d payload_breakdown = %d%%\n' \
    "$PB_WINDOW_N" "$DU_WINDOW" "$PB_WINDOW_N" "$PCT"
  exit 0
fi

printf 'FAIL: dispatch_usage parity below threshold over recent %d payload_breakdown records: %d dispatch_usage / %d payload_breakdown = %d%% (threshold=%d%%)\n' \
  "$PB_WINDOW_N" "$DU_WINDOW" "$PB_WINDOW_N" "$PCT" "$T" >&2
exit 1

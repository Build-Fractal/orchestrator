#!/usr/bin/env bash
# scripts/verify/m019-p01-no-pre-p00-emission.sh — SC-12 ordering guard.
#
# Asserts no M019 emitter record exists in any post-M011 milestone's
# execution-log.jsonl with a timestamp earlier than P00 SUMMARY's
# completed_at (the P00->P01 ordering epoch).
#
# Epoch: 2026-04-18T02:21:28Z (from M019/P00/P00-SUMMARY.md completed_at).
# Post-M011 milestones: M012 and above (M011 and earlier are explicitly
# exempted per D009 — pre-M019 records are unlogged-on-purpose).
#
# Scans .orchestrator/milestones/M{012..}/execution-log.jsonl. For each
# record carrying record_type in {payload_breakdown, dispatch_usage,
# unit_close}, extracts the timestamp field and compares lexically
# (ISO-8601 UTC timestamps sort correctly as strings).
#
# Exit 1 with a FAIL line naming the offending file + timestamp on any
# violation. Exit 0 on green.
#
# Bash 3.2 compatible. MEM004 carve-out — awk/pipes/$() permitted.

set -u

P00_EPOCH="2026-04-18T02:21:28Z"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MILESTONES_DIR="$REPO_ROOT/.orchestrator/milestones"

fail_count=0
scanned=0

if [ ! -d "$MILESTONES_DIR" ]; then
  echo "FAIL: $MILESTONES_DIR not found"
  exit 1
fi

for mdir in "$MILESTONES_DIR"/M[0-9][0-9][0-9]; do
  [ -d "$mdir" ] || continue
  base="$(basename "$mdir")"
  # Strip leading M, drop leading zeros with arithmetic.
  num_raw="${base#M}"
  # Use base-10 arithmetic explicitly to avoid octal interpretation.
  num=$((10#$num_raw))
  # Exempt M011 and earlier (pre-M019 records are unlogged-on-purpose per D009).
  if [ "$num" -le 11 ]; then
    continue
  fi
  log="$mdir/execution-log.jsonl"
  [ -f "$log" ] || continue
  scanned=$((scanned + 1))
  # Filter M019 record types, extract timestamp, compare to epoch lexically.
  # grep -E first filters candidate lines; awk does the timestamp compare.
  violations="$(
    grep -E '"record_type":"(payload_breakdown|dispatch_usage|unit_close)"' "$log" 2>/dev/null \
      | awk -v epoch="$P00_EPOCH" '
        {
          ts=""
          n=split($0, arr, "\"")
          for (i=1; i<=n; i++) {
            if (arr[i] == "timestamp" && i+2 <= n) { ts=arr[i+2]; break }
          }
          if (ts == "") { next }
          if (ts < epoch) { print ts }
        }
      '
  )"
  if [ -n "$violations" ]; then
    for ts in $violations; do
      echo "FAIL: $base/execution-log.jsonl has M019 emitter record at $ts (pre-epoch $P00_EPOCH)"
      fail_count=$((fail_count + 1))
    done
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: no-pre-p00-emission ($scanned post-M011 logs scanned, epoch $P00_EPOCH)"
  echo "PASS: m019-p01-no-pre-p00-emission.sh"
  exit 0
else
  echo "FAIL: m019-p01-no-pre-p00-emission.sh ($fail_count violations)"
  exit 1
fi

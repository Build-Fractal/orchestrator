#!/usr/bin/env sh
# self-continue-drive.sh <spike-dir> <segment-index> [--limit N] [--work N]
# One segment of the M045 P01 viability spike: simulate a phase's work (append N
# synthetic dispatch entries to the fixture execution log), then run the REAL
# context-monitor.sh with a forced-low limit. On CONTEXT:ROTATE, capture the
# segment and emit SPIKE:SELF_CONTINUE for the caller to translate into a
# ScheduleWakeup re-entry. When the fixture plan is exhausted, emit SPIKE:COMPLETE.
# Mirrors the production exit-14 (CONTEXT:ROTATE) branch M045 P02/P03 will wire.
# Spike-grade / throwaway.
set -eu
SPIKE_DIR="$1"; IDX="$2"; shift 2
LIMIT=3; WORK=4
while [ $# -gt 0 ]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --work) WORK="$2"; shift 2 ;;
    *) shift ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "$0")/../../../../../.." && pwd)"
FIX="$SPIKE_DIR/fixture"
PHASE_COUNT=$(grep -c '' "$FIX/plan.txt")
if [ "$IDX" -gt "$PHASE_COUNT" ]; then
  sh "$SPIKE_DIR/capture-segment.sh" "$SPIKE_DIR" "$IDX" "-" "-" "$LIMIT" "complete" "-"
  echo "SPIKE:COMPLETE segments_done=$((IDX-1))"
  exit 0
fi
PHASE=$(sed -n "${IDX}p" "$FIX/plan.txt")
# Simulate this phase's work: WORK synthetic dispatch entries into the fixture log.
i=0
while [ "$i" -lt "$WORK" ]; do
  printf '{"type":"dispatch","unit":"%s/T0%s","phase":"%s","outcome":"success","timestamp":"2026-07-01T01:00:00Z"}\n' "$PHASE" "$i" "$PHASE" >> "$FIX/execution-log.jsonl"
  i=$((i+1))
done
# REAL rotation check against the seeded log with a forced-low limit.
MON=$(sh "$REPO_ROOT/scripts/lifecycle/context-monitor.sh" "$FIX/execution-log.jsonl" "$FIX/orchestrator.lock" --limit "$LIMIT" 2>/dev/null || true)
WEIGHT=$(printf '%s' "$MON" | sed -n 's/.*weight=\([0-9]*\).*/\1/p')
[ -n "$WEIGHT" ] || WEIGHT=0
case "$MON" in
  *CONTEXT:ROTATE*)
    sh "$SPIKE_DIR/capture-segment.sh" "$SPIKE_DIR" "$IDX" "$PHASE" "$WEIGHT" "$LIMIT" "rotate" "PENDING"
    echo "SPIKE:SELF_CONTINUE next_segment=$((IDX+1)) phase=$PHASE weight=$WEIGHT limit=$LIMIT" ;;
  *)
    sh "$SPIKE_DIR/capture-segment.sh" "$SPIKE_DIR" "$IDX" "$PHASE" "$WEIGHT" "$LIMIT" "ok" "-"
    echo "SPIKE:CONTINUE_INLINE next_segment=$((IDX+1)) phase=$PHASE weight=$WEIGHT limit=$LIMIT" ;;
esac

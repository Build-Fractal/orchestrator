#!/usr/bin/env bash
# tools/verify/m046-p01-cadence-log.sh
# M046 P01: cadence.jsonl carries >=3 unit_close observations each with a
# per-record wall-clock "t" timestamp plus >=1 loop_exit mark, and
# CADENCE-FINDINGS.md names the recommended FR-7/FR-8 cost source.
# Written against the actual T02 log shape (jsonl_append observations with
# "record_type":"unit_close"). Bash 3.2 compatible.
set -u
LOG=".orchestrator/milestones/M046/phases/P01/spike/cost/cadence.jsonl"
FINDINGS=".orchestrator/milestones/M046/phases/P01/spike/cost/CADENCE-FINDINGS.md"

if [ ! -f "$LOG" ]; then
  echo "FAIL: cadence log missing at $LOG"
  exit 1
fi

uc=$(grep -c '"record_type":"unit_close"' "$LOG" || true)
if [ "$uc" -lt 3 ]; then
  echo "FAIL: only $uc unit_close observations in $LOG (min 3)"
  exit 1
fi

uct=$(grep '"record_type":"unit_close"' "$LOG" | grep -c '"t":' || true)
if [ "$uct" -ne "$uc" ]; then
  echo "FAIL: $uct of $uc unit_close observations carry a \"t\" timestamp"
  exit 1
fi

if ! grep -q '"event":"loop_exit"' "$LOG"; then
  echo "FAIL: no loop_exit mark in $LOG"
  exit 1
fi

if [ ! -f "$FINDINGS" ]; then
  echo "FAIL: findings missing at $FINDINGS"
  exit 1
fi

if ! grep -q 'Recommended FR-7/FR-8 cost-source' "$FINDINGS"; then
  echo "FAIL: no recommended FR-7/FR-8 cost-source section in $FINDINGS"
  exit 1
fi

if ! grep -q 'total_cost_usd' "$FINDINGS"; then
  echo "FAIL: findings do not name total_cost_usd as a cost source"
  exit 1
fi

echo "PASS: cadence log has $uc timestamped unit_close observations + loop_exit; findings name the FR-7/FR-8 cost source"
exit 0

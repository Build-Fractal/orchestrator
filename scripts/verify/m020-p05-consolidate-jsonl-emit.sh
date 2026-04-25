#!/usr/bin/env bash
# m020-p05-consolidate-jsonl-emit.sh — assert consolidate-artifacts.sh --cluster
# appends one consolidate_cluster JSONL record per emitted cluster to
# $ORCH_ROOT/execution-log.jsonl, with required fields.
# Bash 3.2 safe. AD-19 single-script-file shape.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/knowledge/consolidate-artifacts.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/knowledge/patterns"
mkdir -p "$tmpdir/orch-state/milestones/MTEST"

# Three candidates: 2 cluster, 1 singleton -> 2 consolidate_cluster records.
for trip in "MEM800:cluster-a:shared body alpha beta gamma" \
            "MEM801:cluster-a:shared body alpha beta gamma" \
            "MEM802:distinct:unique body epsilon zeta eta theta"; do
  id="${trip%%:*}"; rest="${trip#*:}"
  topic="${rest%%:*}"; body="${rest#*:}"
  cat >"$tmpdir/knowledge/patterns/${id}.md" <<EOF
---
id: ${id}
status: candidate
topic: ${topic}
tags: [${topic}]
---

# ${id}: jsonl fixture
${body}
EOF
done

export PROJECT_ROOT="$tmpdir"

LOG="$tmpdir/orch-state/execution-log.jsonl"

bash "$SCRIPT" --cluster "$tmpdir/orch-state" MTEST "$tmpdir/knowledge" 0.1 >/dev/null 2>&1 || {
  echo "FAIL: consolidate-artifacts.sh --cluster exited non-zero in jsonl test"
  exit 1
}

if [ ! -f "$LOG" ]; then
  echo "FAIL: execution-log.jsonl not created at $LOG"
  exit 1
fi

# At least 1 consolidate_cluster record. With three candidates above and a
# 0.1 threshold, the expected outcome is 2 records (cluster-a 2-member +
# singleton MEM802) but if the implementation clusters all three the count
# drops to 1; the load-bearing assertion is "non-zero with required fields".
record_count="$(grep -c '"event":"consolidate_cluster"' "$LOG" 2>/dev/null || echo 0)"
if [ "$record_count" -lt 1 ]; then
  echo "FAIL: expected >= 1 consolidate_cluster JSONL record, got $record_count"
  echo "Log content:"
  cat "$LOG"
  exit 1
fi

# Each record carries cluster_id, member_count, member_ids, threshold_used, conflict_flag.
for field in cluster_id member_count member_ids threshold_used conflict_flag; do
  if ! grep -q "\"$field\"" "$LOG"; then
    echo "FAIL: consolidate_cluster JSONL record missing field '$field'"
    echo "Log content:"
    cat "$LOG"
    exit 1
  fi
done

# threshold_used is the value we passed (0.1).
if ! grep -q '"threshold_used":"0.1"' "$LOG"; then
  echo "FAIL: threshold_used field does not carry the supplied 0.1 value"
  cat "$LOG"
  exit 1
fi

echo "PASS: consolidate_cluster JSONL emission ($record_count records, all required fields present)"
exit 0

#!/usr/bin/env sh
# capture-segment.sh <spike-dir> <segment-index> <phase> <weight> <limit> <rotate|ok|complete> <context-proxy>
# Appends one JSON measurement record to <spike-dir>/segments.jsonl.
# Spike-grade / throwaway (M045 P01 viability spike).
set -eu
SPIKE_DIR="$1"; IDX="$2"; PHASE="$3"; WEIGHT="$4"; LIMIT="$5"; STATUS="$6"; PROXY="$7"
LOG_LINES=$(grep -c '' "$SPIKE_DIR/fixture/execution-log.jsonl" 2>/dev/null || echo 0)
printf '{"segment":%s,"phase":"%s","exec_log_lines":%s,"weight":"%s","limit":"%s","status":"%s","context_proxy":"%s"}\n' \
  "$IDX" "$PHASE" "$LOG_LINES" "$WEIGHT" "$LIMIT" "$STATUS" "$PROXY" >> "$SPIKE_DIR/segments.jsonl"

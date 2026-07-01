#!/usr/bin/env sh
# m045-p01-segments-present.sh
# Checks the M045 P01 spike captured >=3 segments (>=2 boundaries).
# Project-owned per-phase verifier (M045 P01).
set -eu
SEG=".orchestrator/milestones/M045/phases/P01/spike/segments.jsonl"
test -f "$SEG" || { echo "FAIL: segments.jsonl missing at $SEG"; exit 1; }
N=$(grep -c 'segment' "$SEG" 2>/dev/null || echo 0)
[ "$N" -ge 3 ] || { echo "FAIL: <3 segments (got $N)"; exit 1; }
echo "PASS: $N segments captured"

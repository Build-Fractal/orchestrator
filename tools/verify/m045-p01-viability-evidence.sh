#!/usr/bin/env sh
# m045-p01-viability-evidence.sh
# Checks the M045 P01 viability evidence carries a definite verdict backed by
# >=2 rotation boundaries. Project-owned per-phase verifier (M045 P01).
set -eu
EV=".orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md"
SEG=".orchestrator/milestones/M045/phases/P01/spike/segments.jsonl"
test -f "$EV" || { echo "FAIL: evidence missing at $EV"; exit 1; }
grep -Eq '^VERDICT: (PASS|NEGATIVE|PARTIAL)' "$EV" || { echo "FAIL: no VERDICT line"; exit 1; }
ROT=$(grep -c '"status":"rotate"' "$SEG" 2>/dev/null || echo 0)
[ "$ROT" -ge 2 ] || { echo "FAIL: <2 rotation boundaries (got $ROT)"; exit 1; }
echo "PASS: viability evidence present with VERDICT and $ROT boundaries"

#!/usr/bin/env bash
# tools/verify/m046-p01-viability-evidence.sh
# M046 P01: the viability evidence doc exists, is >=60 lines, carries one
# grep-stable VERDICT line each for #Q-1 and #Q-4 (PASS|NEGATIVE|PARTIAL),
# and has a Decision-gate routing section. Bash 3.2 compatible.
set -u
EV=".orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md"

if [ ! -f "$EV" ]; then
  echo "FAIL: evidence missing at $EV"
  exit 1
fi

lines=$(wc -l < "$EV" | tr -d ' ')
if [ "$lines" -lt 60 ]; then
  echo "FAIL: evidence has $lines lines (min 60)"
  exit 1
fi

if ! grep -Eq '^VERDICT: #Q-1 (PASS|NEGATIVE|PARTIAL)' "$EV"; then
  echo "FAIL: no line-start 'VERDICT: #Q-1 <PASS|NEGATIVE|PARTIAL>' in $EV"
  exit 1
fi

if ! grep -Eq '^VERDICT: #Q-4 (PASS|NEGATIVE|PARTIAL)' "$EV"; then
  echo "FAIL: no line-start 'VERDICT: #Q-4 <PASS|NEGATIVE|PARTIAL>' in $EV"
  exit 1
fi

if ! grep -q '^## Decision-gate routing' "$EV"; then
  echo "FAIL: no '## Decision-gate routing' section in $EV"
  exit 1
fi

echo "PASS: viability evidence present ($lines lines) with #Q-1 + #Q-4 verdicts and decision-gate routing"
exit 0

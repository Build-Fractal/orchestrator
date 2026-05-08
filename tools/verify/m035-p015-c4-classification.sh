#!/usr/bin/env bash
# tools/verify/m035-p015-c4-classification.sh
#
# T07 Must-Have verifier: assert the C4 classification log exists, has zero
# REVIEW verdicts (operator resolved them all to C4-rename or UPSTREAM), and
# every C4-rename verdict line corresponds to a no-longer-present standalone
# spec-kit token in its named file (i.e., the rewrite was applied).
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="$REPO_ROOT/.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt"
fail=0

# Log file must exist.
if [ ! -f "$LOG" ]; then
  echo "FAIL: c4-classification.txt missing at $LOG" >&2
  exit 1
fi

# Zero REVIEW verdicts (operator resolved them all).
review_count=$(grep -cE ':REVIEW:' "$LOG" 2>/dev/null)
if [ -z "$review_count" ]; then review_count=0; fi
if [ "$review_count" != "0" ]; then
  echo "FAIL: c4-classification.txt still has $review_count REVIEW entries" >&2
  fail=1
fi

# Every C4-rename verdict line corresponds to a no-longer-present standalone
# spec-kit token in its named file. (Strict check: the token was rewritten.)
while IFS= read -r line; do
  case "$line" in
    \#*) continue ;;
    *":C4-rename:"*)
      file=$(echo "$line" | awk -F: '{print $1}')
      lineno=$(echo "$line" | awk -F: '{print $2}')
      if [ -f "$REPO_ROOT/$file" ]; then
        # Check the line at the recorded line number for a standalone
        # spec-kit token (not bound to -orchestrator or .orchestrator).
        line_text=$(sed -n "${lineno}p" "$REPO_ROOT/$file")
        # Strip the compound forms first, then look for a residual spec-kit token.
        residual=$(echo "$line_text" | sed -E 's/spec-kit-orchestrator//g; s/speckit\.orchestrator//g; s/Spec-Kit Orchestrator//g; s/spec-kit orchestrator//g; s/spec kit orchestrator//g')
        if echo "$residual" | grep -qiE 'spec-kit|spec kit'; then
          echo "FAIL: $file:$lineno still has standalone spec-kit token after C4-rename verdict" >&2
          fail=1
        fi
      fi
      ;;
  esac
done < "$LOG"

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p015-c4-classification"
  exit 0
fi
exit 1

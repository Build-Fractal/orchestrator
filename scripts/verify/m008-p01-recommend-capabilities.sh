#!/usr/bin/env bash
# Verifies intensity-recommend.sh factors capabilities into its recommendation.
# Full intensity with low cap_score should have reduced confidence.
set -eu

f="scripts/engine/intensity-recommend.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Full intensity + lean environment -> confidence should be medium
analyze_full="scope=large
risk_level=high
complexity=complex
risk_signals=migration_detected
recommended_intensity=Full"

profile_lean="cap_execution=local
cap_graph=false
cap_mcp=false
cap_ci=false
cap_subagent=false
cap_score=0"

output_lean="$(bash "$f" --analyze-output "$analyze_full" --profile-output "$profile_lean" 2>/dev/null)"
conf_lean="$(echo "$output_lean" | grep "^confidence=" | cut -d= -f2)"

if [[ "$conf_lean" != "medium" ]]; then
  echo "FAIL: Full intensity with cap_score=0 should have confidence=medium, got $conf_lean"; exit 1
fi

# Full intensity + rich environment -> confidence should be high
profile_rich="cap_execution=ci
cap_graph=true
cap_mcp=true
cap_ci=true
cap_subagent=true
cap_score=5"

output_rich="$(bash "$f" --analyze-output "$analyze_full" --profile-output "$profile_rich" 2>/dev/null)"
conf_rich="$(echo "$output_rich" | grep "^confidence=" | cut -d= -f2)"

if [[ "$conf_rich" != "high" ]]; then
  echo "FAIL: Full intensity with cap_score=5 should have confidence=high, got $conf_rich"; exit 1
fi

echo "PASS: intensity-recommend.sh factors capabilities into confidence (lean=medium, rich=high)"

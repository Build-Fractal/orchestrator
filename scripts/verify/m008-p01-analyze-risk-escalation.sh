#!/usr/bin/env bash
# Verifies intensity-analyze.sh detects risk signals and escalates intensity.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# A small change to auth code should escalate to Full due to risk
output="$(echo "Update the auth middleware to fix a token validation bug" | bash "$f" 2>/dev/null)"

risk_val="$(echo "$output" | grep "^risk_level=" | cut -d= -f2)"
signals_val="$(echo "$output" | grep "^risk_signals=" | cut -d= -f2-)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$risk_val" != "high" ]]; then
  echo "FAIL: auth-related task has risk_level=$risk_val, expected high"; exit 1
fi
if [[ "$signals_val" = "none" ]]; then
  echo "FAIL: auth-related task has risk_signals=none, expected at least one signal"; exit 1
fi
if [[ "$intensity_val" != "Full" ]]; then
  echo "FAIL: high-risk task has intensity=$intensity_val, expected Full"; exit 1
fi

echo "PASS: auth-related task correctly escalated to risk_level=high, recommended_intensity=Full"

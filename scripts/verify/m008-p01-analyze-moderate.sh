#!/usr/bin/env bash
# Verifies intensity-analyze.sh classifies a multi-component feature as scope=moderate, intensity=Standard.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

output="$(echo "Add a new API endpoint for user profile updates with validation and error handling" | bash "$f" 2>/dev/null)"

scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$scope_val" != "moderate" ]]; then
  echo "FAIL: multi-component feature classified as scope=$scope_val, expected moderate"; exit 1
fi
if [[ "$intensity_val" != "Standard" ]]; then
  echo "FAIL: multi-component feature classified as intensity=$intensity_val, expected Standard"; exit 1
fi

echo "PASS: moderate task correctly classified as scope=moderate, recommended_intensity=Standard"

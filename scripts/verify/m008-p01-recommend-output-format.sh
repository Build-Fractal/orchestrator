#!/usr/bin/env bash
# Verifies intensity-recommend.sh outputs all required key=value fields.
set -eu

f="scripts/engine/intensity-recommend.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Provide pre-computed inputs so we don't depend on other scripts' runtime behavior
analyze="scope=moderate
risk_level=medium
complexity=moderate
risk_signals=none
recommended_intensity=Standard"

profile="cap_execution=local
cap_graph=false
cap_mcp=false
cap_ci=false
cap_subagent=false
cap_score=0"

output="$(bash "$f" --analyze-output "$analyze" --profile-output "$profile" 2>/dev/null)"

echo "$output" | grep -q "^intensity=" || { echo "FAIL: output missing intensity="; exit 1; }
echo "$output" | grep -q "^confidence=" || { echo "FAIL: output missing confidence="; exit 1; }
echo "$output" | grep -q "^reasoning=" || { echo "FAIL: output missing reasoning="; exit 1; }
echo "$output" | grep -q "^scope=" || { echo "FAIL: output missing scope="; exit 1; }
echo "$output" | grep -q "^risk_level=" || { echo "FAIL: output missing risk_level="; exit 1; }
echo "$output" | grep -q "^complexity=" || { echo "FAIL: output missing complexity="; exit 1; }
echo "$output" | grep -q "^risk_signals=" || { echo "FAIL: output missing risk_signals="; exit 1; }
echo "$output" | grep -q "^cap_score=" || { echo "FAIL: output missing cap_score="; exit 1; }

# Verify intensity is a valid value
intensity_val="$(echo "$output" | grep "^intensity=" | cut -d= -f2)"
case "$intensity_val" in
  Quick|Standard|Full) ;;
  *) echo "FAIL: intensity='$intensity_val' is not Quick|Standard|Full"; exit 1 ;;
esac

# Verify confidence is a valid value
conf_val="$(echo "$output" | grep "^confidence=" | cut -d= -f2)"
case "$conf_val" in
  high|medium|low) ;;
  *) echo "FAIL: confidence='$conf_val' is not high|medium|low"; exit 1 ;;
esac

echo "PASS: intensity-recommend.sh outputs all required key=value fields with valid values"

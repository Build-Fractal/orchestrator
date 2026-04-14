#!/usr/bin/env bash
# Verifies intensity-analyze.sh outputs all required key=value fields.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

output="$(echo "Add a new user authentication module with OAuth2 support" | bash "$f" 2>/dev/null)"

echo "$output" | grep -q "^scope=" || { echo "FAIL: output missing scope="; exit 1; }
echo "$output" | grep -q "^risk_level=" || { echo "FAIL: output missing risk_level="; exit 1; }
echo "$output" | grep -q "^complexity=" || { echo "FAIL: output missing complexity="; exit 1; }
echo "$output" | grep -q "^risk_signals=" || { echo "FAIL: output missing risk_signals="; exit 1; }
echo "$output" | grep -q "^recommended_intensity=" || { echo "FAIL: output missing recommended_intensity="; exit 1; }

# Verify scope is a valid value
scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
case "$scope_val" in
  trivial|moderate|large) ;;
  *) echo "FAIL: scope='$scope_val' is not trivial|moderate|large"; exit 1 ;;
esac

# Verify recommended_intensity is a valid value
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"
case "$intensity_val" in
  Quick|Standard|Full) ;;
  *) echo "FAIL: recommended_intensity='$intensity_val' is not Quick|Standard|Full"; exit 1 ;;
esac

echo "PASS: intensity-analyze.sh outputs all required key=value fields with valid values"

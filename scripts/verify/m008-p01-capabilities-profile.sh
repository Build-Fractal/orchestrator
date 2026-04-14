#!/usr/bin/env bash
# Verifies detect-capabilities.sh --profile outputs capability summary.
set -eu

f="scripts/dispatch/detect-capabilities.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# Check --profile flag is handled
grep -q '\-\-profile' "$f" || { echo "FAIL: $f missing --profile flag handling"; exit 1; }

# Run with --profile and verify output format
output="$(bash "$f" --profile 2>/dev/null)"
echo "$output" | grep -q "^cap_execution=" || { echo "FAIL: profile output missing cap_execution"; exit 1; }
echo "$output" | grep -q "^cap_graph=" || { echo "FAIL: profile output missing cap_graph"; exit 1; }
echo "$output" | grep -q "^cap_mcp=" || { echo "FAIL: profile output missing cap_mcp"; exit 1; }
echo "$output" | grep -q "^cap_ci=" || { echo "FAIL: profile output missing cap_ci"; exit 1; }
echo "$output" | grep -q "^cap_subagent=" || { echo "FAIL: profile output missing cap_subagent"; exit 1; }
echo "$output" | grep -q "^cap_score=" || { echo "FAIL: profile output missing cap_score"; exit 1; }

# Verify cap_score is a number 0-5
score="$(echo "$output" | grep "^cap_score=" | cut -d= -f2)"
if ! echo "$score" | grep -qE '^[0-5]$'; then
  echo "FAIL: cap_score='$score' is not a number 0-5"; exit 1
fi

echo "PASS: detect-capabilities.sh --profile outputs valid capability summary"

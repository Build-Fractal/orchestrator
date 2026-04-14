#!/usr/bin/env bash
# Verifies intensity-analyze.sh classifies a trivial task as scope=trivial, intensity=Quick.
set -eu

f="scripts/engine/intensity-analyze.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

output="$(echo "Fix typo in README.md" | bash "$f" 2>/dev/null)"

scope_val="$(echo "$output" | grep "^scope=" | cut -d= -f2)"
intensity_val="$(echo "$output" | grep "^recommended_intensity=" | cut -d= -f2)"

if [[ "$scope_val" != "trivial" ]]; then
  echo "FAIL: 'Fix typo in README.md' classified as scope=$scope_val, expected trivial"; exit 1
fi
if [[ "$intensity_val" != "Quick" ]]; then
  echo "FAIL: 'Fix typo in README.md' classified as intensity=$intensity_val, expected Quick"; exit 1
fi

echo "PASS: trivial task correctly classified as scope=trivial, recommended_intensity=Quick"

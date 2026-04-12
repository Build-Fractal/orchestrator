#!/usr/bin/env bash
# Verifies templates/autonomy-defaults.yaml declares tier_defaults mapping
# with the three canonical modes (minimal, standard, full).
set -eu
f="templates/autonomy-defaults.yaml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "tier_defaults:" "$f" || { echo "FAIL: $f missing tier_defaults block"; exit 1; }
grep -q "minimal" "$f" || { echo "FAIL: $f missing 'minimal' mode"; exit 1; }
grep -q "standard" "$f" || { echo "FAIL: $f missing 'standard' mode"; exit 1; }
grep -q "full" "$f" || { echo "FAIL: $f missing 'full' mode"; exit 1; }
echo "PASS: $f declares tier_defaults with all three modes"

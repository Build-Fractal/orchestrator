#!/usr/bin/env bash
# Verifies write-permissions.sh uses additive-only merge semantics (AD-13).
# Passes when the script contains the word "additive" in a comment AND
# references the _generated_by marker (used to detect user-authored files).
set -eu
f="scripts/lifecycle/write-permissions.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "additive" "$f" || { echo "FAIL: $f missing 'additive' comment (AD-13)"; exit 1; }
grep -q "_generated_by" "$f" || { echo "FAIL: $f missing _generated_by check"; exit 1; }
echo "PASS: $f implements additive merge (AD-13)"

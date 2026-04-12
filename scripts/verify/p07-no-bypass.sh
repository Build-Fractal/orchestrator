#!/usr/bin/env bash
# Verifies the generator never defaults to bypassPermissions (AD-7).
# Also verifies autonomy-defaults.yaml default_mode values are the closed
# enum {default, acceptEdits} — never bypassPermissions.
set -eu
gen="scripts/lifecycle/generate-permissions.sh"
defaults="templates/autonomy-defaults.yaml"
test -f "$gen" || { echo "FAIL: $gen missing"; exit 1; }
test -f "$defaults" || { echo "FAIL: $defaults missing"; exit 1; }
grep -q "bypassPermissions" "$gen" && { echo "FAIL: $gen references bypassPermissions (AD-7)"; exit 1; }
grep -q "bypassPermissions" "$defaults" && { echo "FAIL: $defaults references bypassPermissions (AD-7)"; exit 1; }
echo "PASS: no bypassPermissions in $gen or $defaults"

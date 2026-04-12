#!/usr/bin/env bash
# Verifies the P07 generator does NOT emit GSD-specific patterns (AD-10).
# Passes when Skill(gsd:*) / .gsd/ markers are absent from the generator
# script. This is a preventive check — if someone adds GSD patterns to
# generate-permissions.sh, this fails and the phase must-haves fail.
set -eu
f="scripts/lifecycle/generate-permissions.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "Skill(gsd" "$f" && { echo "FAIL: $f contains Skill(gsd pattern (AD-10 violation)"; exit 1; }
grep -q "\.gsd/" "$f" && { echo "FAIL: $f contains .gsd/ reference (AD-10 violation)"; exit 1; }
echo "PASS: no GSD patterns in $f"

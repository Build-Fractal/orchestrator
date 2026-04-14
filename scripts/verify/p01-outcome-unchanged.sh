#!/usr/bin/env bash
# Verifies record-result.sh accepts unchanged as a valid outcome.
set -eu
f="scripts/lifecycle/record-result.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "unchanged" "$f" || { echo "FAIL: $f missing unchanged outcome value"; exit 1; }
echo "PASS: record-result.sh accepts unchanged outcome"

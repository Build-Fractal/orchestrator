#!/usr/bin/env bash
# Verify docs/recipe-authoring.md has progressive disclosure header + audience label.
set -eu
f="docs/recipe-authoring.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "^# " "$f" || { echo "FAIL: missing title"; exit 1; }
grep -qi "user guide\|progressive disclosure\|self-contained" "$f" || { echo "FAIL: missing progressive disclosure statement"; exit 1; }
grep -qi "Audience:.*users" "$f" || { echo "FAIL: missing audience label 'users' (DC-2)"; exit 1; }
grep -q "## Overview" "$f" || { echo "FAIL: missing ## Overview section (DC-1)"; exit 1; }
echo "PASS: recipe-authoring.md header and audience label"

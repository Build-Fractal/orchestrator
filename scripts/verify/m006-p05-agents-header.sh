#!/usr/bin/env bash
# Verify scripts/AGENTS.md has progressive disclosure header + audience label.
set -eu
f="scripts/AGENTS.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
head -1 "$f" | grep -q "^#" || { echo "FAIL: missing title line starting with #"; exit 1; }
grep -qi "self-contained\|progressive disclosure\|contributor guide" "$f" || { echo "FAIL: missing progressive disclosure statement"; exit 1; }
grep -qi "Audience:.*contributors" "$f" || { echo "FAIL: missing audience label 'contributors' (DC-2)"; exit 1; }
grep -q "## Overview" "$f" || { echo "FAIL: missing ## Overview section (DC-1)"; exit 1; }
echo "PASS: scripts/AGENTS.md header and audience label"

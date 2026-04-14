#!/usr/bin/env bash
# Verify references/events.md has progressive disclosure header + audience label.
set -eu
f="references/events.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "^# " "$f" || { echo "FAIL: missing title line"; exit 1; }
grep -qi "progressive disclosure\|self-contained" "$f" || { echo "FAIL: missing progressive disclosure statement"; exit 1; }
grep -qi "Audience:" "$f" || { echo "FAIL: missing audience label (DC-2)"; exit 1; }
grep -q "## Overview" "$f" || { echo "FAIL: missing ## Overview section (DC-1)"; exit 1; }
echo "PASS: events.md header and audience label"

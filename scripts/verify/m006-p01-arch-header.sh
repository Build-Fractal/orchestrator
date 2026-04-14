#!/usr/bin/env bash
# Verify references/architecture.md has progressive disclosure header + audience label.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "^# Architecture Reference" "$f" || { echo "FAIL: missing title"; exit 1; }
grep -q "Progressive disclosure" "$f" || { echo "FAIL: missing progressive disclosure statement"; exit 1; }
grep -qi "Audience:" "$f" || { echo "FAIL: missing audience label (DC-2)"; exit 1; }
grep -q "## Overview" "$f" || { echo "FAIL: missing ## Overview section (DC-1)"; exit 1; }
echo "PASS: architecture.md header and audience label"

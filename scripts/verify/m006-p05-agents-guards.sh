#!/usr/bin/env bash
# Verify scripts/AGENTS.md documents double-sourcing guards.
set -eu
f="scripts/AGENTS.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "double-sourcing\|sourcing guard" "$f" || { echo "FAIL: missing double-sourcing guard section"; exit 1; }
grep -q "_SOURCED" "$f" || { echo "FAIL: missing guard pattern (_SOURCED variable)"; exit 1; }
grep -qi "AP-003\|missing.*guard" "$f" || { echo "FAIL: missing AP-003 or missing-guard antipattern reference"; exit 1; }
echo "PASS: scripts/AGENTS.md double-sourcing guard documentation"

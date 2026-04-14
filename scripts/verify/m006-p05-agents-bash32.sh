#!/usr/bin/env bash
# Verify scripts/AGENTS.md documents Bash 3.2 compatibility patterns.
set -eu
f="scripts/AGENTS.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "Bash 3\.2\|3\.2" "$f" || { echo "FAIL: missing Bash 3.2 compatibility mention"; exit 1; }
grep -q "declare -A" "$f" || { echo "FAIL: missing declare -A as prohibited construct"; exit 1; }
grep -qi "process substitution\|<(" "$f" || { echo "FAIL: missing process substitution documentation"; exit 1; }
grep -qi "AP-001\|platform-specific" "$f" || { echo "FAIL: missing AP-001 or platform-specific reference"; exit 1; }
echo "PASS: scripts/AGENTS.md Bash 3.2 compatibility documentation"

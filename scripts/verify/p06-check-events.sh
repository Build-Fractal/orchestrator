#!/usr/bin/env bash
# Verify check-events.sh exists, is executable, contains DOCTOR:EVENTS,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-events.sh"

# File exists
[ -f "$script" ] || { echo "FAIL: check-events.sh not found"; exit 1; }

# Is executable
[ -x "$script" ] || { echo "FAIL: check-events.sh not executable"; exit 1; }

# Contains structured output marker
grep -q 'DOCTOR:EVENTS' "$script" || { echo "FAIL: missing DOCTOR:EVENTS output"; exit 1; }

# Runs without crash
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:EVENTS' || { echo "FAIL: no DOCTOR:EVENTS in output"; exit 1; }

echo "PASS: check-events.sh verified"

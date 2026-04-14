#!/usr/bin/env bash
# Verify check-constitution.sh exists, is executable, contains DOCTOR:CONSTITUTION,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-constitution.sh"

# File exists
[ -f "$script" ] || { echo "FAIL: check-constitution.sh not found"; exit 1; }

# Is executable
[ -x "$script" ] || { echo "FAIL: check-constitution.sh not executable"; exit 1; }

# Contains structured output marker
grep -q 'DOCTOR:CONSTITUTION' "$script" || { echo "FAIL: missing DOCTOR:CONSTITUTION output"; exit 1; }

# Runs without crash (exit 0 or 1 are both valid)
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:CONSTITUTION' || { echo "FAIL: no DOCTOR:CONSTITUTION in output"; exit 1; }

echo "PASS: check-constitution.sh verified"

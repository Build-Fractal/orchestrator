#!/usr/bin/env bash
# Verify check-plans.sh exists, is executable, contains DOCTOR:PLANS,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-plans.sh"

# File exists and is executable
[ -f "$script" ] || { echo "FAIL: check-plans.sh not found"; exit 1; }
[ -x "$script" ] || { echo "FAIL: check-plans.sh not executable"; exit 1; }

# Contains structured output marker
grep -q 'DOCTOR:PLANS' "$script" || { echo "FAIL: missing DOCTOR:PLANS output"; exit 1; }

# Has minimum complexity (checks for at least 3 trigger patterns)
trigger_count="$(grep -cE 'bash-c|chain|heredoc|subshell|cmdsub|procsub|redirect|compound|inline' "$script" || true)"
[ "$trigger_count" -ge 3 ] || { echo "FAIL: check-plans.sh has too few trigger patterns ($trigger_count)"; exit 1; }

# Runs without crash (advisory — always exits 0)
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)"
echo "$output" | grep -q 'DOCTOR:PLANS' || { echo "FAIL: no DOCTOR:PLANS in output"; exit 1; }

echo "PASS: check-plans.sh verified"

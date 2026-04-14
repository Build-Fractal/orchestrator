#!/usr/bin/env bash
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
script="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"
[ -f "$script" ] || { echo "FAIL: run-doctor.sh not found"; exit 1; }
grep -q 'Checks passed' "$script" || { echo "FAIL: run-doctor.sh missing 'Checks passed' output"; exit 1; }
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'Checks passed' || { echo "FAIL: no 'Checks passed' in doctor output"; exit 1; }
echo "$output" | grep -qE 'Checks passed: [0-9]+ / [0-9]+' || { echo "FAIL: scored output not in N / M format"; exit 1; }
echo "PASS: run-doctor.sh produces scored health report"

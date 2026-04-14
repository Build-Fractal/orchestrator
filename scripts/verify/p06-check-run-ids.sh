#!/usr/bin/env bash
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
script="$PROJECT_ROOT/scripts/diagnostics/check-run-ids.sh"
[ -f "$script" ] || { echo "FAIL: check-run-ids.sh not found"; exit 1; }
[ -x "$script" ] || { echo "FAIL: check-run-ids.sh not executable"; exit 1; }
grep -q 'DOCTOR:RUNIDS' "$script" || { echo "FAIL: missing DOCTOR:RUNIDS output"; exit 1; }
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:RUNIDS' || { echo "FAIL: no DOCTOR:RUNIDS in output"; exit 1; }
echo "PASS: check-run-ids.sh verified"

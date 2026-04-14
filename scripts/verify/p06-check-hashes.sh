#!/usr/bin/env bash
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
script="$PROJECT_ROOT/scripts/diagnostics/check-hashes.sh"
[ -f "$script" ] || { echo "FAIL: check-hashes.sh not found"; exit 1; }
[ -x "$script" ] || { echo "FAIL: check-hashes.sh not executable"; exit 1; }
grep -q 'DOCTOR:HASHES' "$script" || { echo "FAIL: missing DOCTOR:HASHES output"; exit 1; }
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:HASHES' || { echo "FAIL: no DOCTOR:HASHES in output"; exit 1; }
echo "PASS: check-hashes.sh verified"

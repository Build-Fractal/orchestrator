#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh discovers gate scripts for a known phase
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SUITE="$PROJECT_ROOT/scripts/verify/run-suite.sh"

# m016 P01 has 5 known gate scripts
output=$(bash "$RUN_SUITE" m016 P01 2>&1) || true

# Check the header line reports the correct count
if echo "$output" | grep -q "(5 scripts)"; then
  echo "PASS: run-suite.sh discovers correct script count (5) for m016 P01"
  exit 0
fi

# Fallback: count per-script PASS/FAIL lines (at least 4 expected)
line_count=$(echo "$output" | grep -cE '^  (PASS|FAIL):' || true)
if [ "$line_count" -ge 4 ]; then
  echo "PASS: run-suite.sh discovered ${line_count} scripts for m016 P01"
  exit 0
fi

echo "FAIL: run-suite.sh did not discover expected scripts"
echo "Output: $output"
exit 1

#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh output format: per-script PASS/FAIL lines + summary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SUITE="$PROJECT_ROOT/scripts/verify/run-suite.sh"

output=$(bash "$RUN_SUITE" m016 P01 2>&1) || true

errors=""

# Check for header line
if ! echo "$output" | grep -qE '=== Verify Suite:.*scripts\) ===$'; then
  errors="${errors}  missing header line\n"
fi

# Check for at least one per-script result line (2-space indent + PASS/FAIL)
if ! echo "$output" | grep -qE '^  (PASS|FAIL): '; then
  errors="${errors}  missing per-script PASS/FAIL lines\n"
fi

# Check for summary line matching "PASS: N / FAIL: M" (no indent)
if ! echo "$output" | grep -qE '^PASS: [0-9]+ / FAIL: [0-9]+$'; then
  errors="${errors}  missing summary line (PASS: N / FAIL: M)\n"
fi

if [ -z "$errors" ]; then
  echo "PASS: run-suite.sh output contains header, per-script lines, and summary"
  exit 0
fi

echo "FAIL: run-suite.sh output format issues:"
printf "%b" "$errors"
echo "Output: $output"
exit 1

#!/usr/bin/env bash
# Verify no Bash 4+ features in the 5 target scripts
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

fail=0
for script in \
  scripts/verify/check-must-haves.sh \
  scripts/lifecycle/record-result.sh \
  scripts/telemetry/record-telemetry.sh \
  scripts/telemetry/aggregate-metrics.sh \
  scripts/dispatch/classify-complexity.sh \
  scripts/lifecycle/phase-transition.sh; do

  if grep -qE 'declare -A|readarray|mapfile' "$PROJECT_ROOT/$script" 2>/dev/null; then
    echo "FAIL: $script uses Bash 4+ features"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: all target scripts are Bash 3.2 compatible"
fi
exit $fail

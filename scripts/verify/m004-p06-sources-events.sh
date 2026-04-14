#!/usr/bin/env bash
# Verify that all 5 target scripts source lib/events.sh
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

  if ! grep -q 'events\.sh' "$PROJECT_ROOT/$script" 2>/dev/null; then
    echo "FAIL: $script does not source lib/events.sh"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: all target scripts source lib/events.sh"
fi
exit $fail

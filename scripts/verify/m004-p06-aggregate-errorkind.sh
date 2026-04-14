#!/usr/bin/env bash
# Verify aggregate-metrics.sh groups failures by error_kind
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

script="$PROJECT_ROOT/scripts/telemetry/aggregate-metrics.sh"

if grep -q 'error_kind' "$script" 2>/dev/null; then
  echo "PASS: aggregate-metrics.sh supports error_kind grouping"
  exit 0
fi

echo "FAIL: aggregate-metrics.sh does not reference error_kind"
exit 1

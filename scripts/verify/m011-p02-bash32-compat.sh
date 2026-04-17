#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail_count=0

for script in "$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"; do
  if ! /bin/bash -n "$script" 2>/dev/null; then
    echo "FAIL: $script does not pass bash -n syntax check"
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: ingest-spec.sh passes Bash 3.2 syntax check"
else
  echo "FAIL: $fail_count script(s) failed syntax check"
  exit 1
fi

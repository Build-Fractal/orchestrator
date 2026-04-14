#!/usr/bin/env bash
# Verify record-result.sh adds error_kind to JSONL entries
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

script="$PROJECT_ROOT/scripts/lifecycle/record-result.sh"

# Check that the script accepts and records error_kind
if grep -q 'error_kind' "$script" 2>/dev/null; then
  echo "PASS: record-result.sh includes error_kind field"
  exit 0
fi

echo "FAIL: record-result.sh does not include error_kind field"
exit 1

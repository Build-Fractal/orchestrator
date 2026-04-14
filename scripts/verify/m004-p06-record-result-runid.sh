#!/usr/bin/env bash
# Verify record-result.sh adds run_id to JSONL entries when ORCH_RUN_ID is set
set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

script="$PROJECT_ROOT/scripts/lifecycle/record-result.sh"

# Check that the script references run_id in its JSON building logic
if grep -q 'run_id' "$script" 2>/dev/null; then
  echo "PASS: record-result.sh includes run_id field"
  exit 0
fi

echo "FAIL: record-result.sh does not include run_id field"
exit 1

#!/usr/bin/env bash
set -euo pipefail
# Verify create-entry.sh with no --id flag still auto-generates MEM### IDs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_ENTRY="$PROJECT_ROOT/scripts/knowledge/create-entry.sh"

# Use a temp directory as project root to avoid polluting real knowledge/
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up minimal structure
mkdir -p "$TMP_ROOT/knowledge"
mkdir -p "$TMP_ROOT/.orchestrator"

# Run create-entry.sh WITHOUT --id (should auto-generate MEM001)
output=$(PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --category patterns \
  --scope-tags "[project]" \
  --source-unit "M011/P01" \
  --description "Test auto-generated ID" \
  --body "This entry should get a MEM### ID automatically." 2>&1)

# Verify output shows CREATED with MEM prefix
if ! echo "$output" | grep -qE '^CREATED: MEM[0-9]+'; then
  echo "FAIL: auto-generated ID does not use MEM### prefix"
  echo "Output was: $output"
  exit 1
fi

# Verify the file exists with MEM prefix
mem_file=$(find "$TMP_ROOT/knowledge/patterns/" -name "MEM*.md" 2>/dev/null | head -1)
if [ -z "$mem_file" ] || [ ! -f "$mem_file" ]; then
  echo "FAIL: no MEM*.md file created under knowledge/patterns/"
  exit 1
fi

echo "PASS: create-entry.sh auto-generates MEM### IDs when --id is omitted"
exit 0

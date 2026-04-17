#!/usr/bin/env bash
set -euo pipefail
# Verify create-entry.sh rejects SPEC- prefix when category does not start with spec/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_ENTRY="$PROJECT_ROOT/scripts/knowledge/create-entry.sh"

# Use a temp directory as project root
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge"
mkdir -p "$TMP_ROOT/.orchestrator"

# Attempt to create a SPEC- entry with a non-spec category — should fail
rc=0
output=$(PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --id SPEC-FR-001 \
  --category patterns \
  --scope-tags "[project]" \
  --source-unit "specs/test/spec.md" \
  --description "Invalid combo" \
  --body "SPEC- prefix with non-spec/ category should be rejected." 2>&1) || rc=$?

if [ "$rc" -eq 0 ]; then
  echo "FAIL: create-entry.sh accepted SPEC- prefix with non-spec/ category (should have rejected)"
  echo "Output was: $output"
  exit 1
fi

# Verify error message mentions the validation
if ! echo "$output" | grep -qi "SPEC-"; then
  echo "FAIL: error message does not mention SPEC- namespace"
  echo "Output was: $output"
  exit 1
fi

# Verify no file was created
if [ -f "$TMP_ROOT/knowledge/patterns/SPEC-FR-001.md" ]; then
  echo "FAIL: detail file was created despite validation failure"
  exit 1
fi

echo "PASS: create-entry.sh rejects SPEC- prefix with non-spec/ category"
exit 0

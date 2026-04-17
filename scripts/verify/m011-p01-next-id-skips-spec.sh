#!/usr/bin/env bash
set -euo pipefail
# Verify next_entry_id() skips SPEC-prefixed files when computing next MEM### ID
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REAL="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_ENTRY="$PROJECT_ROOT_REAL/scripts/knowledge/create-entry.sh"

# Use a temp directory as project root
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/patterns"
mkdir -p "$TMP_ROOT/knowledge/spec/requirement"
mkdir -p "$TMP_ROOT/.orchestrator"

# Source index-utils.sh with our temp root
export PROJECT_ROOT="$TMP_ROOT"
source "$PROJECT_ROOT_REAL/scripts/knowledge/lib/index-utils.sh" 2>/dev/null || true

# Create MEM001 entry
PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --category patterns \
  --scope-tags "[project]" \
  --source-unit "M011/P01" \
  --description "First entry" \
  --body "MEM001 body." >/dev/null 2>&1

# Create a SPEC-prefixed entry (should not affect MEM sequence)
PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --id SPEC-FR-001 \
  --category spec/requirement \
  --scope-tags "[project]" \
  --source-unit "specs/011/spec.md" \
  --description "Spec requirement" \
  --body "SPEC entry body." >/dev/null 2>&1

# Create MEM002 — if SPEC-FR-001 doesn't interfere, this should be MEM002
output=$(PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --category patterns \
  --scope-tags "[project]" \
  --source-unit "M011/P01" \
  --description "Second entry" \
  --body "MEM002 body." 2>&1)

# Verify the auto-generated ID is MEM002 (not MEM003 or some SPEC-contaminated value)
if echo "$output" | grep -q 'CREATED: MEM002'; then
  echo "PASS: next_entry_id() correctly skips SPEC- entries and returns MEM002"
  exit 0
fi

echo "FAIL: expected MEM002 but got different ID"
echo "Output was: $output"
exit 1

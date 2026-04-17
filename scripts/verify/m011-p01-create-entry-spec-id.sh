#!/usr/bin/env bash
set -euo pipefail
# Verify create-entry.sh accepts --id SPEC-FR-001 --category spec/requirement
# and creates the file at knowledge/spec/requirement/SPEC-FR-001.md
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_ENTRY="$PROJECT_ROOT/scripts/knowledge/create-entry.sh"

# Use a temp directory as project root to avoid polluting real knowledge/
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up minimal structure
mkdir -p "$TMP_ROOT/knowledge"
mkdir -p "$TMP_ROOT/.orchestrator"

# Run create-entry.sh with SPEC- prefix
output=$(PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --id SPEC-FR-001 \
  --category spec/requirement \
  --scope-tags "[project]" \
  --source-unit "specs/011-spec-management/spec.md" \
  --description "Test functional requirement" \
  --body "The system shall accept SPEC-prefixed IDs." 2>&1)

# Check file was created at the right path
detail_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md"
if [ ! -f "$detail_file" ]; then
  echo "FAIL: detail file not created at knowledge/spec/requirement/SPEC-FR-001.md"
  echo "Output was: $output"
  exit 1
fi

# Verify frontmatter has correct id
if ! grep -q '^id: SPEC-FR-001' "$detail_file"; then
  echo "FAIL: frontmatter id field does not contain SPEC-FR-001"
  exit 1
fi

# Verify frontmatter has correct category
if ! grep -q '^category: spec/requirement' "$detail_file"; then
  echo "FAIL: frontmatter category field does not contain spec/requirement"
  exit 1
fi

# Verify output contains CREATED prefix
if ! echo "$output" | grep -q '^CREATED:'; then
  echo "FAIL: output does not contain CREATED: prefix"
  echo "Output was: $output"
  exit 1
fi

echo "PASS: create-entry.sh creates SPEC-prefixed entries at nested category paths"
exit 0

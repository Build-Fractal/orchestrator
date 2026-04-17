#!/usr/bin/env bash
set -euo pipefail
# Verify rebuild-index.sh discovers entries under nested knowledge/spec/*/ directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE_ENTRY="$PROJECT_ROOT/scripts/knowledge/create-entry.sh"
REBUILD_INDEX="$PROJECT_ROOT/scripts/knowledge/rebuild-index.sh"

# Use a temp directory as project root
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/requirement"
mkdir -p "$TMP_ROOT/knowledge/spec/story"
mkdir -p "$TMP_ROOT/knowledge/patterns"
mkdir -p "$TMP_ROOT/.orchestrator"

# Create a regular MEM entry
PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --category patterns \
  --scope-tags "[project]" \
  --source-unit "M011/P01" \
  --description "Regular knowledge entry" \
  --body "This is a standard MEM entry." >/dev/null 2>&1

# Create a SPEC entry in nested dir
PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --id SPEC-FR-001 \
  --category spec/requirement \
  --scope-tags "[project]" \
  --source-unit "specs/011/spec.md" \
  --description "Test requirement" \
  --body "The system shall do X." >/dev/null 2>&1

# Create another SPEC entry
PROJECT_ROOT="$TMP_ROOT" bash "$CREATE_ENTRY" \
  --id SPEC-US-001 \
  --category spec/story \
  --scope-tags "[project]" \
  --source-unit "specs/011/spec.md" \
  --description "Test user story" \
  --body "As a developer I want to ingest specs." >/dev/null 2>&1

# Run rebuild-index.sh
output=$(PROJECT_ROOT="$TMP_ROOT" bash "$REBUILD_INDEX" --root "$TMP_ROOT" 2>&1)

# Verify index contains the MEM entry
if ! grep -q 'MEM001' "$TMP_ROOT/KNOWLEDGE-INDEX.md"; then
  echo "FAIL: KNOWLEDGE-INDEX.md does not contain MEM001"
  echo "Index contents:"
  cat "$TMP_ROOT/KNOWLEDGE-INDEX.md"
  exit 1
fi

# Verify index contains the SPEC-FR entry
if ! grep -q 'SPEC-FR-001' "$TMP_ROOT/KNOWLEDGE-INDEX.md"; then
  echo "FAIL: KNOWLEDGE-INDEX.md does not contain SPEC-FR-001"
  echo "Index contents:"
  cat "$TMP_ROOT/KNOWLEDGE-INDEX.md"
  exit 1
fi

# Verify index contains the SPEC-US entry
if ! grep -q 'SPEC-US-001' "$TMP_ROOT/KNOWLEDGE-INDEX.md"; then
  echo "FAIL: KNOWLEDGE-INDEX.md does not contain SPEC-US-001"
  echo "Index contents:"
  cat "$TMP_ROOT/KNOWLEDGE-INDEX.md"
  exit 1
fi

# Verify rebuild output mentions the entry counts
if ! echo "$output" | grep -q 'REBUILT:'; then
  echo "FAIL: rebuild-index.sh output missing REBUILT: prefix"
  echo "Output was: $output"
  exit 1
fi

echo "PASS: rebuild-index.sh discovers and indexes entries from nested spec directories"
exit 0

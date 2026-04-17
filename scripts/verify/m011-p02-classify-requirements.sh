#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/requirement"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Functional Requirements

- **FR-001**: The system shall accept user input.
- **FR-002**: The system shall validate input before processing.
- **FR-003**: The system shall log all errors to stderr.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

pass=0
for id in SPEC-FR-001 SPEC-FR-002 SPEC-FR-003; do
  if echo "$output" | grep -q "CREATED: $id"; then
    pass=$((pass + 1))
  else
    echo "FAIL: Expected CREATED: $id in output"
    echo "Output: $output"
    exit 1
  fi
done

# Check category in frontmatter
fr_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md"
if [ -f "$fr_file" ] && grep -q "category: spec/requirement" "$fr_file"; then
  echo "PASS: $pass/3 requirements classified as spec/requirement with correct IDs"
else
  echo "FAIL: FR-001 file missing or wrong category"
  exit 1
fi

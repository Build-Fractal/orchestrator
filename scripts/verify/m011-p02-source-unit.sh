#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/constraint"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Constraints

- Must be fast.
SPEC

PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-source 2>/dev/null || true

con_file="$TMP_ROOT/knowledge/spec/constraint/SPEC-CON-001.md"
if [ -f "$con_file" ]; then
  source_unit="$(sed -n '/^---$/,/^---$/p' "$con_file" | grep "^source_unit:" | head -1)"
  if echo "$source_unit" | grep -q "test-spec.md"; then
    echo "PASS: source_unit contains spec path reference"
  else
    echo "FAIL: source_unit does not reference spec path: $source_unit"
    exit 1
  fi
else
  echo "FAIL: Constraint file not created"
  exit 1
fi

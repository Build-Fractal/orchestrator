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

- Must ship before M009.
- Must remain Bash 3.2 compatible.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

if echo "$output" | grep -q "CREATED: SPEC-CON-001" && echo "$output" | grep -q "CREATED: SPEC-CON-002"; then
  echo "PASS: 2 constraints classified as spec/constraint with SPEC-CON-NNN IDs"
else
  echo "FAIL: Expected CREATED: SPEC-CON-001 and SPEC-CON-002"
  echo "Output: $output"
  exit 1
fi

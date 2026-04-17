#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## Functional Requirements

- **FR-001**: Requirement one.
- **FR-002**: Requirement two.

## Constraints

- Constraint one.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-rebuild 2>&1)" || true

# Check that rebuild was called (look for REBUILT: line)
if echo "$output" | grep -q "^REBUILT:"; then
  echo "PASS: rebuild-index.sh called at end of ingest"
else
  echo "FAIL: No REBUILT: line in output -- rebuild-index.sh may not have been called"
  echo "Output: $output"
  exit 1
fi

# Check KNOWLEDGE-INDEX.md exists and contains spec entries
index_file="$TMP_ROOT/KNOWLEDGE-INDEX.md"
if [ -f "$index_file" ]; then
  spec_count="$(grep -c "SPEC-" "$index_file" || true)"
  if [ "$spec_count" -ge 3 ]; then
    echo "PASS: KNOWLEDGE-INDEX.md contains $spec_count SPEC- entries"
  else
    echo "FAIL: KNOWLEDGE-INDEX.md has only $spec_count SPEC- entries, expected >= 3"
    exit 1
  fi
else
  echo "FAIL: KNOWLEDGE-INDEX.md not found after ingest"
  exit 1
fi

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
# Idempotency Test

## User Scenarios & Testing

### User Story 1 - Test (Priority: P1)

Test story.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Test requirement.

## Constraints

- Test constraint.

## Non-Goals

- Test non-goal.
SPEC

# First ingest
output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-idempotent 2>&1)" || true

created_count1="$(echo "$output1" | grep -c "^CREATED:" || true)"
if [ "$created_count1" -lt 5 ]; then
  echo "FAIL: First ingest should create >= 5 chunks, got $created_count1"
  echo "Output: $output1"
  exit 1
fi

# Second ingest -- same spec, should produce no CREATED lines
output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-idempotent 2>&1)" || true

created_count2="$(echo "$output2" | grep -c "^CREATED:" || true)"
skipped_count2="$(echo "$output2" | grep -c "^SKIPPED:" || true)"

if [ "$created_count2" -eq 0 ]; then
  echo "PASS: Second ingest created 0 new chunks (idempotent). Skipped $skipped_count2."
else
  echo "FAIL: Second ingest created $created_count2 chunks (expected 0)"
  echo "Output: $output2"
  exit 1
fi

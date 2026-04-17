#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up minimal structure
mkdir -p "$TMP_ROOT/knowledge/spec/story"
mkdir -p "$TMP_ROOT/knowledge/spec/acceptance"
mkdir -p "$TMP_ROOT/.orchestrator"

# Create synthetic spec with one story + acceptance scenarios
cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## User Scenarios & Testing

### User Story 1 - Login Flow (Priority: P1)

A user wants to log in.

**Acceptance Scenarios**:

1. **Given** a valid user, **When** they log in, **Then** they see a dashboard.
2. **Given** an invalid user, **When** they log in, **Then** they see an error.

---
SPEC

# Run ingest
output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

# Check story was created
if echo "$output" | grep -q "CREATED: SPEC-US-001"; then
  echo "PASS: User story classified as spec/story with SPEC-US-001 ID"
else
  echo "FAIL: Expected CREATED: SPEC-US-001 in output"
  echo "Output: $output"
  exit 1
fi

# Check ACs were created with relates_to
if echo "$output" | grep -q "CREATED: SPEC-AC-001"; then
  echo "PASS: Acceptance scenario 1 classified as spec/acceptance"
else
  echo "FAIL: Expected CREATED: SPEC-AC-001 in output"
  echo "Output: $output"
  exit 1
fi

if echo "$output" | grep -q "CREATED: SPEC-AC-002"; then
  echo "PASS: Acceptance scenario 2 classified as spec/acceptance"
else
  echo "FAIL: Expected CREATED: SPEC-AC-002 in output"
  echo "Output: $output"
  exit 1
fi

# Check relates_to edge in AC file
ac_file="$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-001.md"
if [ -f "$ac_file" ]; then
  if grep -q "relates_to:.*SPEC-US-001" "$ac_file"; then
    echo "PASS: AC-001 has relates_to edge to SPEC-US-001"
  else
    echo "FAIL: AC-001 missing relates_to edge to SPEC-US-001"
    cat "$ac_file"
    exit 1
  fi
else
  echo "FAIL: AC file not created at $ac_file"
  exit 1
fi

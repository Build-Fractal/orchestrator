#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/knowledge/spec/story"
mkdir -p "$TMP_ROOT/knowledge/spec/acceptance"
mkdir -p "$TMP_ROOT/.orchestrator"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Spec

## User Scenarios & Testing

### User Story 1 - Login (Priority: P1)

Story text here.

**Acceptance Scenarios**:

1. **Given** valid creds, **When** login, **Then** success.
2. **Given** expired token, **When** refresh, **Then** new token.
3. **Given** locked account, **When** login, **Then** lockout message.

---

### User Story 2 - Logout (Priority: P2)

Story text here.

**Acceptance Scenarios**:

1. **Given** active session, **When** logout, **Then** session destroyed.

---
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-spec 2>&1)" || true

# Should have 2 stories and 4 acceptance scenarios
for id in SPEC-US-001 SPEC-US-002 SPEC-AC-001 SPEC-AC-002 SPEC-AC-003 SPEC-AC-004; do
  if ! echo "$output" | grep -q "CREATED: $id"; then
    echo "FAIL: Expected CREATED: $id in output"
    echo "Output: $output"
    exit 1
  fi
done

# Verify AC-001 through AC-003 relate to US-001
for num in 001 002 003; do
  ac_file="$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-${num}.md"
  if ! grep -q "SPEC-US-001" "$ac_file" 2>/dev/null; then
    echo "FAIL: SPEC-AC-${num} should relate_to SPEC-US-001"
    exit 1
  fi
done

# Verify AC-004 relates to US-002
ac4_file="$TMP_ROOT/knowledge/spec/acceptance/SPEC-AC-004.md"
if ! grep -q "SPEC-US-002" "$ac4_file" 2>/dev/null; then
  echo "FAIL: SPEC-AC-004 should relate_to SPEC-US-002"
  exit 1
fi

echo "PASS: 4 acceptance scenarios correctly linked to their parent stories"

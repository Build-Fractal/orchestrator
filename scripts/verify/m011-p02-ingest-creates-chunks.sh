#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up full spec directory structure
for dir in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$dir"
done
mkdir -p "$TMP_ROOT/.orchestrator"

# Create a comprehensive test spec
cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Test Feature Spec

## Problem Statement

This is a test.

## User Scenarios & Testing

### User Story 1 - Create Widget (Priority: P1)

A user creates a widget.

**Acceptance Scenarios**:

1. **Given** valid input, **When** submitted, **Then** widget created.

---

## Functional Requirements

- **FR-001**: Accept widget input.
- **FR-002**: Validate widget data.

## Constraints

- Must be Bash 3.2 compatible.

## Non-Goals

- No GUI support.
SPEC

output="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-feature 2>&1)" || true

# Count CREATED lines
created_count="$(echo "$output" | grep -c "^CREATED:" || true)"

if [ "$created_count" -ge 6 ]; then
  echo "PASS: ingest-spec.sh created $created_count chunks from test spec (expected >= 6: 1 story, 1 AC, 2 FRs, 1 constraint, 1 non-goal)"
else
  echo "FAIL: Expected >= 6 CREATED lines, got $created_count"
  echo "Output: $output"
  exit 1
fi

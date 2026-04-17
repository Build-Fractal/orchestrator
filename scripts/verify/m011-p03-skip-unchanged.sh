#!/usr/bin/env bash
# scripts/verify/m011-p03-skip-unchanged.sh
# Ingests a small test spec into a sandbox PROJECT_ROOT, then re-ingests it
# and asserts every chunk shows DECIDE-UNCHANGED: (or SKIPPED: after T02)
# and zero DECIDE-CHANGED: / DECIDE-NEW: lines.
#
# Output: PASS: or FAIL: prefixed lines. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT_REPO/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Scaffold the sandbox project root: knowledge/spec/* dirs + .orchestrator/
for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$sub"
done
mkdir -p "$TMP_ROOT/.orchestrator/tmp"

cat > "$TMP_ROOT/test-spec.md" <<'SPEC'
# Skip-Unchanged Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: First requirement.
- **FR-002**: Second requirement.

## Constraints

- First constraint.

## Non-Goals

- First non-goal.
SPEC

# First ingest -- seeds the sandbox
output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-skip-unchanged 2>&1)" || true

# Count chunks produced on first ingest (CREATED: from create-entry.sh)
first_chunks="$(printf '%s\n' "$output1" | grep -cE '^CREATED:' || true)"
if [ "$first_chunks" -lt 5 ]; then
  echo "FAIL: First ingest expected >= 5 CREATED chunks, got $first_chunks"
  echo "Output: $output1"
  exit 1
fi

# Second ingest on the unchanged spec
output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-skip-unchanged 2>&1)" || true

# Count decision lines on second ingest (strict SKIPPED: pattern)
unchanged_count="$(printf '%s\n' "$output2" | grep -cE '^SKIPPED:' || true)"
superseded_count="$(printf '%s\n' "$output2" | grep -cE '^SUPERSEDED:' || true)"
created_count="$(printf '%s\n' "$output2" | grep -cE '^CREATED:' || true)"

if [ "$superseded_count" -ne 0 ]; then
  echo "FAIL: Second ingest produced $superseded_count SUPERSEDED: lines (expected 0)"
  echo "Output: $output2"
  exit 1
fi

if [ "$created_count" -ne 0 ]; then
  echo "FAIL: Second ingest produced $created_count CREATED: lines (expected 0)"
  echo "Output: $output2"
  exit 1
fi

if [ "$unchanged_count" -lt 5 ]; then
  echo "FAIL: Second ingest expected >= 5 SKIPPED: lines, got $unchanged_count"
  echo "Output: $output2"
  exit 1
fi

echo "PASS: re-ingest of unchanged spec produced $unchanged_count SKIPPED lines, 0 superseded, 0 created"
exit 0

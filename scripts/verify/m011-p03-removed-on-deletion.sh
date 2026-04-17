#!/usr/bin/env bash
# scripts/verify/m011-p03-removed-on-deletion.sh
# Seed spec has FR-001 and FR-002. Re-ingest with FR-002 removed.
# Assert stdout contains REMOVED: SPEC-FR-002 and not REMOVED: SPEC-FR-001.
#
# Output: PASS: or FAIL: prefixed lines. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT_REPO/scripts/knowledge/ingest-spec.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$sub"
done
mkdir -p "$TMP_ROOT/.orchestrator/tmp"

# Seed spec -- FR-001 + FR-002
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Removed-on-Deletion Test

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

- Only constraint.
SPEC_V1

output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-removed 2>&1)" || true

# Sanity: both FRs created on first ingest
if ! printf '%s\n' "$output1" | grep -qE '^CREATED:.*SPEC-FR-001'; then
  echo "FAIL: First ingest did not create SPEC-FR-001"
  echo "Output: $output1"
  exit 1
fi
if ! printf '%s\n' "$output1" | grep -qE '^CREATED:.*SPEC-FR-002'; then
  echo "FAIL: First ingest did not create SPEC-FR-002"
  echo "Output: $output1"
  exit 1
fi

# Re-ingest with FR-002 removed
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Removed-on-Deletion Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: First requirement.

## Constraints

- Only constraint.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-removed 2>&1)" || true

# Assert REMOVED: SPEC-FR-002 appears
if ! printf '%s\n' "$output2" | grep -qE '^REMOVED: SPEC-FR-002$'; then
  echo "FAIL: Re-ingest did not emit REMOVED: SPEC-FR-002"
  echo "Output: $output2"
  exit 1
fi

# Assert REMOVED: SPEC-FR-001 does NOT appear (still present)
if printf '%s\n' "$output2" | grep -qE '^REMOVED: SPEC-FR-001'; then
  echo "FAIL: Re-ingest incorrectly emitted REMOVED for still-present SPEC-FR-001"
  echo "Output: $output2"
  exit 1
fi

echo "PASS: SPEC-FR-002 deletion emitted REMOVED: SPEC-FR-002; SPEC-FR-001 preserved"
exit 0

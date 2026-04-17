#!/usr/bin/env bash
# scripts/verify/m011-p03-phase-impact-review.sh
# Seed requirement with scope_tags including [phase:P05]; modify; re-ingest.
# Assert stdout contains REVIEW: P05 affected by SPEC-FR-001 supersession.
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

cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Phase-Impact Review Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Requirement scoped to a phase.

## Constraints

- Only constraint.
SPEC_V1

# First ingest with phase-scoped tags
output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-phase-impact \
  --scope-tags "[spec:test-phase-impact][phase:P05]" 2>&1)" || true

if ! printf '%s\n' "$output1" | grep -qE '^CREATED:.*SPEC-FR-001'; then
  echo "FAIL: First ingest did not create SPEC-FR-001"
  echo "Output: $output1"
  exit 1
fi

# Sanity: old detail file has scope_tags with phase:P05
old_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md"
if ! grep -qE '\[phase:P05\]' "$old_file"; then
  echo "FAIL: SPEC-FR-001.md scope_tags missing [phase:P05]"
  cat "$old_file"
  exit 1
fi

# Modify FR-001 body
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Phase-Impact Review Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Requirement scoped to a phase -- now modified.

## Constraints

- Only constraint.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-phase-impact \
  --scope-tags "[spec:test-phase-impact][phase:P05]" 2>&1)" || true

# Assert REVIEW: P05 affected by SPEC-FR-001 supersession
if ! printf '%s\n' "$output2" | grep -qE '^REVIEW: P05 affected by SPEC-FR-001 supersession$'; then
  echo "FAIL: Re-ingest did not emit REVIEW: P05 affected by SPEC-FR-001 supersession"
  echo "Output: $output2"
  exit 1
fi

echo "PASS: Phase-scoped supersession emitted REVIEW: P05 affected by SPEC-FR-001 supersession"
exit 0

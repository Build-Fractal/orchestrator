#!/usr/bin/env bash
# scripts/verify/m011-p03-removed-frontmatter.sh
# Seed spec with FR-001 and FR-002; re-ingest with FR-002 removed.
# Assert SPEC-FR-002.md frontmatter has superseded_by: "REMOVED" and
# no replacement file is created.
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
# Removed Frontmatter Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body.

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
  --slug test-rm-fm 2>&1)" || true

if ! printf '%s\n' "$output1" | grep -qE '^CREATED:.*SPEC-FR-002'; then
  echo "FAIL: First ingest did not create SPEC-FR-002"
  echo "Output: $output1"
  exit 1
fi

# Re-ingest without FR-002
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Removed Frontmatter Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body.

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
  --slug test-rm-fm 2>&1)" || true

removed_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-002.md"

if [ ! -f "$removed_file" ]; then
  echo "FAIL: SPEC-FR-002.md file missing after REMOVED mark"
  echo "Output: $output2"
  exit 1
fi

# Assert superseded_by: "REMOVED"
removed_line="$(grep -E '^superseded_by:' "$removed_file" | head -1 || true)"
case "$removed_line" in
  *'"REMOVED"'*) : ;;
  *)
    echo "FAIL: SPEC-FR-002 superseded_by is not \"REMOVED\": $removed_line"
    exit 1
    ;;
esac

# Assert no replacement file created (no SPEC-FR-002-v*)
for vfile in "$TMP_ROOT"/knowledge/spec/requirement/SPEC-FR-002-v*.md; do
  if [ -f "$vfile" ]; then
    echo "FAIL: Unexpected replacement file exists: $vfile"
    exit 1
  fi
done

echo "PASS: SPEC-FR-002 marked superseded_by=REMOVED; no replacement file created"
exit 0

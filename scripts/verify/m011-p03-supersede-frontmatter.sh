#!/usr/bin/env bash
# scripts/verify/m011-p03-supersede-frontmatter.sh
# Seed spec with FR-001, modify its body, re-ingest.
# Assert knowledge/spec/requirement/SPEC-FR-001.md has superseded_by: "SPEC-FR-001-v2"
# and SPEC-FR-001-v2.md has supersedes: "SPEC-FR-001".
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

# Seed spec
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Supersede Frontmatter Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Original requirement text.

## Constraints

- Only constraint.
SPEC_V1

output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-sup-fm 2>&1)" || true

if ! printf '%s\n' "$output1" | grep -qE '^CREATED:.*SPEC-FR-001'; then
  echo "FAIL: First ingest did not create SPEC-FR-001"
  echo "Output: $output1"
  exit 1
fi

# Modify FR-001 body
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Supersede Frontmatter Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Modified requirement with different content.

## Constraints

- Only constraint.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-sup-fm 2>&1)" || true

old_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001.md"
new_file="$TMP_ROOT/knowledge/spec/requirement/SPEC-FR-001-v2.md"

if [ ! -f "$old_file" ]; then
  echo "FAIL: Old detail file missing: $old_file"
  echo "Output: $output2"
  exit 1
fi

if [ ! -f "$new_file" ]; then
  echo "FAIL: New versioned detail file missing: $new_file"
  echo "Output: $output2"
  exit 1
fi

# Assert superseded_by on old file
old_sup="$(grep -E '^superseded_by:' "$old_file" | head -1 || true)"
case "$old_sup" in
  *'"SPEC-FR-001-v2"'*) : ;;
  *)
    echo "FAIL: Old file superseded_by is not \"SPEC-FR-001-v2\": $old_sup"
    exit 1
    ;;
esac

# Assert supersedes on new file
new_sups="$(grep -E '^supersedes:' "$new_file" | head -1 || true)"
case "$new_sups" in
  *'"SPEC-FR-001"'*) : ;;
  *)
    echo "FAIL: New file supersedes is not \"SPEC-FR-001\": $new_sups"
    exit 1
    ;;
esac

echo "PASS: SPEC-FR-001 superseded_by=SPEC-FR-001-v2; SPEC-FR-001-v2 supersedes=SPEC-FR-001"
exit 0

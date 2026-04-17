#!/usr/bin/env bash
# scripts/verify/m011-p03-supersede-on-change.sh
# Ingests a spec with one requirement, modifies its text, re-ingests,
# and asserts one DECIDE-CHANGED: (or SUPERSEDED:) line for the modified ID.
# Permissive grep so T02 can tighten to SUPERSEDED: without rewriting this file.
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

# Spec v1 -- single FR item alongside a tiny story + AC so the section
# splitter has something to route; the target of the change is FR-001.
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Supersede-on-Change Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

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
  --slug test-supersede 2>&1)" || true

# Sanity: first ingest must create SPEC-FR-001
if ! printf '%s\n' "$output1" | grep -qE '^CREATED:.*SPEC-FR-001'; then
  echo "FAIL: First ingest did not create SPEC-FR-001"
  echo "Output: $output1"
  exit 1
fi

# Modify FR-001 body text and re-ingest
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Supersede-on-Change Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: Modified requirement text with different content.

## Constraints

- Only constraint.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-supersede 2>&1)" || true

# Strict grep: require a SUPERSEDED: line for SPEC-FR-001.
changed_line="$(printf '%s\n' "$output2" | grep -E '^SUPERSEDED:.*SPEC-FR-001' || true)"

if [ -z "$changed_line" ]; then
  echo "FAIL: Re-ingest of modified spec did not emit SUPERSEDED: for SPEC-FR-001"
  echo "Output: $output2"
  exit 1
fi

# Also assert the other (unchanged) chunks remain unchanged (no extra SUPERSEDED)
other_changed="$(printf '%s\n' "$output2" | grep -E '^SUPERSEDED:' | grep -vE 'SPEC-FR-001' || true)"
if [ -n "$other_changed" ]; then
  echo "FAIL: Unexpected SUPERSEDED lines for unmodified chunks:"
  echo "$other_changed"
  exit 1
fi

echo "PASS: modified FR-001 produced SUPERSEDED, other chunks unchanged"
echo "      matched line: $changed_line"
exit 0

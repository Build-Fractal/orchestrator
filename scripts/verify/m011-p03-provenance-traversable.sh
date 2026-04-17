#!/usr/bin/env bash
# scripts/verify/m011-p03-provenance-traversable.sh
# Seeds FR-003, ingests, modifies FR-003, re-ingests.
# Calls traverse-graph.sh --provenance --id SPEC-FR-003 and asserts:
#   - First line matches: PROVENANCE: SPEC-FR-003 (chain length: 2)
#   - A line for SPEC-FR-003 with label (origin) or (superseded)
#   - A line for SPEC-FR-003-v2 with label (current)
#
# Output: PASS: or FAIL: prefixed lines. Exit 0 on pass, 1 on fail.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
INGEST="$PROJECT_ROOT_REPO/scripts/knowledge/ingest-spec.sh"
TRAVERSE="$PROJECT_ROOT_REPO/scripts/knowledge/traverse-graph.sh"
REBUILD="$PROJECT_ROOT_REPO/scripts/knowledge/rebuild-index.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

for sub in story requirement constraint nfr acceptance non-goal; do
  mkdir -p "$TMP_ROOT/knowledge/spec/$sub"
done
mkdir -p "$TMP_ROOT/.orchestrator/tmp"

# Seed spec with FR-003
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Provenance Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-003**: Original provenance body.

## Constraints

- Only constraint.
SPEC_V1

output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-provenance 2>&1)" || true

if ! printf '%s\n' "$output1" | grep -qE '^CREATED: SPEC-FR-003( |$)'; then
  echo "FAIL: First ingest did not create SPEC-FR-003"
  echo "Output: $output1"
  exit 1
fi

# Modify FR-003 and re-ingest
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Provenance Test

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-003**: Revised provenance body text for v2.

## Constraints

- Only constraint.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-provenance 2>&1)" || true

if ! printf '%s\n' "$output2" | grep -qE '^SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2$'; then
  echo "FAIL: Re-ingest did not emit 'SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2'"
  echo "Output: $output2"
  exit 1
fi

# Ensure knowledge.db is current (ingest-spec calls rebuild-index internally,
# but run explicitly for defense-in-depth in sandbox).
PROJECT_ROOT="$TMP_ROOT" bash "$REBUILD" >/dev/null 2>&1 || true

prov_out="$(PROJECT_ROOT="$TMP_ROOT" bash "$TRAVERSE" \
  --provenance --id SPEC-FR-003 2>&1)" || true

# First line must match exactly
first_line="$(printf '%s\n' "$prov_out" | head -1)"
if [ "$first_line" != "PROVENANCE: SPEC-FR-003 (chain length: 2)" ]; then
  echo "FAIL: First line of provenance output did not match expected header"
  echo "Expected: PROVENANCE: SPEC-FR-003 (chain length: 2)"
  echo "Got: $first_line"
  echo "Full output: $prov_out"
  exit 1
fi

# Must contain a line for SPEC-FR-003 with (origin) or (superseded) label
if ! printf '%s\n' "$prov_out" | grep -qE 'SPEC-FR-003 .*\((origin|superseded)\)$'; then
  echo "FAIL: Provenance output missing SPEC-FR-003 line with (origin) or (superseded) label"
  echo "Output: $prov_out"
  exit 1
fi

# Must contain a line for SPEC-FR-003-v2 with (current) label
if ! printf '%s\n' "$prov_out" | grep -qE 'SPEC-FR-003-v2 .*\(current\)$'; then
  echo "FAIL: Provenance output missing SPEC-FR-003-v2 line with (current) label"
  echo "Output: $prov_out"
  exit 1
fi

echo "PASS: provenance chain for SPEC-FR-003 traversable with length 2 and correct labels"
exit 0

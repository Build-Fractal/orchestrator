#!/usr/bin/env bash
# scripts/verify/m011-p03-demo-scenario.sh
# Reproduces the roadmap demo sentence exactly:
#   Seed FR-001 + FR-003 + FR-005 -> ingest (three CREATED:).
#   Rewrite: FR-003 text changed, FR-005 deleted, FR-001 unchanged -> re-ingest.
#   Assert SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2, SKIPPED: SPEC-FR-001,
#   REMOVED: SPEC-FR-005, and absence of SUPERSEDED: SPEC-FR-001 /
#   REMOVED: SPEC-FR-001 / REMOVED: SPEC-FR-003.
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

# Initial spec -- FR-001, FR-003, FR-005
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Demo Spec

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: First requirement (unchanged baseline).
- **FR-003**: Original text of the third requirement.
- **FR-005**: Fifth requirement that will be deleted.

## Constraints

- Only constraint.
SPEC_V1

output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug demo 2>&1)" || true

# First ingest: all three FRs must be CREATED
for fr in SPEC-FR-001 SPEC-FR-003 SPEC-FR-005; do
  if ! printf '%s\n' "$output1" | grep -qE "^CREATED: ${fr}( |\$)"; then
    echo "FAIL: First ingest did not create ${fr}"
    echo "Output: $output1"
    exit 1
  fi
done

# First ingest: no SUPERSEDED: or REMOVED: lines
if printf '%s\n' "$output1" | grep -qE '^SUPERSEDED:'; then
  echo "FAIL: First ingest emitted unexpected SUPERSEDED line"
  echo "Output: $output1"
  exit 1
fi
if printf '%s\n' "$output1" | grep -qE '^REMOVED:'; then
  echo "FAIL: First ingest emitted unexpected REMOVED line"
  echo "Output: $output1"
  exit 1
fi

# Rewrite: FR-003 text changed, FR-005 deleted, FR-001 unchanged
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Demo Spec

## User Scenarios & Testing

### User Story 1 - Alpha (Priority: P1)

Story body text.

**Acceptance Scenarios**:

1. **Given** a test, **When** run, **Then** passes.

---

## Functional Requirements

- **FR-001**: First requirement (unchanged baseline).
- **FR-003**: Revised text of the third requirement.

## Constraints

- Only constraint.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug demo 2>&1)" || true

# Required lines
if ! printf '%s\n' "$output2" | grep -qE '^SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2$'; then
  echo "FAIL: Re-ingest did not emit 'SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2'"
  echo "Output: $output2"
  exit 1
fi

if ! printf '%s\n' "$output2" | grep -qE '^SKIPPED: SPEC-FR-001$'; then
  echo "FAIL: Re-ingest did not emit 'SKIPPED: SPEC-FR-001'"
  echo "Output: $output2"
  exit 1
fi

if ! printf '%s\n' "$output2" | grep -qE '^REMOVED: SPEC-FR-005$'; then
  echo "FAIL: Re-ingest did not emit 'REMOVED: SPEC-FR-005'"
  echo "Output: $output2"
  exit 1
fi

# Forbidden lines
if printf '%s\n' "$output2" | grep -qE '^SUPERSEDED:.*SPEC-FR-001'; then
  echo "FAIL: Re-ingest unexpectedly emitted SUPERSEDED for SPEC-FR-001"
  echo "Output: $output2"
  exit 1
fi

if printf '%s\n' "$output2" | grep -qE '^REMOVED: SPEC-FR-001$'; then
  echo "FAIL: Re-ingest unexpectedly emitted REMOVED for SPEC-FR-001"
  echo "Output: $output2"
  exit 1
fi

if printf '%s\n' "$output2" | grep -qE '^REMOVED: SPEC-FR-003$'; then
  echo "FAIL: Re-ingest unexpectedly emitted REMOVED for SPEC-FR-003"
  echo "Output: $output2"
  exit 1
fi

echo "PASS: demo scenario produced SUPERSEDED/SKIPPED/REMOVED mix for FR-003/FR-001/FR-005"
exit 0

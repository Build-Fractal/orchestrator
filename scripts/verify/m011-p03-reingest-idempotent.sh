#!/usr/bin/env bash
# scripts/verify/m011-p03-reingest-idempotent.sh
# Chain-tip idempotency check:
#   1. Seed FR-001 + FR-003 + FR-005 -> ingest (3 CREATED:).
#   2. Modify FR-003, delete FR-005 -> ingest (SUPERSEDED + REMOVED).
#   3. Ingest the same modified spec again -> must be no-op:
#      zero CREATED, zero SUPERSEDED, zero REMOVED, exactly two SKIPPED
#      (one for FR-001 and one for FR-003 whose chain tip is SPEC-FR-003-v2).
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

# Seed spec -- FR-001, FR-003, FR-005 only (no other sections so the
# SKIPPED: count is deterministic).
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V1'
# Reingest Idempotent Test

## Functional Requirements

- **FR-001**: First requirement (baseline).
- **FR-003**: Original third requirement.
- **FR-005**: Fifth requirement to delete.
SPEC_V1

output1="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-reingest-idem 2>&1)" || true

for fr in SPEC-FR-001 SPEC-FR-003 SPEC-FR-005; do
  if ! printf '%s\n' "$output1" | grep -qE "^CREATED: ${fr}( |\$)"; then
    echo "FAIL: First ingest did not create ${fr}"
    echo "Output: $output1"
    exit 1
  fi
done

# Modify FR-003, delete FR-005
cat > "$TMP_ROOT/test-spec.md" <<'SPEC_V2'
# Reingest Idempotent Test

## Functional Requirements

- **FR-001**: First requirement (baseline).
- **FR-003**: Revised third requirement.
SPEC_V2

output2="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-reingest-idem 2>&1)" || true

if ! printf '%s\n' "$output2" | grep -qE '^SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2$'; then
  echo "FAIL: Second ingest did not supersede SPEC-FR-003"
  echo "Output: $output2"
  exit 1
fi
if ! printf '%s\n' "$output2" | grep -qE '^REMOVED: SPEC-FR-005$'; then
  echo "FAIL: Second ingest did not remove SPEC-FR-005"
  echo "Output: $output2"
  exit 1
fi

# Third ingest -- spec identical to second run's spec. Must be a no-op.
output3="$(PROJECT_ROOT="$TMP_ROOT" bash "$INGEST" \
  --spec-path "$TMP_ROOT/test-spec.md" \
  --slug test-reingest-idem 2>&1)" || true

created3="$(printf '%s\n' "$output3" | grep -c '^CREATED:' || true)"
superseded3="$(printf '%s\n' "$output3" | grep -c '^SUPERSEDED:' || true)"
removed3="$(printf '%s\n' "$output3" | grep -c '^REMOVED:' || true)"
skipped3="$(printf '%s\n' "$output3" | grep -c '^SKIPPED:' || true)"

if [ "$created3" -ne 0 ]; then
  echo "FAIL: Third ingest produced $created3 CREATED: lines (expected 0)"
  echo "Output: $output3"
  exit 1
fi
if [ "$superseded3" -ne 0 ]; then
  echo "FAIL: Third ingest produced $superseded3 SUPERSEDED: lines (expected 0)"
  echo "Output: $output3"
  exit 1
fi
if [ "$removed3" -ne 0 ]; then
  echo "FAIL: Third ingest produced $removed3 REMOVED: lines (expected 0)"
  echo "Output: $output3"
  exit 1
fi

# Two SKIPPED: lines expected -- SPEC-FR-001 and SPEC-FR-003 (chain tip match).
if ! printf '%s\n' "$output3" | grep -qE '^SKIPPED: SPEC-FR-001$'; then
  echo "FAIL: Third ingest did not emit SKIPPED: SPEC-FR-001"
  echo "Output: $output3"
  exit 1
fi
if ! printf '%s\n' "$output3" | grep -qE '^SKIPPED: SPEC-FR-003$'; then
  echo "FAIL: Third ingest did not emit SKIPPED: SPEC-FR-003 (chain-tip hash match)"
  echo "Output: $output3"
  exit 1
fi

if [ "$skipped3" -ne 2 ]; then
  echo "FAIL: Third ingest produced $skipped3 SKIPPED: lines (expected exactly 2)"
  echo "Output: $output3"
  exit 1
fi

echo "PASS: third ingest is a no-op (0 CREATED / 0 SUPERSEDED / 0 REMOVED, 2 SKIPPED)"
exit 0

#!/usr/bin/env bash
# scripts/verify/m011-p06-e2e-pipeline-timing.sh
# Timing harness: runs the same ingest -> metrics -> scope-filter sequence
# and asserts elapsed seconds < 60.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/specs/016-dogfood"
SPEC="$FIXTURE/specs/016-dogfood/spec.md"

# Reuse the same minimal spec shape as the pipeline gate. Keep the
# content identical so timing and functional gates stay in sync.
cat > "$SPEC" <<'SPECEOF'
# Feature Specification: Dogfood Spec

## User Scenarios & Testing

### User Story 1 - First Story (Priority: P1)

As a developer, I want to ingest a spec.

**Acceptance Scenarios**:

1. **Given** a markdown spec, **When** ingested, **Then** chunks are created.

### User Story 2 - Second Story (Priority: P1)

As a developer, I want idempotent re-ingest.

**Acceptance Scenarios**:

1. **Given** unchanged spec, **When** re-ingested, **Then** SKIPPED.

### User Story 3 - Third Story (Priority: P2)

As a developer, I want scope filtering.

**Acceptance Scenarios**:

1. **Given** ingested chunks, **When** filtered, **Then** SPEC-US-* returned.

## Functional Requirements

- **FR-001**: Accept --spec-path.
- **FR-002**: Accept --slug.
- **FR-003**: Classify sections.
- **FR-004**: Idempotent re-ingest.
- **FR-005**: scope-filter enumerates stories.

## Constraints

- Bash 3.2 compatible.

## Non-Goals

- Non-markdown input.
SPECEOF

T_START="$(date +%s)"

PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/ingest-spec.sh" \
  --spec-path "$SPEC" \
  --slug "016-dogfood" \
  --scope-tags "[project]" >/dev/null 2>&1

bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" >/dev/null 2>&1

# scope-filter.sh requires positional args even in --graph mode (FILE_PATH
# is unused in graph mode, placeholder is fine).
PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/dispatch/scope-filter.sh" \
  "KNOWLEDGE-INDEX.md" "M011/P06" \
  --category spec/story --graph >/dev/null 2>&1 || true

T_END="$(date +%s)"

ELAPSED=$((T_END - T_START))

printf 'elapsed_seconds=%s\n' "$ELAPSED"

if [ "$ELAPSED" -ge 60 ]; then
  printf 'FAIL[timing]: pipeline took %s seconds (expected < 60)\n' "$ELAPSED"
  exit 1
fi

echo "PASS: e2e pipeline completed in ${ELAPSED}s (< 60s)"

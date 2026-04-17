#!/usr/bin/env bash
# scripts/verify/m011-p06-e2e-pipeline.sh
# End-to-end gate: ingest -> rebuild-index -> spec-metrics -> scope-filter.
# Runs against a sandboxed PROJECT_ROOT and asserts every stage produces
# the expected output.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# --- Build sandbox layout ---
mkdir -p "$FIXTURE/.orchestrator"
mkdir -p "$FIXTURE/specs/016-dogfood"

SPEC="$FIXTURE/specs/016-dogfood/spec.md"

# Build a minimal but representative markdown spec. The exact content
# doesn't need to exercise every classifier edge -- just enough sections
# that ingest-spec.sh produces chunks in multiple categories.
cat > "$SPEC" <<'SPECEOF'
# Feature Specification: Dogfood Spec

## User Scenarios & Testing

### User Story 1 - First Story (Priority: P1)

As a developer, I want to ingest a spec so that the orchestrator can
classify it.

**Acceptance Scenarios**:

1. **Given** a markdown spec, **When** the developer runs ingest, **Then** chunks are created.
2. **Given** the ingested spec, **When** evaluate runs, **Then** metrics come from chunks.

### User Story 2 - Second Story (Priority: P1)

As a developer, I want a deterministic chunker so that re-ingest is idempotent.

**Acceptance Scenarios**:

1. **Given** an unchanged spec, **When** re-ingested, **Then** all chunks emit SKIPPED.

### User Story 3 - Third Story (Priority: P2)

As a developer, I want scope-filter to enumerate story chunks.

**Acceptance Scenarios**:

1. **Given** ingested chunks, **When** scope-filter runs, **Then** it returns SPEC-US-* IDs.

## Functional Requirements

- **FR-001**: The ingest command accepts a --spec-path flag.
- **FR-002**: The ingest command accepts a --slug flag.
- **FR-003**: The ingest command classifies sections into chunks.
- **FR-004**: Re-ingest is idempotent.
- **FR-005**: scope-filter.sh enumerates spec/story chunks.

## Constraints

- Must be Bash 3.2 compatible.

## Non-Goals

- Non-markdown input formats.
SPECEOF

# --- Stage 1: ingest-spec.sh ---
set +e
INGEST_OUT="$(PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/ingest-spec.sh" \
  --spec-path "$SPEC" \
  --slug "016-dogfood" \
  --scope-tags "[project]" 2>&1)"
INGEST_RC=$?
set -e

if [ "$INGEST_RC" -ne 0 ]; then
  printf 'FAIL[ingest]: ingest-spec.sh exited non-zero (rc=%s)\n' "$INGEST_RC"
  printf 'Output:\n%s\n' "$INGEST_OUT"
  exit 1
fi

CREATED_LINES="$(printf '%s\n' "$INGEST_OUT" | grep -c '^CREATED:' || true)"
if [ "$CREATED_LINES" -lt 1 ]; then
  printf 'FAIL[ingest]: expected >=1 CREATED: line, got %s\n' "$CREATED_LINES"
  printf 'Output:\n%s\n' "$INGEST_OUT"
  exit 1
fi

# --- Stage 2: spec-metrics.sh ---
METRICS_OUT="$(bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" 2>/dev/null)"

get_metric() {
  local k="$1"
  printf '%s\n' "$METRICS_OUT" | awk -F= -v k="$k" '$1==k {print $2; exit}'
}

PRESENT="$(get_metric spec_chunks_present)"
STORY_COUNT="$(get_metric story_count)"
REQ_COUNT="$(get_metric requirement_count)"

if [ "$PRESENT" != "true" ]; then
  printf 'FAIL[metrics]: spec_chunks_present expected=true got=%s\n' "$PRESENT"
  printf 'Metrics:\n%s\n' "$METRICS_OUT"
  exit 1
fi

if [ "${STORY_COUNT:-0}" -lt 3 ]; then
  printf 'FAIL[metrics]: story_count expected>=3 got=%s\n' "$STORY_COUNT"
  printf 'Metrics:\n%s\n' "$METRICS_OUT"
  exit 1
fi

if [ "${REQ_COUNT:-0}" -lt 5 ]; then
  printf 'FAIL[metrics]: requirement_count expected>=5 got=%s\n' "$REQ_COUNT"
  printf 'Metrics:\n%s\n' "$METRICS_OUT"
  exit 1
fi

# --- Stage 3: scope-filter.sh --category spec/story --graph ---
# Note: scope-filter.sh requires positional <file-path> and <scope-context>
# arguments even in --graph mode. In graph mode, FILE_PATH is unused (the DB
# is queried directly), so we pass a placeholder. SCOPE_CONTEXT controls the
# SQL scope filter which always includes [project]-scoped entries.
STORY_OUT="$(PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/dispatch/scope-filter.sh" \
  "KNOWLEDGE-INDEX.md" "M011/P06" \
  --category spec/story --graph 2>/dev/null || true)"
STORY_IDS="$(printf '%s\n' "$STORY_OUT" | grep -c '^SPEC-US-' || true)"

if [ "$STORY_IDS" -lt 1 ]; then
  printf 'FAIL[scope-filter]: expected >=1 SPEC-US- line, got %s\n' "$STORY_IDS"
  printf 'Output:\n%s\n' "$STORY_OUT"
  exit 1
fi

echo "PASS: e2e pipeline ingest -> metrics -> scope-filter produced expected chunks"

---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M011"
name: "End-to-end pipeline gate script + timing harness"
depends_on: []
---

## Prerequisites

- P03 is complete: `scripts/knowledge/ingest-spec.sh` parses a markdown spec file and emits chunk entries under `<project-root>/knowledge/spec/<category>/SPEC-<type>-NNN.md` with `scope_tags: "[spec:<slug>]"` (when `--scope-tags` is not passed). It calls `rebuild-index.sh` at the end.
- P05 is complete: `scripts/state/spec-metrics.sh <orch_root>` emits `spec_chunks_present=true|false` and six category `<name>_count=N` lines to stdout.
- P04 is complete: `scripts/dispatch/scope-filter.sh --category spec/story --graph` enumerates `spec/story` chunk IDs on stdout (used by `commands/roadmap.md`'s chunks-first decomposition in P05).
- A real markdown spec is available in-repo at `specs/016-autonomous-hardening/spec.md` (or any other `specs/NNN-name/spec.md`) for the T03 dogfood. For the T02 gate script itself, a small synthetic fixture spec built inline in the verify script is sufficient — T02 proves the pipeline shape; T03 proves it on real content.

No `scripts/verify/m011-p06-e2e-pipeline.sh` or `-timing.sh` currently exists.

## Description

T02 delivers the end-to-end gate script that exercises the full ingest → rebuild-index → spec-metrics → scope-filter pipeline against a sandboxed `PROJECT_ROOT`, plus a timing harness that captures elapsed seconds and enforces the 60-second success criterion from the P06 roadmap demo sentence.

Two verify scripts, both self-contained under `mktemp -d`:

1. **`m011-p06-e2e-pipeline.sh`** — builds a minimal but representative markdown spec (3 stories, 5 requirements, 4 acceptances, 1 constraint, 1 non-goal) under a sandbox `PROJECT_ROOT`, invokes `ingest-spec.sh`, asserts ≥1 `CREATED:` line in output, runs `spec-metrics.sh` and asserts `spec_chunks_present=true` plus `story_count>=3` and `requirement_count>=5`, runs `scope-filter.sh --category spec/story --graph` and asserts ≥1 `SPEC-US-` line, exits 0 on all-pass.

2. **`m011-p06-e2e-pipeline-timing.sh`** — reuses the same fixture-building shape but wraps the ingest → spec-metrics → scope-filter sequence in `date +%s` bookends, computes `elapsed_seconds = end - start` with integer arithmetic (Bash 3.2 safe), and asserts `elapsed_seconds < 60`. Writes the integer to stdout for transcript capture.

Both scripts use a `trap 'rm -rf "$FIXTURE"' EXIT` cleanup so repeated runs do not leak `/tmp` state (P05/T03 pattern).

No production code changes in T02. Only two verify scripts.

## Steps

### Step 1: Write `scripts/verify/m011-p06-e2e-pipeline.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-e2e-pipeline.sh
# End-to-end gate: ingest → rebuild-index → spec-metrics → scope-filter.
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
# doesn't need to exercise every classifier edge — just enough sections
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
INGEST_OUT="$(PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/knowledge/ingest-spec.sh" \
  --spec-path "$SPEC" \
  --slug "016-dogfood" 2>&1)"
INGEST_RC=$?

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
  exit 1
fi

if [ "${REQ_COUNT:-0}" -lt 5 ]; then
  printf 'FAIL[metrics]: requirement_count expected>=5 got=%s\n' "$REQ_COUNT"
  exit 1
fi

# --- Stage 3: scope-filter.sh --category spec/story --graph ---
STORY_OUT="$(PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/dispatch/scope-filter.sh" \
  --category spec/story --graph 2>/dev/null || true)"
STORY_IDS="$(printf '%s\n' "$STORY_OUT" | grep -c '^SPEC-US-' || true)"

if [ "$STORY_IDS" -lt 1 ]; then
  printf 'FAIL[scope-filter]: expected >=1 SPEC-US- line, got %s\n' "$STORY_IDS"
  printf 'Output:\n%s\n' "$STORY_OUT"
  exit 1
fi

echo "PASS: e2e pipeline ingest → metrics → scope-filter produced expected chunks"
```

`chmod +x`.

Notes on the shape:

- The `PROJECT_ROOT=` env-var export to the ingest step is the convention used by `scripts/knowledge/lib/index-utils.sh::get_project_root` (already sourced by ingest-spec.sh). The P03 verify scripts use the same pattern.
- The `|| true` after `grep -c` is so `set -u` does not trip on the grep-no-match exit code.
- `scope-filter.sh` may need `PROJECT_ROOT=` too — follow whatever `scripts/dispatch/scope-filter.sh` does internally for its root resolution (same convention as P05 verify scripts).

### Step 2: Write `scripts/verify/m011-p06-e2e-pipeline-timing.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-e2e-pipeline-timing.sh
# Timing harness: runs the same ingest → metrics → scope-filter sequence
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
  --slug "016-dogfood" >/dev/null 2>&1

bash "$REPO/scripts/state/spec-metrics.sh" "$FIXTURE/.orchestrator" >/dev/null 2>&1

PROJECT_ROOT="$FIXTURE" bash "$REPO/scripts/dispatch/scope-filter.sh" \
  --category spec/story --graph >/dev/null 2>&1 || true

T_END="$(date +%s)"

ELAPSED=$((T_END - T_START))

printf 'elapsed_seconds=%s\n' "$ELAPSED"

if [ "$ELAPSED" -ge 60 ]; then
  printf 'FAIL[timing]: pipeline took %s seconds (expected < 60)\n' "$ELAPSED"
  exit 1
fi

echo "PASS: e2e pipeline completed in ${ELAPSED}s (< 60s)"
```

`chmod +x`.

### Step 3: Run both verify scripts

```
bash scripts/verify/m011-p06-e2e-pipeline.sh
bash scripts/verify/m011-p06-e2e-pipeline-timing.sh
```

Both must print `PASS:` and exit 0.

If the timing script prints `elapsed_seconds=<N>` with N ≥ 60 — investigate. The synthetic fixture is tiny; anything over 60 seconds implies a regression in `ingest-spec.sh`, `rebuild-index.sh`, or `spec-metrics.sh`. Do NOT relax the threshold in T02; fix upstream or surface the regression as a blocker.

## Must-Haves

- `scripts/verify/m011-p06-e2e-pipeline.sh` exists, is executable, builds a sandbox fixture spec, invokes `ingest-spec.sh` → `spec-metrics.sh` → `scope-filter.sh --category spec/story --graph`, asserts each stage produces expected output, and exits 0 on all-pass.
- `scripts/verify/m011-p06-e2e-pipeline-timing.sh` exists, is executable, captures elapsed seconds for the full pipeline, prints `elapsed_seconds=<N>`, and exits 0 only when `N < 60`.
- Both scripts clean up their sandbox via `trap 'rm -rf "$FIXTURE"' EXIT`.
- Both scripts are Bash 3.2 compatible (no `declare -A`, `mapfile`, `readarray`, `<(...)`).

## Verification

```
bash scripts/verify/m011-p06-e2e-pipeline.sh
bash scripts/verify/m011-p06-e2e-pipeline-timing.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

None — T02 has no in-phase dependencies. It consumes P03 (ingest-spec.sh) and P05 (spec-metrics.sh) artifacts directly from disk.

### From Disk (Pre-existing)

- `scripts/knowledge/ingest-spec.sh` — Key API: `ingest-spec.sh --spec-path <path> --slug <slug>`. Emits CREATED/SKIPPED/SUPERSEDED/REMOVED lines. Writes chunks under `<PROJECT_ROOT>/knowledge/spec/<category>/SPEC-<type>-NNN.md`. Calls `rebuild-index.sh` internally at the end.
- `scripts/state/spec-metrics.sh` — Key API: `spec-metrics.sh <orch_root>`. Emits 7 key=value lines including `spec_chunks_present`, `story_count`, `requirement_count`, `acceptance_count`, `constraint_count`, `nfr_count`, `non_goal_count`.
- `scripts/dispatch/scope-filter.sh` — Key API: `--category spec/story --graph` enumerates one SPEC-US-NNN ID per line on stdout (P04 extension).
- `scripts/knowledge/rebuild-index.sh` — invoked indirectly via ingest-spec.sh.
- `scripts/knowledge/lib/index-utils.sh::get_project_root` — honors `PROJECT_ROOT=` env var for sandboxed runs.

## Constraints

- Bash 3.2 compatible: no `declare -A`, `mapfile`, `readarray`, `<(...)`.
- AD-19 / AP-004 discipline: phase-plan `Check:` commands are single-script-file invocations (already satisfied).
- The gate script MUST use `mktemp -d` for its fixture and MUST `trap 'rm -rf "$FIXTURE"' EXIT` so `/tmp` does not accumulate stale state.
- The timing threshold is 60 seconds (from the P06 demo sentence). Do NOT relax it. If the synthetic fixture cannot complete in under 60s, that is a bug upstream, not a timing-gate defect.
- Do NOT introduce a runtime dependency on `jq` or `python3`.
- Do NOT modify `scripts/knowledge/ingest-spec.sh`, `scripts/state/spec-metrics.sh`, `scripts/dispatch/scope-filter.sh`, `scripts/knowledge/rebuild-index.sh`, or any other pre-existing script.
- Do NOT modify `commands/ingest.md`, `commands/evaluate.md`, or `commands/roadmap.md` — that is T01's / T03's scope.
- Error-tolerant prefixing: every `grep -c` that might report zero matches must be followed by `|| true` to stay compatible with `set -u` / common error modes.

## Expected Output

- `scripts/verify/m011-p06-e2e-pipeline.sh` (create, ~100–130 lines, executable).
- `scripts/verify/m011-p06-e2e-pipeline-timing.sh` (create, ~60–90 lines, executable).
- Both scripts print a `PASS:` line and exit 0 when invoked from the repo root.
- The timing script prints an `elapsed_seconds=<N>` line (before the final `PASS:` line) with N < 60.

Write the task summary via:

```
bash scripts/knowledge/write-summary.sh \
  --milestone M011 --phase P06 --task T02 \
  --provides "m011-p06-e2e-pipeline.sh end-to-end gate script (ingest → metrics → scope-filter sandbox), m011-p06-e2e-pipeline-timing.sh 60s threshold harness" \
  --requires "P03 ingest-spec.sh, P04 scope-filter.sh --category spec/story --graph, P05 spec-metrics.sh, rebuild-index.sh" \
  --affects "T03 evidence-capture reuses the same pipeline shape against a real in-repo spec, P06 phase verification gates on these two scripts passing, milestone-level validation of chunks-first dispatch path" \
  --key-files "scripts/verify/m011-p06-e2e-pipeline.sh, scripts/verify/m011-p06-e2e-pipeline-timing.sh" \
  --verification-result pass \
  --body="T02 delivers two Bash 3.2 compatible verify scripts: an end-to-end pipeline gate that builds a synthetic markdown fixture spec, exercises ingest → spec-metrics → scope-filter, and asserts each stage produces the expected output; plus a timing harness that captures elapsed seconds with date +%s bookends and enforces the 60-second P06 success criterion. Both scripts sandbox under mktemp -d with EXIT-trap cleanup. No production code changes."
```

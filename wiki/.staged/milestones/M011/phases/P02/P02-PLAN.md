---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M011"
goal: "Create the core spec ingestion script that parses markdown specs, classifies sections into chunk types, creates knowledge entries with graph relationships, and populates content hashes"
demo_sentence: "A developer runs `bash scripts/knowledge/ingest-spec.sh --spec-path specs/016-autonomous-hardening/spec.md --slug 016-autonomous-hardening` and sees `CREATED: SPEC-US-001`, `CREATED: SPEC-FR-001`, ... for every story, requirement, constraint, NFR, acceptance scenario, and non-goal in the spec, with `relates_to` edges linking stories to their acceptance scenarios."
risk: "high"
depends_on: [P01]
---

## Must-Haves

### Truths

- `ingest-spec.sh --spec-path <path> --slug <slug>` accepts a markdown spec file and emits `CREATED:` lines for each classified chunk
  - Check: `bash scripts/verify/m011-p02-ingest-creates-chunks.sh`
- The script classifies `### User Story N` headings as `spec/story` with SPEC-US-NNN IDs
  - Check: `bash scripts/verify/m011-p02-classify-stories.sh`
- The script classifies `- **FR-NNN**:` items under `## Functional Requirements` as `spec/requirement` with SPEC-FR-NNN IDs
  - Check: `bash scripts/verify/m011-p02-classify-requirements.sh`
- The script classifies items under `## Constraints` as `spec/constraint` with SPEC-CON-NNN IDs
  - Check: `bash scripts/verify/m011-p02-classify-constraints.sh`
- The script classifies items under `## Non-Goals` as `spec/non-goal` with SPEC-NG-NNN IDs
  - Check: `bash scripts/verify/m011-p02-classify-nongoals.sh`
- The script classifies Given/When/Then blocks under user stories as `spec/acceptance` with SPEC-AC-NNN IDs and `relates_to` the parent story
  - Check: `bash scripts/verify/m011-p02-classify-acceptance.sh`
- Each chunk has `source_unit` pointing to the spec path and section identifier (FR-006)
  - Check: `bash scripts/verify/m011-p02-source-unit.sh`
- Each chunk has a non-empty `content_hash` field in frontmatter set to `sha256:{hex}` format
  - Check: `bash scripts/verify/m011-p02-content-hash.sh`
- Running ingest twice on the same unchanged spec produces no new `CREATED:` lines (idempotency via create-entry.sh EXISTS check, FR-007)
  - Check: `bash scripts/verify/m011-p02-idempotent.sh`
- `rebuild-index.sh` is called once at the end of ingest and the resulting KNOWLEDGE-INDEX.md contains all spec entries (FR-013)
  - Check: `bash scripts/verify/m011-p02-rebuild-index.sh`
- All new and modified scripts pass `bash -n` syntax check under Bash 3.2
  - Check: `bash scripts/verify/m011-p02-bash32-compat.sh`

### Artifacts

- `scripts/knowledge/ingest-spec.sh` (min 150 lines, contains "CREATED:")
- `scripts/verify/m011-p02-ingest-creates-chunks.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-classify-stories.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-classify-requirements.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-classify-constraints.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-classify-nongoals.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-classify-acceptance.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-source-unit.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p02-content-hash.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p02-idempotent.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p02-rebuild-index.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p02-bash32-compat.sh` (min 5 lines, contains "PASS")

### Key Links

- `scripts/knowledge/ingest-spec.sh` -> `scripts/knowledge/create-entry.sh` (calls create-entry.sh per chunk with --id, --category, --body, --relates-to)
- `scripts/knowledge/ingest-spec.sh` -> `scripts/knowledge/rebuild-index.sh` (calls rebuild-index.sh once at end of ingest)
- `scripts/knowledge/ingest-spec.sh` -> `scripts/lib/hash.sh` (sources hash.sh for compute_content_hash)

## Tasks

### T01: Core ingest script skeleton + section splitter

See `tasks/T01-PLAN.md`.

### T02: Section classifiers + chunk creation

See `tasks/T02-PLAN.md`.

### T03: Content hash + idempotency + end-to-end verification

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 (no deps)
T02 depends on T01
T03 depends on T02
```

Linear chain: T01 -> T02 -> T03. Each task builds on the previous. T01 creates the script skeleton and section splitter. T02 fills in the classifiers and chunk creation. T03 wires content hashing, verifies idempotency, and runs end-to-end tests.

## Files Likely Touched

- `scripts/knowledge/ingest-spec.sh` (create)
- `scripts/verify/m011-p02-ingest-creates-chunks.sh` (create)
- `scripts/verify/m011-p02-classify-stories.sh` (create)
- `scripts/verify/m011-p02-classify-requirements.sh` (create)
- `scripts/verify/m011-p02-classify-constraints.sh` (create)
- `scripts/verify/m011-p02-classify-nongoals.sh` (create)
- `scripts/verify/m011-p02-classify-acceptance.sh` (create)
- `scripts/verify/m011-p02-source-unit.sh` (create)
- `scripts/verify/m011-p02-content-hash.sh` (create)
- `scripts/verify/m011-p02-idempotent.sh` (create)
- `scripts/verify/m011-p02-rebuild-index.sh` (create)
- `scripts/verify/m011-p02-bash32-compat.sh` (create)

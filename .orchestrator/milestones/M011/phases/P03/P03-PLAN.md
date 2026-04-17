---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M011"
goal: "Extend ingest-spec.sh with a re-ingest mode that compares content hashes against existing entries, supersedes changed chunks via supersede-entry.sh, marks removed chunks with superseded_by: REMOVED, emits REVIEW lines when affected phases are detected, and leaves the supersession chain traversable via traverse-graph.sh --provenance"
demo_sentence: "A developer modifies FR-003 in the spec, re-runs `ingest-spec.sh`, and sees `SUPERSEDED: SPEC-FR-003 → SPEC-FR-003-v2` for the changed requirement, `SKIPPED: SPEC-FR-001` for unchanged requirements, and `REMOVED: SPEC-FR-005` for a deleted requirement — with the supersession chain traversable via `traverse-graph.sh --provenance --id SPEC-FR-003`."
risk: "high"
depends_on: [P02]
---

## Must-Haves

### Truths

<!-- Each truth has a single-script-file Check per AD-19. -->

- `ingest-spec.sh` emits `SUPERSEDED: <old-id> -> <new-id>` when a chunk's normalized body hash differs from the existing entry's `content_hash`
  - Check: `bash scripts/verify/m011-p03-supersede-on-change.sh`
- `ingest-spec.sh` emits `SKIPPED: <id>` for chunks whose normalized body hash matches the existing `content_hash`
  - Check: `bash scripts/verify/m011-p03-skip-unchanged.sh`
- `ingest-spec.sh` emits `REMOVED: <id>` for entries whose derived chunk IDs are absent from the re-ingested spec
  - Check: `bash scripts/verify/m011-p03-removed-on-deletion.sh`
- For each `SUPERSEDED:` event the new chunk file exists at `knowledge/spec/<type>/<id>-v<N>.md` and the old entry's frontmatter has `superseded_by: "<new-id>"`
  - Check: `bash scripts/verify/m011-p03-supersede-frontmatter.sh`
- For each `REMOVED:` event the old entry's frontmatter has `superseded_by: "REMOVED"` and no replacement file is created
  - Check: `bash scripts/verify/m011-p03-removed-frontmatter.sh`
- The supersession chain for a changed chunk is traversable via `traverse-graph.sh --provenance --id <old-id>` and shows the origin, superseded, and current labels
  - Check: `bash scripts/verify/m011-p03-provenance-traversable.sh`
- When a superseded or removed chunk's `scope_tags` reference a milestone phase (`[phase:P##]` or `[milestone:M###/P##]`), ingest-spec.sh emits a `REVIEW: P## affected by <id> supersession` line
  - Check: `bash scripts/verify/m011-p03-phase-impact-review.sh`
- Re-running ingest a second time on the already-modified spec produces zero new `SUPERSEDED:`, `CREATED:`, or `REMOVED:` lines (re-ingest is itself idempotent)
  - Check: `bash scripts/verify/m011-p03-reingest-idempotent.sh`
- The end-to-end demo scenario (modify FR-003, delete FR-005, leave FR-001 unchanged) produces exactly the expected mix of `SUPERSEDED`, `SKIPPED`, and `REMOVED` lines
  - Check: `bash scripts/verify/m011-p03-demo-scenario.sh`
- `ingest-spec.sh` passes `bash -n` syntax check under Bash 3.2 with no `declare -A` / associative-array usage
  - Check: `bash scripts/verify/m011-p03-bash32-compat.sh`

### Artifacts

- `scripts/knowledge/ingest-spec.sh` (min 700 lines, contains "SUPERSEDED:")
- `scripts/verify/m011-p03-supersede-on-change.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-skip-unchanged.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-removed-on-deletion.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-supersede-frontmatter.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-removed-frontmatter.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-provenance-traversable.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-phase-impact-review.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-reingest-idempotent.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p03-demo-scenario.sh` (min 30 lines, contains "PASS")
- `scripts/verify/m011-p03-bash32-compat.sh` (min 5 lines, contains "PASS")

### Key Links

- `scripts/knowledge/ingest-spec.sh` -> `scripts/knowledge/supersede-entry.sh` (calls supersede-entry.sh with --old-id/--new-id when a chunk's hash changes)
- `scripts/knowledge/ingest-spec.sh` -> `scripts/knowledge/lib/detail-utils.sh` (sources find_detail_file, fm_field, sed_i for reading existing content_hash and patching superseded_by)
- `scripts/knowledge/ingest-spec.sh` -> `scripts/knowledge/create-entry.sh` (calls create-entry.sh with versioned IDs like SPEC-FR-003-v2 for new chunks created during supersession)
- `scripts/knowledge/ingest-spec.sh` -> `scripts/knowledge/traverse-graph.sh` (chain built by ingest is traversable via --provenance mode; no direct call, but integration is verified)

## Tasks

### T01: Re-ingest change detection (lookup + hash compare + classification)

See `tasks/T01-PLAN.md`.

### T02: Supersession wiring + REMOVED marking + phase-impact review

See `tasks/T02-PLAN.md`.

### T03: End-to-end demo scenario + provenance + idempotent re-ingest verification

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 (no new deps beyond P02)
T02 depends on T01
T03 depends on T02
```

Linear chain: T01 -> T02 -> T03. T01 adds the classification layer (lookup existing, decide CREATE / SKIP / CHANGE / REMOVE). T02 wires CHANGE to `supersede-entry.sh`, REMOVE to `superseded_by: REMOVED` patching, and emits `REVIEW:` lines for phase-scoped chunks. T03 adds the end-to-end demo scenario verification plus idempotency and provenance checks.

## Files Likely Touched

- `scripts/knowledge/ingest-spec.sh` (modify)
- `scripts/verify/m011-p03-supersede-on-change.sh` (create)
- `scripts/verify/m011-p03-skip-unchanged.sh` (create)
- `scripts/verify/m011-p03-removed-on-deletion.sh` (create)
- `scripts/verify/m011-p03-supersede-frontmatter.sh` (create)
- `scripts/verify/m011-p03-removed-frontmatter.sh` (create)
- `scripts/verify/m011-p03-provenance-traversable.sh` (create)
- `scripts/verify/m011-p03-phase-impact-review.sh` (create)
- `scripts/verify/m011-p03-reingest-idempotent.sh` (create)
- `scripts/verify/m011-p03-demo-scenario.sh` (create)
- `scripts/verify/m011-p03-bash32-compat.sh` (create)

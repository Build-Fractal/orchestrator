---
schema_version: "1.0"
type: reference-frontmatter-contract
milestone: "M036"
phase: "P00"
created_at: "2026-05-01"
---

# Reference Chunk Frontmatter Contract (M036 SSOT)

Every reference markdown file ingested by `orchestrator:ingest`
into `knowledge/reference/<category>/REF-<cat>-<id>.md` MUST
carry the following frontmatter. Files missing required fields
are rejected at ingest (FR-2 / US-1 acceptance scenario 2).

This file is the single source of truth (Principle XI) for the
reference-chunk frontmatter shape. Consumers:

- `scripts/knowledge/ingest-reference.sh` (P04) — classifier +
  field validator (rejects on missing required field).
- `scripts/dispatch/build-context.sh` + injection helpers (P07) —
  topic-tag / applies-to-field retrieval.
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (T03 deliverable) —
  mechanical schema lint, called from `tools/verify/p00-taxonomy-rejects-unknown.sh`.

## Required Fields

These six fields are operator-supplied via the reference manifest
or per-document frontmatter override. Missing any of them rejects
the chunk at ingest (FR-2).

- `source` — operator-facing identifier of the publishing body
  (e.g., `cms`, `sme-pbj-circle`, `internal-glossary`). String.
- `published` — publication date in `YYYY-MM-DD` format. The
  extractor MAY auto-derive this from PDF/DOCX metadata; the
  operator manifest is the override path (Assumption A-2).
- `version` — operator-supplied version string. Free-form;
  orchestrator does not parse semver. The supersede chain
  (FR-10) is content-hash-driven, not version-string-driven —
  `version` is human-facing only.
- `cite_id` — unique stable identifier for citation. Must be
  unique within an ingest pass; duplicates are rejected (Edge
  Cases — "Two reference files declare the same `cite_id`").
- `topic_tags` — YAML list (may be empty). Free-form tags
  consumed by dispatch injection (FR-7) for topic-scoped
  retrieval.
- `applies_to_field` — YAML list (may be empty). Field names
  this content authoritatively governs (e.g., `staff_count`,
  `census`). Consumed by dispatch injection (FR-7) for
  field-scoped retrieval.

## Chunk-Output Additions

Fields the ingest classifier writes into the emitted chunk's
frontmatter (in addition to preserving the FR-2 fields above).
These are derived by the orchestrator, not operator-supplied
(FR-4):

- `category` — one of the four taxonomy values
  (`cms-rule|training-material|glossary|regulatory-doc`). See
  `references/reference-taxonomy.md`.
- `chunk_id` — the assigned `REF-<cat>-<id>` slug.
- `content_hash` — sha256 of the chunk body. Drives idempotent
  re-ingest (FR-9) and the supersede chain (FR-10).
- `scope_tags` — YAML list of orchestrator scope tags
  (`[project]`, `[milestone:M###]`, `[source:<cite_id>]`, etc.).
  The `[source:...]` namespace is M036-introduced — see
  `references/file-formats.md` `### Scope Tags`.

## Graph Edge Fields

Fields the ingest classifier interprets as graph edges into the
`KNOWLEDGE-INDEX.md` graph. Each is a YAML list of `chunk_id`
targets. Edge directionality is declared in
`references/reference-edge-types.md` (T02 deliverable).

- `cites` — chunk → reference. New in M036. Directional.
- `derived_from` — chunk → upstream-source-chunk. New in M036.
  Directional (downstream → upstream).
- `applies_to_field` — chunk → field-name. New in M036.
  (Note: `applies_to_field` is BOTH a frontmatter field name
  AND an edge type — the field is interpreted as an edge by
  the graph layer.)
- `relates_to` — bidirectional. Pre-existing (M011/M020).
  Listed for completeness; not authored by M036.
- `supersedes` — directional (newer → older). Pre-existing.
  Listed for completeness; not authored by M036.

## Validation

Frontmatter validation is mechanical:
`tools/verify/lib/p00-validate-chunk-frontmatter.sh` (T03
deliverable) reads stdin and rejects any chunk whose `category`
is outside the taxonomy or whose `tier` (when present, used by
the extract command) is outside `{0, 1, 2}`.

Structural shape (does this contract file declare every required
field name?) is gated by `tools/verify/p00-frontmatter-contract-shape.sh`
authored alongside this file (T01).

## Cross-References

- Closed taxonomy enumeration: `references/reference-taxonomy.md`.
- Per-category default extraction tier: `references/reference-source-types.yaml`.
- Edge directionality: `references/reference-edge-types.md` (T02 deliverable).
- Scope-tag namespace: `references/file-formats.md` `### Scope Tags`.
- Spec authority: `specs/033-reference-corpus-ingest/spec.md` (FR-2, FR-4, FR-5).

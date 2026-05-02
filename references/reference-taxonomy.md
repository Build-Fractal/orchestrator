---
schema_version: "1.0"
type: reference-taxonomy
milestone: "M036"
phase: "P00"
created_at: "2026-05-01"
---

# Reference Corpus Taxonomy (M036 SSOT)

The orchestrator's reference-corpus ingest (M036, spec
`specs/033-reference-corpus-ingest/spec.md`) recognizes a closed
four-category taxonomy. Files declared with a `category` field
outside this list are rejected at ingest (FR-1 / US-1 acceptance
scenario 3).

This file is the single source of truth (Principle XI). Consumers:
- `scripts/knowledge/ingest-reference.sh` (P04) — classifier
- `scripts/dispatch/extract.sh` (P02) — manifest validation
- `scripts/wiki/build-nav.sh` (P08) — top-level nav generation
- `references/reference-source-types.yaml` (P00) — keys must match

Adding or removing a category requires a follow-on M036 D-row in
`.orchestrator/DECISIONS.md` and a coordinated update across the
four consumers above. Do not hardcode the list in any consumer.

## Categories

### cms-rule

CMS-published regulatory rule. Citation-grade; small (typically
<50 pages); structure (sections, tables) matters for verbatim
quoting. Default extraction tier: 2 (clean structured Markdown).
Example `cite_id`: `cms-rule-483-20`.

### training-material

SME-authored training content (e.g., PBJ Circle decks). Already
prose; relatively small; high reference value across many
validator agents. Default extraction tier: 2. Example `cite_id`:
`training-pbj-circle-2024-08`.

### glossary

Definitional content (term → definition mappings). Frequently
cited in narrow excerpts. Default extraction tier: 2. Example
`cite_id`: `glossary-pbj-2024`.

### regulatory-doc

Long-form regulatory documents (CMS state operations manuals,
guidance bulletins). Often hundreds of pages; clean Markdown
conversion is expensive and produces a worse retrieval surface
than searchable plain text + read-section workflows. Default
extraction tier: 1 (searchable text via `pdftotext -layout`).
Example `cite_id`: `regulatory-cms-som-app-pp`.

## Cross-References

- Per-category default extraction tier: `references/reference-source-types.yaml`.
- Required frontmatter fields per chunk: `references/reference-frontmatter-contract.md`.
- Edge types authored by M036: `references/reference-edge-types.md` (T02 deliverable).
- Spec authority: `specs/033-reference-corpus-ingest/spec.md` (FR-1, FR-17, #Q-8).

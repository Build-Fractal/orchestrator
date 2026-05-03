---
schema_version: "1.0"
type: extract-manifest-contract
milestone: "M036"
phase: "P02"
created_at: "2026-05-02"
---

# Extract Manifest Contract (M036 SSOT)

The `orchestrator:extract` command (see `commands/extract.md`) consumes
an extraction manifest declaring per-document tier targets, summary
modes, and provenance frontmatter. This file is the single source of
truth (Principle XI) for the manifest schema. Consumers:

- `scripts/knowledge/extract-reference.sh` — the driver. Reads + validates.
- `scripts/knowledge/lib/extract-manifest.sh` — pure parser helpers.

Adding or changing a manifest field requires a follow-on M036 D-row in
`.orchestrator/DECISIONS.md` and a coordinated update to driver + lib
helpers + this contract in lockstep.

## Top-Level Fields

- `schema_version` — string, currently `"1.0"`.
- `type` — string, currently `"extract-manifest"`.
- `milestone` — string. Identifies the consumer's milestone for
  attribution in `unit_close` records (see FR-19, P03).
- `size_cap_bytes` — integer (default `10485760` = 10 MiB). Per CON-7,
  binaries above this cap record an `external_pointer:` instead of
  being copied into `_originals/`. Per-document override available via
  `size_cap_bytes_override:` in the document record.
- `documents:` — YAML list of per-document records (see Per-Document
  Fields below).

## Per-Document Fields (each list entry under `documents:`)

Required:

- `cite_id` — unique stable identifier. Becomes the chunk slug
  (`REF-<category>-<cite_id>`). Must be unique within a manifest
  pass; duplicates rejected per spec Edge Cases.
- `source_path` — relative path to the source binary, resolved against
  the manifest's directory (or absolute path).
- `category` — one of `cms-rule|training-material|glossary|regulatory-doc`
  (see `references/reference-taxonomy.md`). Out-of-taxonomy values
  rejected by `tools/verify/lib/p00-validate-chunk-frontmatter.sh`.
- `source` — operator-facing identifier of the publishing body (per
  `references/reference-frontmatter-contract.md`).
- `published` — `YYYY-MM-DD`.
- `version` — free-form string.
- `topic_tags` — YAML list (may be empty).
- `applies_to_field` — YAML list (may be empty).

Optional:

- `tier` — `0|1|2`. When omitted, the driver resolves from
  `references/reference-source-types.yaml` per category (FR-17).
- `summary_mode` — `operator|stub|auto` (see Summary Modes below).
  Default: `operator`.
- `summary` — operator-supplied summary text (required when
  `summary_mode: operator`).
- `size_cap_bytes_override` — integer, per-document override of the
  manifest-level `size_cap_bytes`.

## Summary Modes (P02 scope)

- `operator` — manifest entry's `summary:` string is written to the
  chunk frontmatter verbatim. Required field is `summary:`. Used in
  CI and for hand-authored summaries.
- `stub` — driver writes a deterministic placeholder summary
  (`"[stub-summary] <category>: <cite_id>"`). Used for smoke tests
  and Tier-2-pending docs that the operator hasn't yet annotated.
- `auto` — driver routes the summary call through the Tier 2 LLM
  pipeline. **NOT IMPLEMENTED in P02** — driver exits non-zero with a
  stderr message naming "P03" and "not implemented". P03 wires the
  conversus-gated Tier 2 path that fills this seam.

## Default-Tier Resolution

When a document record omits `tier:`, the driver reads
`references/reference-source-types.yaml` and resolves the category's
`default_tier`. For the launch taxonomy:

- `cms-rule` → 2
- `training-material` → 2
- `glossary` → 2
- `regulatory-doc` → 1

Per-document `tier:` overrides any default.

## Tier Output Layout (P02 = Tier 0/1)

For each document the driver emits:

- `_originals/<source>/<basename(source_path)>` — byte-identical copy
  of the binary, OR an `external_pointer:` recorded in chunk
  frontmatter when the binary exceeds `size_cap_bytes`. (FR-14, CON-7.)
- `knowledge/reference/<category>/REF-<category>-<cite_id>.md` — the
  chunk file (manifest entry + Tier 0 summary).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.text.md` —
  Tier 1 plain-text extraction (only when `tier: 1` or `tier: 2`).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.structured.md`
  — Tier 2 structured Markdown. **Authored in P03**, not P02.

## Idempotency

Re-running the driver on an unchanged manifest produces zero
modifications to the chunk store and the `_originals/` tree. Content
hash gates re-extraction at every tier (CON-4, FR-9). Output: every
doc emits `SKIPPED:` on the second run.

## Cross-References

- Closed taxonomy: `references/reference-taxonomy.md`.
- Per-category default tier: `references/reference-source-types.yaml`.
- Chunk frontmatter shape: `references/reference-frontmatter-contract.md`.
- Spec authority: `specs/033-reference-corpus-ingest/spec.md` (FR-14, FR-16, FR-17, CON-4, CON-7).

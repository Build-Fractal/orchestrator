---
description: "Use when extracting reference materials (PDF / Word / Excel / Markdown) into the orchestrator's reference-corpus knowledge layer. Synchronous Tier 0 (manifest + binary preservation + summary) and Tier 1 (deterministic plain-text via shell adapters); Tier 2 (LLM-driven structured Markdown) routes through M030 + conversus and is wired in P03."
---

# orchestrator:extract

Run a tiered extraction pass over a manifest of source documents. The command preserves original binaries under `_originals/<source>/` (CON-7), computes content hashes (FR-9, FR-14), and emits Tier 0 chunk files plus Tier 1 plain-text extraction files into the reference-corpus tree.

This command is **separate from `orchestrator:ingest`**: extract produces the artifacts ingest later promotes to chunks (FR-16). They compose: extract -> ingest -> dispatch.

## Prerequisites

- An extraction manifest at a known path (default convention: `<reference-root>/extract-manifest.yaml`). See `references/extract-manifest-contract.md` for the schema.
- Tier 1 host tools available for the formats the manifest declares:
  - `pdftotext` (poppler-utils) for PDFs.
  - `pandoc` for DOCX.
  - `python3 + openpyxl` for XLSX.
  - None required for `.md` (passthrough).
- The orchestrator's reference-corpus directory tree (`knowledge/reference/`) -- the command creates per-category subdirectories on demand.

## Inputs

- `--manifest <path>` (required) -- path to the extraction manifest.
- `--reference-root <path>` (optional, default `knowledge/reference`) -- root under which chunk files are written.
- `--originals-root <path>` (optional, default `.orchestrator/knowledge/reference/_originals`) -- root under which preserved binaries are written.
- `--summary-mode <operator|stub|auto>` (optional) -- overrides the manifest's per-document `summary_mode`. `auto` is **not implemented in P02**; that mode is the P03 seam.
- `--size-cap-bytes <int>` (optional) -- overrides the manifest's `size_cap_bytes`. Files above the cap record an `external_pointer:` instead of being copied into `_originals/`.

## Output

For each document in the manifest:

- `_originals/<source>/<filename>` -- byte-identical copy of the source binary, OR no copy when above the size cap (chunk frontmatter then carries `external_pointer:`).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.md` -- Tier 0 chunk: frontmatter (provenance + content_hash + tier) + body (Tier 0 summary).
- `knowledge/reference/<category>/REF-<category>-<cite_id>.text.md` -- Tier 1 plain-text extraction (when `tier: 1` or `tier: 2`).
- *(Tier 2 structured Markdown lands in P03.)*

Stdout protocol:

- `EXTRACTED: <cite_id> tier=<n> bytes=<n> hash=<sha256-prefix>` per newly-extracted doc.
- `SKIPPED: <cite_id> reason=unchanged` per content-hash-matched re-run.

Errors to stderr; non-zero exit on any error.

## Idempotency

Re-running on an unchanged manifest produces zero modifications under `<reference-root>` and `<originals-root>` (CON-4 / FR-9). Content hash gates re-extraction at every tier.

## Error Handling

- Missing `--manifest` path: exit 1, stderr names the missing flag.
- Source binary not found: exit 1, names the doc + missing path.
- `summary_mode: operator` without a `summary:` field: exit 1, names the doc.
- `summary_mode: auto`: exit 1 with stderr "P03 not implemented" pointer (Tier 2 wires in P03).
- Tier 1 adapter exit 2 (host tool absent): driver bails with a stderr hint pointing at `scripts/lifecycle/probe-extraction-tools.sh`.
- Out-of-taxonomy `category:`: rejected by `scripts/knowledge/lib/validate-chunk-frontmatter.sh` defence-in-depth check.

## Referenced Scripts

- `scripts/knowledge/extract-reference.sh` -- driver.
- `scripts/knowledge/lib/extract-manifest.sh` -- manifest accessors.
- `scripts/knowledge/lib/extract-binary-preservation.sh` -- sha256 + preservation.
- `scripts/knowledge/lib/extract-tier-0-summary.sh` -- summary modes + Tier 1 registry dispatch.
- `scripts/dispatch/adapters/format/markdown.sh` -- Tier 1 markdown adapter (P01).
- `scripts/dispatch/adapters/format/pdf.sh` -- Tier 1 PDF adapter (P01).
- `scripts/dispatch/adapters/format/docx.sh` -- Tier 1 DOCX adapter (P01).
- `scripts/dispatch/adapters/format/xlsx.sh` -- Tier 1 XLSX adapter (P01).
- `scripts/dispatch/adapters/format/registry.tsv` -- adapter dispatch table (P00 / P01).
- `references/extract-manifest-contract.md` -- manifest schema SSOT.
- `references/reference-source-types.yaml` -- per-category default tier.
- `references/reference-frontmatter-contract.md` -- chunk frontmatter SSOT.

## Reference Files

- `tests/fixtures/m036/extract-manifest.yaml` -- the M036 fixture manifest exercised by `tests/test-tier-0-manifest.sh` (SC-10).
- `tests/test-tier-0-manifest.sh` -- SC-10 acceptance harness.
- Spec authority: `specs/033-reference-corpus-ingest/spec.md` (FR-14, FR-16, FR-17, FR-18, FR-19, CON-3, CON-4, CON-7).

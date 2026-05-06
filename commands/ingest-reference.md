---
description: "Use when ingesting a populated reference-corpus tree into the orchestrator's knowledge graph. Walks knowledge/reference/<category>/REF-*.md, classifies (FR-1 taxonomy + FR-2 required fields), gates re-ingest via content_hash idempotency, surfaces Tier 2 BLOCK-verdict chunks as advisories, and rebuilds KNOWLEDGE-INDEX.md so reference chunks participate in graph traversal."
---

# orchestrator:ingest-reference

Ingest a reference-corpus tree (`knowledge/reference/<category>/REF-*.md`) into the orchestrator's knowledge graph.

This command is the **ingest layer** in the M036 reference-corpus pipeline. It consumes the chunk artifacts produced upstream by `orchestrator:extract` (M036/P02 + P03 — `scripts/knowledge/extract-reference.sh`) or operator-authored REF chunks placed directly under the reference root. Per-file classification gates each chunk against the M036 taxonomy + frontmatter contract; valid chunks are recognized as graph entries; invalid chunks are rejected with per-file errors (partial-success ingest); Tier 2 BLOCK-verdict chunks are surfaced as advisories per FR-18.

Run `orchestrator:ingest-reference` after a successful `orchestrator:extract` pass, or whenever you have hand-authored REF chunks to bring into the graph. The re-ingest path is idempotent (CON-4): unchanged chunks produce zero file modifications.

## Prerequisites

1. **Reference root populated** — a directory tree at `knowledge/reference/<category>/` (default) or a custom path passed via `--reference-root`. The four taxonomy categories (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`) are walked; any other top-level directory under the reference root is silently skipped (e.g., `_originals/`, `_extraction-log/`, `_negative/`).
2. **Knowledge tree initialized** — the `knowledge/` directory must exist at the orchestrator root. Created by `scripts/lifecycle/scaffold.sh` during `orchestrator:evaluate`. This command does not bootstrap the tree.
3. **Classifier helper present** — `scripts/knowledge/classify-reference.sh` (M036 P04 deliverable) and `scripts/knowledge/lib/validate-chunk-frontmatter.sh` (M036 P00 deliverable; relocated 2026-05-06 from `tools/verify/lib/p00-validate-chunk-frontmatter.sh` so it ships in the install bundle) must be present.
4. **Index rebuilder present** — `scripts/knowledge/rebuild-index.sh` (M011/M020 deliverable) must be present and recognize `REF-*` basenames (extended in M036 P04 — basename filter `MEM*|SPEC-*|REF-*`).

No prior orchestrator state beyond the knowledge tree is required — `orchestrator:ingest-reference` is safe to run before or after `orchestrator:evaluate`.

## Inputs

The canonical invocation:

```bash
bash scripts/knowledge/ingest-reference.sh [--reference-root <path>] [--no-index-rebuild]
```

User-facing flags:

- `--reference-root <path>` — optional. Absolute or repo-relative path to the reference-corpus root. Default: `knowledge/reference/`. Must exist (or be absent — see Edge Case "no reference corpus configured" below); if present, must contain at least one of the four taxonomy-category subdirectories.
- `--no-index-rebuild` — optional. Skip the final `rebuild-index.sh` invocation. Useful when chaining multiple ingest passes (e.g., spec ingest + reference ingest in the same operator workflow); rebuild once at the end.

## Output

Structured stdout per the M036-canonical contract:

- `CREATED: <chunk_id> category=<cat> tier=<n>` — emitted for each valid chunk that is not BLOCK-verdict and not unchanged-content-hash.
- `SKIPPED: <chunk_id> reason=unchanged-content-hash` — emitted for chunks whose frontmatter `content_hash` matches the body sha256 (re-ingest of an unchanged chunk).
- `REJECTED: <chunk_id> reason=<missing-required-field|unknown-category|...>` — emitted for chunks that fail FR-1 (taxonomy) or FR-2 (required-field presence). Per-file rejection — partial-success ingest continues with the next file.
- `BLOCKED: <chunk_id> reason=tier-2-fidelity-gate` — emitted for chunks whose Tier 0 frontmatter declares `tier_2_verdict: "BLOCK"`. The Tier 0 chunk persists on disk per FR-18; only the `.structured.md` sibling is withheld (and that withholding happens at extract-time in M036/P03, not at ingest-time here). Ingest verifies the absence of the structured-md sibling and emits a stderr WARNING if it finds one (operator-error indicator).
- `SUMMARY: ingest-reference.sh created=<n> skipped=<n> rejected=<n> blocked=<n>` — emitted as the last stdout line of the run.

Errors to stderr; non-zero exit only on unrecoverable error (per-chunk rejections do NOT abort the pass). Idempotency contract: re-running on an unchanged tree produces a `git status` reporting zero modified files under `knowledge/reference/`.

## Idempotency

Re-running `orchestrator:ingest-reference` is fully supported and is the expected workflow when the corpus evolves. CON-4 invariant: unchanged inputs produce zero file modifications.

- Unchanged chunks emit `SKIPPED:` (when the frontmatter `content_hash` matches the body sha256) or fall through to `CREATED:` (when the hash mismatches but the chunk is otherwise valid — this is the `extract-reference.sh` fall-through case where the frontmatter `content_hash` records the source-binary hash, not the body hash, so the per-line idempotency gate misses but the tree itself remains untouched).
- The hard idempotency invariant is the byte-identical tree across runs — the driver does not modify chunk files. T04's acceptance harness verifies this via tree-diff snapshots.

## Error Handling

- **Reference root missing** — exit 0 with `SUMMARY: ingest-reference.sh created=0 ... (no reference corpus configured)` (CON-1 backwards compat for projects that never ingest reference content).
- **Per-chunk classifier rejection** — emit `REJECTED:` line + stderr error naming the missing field or invalid category; continue with the next chunk. Final exit code is 0 unless an unrecoverable error (e.g., missing classifier helper) occurs.
- **rebuild-index.sh failure** — emit a stderr warning that the index may be stale; exit 0 (chunks are on disk; index can be rebuilt manually). The non-fatal posture matches the spec-chunk path at `commands/ingest.md:90`.

## Referenced Scripts / Templates

- `scripts/knowledge/ingest-reference.sh` — the production driver.
- `scripts/knowledge/classify-reference.sh` — taxonomy + required-field classifier helper (sourced by the driver).
- `scripts/knowledge/rebuild-index.sh` — index rebuilder (invoked at end unless `--no-index-rebuild`).
- `scripts/knowledge/lib/validate-chunk-frontmatter.sh` — taxonomy + tier validator delegated to by the classifier helper.

## Reference Files

- `references/reference-taxonomy.md` — M036 closed-taxonomy SSOT (4 categories).
- `references/reference-frontmatter-contract.md` — FR-2 required-field SSOT (6 fields per chunk).
- `references/reference-source-types.yaml` — per-category default extraction-tier mapping.
- `specs/033-reference-corpus-ingest/spec.md` — feature spec (FR-1 taxonomy, FR-2 frontmatter, FR-3 ingest, FR-9 idempotency, FR-18 BLOCK retention).

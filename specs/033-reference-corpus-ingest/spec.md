---
schema_version: "1.0"
type: feature-spec
feature_slug: "033-reference-corpus-ingest"
created_at: "2026-04-30"
amended_at: "2026-05-01"
status: "Draft (Amended 2026-05-01)"
milestone: "M036 (split: M036a pre-launch, M036b post-launch — see Amendment Record)"
---

# Feature Specification: 033-reference-corpus-ingest

**Feature Branch**: `033-reference-corpus-ingest`
**Created**: 2026-04-30
**Amended**: 2026-05-01 (extraction-ownership flip + tier model + M036a/M036b split — see Amendment Record below)
**Status**: Draft (Amended)
**Milestone**: M036 (split: M036a pre-launch urgent, M036b post-launch — see Amendment Record)
**Input**: User description: "Reference-corpus ingest: extend the orchestrator's knowledge layer to ingest non-spec reference materials (regulatory PDFs/Word/Excel, SME training content, glossaries) into a new reference/ chunk family with source-provenance frontmatter (source/published/version/cite_id/topic_tags/applies_to_field), new edge types (cites, derived_from, applies_to_field) alongside existing relates_to/supersedes, new [source:...] tag namespace, and dispatch context injection with a token-budget governor. Orchestrator-owned tiered extraction (Tier 0 manifest+original / Tier 1 cheap searchable text / Tier 2 LLM-driven structured Markdown with conversus fidelity gate). Idempotent re-ingest with content-hash + supersede chain. MkDocs wiki projection. Driven by PBJ Analyzer CMS regulatory + SME training corpus needs (validator pilot 2026-05-15)."

## Amendment Record (2026-05-01)

**Trigger**: Discussion 2026-05-01 with project owner clarified that PBJ Analyzer has **no path-B markdown-floor extractor**, externally or internally. The original spec (2026-04-30) was authored on the assumption that consumer projects normalize PDFs/XLS to markdown floors externally; that assumption was incorrect.

**Consequence**: Extraction is **orchestrator-owned** as a first-class capability, not a consumer concern. Three Non-Goals invert; the architecture gains a tier model; the milestone splits across pre-launch (urgent) and post-launch (scale + polish) slots.

**Changes captured in this amendment**:

| Section | Original | Amended |
|---|---|---|
| NG-3 (binary storage) | "no binary source storage" | **Inverted**: original binaries preserved at Tier 0 as source of truth (with size governance) |
| NG-4 (extraction pipeline) | "no auto-extraction pipelines (path-B handles externally)" | **Inverted**: orchestrator owns Tier 1 (deterministic shell adapters) and Tier 2 (LLM-driven, conversus-gated) extraction |
| NG-5 (LLM rewrite) | "no LLM-rewrite during ingest" | **Narrowed**: no LLM rewrite at Tier 0/1; Tier 2 LLM-driven extraction permitted under conversus fidelity gate |
| FR-13 (adapters) | PDF/XLS as stubs, markdown live | PDF/Word/Excel/markdown all **live** (Tier 1 minimum); Tier 2 LLM extraction declared per source-type |
| FR-14 (binary storage) | MUST NOT persist binaries | MUST preserve original binary at Tier 0 with content-hash and external-storage hook for >size-cap |
| Format list | PDF + XLS | PDF + Word/DOCX + Excel/XLS (and markdown floor for already-normalized) |
| #Q-3 (versioning) | Deferred | **Resolved**: supersede chain (preserves change-over-time queries; matches existing spec-chunk pattern) |
| #Q-5 (fidelity gate) | Deferred, default "no" | **Resolved**: yes for Tier 2 (conversus fidelity gate); no for Tier 0/1 (deterministic) |
| New: Tier model | n/a | Tier 0 manifest + Tier 1 searchable text + Tier 2 clean structured Markdown — core architecture |
| New: extract command | n/a | `orchestrator:extract` separate from ingest; queue-based; explicit upgrades (no implicit at dispatch — Principle VI) |
| Milestone slot | post-launch fast-follow | **Split**: M036a pre-launch (defends 2026-05-15 PBJ pilot), M036b post-launch (scale + polish) |

The taxonomy, frontmatter contract, edge types, tag namespace, dispatch injection, and idempotency invariant are unchanged.

## Problem Statement

The orchestrator's knowledge layer is **spec-chunk + memory centric**. `orchestrator:ingest` accepts only markdown shaped like a spec-kit doc; the chunker classifies content into six spec categories (`story`, `requirement`, `acceptance`, `constraint`, `nfr`, `non-goal`); `scripts/dispatch/scope-filter.sh` and the dispatch context-builder assemble payloads from scope-filtered spec chunks plus memory categories (patterns / conventions / lessons / decisions). There is no `reference/` chunk family, no provenance-bearing frontmatter for external authoritative sources, no edge type expressing "this requirement *cites* this rule", and no mechanism for agents to receive reference excerpts scoped to the task at hand.

Three concrete pain points follow:

1. **Validator agents work blind to authoritative rules.** A consumer project (PBJ Analyzer) is preparing a validator pilot window starting 2026-05-15 against CMS regulatory PDFs and SME-authored training material. Today, an orchestrator-dispatched validation task receives only spec chunks + memory; the CMS rule the validator is checking *against* must be re-supplied (and re-summarized) by the operator on every dispatch — or omitted, leaving the agent to confabulate. Reference materials are first-class context for entire classes of work, but the orchestrator treats them as out-of-band.
2. **No provenance, no recency.** When a CMS rule is republished, today there is no way to express "the agent's understanding of rule X is based on the 2024-Q3 publication" or to invalidate stale citations. The supersede chain that exists for spec chunks does not extend to reference content because reference content does not exist as chunks.
3. **No graph-queryable structure.** The knowledge graph today expresses `relates_to` and `supersedes` between spec chunks. There is no way to express that requirement FR-7 *cites* CMS-rule §483.20, or that training-material PBJ-circle-2024-08 is *derived_from* a published CMS guidance document, or that a glossary term *applies_to_field* `staff_count`. Without these edges, BFS traversal during dispatch context construction cannot find authoritative sources by walking from a task's spec scope.

The minimum surface that fixes all three: a new `reference/` chunk family parallel to `spec/`, provenance-bearing frontmatter, three new edge types (`cites`, `derived_from`, `applies_to_field`), a `[source:...]` tag namespace, and a dispatch context-injection path that pulls reference chunks scoped by topic / `applies_to_field` under a token-budget governor.

This feature explicitly **does not** introduce vector/embedding retrieval (BFS + scope-filter remains the retrieval primitive) and does not replace external Q&A tools (NotebookLM, etc.). Per the 2026-05-01 amendment, this feature **does** own extraction (PDF/Word/Excel → markdown chunks) under a tiered model — see Extraction Tier Model below.

## Extraction Tier Model (core architecture, added 2026-05-01)

Reference documents vary across orders of magnitude in size, structure, and citation depth. A single 800-page CMS manual and a 5-page rule citation cannot share the same extraction strategy. This feature defines a **three-tier extraction model** that lets each document declare the retrieval contract it supports, with sensible source-type defaults and explicit per-document override.

The decision driver is **what question the agent will ask of the document**:

| Question | Tier needed | What the tier delivers |
|---|---|---|
| "Does a doc about X exist?" | Tier 0 | Tag + summary search |
| "Find every mention of phrase Y across the corpus" | Tier 1 | Searchable plain text |
| "Quote section 5.2 verbatim with table structure" | Tier 2 | Clean structured Markdown |

### Tier 0 — Manifest entry (always, mandatory)

**Mandatory for every ingested document.** Manifest entry under `knowledge/reference/<category>/REF-<cat>-<id>.md` with:

- Original binary preserved (under `.orchestrator/knowledge/reference/_originals/<source>/<filename>` by default; external-storage hook for files exceeding configured size cap — default 10MB)
- Content-hash of the binary
- Provenance frontmatter (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`)
- Summary (LLM-generated at extract time OR human-authored — operator may override)
- Tags

Cost: ~free per doc (single LLM call for summary, plus binary preservation). Answers existence/topic questions; participates in the knowledge graph; insufficient by itself for phrase-search across the corpus.

### Tier 1 — Searchable plain text (default for most)

**Cheap-automated extraction via deterministic shell adapters**:

- PDF → `pdftotext -layout` (or equivalent)
- Word/DOCX → `pandoc` plaintext
- Excel/XLS/XLSX → sheet-by-sheet CSV/JSON with header-aware extraction (Excel→Markdown is *worse* than Excel→CSV for typical sheets — format-aware extractors are mandatory)

Output stored alongside the Tier 0 manifest as `REF-<cat>-<id>.text.md` (plain text, not pretty Markdown). Answers phrase-search questions ("find every mention of staff_count across all CMS docs") via grep / scope-filter. No LLM involvement; fully deterministic; testable with text fixtures.

### Tier 2 — Clean structured Markdown (expensive-deliberate, opt-in)

**LLM-driven extraction** that preserves headings, tables, figure captions, and citation-grade structure. Output stored as `REF-<cat>-<id>.structured.md`.

- Routes through M030 adaptive model selection (`task_type: extraction`); cheap models for prose docs, premium for citation-grade regulatory text
- Subject to **conversus fidelity gate** (cooperative two-agent deliberation: extractor-advocate vs. fidelity-advocate; PASS/BLOCK verdict per chunk)
- Triggered by explicit `orchestrator:extract --tier=2 --doc=<id>` command — **not** lazily promoted at dispatch time (Principle VI: state on disk is truth — dispatch payloads must be deterministic and replay-able)

The dispatch path MAY *log* "this doc would benefit from Tier 2 upgrade" as an advisory, but does not auto-promote. An operator (or scheduled agent) processes the upgrade queue.

### Tier policy declaration

Tier choice is declared in two layers:

1. **Source-type default** in `references/reference-source-types.yaml` — e.g.,
   - `cms-rule: tier 2` (small, high-citation, structure matters)
   - `cms-manual: tier 1` (too big for clean conversion; grep+read-section is the pattern)
   - `training-material: tier 2` (already prose, cheap upgrade, high reference value)
   - `glossary: tier 2` (definitional, frequently cited)
   - `excel-table: tier 1 + structured CSV/JSON` (data, not prose)
2. **Per-document override** in the ingest manifest entry (`tier: 2`, `tier: 1`, `tier: 0`)

### Searchability invariant

Orchestrator's "find docs about X" via scope-filter and BFS works on Tier 1+ content. **Tier 0-only docs do not participate in phrase search** (only tag + summary search). This is a documented contract; ingest emits a warning if a Tier 0-only doc is registered without a manually-authored summary.

### Backwards-compatibility note

For projects with no reference corpus, the entire tier machinery is dormant. CON-1 (no regression on pre-feature payloads) is preserved.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (M036a Pre-Launch Load-Bearing Scope, amended 2026-05-01)

The smallest coherent subset that defends the 2026-05-15 PBJ validator pilot is **US-1 + US-2 + US-3 + US-6 + US-7**:

- **US-7 (tiered extraction command)** — without it, PBJ has no path from source PDFs/Word/Excel to ingested chunks. **Load-bearing**.
- **US-6 (Tier 1 live adapters)** — the deterministic backbone US-7 calls out to. **Load-bearing**.
- **US-1 (provenance ingest)** — chunks the extractor's output into the knowledge graph. **Load-bearing**.
- **US-2 (dispatch injection)** — surfaces chunks to validator agents under a token budget. **Load-bearing**.
- **US-3 (edge graph + tag namespace)** — dispatch injection requires the new edge types to express "task X cites reference Y". **Load-bearing**.

These five user stories constitute **M036a** (pre-launch urgent).

US-4 (re-ingest idempotency at scale + supersede chain UX) and US-5 (wiki projection) are independently testable add-ons that improve the corpus-management workflow but do not gate the pilot. These constitute **M036b** (post-launch). Note: the supersede *mechanism* lands in M036a (cheap to implement once content-hash is wired) — M036b is about exercising it at scale and adding the operator-facing surfaces (REVIEW queue UI, change-over-time queries, polished MkDocs nav).

### User Story 1 — Ingest provenance-bearing reference markdown (Priority: P1)

A project owner has a directory of regulatory and training markdown files at `.orchestrator/knowledge/reference/{source}/{slug}.md`, each with frontmatter declaring `source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`. They invoke a single orchestrator command to ingest the whole directory; afterwards the markdown is decomposed into typed reference chunks under `knowledge/reference/<category>/REF-<cat>-<id>.md`, the knowledge index is rebuilt, and downstream graph queries can resolve a `cite_id` to a chunk.

**Why this priority**: This is the load-bearing capability. Without ingest, none of the downstream stories function. The PBJ validator pilot window depends on it.

**Independent Test**: Drop a fixture corpus of 5–10 markdown reference files (no binaries) into a test reference root with valid frontmatter; run the ingest command; assert (a) `knowledge/reference/<category>/REF-*.md` files exist for each input chunk, (b) every chunk's frontmatter preserves `source` / `published` / `version` / `cite_id` / `topic_tags` / `applies_to_field`, (c) the knowledge index lists every new chunk, (d) the command exits 0.

**Acceptance Scenarios**:

1. **Given** a fixture reference root with five markdown files (two cms-rule, two training-material, one glossary), **When** the operator runs the reference-ingest command pointed at that root, **Then** five `REF-*.md` chunks exist under the appropriate category subdirectories, the knowledge index lists all five, and the command exits 0.
2. **Given** a reference markdown file missing the required `source` frontmatter field, **When** the operator runs ingest, **Then** the command exits non-zero, names the offending file, and writes no chunks for that source (other valid sources in the same directory may proceed or be skipped — see Edge Cases).
3. **Given** the reference root contains a file whose `category` is not in the allowed taxonomy (e.g., `category: blog-post`), **When** ingest runs, **Then** the file is rejected with a clear error pointing at the taxonomy reference; no chunk is written.

### User Story 2 — Dispatch agents receive task-scoped reference excerpts (Priority: P1)

An operator dispatches a task whose plan declares a topic scope (e.g., `topic_tags: [pbj-staffing, cms-§483.20]`) or an `applies_to_field` (e.g., `staff_count`). The dispatch context builder pulls matching reference chunks into the agent's context payload, capped by a token budget so the context window is not exhausted on large corpora. The agent receives the most-relevant subset of authoritative content for its scope.

**Why this priority**: Without this story, ingest is a write-only sink. The point of the corpus is to feed dispatch.

**Independent Test**: With the fixture corpus from US-1 already ingested, construct a synthetic task plan declaring `topic_tags: [<tag-present-in-fixture>]` and a token budget; invoke the dispatch context builder in dry-run / inspect mode; assert (a) the resulting payload contains reference chunks whose `topic_tags` overlap, (b) the payload's reference-section byte count stays under the declared budget, (c) chunks are ordered by relevance with provenance-rich excerpts inline, (d) when the budget would be exceeded, lower-priority chunks are dropped (not truncated mid-chunk).

**Acceptance Scenarios**:

1. **Given** ten ingested reference chunks tagged `[pbj-staffing]` totaling ~12k tokens, **When** the operator dispatches a task whose plan declares `topic_tags: [pbj-staffing]` with a 4k token budget for reference content, **Then** the agent's payload includes a subset of those chunks summing to ≤4k tokens, ordered by a declared relevance signal (see Open Question #Q-2), with chunk-level provenance preserved.
2. **Given** a task plan declares `applies_to_field: staff_count`, **When** dispatch context is built, **Then** reference chunks whose frontmatter `applies_to_field` includes `staff_count` are included in the payload (alongside any topic-tag matches).
3. **Given** the existing dispatch payload assembly for spec chunks + memory, **When** a task plan declares no `topic_tags` and no `applies_to_field`, **Then** no reference chunks are included and the dispatch payload is byte-identical to the pre-feature payload (backwards compatibility — see CON-1).

### User Story 3 — Reference chunks participate in the knowledge graph (Priority: P1)

A spec chunk or memory entry expresses an edge to a reference chunk via the new `cites` / `derived_from` / `applies_to_field` edge types; the same `[source:cms-pbj-2024-q3]` tag namespace can be applied to spec or memory chunks to mark them as scoped to a particular source. BFS traversal during dispatch payload assembly walks across these edges so that a task whose scope cites FR-7 can reach the CMS rule §483.20 chunk that FR-7 itself cites.

**Why this priority**: Without graph integration, reference chunks are isolated. The orchestrator's BFS traversal is the retrieval primitive; reference chunks must participate in it for US-2's relevance ordering to be meaningful at scale.

**Independent Test**: Author a fixture spec chunk (`relates_to` → existing pattern) plus a fixture reference chunk and an explicit `cites` edge from the spec to the reference; run the BFS traverser starting at the spec chunk; assert the reference is reached at depth 1 and the edge type is preserved in the output.

**Acceptance Scenarios**:

1. **Given** a spec chunk `SPEC-requirement-FR-7` declaring `cites: [REF-cms-rule-483-20]` in its frontmatter, **When** `scripts/knowledge/traverse-graph.sh` runs from `SPEC-requirement-FR-7`, **Then** the output includes `REF-cms-rule-483-20` at depth 1, with edge label `cites`.
2. **Given** a memory chunk tagged `[source:cms-pbj-2024-q3]`, **When** scope-filter runs with `--tag '[source:cms-pbj-2024-q3]'`, **Then** the chunk is returned alongside any spec/reference chunks bearing the same tag.
3. **Given** a reference chunk `REF-training-pbj-circle-2024-08` declaring `derived_from: [REF-cms-rule-483-20]`, **When** BFS runs from the cms-rule chunk in reverse, **Then** the training chunk is reachable; edge direction is preserved (`derived_from` is directional from training → rule).

### User Story 4 — Re-ingest is idempotent with supersede chain (Priority: P2)

When CMS republishes a rule (or an SME revises training), the operator drops a new version of the source markdown into the reference root. Re-running ingest detects the content-hash change, supersedes the prior chunk via a versioned successor file (`REF-cat-id-v2.md`), and annotates the prior file with `superseded_by:` — matching the existing spec-chunk re-ingest pattern.

**Why this priority**: P2, not P1, because the validator pilot can ship with a one-shot ingest of the as-of-launch corpus; re-ingest matters for the second-quarter cycle, not the first. Independently testable.

**Independent Test**: Ingest a fixture chunk; mutate its content; re-ingest; assert (a) the prior detail file gains a `superseded_by:` line, (b) a new versioned detail file exists, (c) BFS from chunks that previously cited the prior version surface a `REVIEW:` advisory.

**Acceptance Scenarios**:

1. **Given** `REF-cms-rule-483-20-v1` exists from a prior ingest, **When** the operator drops a content-modified `cms/483-20.md` and re-runs ingest, **Then** `REF-cms-rule-483-20-v2` is written, `v1`'s frontmatter gains `superseded_by: REF-cms-rule-483-20-v2`, and the index hot-file lists both with the chain tip marked.
2. **Given** a re-ingest pass detects no content change in a reference file, **When** ingest runs, **Then** the chunk emits `SKIPPED:` and no detail file is rewritten (matching the spec-chunk pattern at `commands/ingest.md:98-99`).
3. **Given** a reference file that existed in a prior ingest is removed from the source directory, **When** re-ingest runs, **Then** the corresponding chunk is annotated with `removed_at:` and a `REVIEW:` line surfaces if any spec or memory chunk currently `cites` it.

### User Story 5 — Reference corpus is browseable in the wiki (Priority: P2)

The MkDocs wiki projection exposes the ingested reference corpus alongside spec content. A reader navigating the wiki can browse `Reference > CMS Rules`, `Reference > Training Materials`, `Reference > Glossary`, etc., and follow `cites` / `derived_from` links rendered as cross-doc links.

**Why this priority**: P2 because operator-side browsing and review are valuable but not load-bearing for the validator dispatch. Decouples cleanly from US-1/2/3.

**Independent Test**: After ingest, run the wiki build; assert that the rendered site includes navigation entries under a `Reference` section keyed off the chunk taxonomy and that at least one cross-doc link from a spec page resolves to a reference page.

**Acceptance Scenarios**:

1. **Given** an ingested corpus with at least one chunk per category, **When** the wiki build runs, **Then** the rendered nav includes `Reference > CMS Rules`, `Reference > Training Materials`, `Reference > Glossary`, `Reference > Regulatory Docs` (and any other taxonomy categories present in the ingest).
2. **Given** a spec chunk declares `cites: [REF-cms-rule-483-20]`, **When** the wiki renders the spec page, **Then** the inline citation links resolve to the reference chunk's wiki page.

### User Story 6 — Tier 1 format adapters live (PDF / Word / Excel / Markdown) (Priority: P1, amended 2026-05-01)

The orchestrator ships **live Tier 1 adapters** for the four formats consumers commonly hold reference content in: markdown (already-normalized passthrough), PDF (`pdftotext -layout`), Word/DOCX (`pandoc`), Excel/XLS/XLSX (sheet-by-sheet CSV/JSON with header detection). All four are registered in the adapter dispatch table at `status: live`. Consumers can replace any adapter implementation by re-registering (Principle X declarative seam) without touching the ingest control flow.

**Why this priority** (raised P3 → P1 by amendment): PBJ Analyzer holds ~30 PDF + Word docs and an unknown set of Excel files for the MVP-critical knowledge-graph cohort. With no consumer-side path-B extractor, Tier 1 adapters are load-bearing for the validator pilot.

**Independent Test**: Invoke each adapter with a fixture document; assert (a) exit 0, (b) emitted plain text contains expected phrases from the source, (c) Excel adapter emits structured CSV/JSON (not flattened Markdown tables), (d) all four are listed `status: live` in the registry.

**Acceptance Scenarios**:

1. **Given** a fixture PDF (single-page, English text), **When** the PDF adapter is invoked, **Then** it exits 0 and the emitted plain text contains the source's body text (whitespace-normalized comparison).
2. **Given** a fixture DOCX, **When** the Word adapter is invoked, **Then** it exits 0 and the emitted text preserves heading hierarchy as Markdown headings.
3. **Given** a fixture XLSX with two sheets, **When** the Excel adapter is invoked, **Then** it emits one CSV per sheet with header row detected and the registry lists `xlsx` with `status: live`.
4. **Given** the markdown adapter, **When** the same adapter registry is inspected, **Then** all four (`markdown`, `pdf`, `docx`, `xlsx`) are listed `status: live`.

### User Story 7 — Tiered extraction command (Tier 2 LLM extraction with conversus fidelity gate) (Priority: P1, added 2026-05-01)

An operator runs `orchestrator:extract` against a manifest of source documents (PDFs, Word, Excel) declaring per-document tier targets. Tier 0 (manifest + original binary preservation + summary) and Tier 1 (deterministic shell adapter → searchable text) execute synchronously and cheaply. Tier 2 (LLM-driven structured Markdown extraction) routes through M030 adaptive model selection and is gated by a conversus fidelity deliberation; the operator gets a per-document PASS/BLOCK verdict and can re-run on BLOCK with adjusted parameters.

**Why this priority**: Without explicit tiered extraction, PBJ has no path from raw source documents (which it holds today) to ingested reference chunks (which the validator dispatch needs). Load-bearing for the 2026-05-15 pilot.

**Independent Test**: Author a manifest declaring 3 fixture documents at tiers 0, 1, 2 respectively. Run `orchestrator:extract --manifest=<path>`. Assert (a) Tier 0 doc has manifest + preserved original binary + auto-generated summary, (b) Tier 1 doc has plain-text extraction file alongside Tier 0 artifacts, (c) Tier 2 doc has structured Markdown file alongside Tier 0 + 1 artifacts AND a conversus gate result file showing PASS verdict, (d) command exits 0, (e) re-running on the same manifest is idempotent (zero diff).

**Acceptance Scenarios**:

1. **Given** a manifest entry declaring `tier: 2` for a 5-page CMS rule fixture PDF, **When** the operator runs `orchestrator:extract --manifest=<path>`, **Then** the structured Markdown file exists, contains preserved heading hierarchy and table structure, and the conversus gate result is `PASS`.
2. **Given** the same manifest, **When** re-run on unchanged inputs, **Then** zero files are modified (idempotency — content hash gates re-extraction at every tier).
3. **Given** a Tier 2 extraction whose conversus gate returns `BLOCK`, **When** the operator inspects the result, **Then** the BLOCK rationale is on disk, the structured Markdown file is *not* promoted to the chunk store, and the operator can re-run with `--retry --reviewer-notes=<path>` to incorporate the gate's notes.
4. **Given** an extraction-queue manifest with 30 documents, **When** the operator runs the extraction command, **Then** Tier 0/1 jobs run sequentially (deterministic, fast); Tier 2 jobs route through M030 task-type=`extraction` and emit `unit_close` records with model selection metadata.

---

## Edge Cases

- **Reference markdown with malformed frontmatter** — A file in the reference root has a YAML parse error or a missing required field (`source` / `published`). Defined behavior: ingest exits non-zero, names the file, writes no chunks for that file, but does not abort other valid files in the same pass — partial-success ingest with explicit error list, matching the spec-chunk classifier's tolerance for one bad section.
- **Two reference files declare the same `cite_id`** — Defined behavior: the second is rejected with a duplicate-cite_id error; the first wins. `cite_id` is the operator-facing stable identifier and must be unique per ingest pass.
- **A reference chunk's `applies_to_field` references a field name not present in any spec chunk** — Defined behavior: ingest succeeds (validation does not require referent existence — the field may be added later); a `REVIEW:` advisory is emitted listing dangling field references so the operator can audit.
- **Token budget for reference injection is set lower than the smallest single-chunk size** — Defined behavior: the smallest single chunk is included regardless; the alternative (silently dropping all reference content) is worse than slightly over-budget. A warning is emitted on the dispatch payload's stderr.
- **A spec chunk declares `cites: [REF-...]` for a chunk that does not exist** — Defined behavior: not a hard error at spec-ingest time (forward references are valid during planning); a `REVIEW:` line is emitted; BFS traversal silently skips the dangling edge.
- **The reference root directory does not exist** — Defined behavior: ingest exits 0 with a "no reference corpus configured" message; this is the green path for projects that never ingest reference content. Backwards compatibility is preserved (CON-1).
- **A re-ingest pass finds two chunks have swapped slugs/cite_ids** — Defined behavior: treated as a delete + create pair (`REMOVED:` for the old `cite_id`, `CREATED:` for the new). Operators wanting rename support are directed to a future surface (deferred — see Open Question #Q-3 versioning model).
- **Wiki build encounters a `cites:` edge whose target was deleted between ingests** — Defined behavior: the wiki renders the citation as a broken link with a tooltip naming the missing `cite_id`; build does not fail (matches MkDocs broken-link convention).

---

## Functional Requirements

- **FR-1 (reference-taxonomy)**: The orchestrator MUST define a closed taxonomy of reference categories — initially `cms-rule`, `training-material`, `glossary`, `regulatory-doc`. Files outside this taxonomy are rejected at ingest. The taxonomy lives in a single reference doc consumed by both the ingest classifier and the wiki nav generator (Principle XI Single Source of Truth). Satisfies US-1 acceptance scenario 3.
- **FR-2 (provenance-frontmatter)**: Every reference markdown file MUST declare frontmatter fields `source`, `published`, `version`, `cite_id`, `topic_tags` (list), `applies_to_field` (list, may be empty). Ingest validates presence; files missing required fields are rejected with a per-file error. Satisfies US-1 acceptance scenario 2.
- **FR-3 (reference-ingest-command)**: A new orchestrator-facing entry point ingests a reference root directory: chunks, classifies, writes typed chunks under `knowledge/reference/<category>/REF-<cat>-<id>.md`, rebuilds the knowledge index. Mirrors the orchestrator:ingest UX (CLI-first bash glue). Satisfies US-1.
- **FR-4 (chunk-output-shape)**: Each emitted chunk file's frontmatter MUST preserve all FR-2 provenance fields plus the assigned `category`, `chunk_id`, `content_hash`, `scope_tags`, and graph edge fields (`cites`, `derived_from`, `applies_to_field`, `relates_to`, `supersedes`). Body content is the source markdown body verbatim (no LLM rewrite during ingest). Satisfies US-1.
- **FR-5 (edge-types)**: The graph schema MUST recognize three new directional edge types — `cites` (chunk → reference), `derived_from` (chunk → upstream-source-chunk), `applies_to_field` (chunk → field-name) — alongside existing `relates_to` and `supersedes`. Edge types are declared in the same SSOT (Principle XI) the traverser already reads. Satisfies US-3.
- **FR-6 (tag-namespace)**: The scope-tag grammar MUST recognize a `[source:<cite_id>]` tag namespace alongside existing `[project]` / `[milestone:M###]` / `[phase:P##]` / `[spec:<slug>]`. Scope-filter accepts `--tag '[source:...]'` and returns matching chunks (spec, memory, or reference) without category restriction. Satisfies US-3.
- **FR-7 (dispatch-injection)**: The dispatch context builder MUST, when a task plan declares `topic_tags` or `applies_to_field`, include matching reference chunks in the assembled payload under a declared `reference:` recipe section (Principle X Templating Over Inference; Principle XIII Agent Instruction Schema). The recipe section is opt-in: plans without those fields produce byte-identical pre-feature payloads. Satisfies US-2 acceptance scenario 3 (CON-1).
- **FR-8 (token-budget-governor)**: The reference-injection path MUST honor a token budget (default declared in the recipe; per-plan override supported). When the matching set's total token count exceeds the budget, chunks are dropped in declared-priority order (chunk-level granularity, not mid-chunk truncation). At least one chunk is always included if any matched. Satisfies US-2 acceptance scenario 1; satisfies the "smallest-chunk-larger-than-budget" edge case.
- **FR-9 (idempotent-re-ingest)**: Re-running the reference-ingest command on an unchanged source set MUST produce a disk state byte-identical to the prior run (matching the spec-chunk re-ingest invariant at `commands/ingest.md:103-105`). Content-modified files emit `SUPERSEDED:`; deleted files emit `REMOVED:`; new files emit `CREATED:`; unchanged emit `SKIPPED:`. Satisfies US-4.
- **FR-10 (supersede-chain)**: When a reference file's content hash changes between ingests, a versioned successor (`REF-cat-id-v<N+1>.md`) is written and the predecessor's frontmatter gains `superseded_by:` pointing at the successor. The chain is walked before appending so a chunk superseded multiple times forms `v1 → v2 → v3` and not duplicate `v2`s. Mirrors `commands/ingest.md:99-100`. Satisfies US-4 acceptance scenario 1.
- **FR-11 (review-advisories)**: Re-ingest emits `REVIEW:` lines for each spec or memory chunk that currently `cites` a reference chunk that was superseded or removed. Advisory only — no automatic spec edits (Principle XV Surgical Precision). Satisfies US-4 acceptance scenario 3.
- **FR-12 (wiki-projection)**: The MkDocs wiki build MUST render the reference corpus under a `Reference` top-level nav section organized by category. Inline `cites` references in spec pages render as cross-doc links to the corresponding reference page. Satisfies US-5.
- **FR-13 (live-tier-1-adapters)** *(amended 2026-05-01)*: The codebase MUST register a format-adapter dispatch table with at minimum **four live entries**: `markdown` (passthrough), `pdf` (`pdftotext -layout`), `docx` (`pandoc`), `xlsx` (sheet-by-sheet CSV/JSON with header detection). All four exit 0 on valid input and emit Tier 1 plain-text output. Stubs are permitted only for formats the orchestrator does not commit to supporting (e.g., raw image OCR, RTF) — and any stub MUST exit 2 with a clear pointer to the documented workaround. Satisfies US-6.
- **FR-14 (binary-preservation)** *(amended 2026-05-01)*: The orchestrator MUST preserve the original binary of every ingested document at Tier 0 under `.orchestrator/knowledge/reference/_originals/<source>/<filename>` with content-hash recorded in the chunk frontmatter. Files exceeding the configured size cap (default 10MB; configurable per-project) MUST instead record an external-storage pointer (path on the operator's filesystem, S3 URL, etc.) — the orchestrator never copies binaries above the cap into the repo. The original binary is the **source of truth** that supports re-extraction at higher tiers. Satisfies the inverted NG-3.
- **FR-15 (backwards-compat-dispatch)**: For any task plan that does not declare `topic_tags` or `applies_to_field`, the dispatched context payload MUST be byte-identical to the pre-feature payload. A `golden-baseline diff` test enforces this at the same shape as M030 SC-11. Satisfies US-2 acceptance scenario 3 and CON-1.
- **FR-16 (extract-command)** *(added 2026-05-01)*: The orchestrator MUST expose `orchestrator:extract` as a separate command (distinct from `orchestrator:ingest`) that consumes an extraction manifest declaring per-document tier targets. Tier 0/1 jobs run synchronously and deterministically. Tier 2 jobs route through M030 adaptive model selection (`task_type: extraction`) and emit `unit_close` JSONL records with model + cost metadata. The command is idempotent (content-hash gating per tier output). Satisfies US-7.
- **FR-17 (tier-policy-declaration)** *(added 2026-05-01)*: The orchestrator MUST support tier policy declaration in two layers — source-type defaults at `references/reference-source-types.yaml` (e.g., `cms-rule: tier 2`, `cms-manual: tier 1`) and per-document override in the extraction manifest. Tier choice is explicit and on disk; no implicit/lazy promotion at dispatch time (Principle VI). Default source-type policies MUST be declared for the four taxonomy categories (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`). Satisfies US-7.
- **FR-18 (conversus-fidelity-gate-tier-2)** *(added 2026-05-01, resolves #Q-5)*: Tier 2 LLM-driven extraction MUST be subject to a conversus fidelity gate (cooperative two-agent: extractor-advocate vs. fidelity-advocate, PASS/BLOCK verdict per document). PASS promotes the structured Markdown into the chunk store; BLOCK retains the rationale on disk and excludes the structured output from the chunk store until the operator re-runs with adjusted parameters. Tier 0 and Tier 1 are deterministic and **NOT** gated. Satisfies US-7 acceptance scenario 3.
- **FR-19 (m030-task-type-extraction)** *(added 2026-05-01)*: Tier 2 extraction jobs MUST be classified as M030 `task_type: extraction` so adaptive model selection applies (cheap models for prose extraction, premium for citation-grade regulatory text). Each Tier 2 invocation emits an M030-shape `unit_close` record with `model`, `tokens_in`, `tokens_out`, `cost_usd`, and `quality_score` fields. Satisfies US-7 acceptance scenario 4.
- **FR-20 (searchability-invariant)** *(added 2026-05-01)*: The orchestrator's scope-filter and BFS traversal MUST work on Tier 1+ content. Tier 0-only documents participate in tag/summary search but **NOT** in phrase search. Ingest MUST emit a warning if a Tier 0-only document is registered without a manually-authored summary (auto-generated summaries are acceptable but the warning prompts operator review).

## Success Criteria

- **SC-1 (ingest-fixture-roundtrip)**: Running the new reference-ingest command against a fixture reference root with N≥10 markdown files (covering all four taxonomy categories) writes N chunks under the expected paths, the knowledge index lists all N, and the command exits 0. Mechanically verified by `tests/test-reference-ingest-fixture.sh` (or equivalent) with a fixture corpus checked into `tests/fixtures/`.
- **SC-2 (frontmatter-preservation)**: For every fixture input, the emitted chunk's frontmatter fields `source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field` are byte-identical to the source. Mechanically verified by a post-ingest assertion script that walks `knowledge/reference/**/*.md` and diffs against fixture inputs.
- **SC-3 (dispatch-injection-budget)**: A synthetic task plan declaring `topic_tags: [<fixture-tag>]` and `reference_token_budget: 4000` produces a dispatch payload whose reference section is ≤4000 tokens (measured by the same tokenizer used elsewhere in the orchestrator) and contains ≥1 chunk. Verified by an inspection-mode dispatch test that prints payload byte counts.
- **SC-4 (graph-edge-traversal)**: `traverse-graph.sh` invoked at depth=1 from a spec chunk declaring `cites: [REF-...]` returns the cited reference chunk with the correct edge label. Mechanically verified by a fixture spec + reference + traverse-and-grep test.
- **SC-5 (idempotent-re-ingest)**: Re-running ingest on an unchanged fixture corpus produces a `git status` that reports zero modified files under `knowledge/reference/`. Mechanically verified.
- **SC-6 (supersede-chain)**: Mutating one fixture file's body and re-ingesting produces (a) a new versioned chunk file, (b) the prior chunk's frontmatter gains `superseded_by:`, (c) the index hot-file shows both versions with the chain tip marked. Mechanically verified.
- **SC-7 (backwards-compat)**: A task plan without `topic_tags` and without `applies_to_field` produces a dispatch payload byte-identical to the pre-feature payload (golden-baseline diff). Mechanically verified by the same shape M030 SC-11 uses.
- **SC-8 (wiki-projection-nav)**: After ingest + wiki build, the rendered site nav contains a `Reference` section with at least the four taxonomy categories present in the fixture. Mechanically verified by a grep against the rendered HTML / nav YAML.
- **SC-9 (live-tier-1-adapters)** *(amended 2026-05-01)*: All four Tier 1 adapters (`markdown`, `pdf`, `docx`, `xlsx`) exit 0 on a fixture document for their format and emit non-empty plain-text output. The Excel adapter additionally emits one CSV per sheet with header detection. Mechanically verified by `tests/test-tier-1-adapters.sh`.
- **SC-10 (binary-preservation-and-hash)** *(amended 2026-05-01)*: For every ingested document below the size cap, the original binary exists at `.orchestrator/knowledge/reference/_originals/<source>/<filename>` and the chunk frontmatter `content_hash` matches `sha256` of the binary. For documents above the cap, the chunk frontmatter contains an `external_pointer` and no copy of the binary exists in the repo. Mechanically verified.
- **SC-11 (tier-2-extraction-with-conversus-gate)** *(added 2026-05-01)*: Running `orchestrator:extract --manifest=<path>` on a fixture manifest declaring 1 doc at each of Tier 0, 1, 2 produces all expected outputs (manifest entry with summary; Tier 1 plain-text file; Tier 2 structured Markdown file with conversus PASS verdict on disk). The Tier 2 extraction emits an M030-shape `unit_close` record with non-empty `model` and `cost_usd` fields. Mechanically verified by `tests/test-tiered-extraction.sh`.
- **SC-12 (tier-2-block-retention)** *(added 2026-05-01)*: When a Tier 2 conversus gate returns BLOCK, the BLOCK rationale exists on disk under `.orchestrator/knowledge/reference/_extraction-log/<doc-id>.block.md`, the structured Markdown output is **NOT** present in the chunk store, and re-running with `--retry --reviewer-notes=<path>` consumes the notes (verified by appearance of notes content in the next conversus deliberation transcript). Mechanically verified.
- **SC-13 (extract-idempotency)** *(added 2026-05-01)*: Re-running `orchestrator:extract --manifest=<path>` on unchanged source documents produces zero modified files in `.orchestrator/knowledge/reference/` (`git status` clean). Content-hash gates re-extraction at every tier. Mechanically verified.

## Non-Goals

- **NG-1 (no-vector-retrieval)**: This feature does NOT introduce vector / embedding-based retrieval. The retrieval primitive remains BFS + scope-filter against tagged chunks. Rationale: BFS over tagged chunks has been load-bearing for spec content for two milestones; vector retrieval is a parallel, orthogonal investment that should be evaluated independently when scope warrants.
- **NG-2 (no-external-q-and-a-integration)**: Out-of-tree Q&A tools (NotebookLM and similar) are not consumed or produced by this feature. Rationale: reference-corpus ingest delivers structured chunks consumable by the orchestrator's existing dispatch path; external Q&A is a parallel concern with its own orchestration.
- **NG-3 (REPLACED 2026-05-01: previously "no-binary-source-storage")** → **NG-3-NEW (governed-binary-preservation)**: The orchestrator preserves original binaries at Tier 0 below a configured size cap (default 10MB). Above the cap, an external-storage pointer is recorded; the binary is **not** copied into the repo. Binaries below the cap are stored under `.orchestrator/knowledge/reference/_originals/` (gitignored by default; the orchestrator's `.gitignore` template adds the path). Original binary preservation is the source of truth that supports Tier 2 re-extraction without re-acquiring source material. Rationale for amendment: PBJ has no path-B extractor; orchestrator owns extraction; original-as-source-of-truth supports change-over-time queries and re-extraction at higher tiers.
- **NG-4 (REPLACED 2026-05-01: previously "no-auto-extraction-pipeline")** → **NG-4-NEW (orchestrator-owned-tiered-extraction)**: The orchestrator **owns** Tier 0/1/2 extraction (formerly out of scope). Tier 1 ships as deterministic shell adapters (PDF/Word/Excel/Markdown, FR-13). Tier 2 ships as M030-routed LLM extraction with conversus fidelity gate (FR-18, FR-19). What remains explicitly out of scope: OCR for image-only PDFs (defer to fast-follow milestone), automated translation between languages, automated factual-content rewrite (Tier 2 is structural extraction, not summarization or paraphrase). Rationale for amendment: PBJ has no consumer-side path-B; orchestrator must own extraction so other consumers benefit too.
- **NG-5 (NARROWED 2026-05-01: previously "no-llm-rewrite-during-ingest")** → **NG-5-NEW (no-llm-rewrite-at-tier-0-1-and-no-summarization-at-tier-2)**: Tier 0 and Tier 1 outputs are byte-faithful to source (Tier 0 = preserved binary + auto-summary in metadata; Tier 1 = deterministic-extracted plain text). Tier 2 LLM extraction preserves heading hierarchy, table structure, and figure captions but **does not** summarize, paraphrase, or rewrite the source's content — the conversus fidelity gate (FR-18) verifies this. A future "summarized references" surface (paraphrased excerpts for context-window compression) is a separate, gated feature out of scope here. Rationale for narrowing: Tier 2 IS LLM-driven and that's load-bearing for citation-grade structured Markdown; the prohibition is now scoped to *content rewriting*, not all LLM use.

## Constraints

- **CON-1 (no-regression-on-pre-feature-payloads)**: Existing `orchestrator:ingest`, scope-filter, dispatch context-builder, and `traverse-graph.sh` MUST continue to operate byte-identically when no reference content is present and no plan declares `topic_tags` / `applies_to_field`. This is a backwards-compatibility hard gate; SC-7 enforces.
- **CON-2 (cli-first-bash)**: New commands and scripts MUST be Bash 3.2 / POSIX-sh (matching `commands/ingest.md`'s `Bash 3.2 compatible` constraint at `commands/ingest.md:130`). Optional `jq` dependency permitted (matches existing project convention). Rationale: portability + reproducibility (Principle IX).
- **CON-3 (text-only-tests-with-binary-fixture-exception)** *(amended 2026-05-01)*: Test fixtures for ingest, classifier, scope-filter, traversal, and dispatch injection MUST be markdown / text. Binary fixtures (small PDF, DOCX, XLSX samples ~tens-of-KB each) are permitted **only** under `tests/fixtures/m036-tier-1-adapters/` for adapter-roundtrip tests. Tier 2 extraction tests use **mocked LLM responses** (recorded conversus deliberation transcripts) — no live LLM calls in CI. Rationale: deterministic CI; reviewable diffs everywhere except the bounded adapter test set.
- **CON-4 (idempotency-mandatory)**: Every command introduced by this feature MUST be idempotent on disk state — re-running with unchanged inputs produces zero modifications. Mirrors R012 (idempotent commands) at `commands/ingest.md:105`. Includes `orchestrator:extract` (content-hash gating per tier, FR-16).
- **CON-5 (no-spec-chunk-schema-change)**: Existing spec-chunk frontmatter / file layout / chain-walking rules MUST NOT change. New edge types and the `[source:...]` tag namespace are additive (existing chunks remain valid without modification). See Knowledge-Layer Boundary below.
- **CON-6 (explicit-tier-upgrade-determinism)** *(added 2026-05-01)*: Tier promotion (e.g., Tier 1 → Tier 2 for a previously-extracted document) is performed **only** by explicit operator command (`orchestrator:extract --tier=2 --doc=<id>`). Dispatch payload assembly MUST NOT trigger lazy/JIT extraction. Dispatch may emit `tier_upgrade_advisory:` log lines (recorded for an operator queue), but does not act on them. Rationale: Principle VI (state on disk is truth) — research/plan runs must be deterministic and replay-able; lazy promotion mid-run breaks that invariant.
- **CON-7 (binary-storage-governance)** *(added 2026-05-01)*: Original-binary preservation under `.orchestrator/knowledge/reference/_originals/` MUST be governed by (a) a per-project size cap (default 10MB, configurable in `.orchestrator/config.yaml`), (b) gitignore default (the orchestrator's `.gitignore` template ignores `_originals/` so operators opt-in to commit), (c) external-storage hook for files above the cap (operator declares S3/path/etc. in source-type config). Rationale: prevents repo bloat while preserving source-of-truth for re-extraction.

### Knowledge-Layer Boundary (M033-reference-corpus-ingest vs. M020 / M011)

This milestone owns: `knowledge/reference/**` (new directory tree), the reference-ingest command and its scripts, the format-adapter dispatch table, the new edge types in the graph schema declaration, the `[source:...]` tag namespace, the `reference:` recipe section in the dispatch context-builder, the wiki nav generator's reference section, and the per-source provenance frontmatter contract.

This milestone does NOT own: the existing spec-chunk classifier (M011 — `scripts/knowledge/ingest-spec.sh`); existing edge types `relates_to` / `supersedes` (declared by M011/M020); existing scope-tag namespaces `[project]` / `[milestone:...]` / `[phase:...]` / `[spec:...]` (M011); `KNOWLEDGE-INDEX.md` rebuild mechanics (M011 — `scripts/knowledge/rebuild-index.sh`, which this milestone re-uses without modification); BFS traversal mechanics (M020 — `scripts/knowledge/traverse-graph.sh`, extended additively for new edge types); the markdown-shape probe / normalize-spec / fidelity gate (M011/P07 — out of scope here, since reference content is already markdown by construction).

Additive extensions to existing files (e.g., `traverse-graph.sh` learns the new edge types) are owned by this milestone; the schema declaration these scripts read is a single SSOT (Principle XI) that this milestone amends in one place.

## Assumptions

- **A-1 (orchestrator-owned-extraction)** *(amended 2026-05-01)*: Consumer projects deliver source documents in their native formats (PDF, Word, Excel, or already-normalized markdown). The orchestrator owns extraction across three tiers (see Extraction Tier Model). PBJ Analyzer holds ~30 PDF + Word docs for the MVP-critical knowledge-graph cohort with no external extractor — orchestrator's tiered extraction is the production path. Original assumption (consumer owns extraction via path-B markdown floor) was invalidated 2026-05-01.
- **A-2 (frontmatter-authored-by-extract-or-operator)** *(amended 2026-05-01)*: The provenance frontmatter (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`) is authored either by the orchestrator's extractor (auto-derived where possible — e.g., `published` from PDF metadata; `cite_id` from filename slug) or by the operator in a manifest accompanying the source documents. Tier 0 ingest validates presence and rejects on missing required fields; the operator's manifest is the override path for fields the extractor cannot derive.
- **A-3 (existing-knowledge-tree)**: `knowledge/` exists at the orchestrator root (created by `orchestrator:evaluate` / scaffold) and the existing spec-chunk machinery is functional. Reference ingest does not bootstrap the knowledge tree.
- **A-4 (tokenizer-available)**: A consistent tokenizer is available to the orchestrator (already required by M018 compression-tier work). Token-budget governance reuses it.
- **A-5 (taxonomy-stable-at-launch)**: The four-category taxonomy (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`) is sufficient for the validator pilot. Adding categories post-launch is additive (FR-1's SSOT design supports it without a schema migration).
- **A-6 (validator-pilot-window)**: The PBJ validator pilot starts ~2026-05-15 and runs through mid-June 2026. The minimal slice (US-1 + US-2 + US-3) MUST be shippable in time to defend that window. See Open Question #Q-1 for milestone-slot timing.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: The token-budget governor (FR-8) is the direct embodiment of `Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited`. Reference content arrives task-scoped via `topic_tags` / `applies_to_field` — never blanket-injected. The default budget plus chunk-level prioritization keeps the relevant fraction high without exhausting the window.
- **Principle II (Evidence Before Claims)**: Every Functional Requirement maps to a mechanically-verifiable Success Criterion (SC-1..SC-10). The ingest command emits structured `CREATED:` / `SUPERSEDED:` / `REMOVED:` / `SKIPPED:` / `REVIEW:` lines matching the spec-chunk emitter's format, providing the evidence trail Principle II requires. `unit_close` and JSONL records will be authored at plan time per the M027 surface conventions.
- **Principle III (Design Before Code)**: This spec's Open Questions section enumerates the load-bearing ambiguities the planner MUST resolve before code starts (table-storage choice, governor algorithm, fidelity-gate posture, versioning model, milestone slot). No requirement is left to executor judgment.
- **Principle X (Templating Over Inference)**: The new `reference:` dispatch payload section is declared in the context recipe (`context-recipe.yaml`), not inferred at runtime. The category taxonomy lives in a SSOT consumed by ingest + wiki nav (FR-1).
- **Principle XI (Single Source of Truth)**: The category taxonomy, the edge-type list, and the tag namespace each have exactly one authoritative declaration site. Multiple consumers (ingest classifier, traverser, wiki nav, scope-filter) read the same source.
- **Principle XIII (Agent Instruction Schema)**: The new `reference:` payload section is added to the declared instruction schema with its own ordering and visibility rules, not appended ad-hoc. New instruction shape requires a recipe change, not a script change.
- **Principle XIV (No Speculative Complexity)** *(amended 2026-05-01)*: Vector retrieval, NotebookLM integration, OCR for image-only PDFs, automated translation, and content paraphrase remain explicit Non-Goals. The amendment **adds** orchestrator-owned tiered extraction (Tier 0/1/2) under demand evidence: PBJ Analyzer's MVP-critical 30-doc cohort has no consumer-side extractor, so the path to ingested chunks does not exist without orchestrator ownership. Tier 1 adapters are deterministic shell-outs (minimum implementation surface); Tier 2 routes through M030 (re-uses shipped infrastructure rather than building parallel routing). The seam preserves Principle XIV by avoiding speculative complexity (no parallel-version retention, no concurrent extraction queue, no factual-grounding verifier — all deferred to demand-driven follow-ons).
- **Principle XV (Surgical Precision)**: The Knowledge-Layer Boundary section names the exact write-sites this milestone claims and the existing files extended additively (e.g., traverse-graph schema). Re-ingest never auto-edits spec or memory chunks; affected chunks surface as `REVIEW:` advisories (FR-11).

## Open Questions (defer to planning)

- **#Q-1 (milestone-slot)**: Where does this feature slot in the roadmap? Three viable framings, decision deferred to `orchestrator:roadmap`: (a) own milestone (proposed M036 — naming TBD; latest pre-launch slot, gated against the post-M035 launch event); (b) extension of M020 (knowledge-layer maturation — already closed; would require a re-open / M020.1 numbering); (c) a deferred-post-launch milestone with the validator-pilot window served by an in-place patch on the consumer side. The 2026-05-15 pilot window strongly biases toward (a) with aggressive scope; (c) is the safest re-launch posture but punts on the consumer's deadline.
- **#Q-2 (relevance-ordering-signal)**: When dispatch injection has more matched chunks than fit the budget, how is priority computed? Options: (i) frontmatter-declared `priority:` integer; (ii) BFS-distance from the task's spec scope; (iii) `published` recency (newest wins); (iv) hybrid. Each has tradeoffs (declarative is operator-burden; BFS-distance requires graph-walk every dispatch; recency is wrong for glossaries). Defer to plan-phase; capture decision in DECISIONS.md.
- **#Q-3 (versioning-model)** *(RESOLVED 2026-05-01: supersede chain)*: Use the supersede chain (matching the existing spec-chunk pattern) with explicit `version:` frontmatter as the operator-facing handle. Older versions remain cite-able via their versioned filenames (`REF-cat-id-v1.md`, `REF-cat-id-v2.md`, ...). Rationale: change-over-time queries are an explicit user need; supersede chain preserves history; matches the M011 pattern operators already know. Parallel-version retention was considered and rejected — adds complexity for a use case (multiple simultaneously-live versions) we don't yet have a consumer for. If that need surfaces, parallel-retention can be added additively as a per-source-type policy.
- **#Q-4 (storage-table-vs-files)**: The existing knowledge layer is file-based (markdown chunks under `knowledge/spec/`). Should reference chunks land in the same shape (`knowledge/reference/<cat>/REF-*.md`) for full architectural symmetry, or is there a SQLite table (mentioned in the input brief) that this work plugs into? Default proposal: same file shape as spec chunks — minimum delta from current architecture, maximum reuse of `rebuild-index.sh`. If a SQLite layer exists or is planned, the planner reconciles. Defer.
- **#Q-5 (fidelity-gate-posture)** *(RESOLVED 2026-05-01: tiered)*: Tier 0 and Tier 1 are deterministic (binary preservation, shell-out extraction) and **NOT** gated. Tier 2 LLM extraction **IS** gated by a conversus fidelity deliberation (extractor-advocate vs. fidelity-advocate, PASS/BLOCK per document). PASS promotes structured Markdown into the chunk store; BLOCK retains rationale on disk. Rationale: the gate applies where lossy transformation occurs; deterministic tiers don't need it. Captured in FR-18. The conversus adapter is therefore a **hard dependency** of the M036a phase that ships Tier 2.
- **#Q-6 (dependencies-on-m013-m014-gate-work)**: The brief asks whether dependencies on M013–M014's gate work need to be called out. Initial reading: NO — those gates fire on spec-shape conformity and section-contract fidelity, neither of which apply to reference content (which has its own taxonomy + provenance contract, not the spec-template Section Contract). But: the dual-write helper (M014) and the M027 metrics surface ARE useful integration points. Defer to plan-phase to enumerate the integration list precisely.
- **#Q-7 (tag-namespace-collision-policy)**: What happens if a spec author uses `[source:cms-pbj-2024-q3]` as a scope tag on a spec chunk that does not factually derive from that source? The system has no factual-grounding verifier. Default proposal: scope tags are operator-asserted; ingest does not verify factual accuracy; mis-tags are an operator concern surfaced by review, not by the engine. Capture in DECISIONS.md regardless of how the planner resolves.
- **#Q-8 (tier-default-policy-per-source-type)** *(added 2026-05-01)*: For each of the four taxonomy categories (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`), what is the default tier? Initial proposals from amendment discussion: `cms-rule → 2` (small + citation-grade), `cms-manual → 1` (too big for clean conversion), `training-material → 2` (already prose), `glossary → 2` (definitional), `regulatory-doc → 2` for short docs and `1` for long docs (size threshold TBD). Defer to plan-phase to set thresholds and per-category defaults; capture in `references/reference-source-types.yaml`.
- **#Q-9 (binary-storage-size-cap-and-external-hook)** *(added 2026-05-01)*: Default size cap is 10MB; external-storage hook for files exceeding the cap is operator-declared. What schema does the external-storage declaration use? S3 URLs vs. local-path vs. arbitrary URI? Defer to plan-phase. Constraint: must support PBJ's MVP-critical 30-doc cohort, which is below 10MB per file (validated at amendment time — confirm during planning).
- **#Q-10 (extraction-queue-concurrency)** *(added 2026-05-01)*: For Tier 2 extraction with M030 routing, does the queue process documents serially or concurrently? Sequential is sufficient for PBJ's 30-doc cohort. Defer to plan-phase; concurrency is additive and can be deferred to M036b. Capture in DECISIONS.md regardless.
- **#Q-11 (m036a-vs-m036b-phase-partition)** *(added 2026-05-01)*: Which of the seven phases (P00–P06 in the existing roadmap, plus the new extraction-command phase) land in M036a (pre-launch urgent) vs. M036b (post-launch)? Initial proposal: M036a = P00 (foundation) + new extraction-command phase + P01 (ingest) + P02 (graph) + P04 (dispatch injection) + P03 (idempotency mechanism, unexercised at scale); M036b = wiki projection (P05) + scale-exercise of supersede chain (P03 follow-on) + adapter polish + REVIEW queue UX. Resolve in M036-ROADMAP.md amendment.

## Dependencies

- **Knowledge tree (M011 / M020)** — `knowledge/` directory tree, `KNOWLEDGE-INDEX.md` mechanics, `scripts/knowledge/rebuild-index.sh`, `scripts/knowledge/traverse-graph.sh`. Re-used; this feature additively extends.
- **Dispatch context-builder (M005 / M018)** — `scripts/dispatch/scope-filter.sh`, `build-context.sh` (or successor), `context-recipe.yaml`. Extended with a `reference:` section.
- **Tokenizer (M018 compression-tier)** — used by the token-budget governor (FR-8).
- **Wiki tooling (M012 / M032)** — MkDocs integration. M032 wiki projection lands in M036b; M036a does not depend on M032.
- **M030 adaptive model selection** *(added 2026-05-01, hard dependency for M036a Tier 2)* — `task_type: extraction` classification + model routing + cost rollup. Tier 2 extraction emits M030-shape `unit_close` records (FR-19). M030 closed 2026-05-01; dependency is satisfied.
- **Conversus adapter (M011/P07)** *(added 2026-05-01, hard dependency for M036a Tier 2)* — cooperative two-agent deliberation engine. Tier 2 fidelity gate (FR-18) invokes conversus with `extractor-advocate` + `fidelity-advocate` agents. Adapter exists; dependency is satisfied.
- **External shell tooling for Tier 1 adapters** *(added 2026-05-01)* — `pdftotext` (poppler-utils), `pandoc`, and an Excel parser (`xlsx2csv` or `python -m openpyxl`-based shim). Plan-phase decides exact toolchain and packaging implications.
- **Source documents (consumer-side)** — consumer projects deliver source documents in native formats with an extraction manifest. Documented as A-1 / A-2 (amended).

## Downstream Consumers (informational, not binding)

- **PBJ Analyzer validator pilot (consumer project)** — the immediate consumer; pilot window 2026-05-15. Validator agents dispatched by the consumer's orchestrator instance receive scoped CMS rules + SME training content via this feature.
- **Future M-N (cross-corpus discovery / Q&A surface)** — a possible later milestone surfacing the reference graph to operators directly (search, browse, ask). Out of scope here but enabled by this feature's graph integration.
- **Constitution amendment (any future milestone)** — Principle X (Templating Over Inference) could be expanded with a worked example referencing the `reference:` recipe section once shipped.

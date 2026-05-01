---
schema_version: "1.0"
type: feature-spec
feature_slug: "033-reference-corpus-ingest"
created_at: "2026-04-30"
status: "Draft"
milestone: "<TODO: bind to milestone — see Open Question #Q-1>"
---

# Feature Specification: 033-reference-corpus-ingest

**Feature Branch**: `033-reference-corpus-ingest`
**Created**: 2026-04-30
**Status**: Draft
**Milestone**: <TODO: bind to milestone — see Open Question #Q-1>
**Input**: User description: "Reference-corpus ingest: extend the orchestrator's knowledge layer to ingest non-spec reference materials (regulatory PDFs/XLS normalized to markdown floors, SME training content, glossaries) into a new reference/ chunk family with source-provenance frontmatter (source/published/version/cite_id/topic_tags/applies_to_field), new edge types (cites, derived_from, applies_to_field) alongside existing relates_to/supersedes, new [source:...] tag namespace, and dispatch context injection with a token-budget governor. Builds on the markdown-floor convention; PDF/XLS direct adapters as stub follow-ons. Idempotent re-ingest with content-hash + supersede chain. MkDocs wiki projection. Driven by PBJ Analyzer CMS regulatory + SME training corpus needs (validator pilot 2026-05-15)."

## Problem Statement

The orchestrator's knowledge layer is **spec-chunk + memory centric**. `orchestrator:ingest` accepts only markdown shaped like a spec-kit doc; the chunker classifies content into six spec categories (`story`, `requirement`, `acceptance`, `constraint`, `nfr`, `non-goal`); `scripts/dispatch/scope-filter.sh` and the dispatch context-builder assemble payloads from scope-filtered spec chunks plus memory categories (patterns / conventions / lessons / decisions). There is no `reference/` chunk family, no provenance-bearing frontmatter for external authoritative sources, no edge type expressing "this requirement *cites* this rule", and no mechanism for agents to receive reference excerpts scoped to the task at hand.

Three concrete pain points follow:

1. **Validator agents work blind to authoritative rules.** A consumer project (PBJ Analyzer) is preparing a validator pilot window starting 2026-05-15 against CMS regulatory PDFs and SME-authored training material. Today, an orchestrator-dispatched validation task receives only spec chunks + memory; the CMS rule the validator is checking *against* must be re-supplied (and re-summarized) by the operator on every dispatch — or omitted, leaving the agent to confabulate. Reference materials are first-class context for entire classes of work, but the orchestrator treats them as out-of-band.
2. **No provenance, no recency.** When a CMS rule is republished, today there is no way to express "the agent's understanding of rule X is based on the 2024-Q3 publication" or to invalidate stale citations. The supersede chain that exists for spec chunks does not extend to reference content because reference content does not exist as chunks.
3. **No graph-queryable structure.** The knowledge graph today expresses `relates_to` and `supersedes` between spec chunks. There is no way to express that requirement FR-7 *cites* CMS-rule §483.20, or that training-material PBJ-circle-2024-08 is *derived_from* a published CMS guidance document, or that a glossary term *applies_to_field* `staff_count`. Without these edges, BFS traversal during dispatch context construction cannot find authoritative sources by walking from a task's spec scope.

The minimum surface that fixes all three: a new `reference/` chunk family parallel to `spec/`, provenance-bearing frontmatter, three new edge types (`cites`, `derived_from`, `applies_to_field`), a `[source:...]` tag namespace, and a dispatch context-injection path that pulls reference chunks scoped by topic / `applies_to_field` under a token-budget governor.

This feature explicitly **does not** redesign extraction (PDFs/XLS arrive as already-normalized markdown — "the floor"), does not introduce vector/embedding retrieval (BFS + scope-filter remains the retrieval primitive), does not replace external Q&A tools (NotebookLM, etc.), and does not store binary source files in the orchestrator state tree.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The smallest coherent subset that closes the dogfood loop is **US-1 + US-2**: ingest a directory of provenance-bearing reference markdown into the new `reference/` chunk family (US-1), and pull those chunks into a dispatched task's context payload via topic-scoped scope-filter with a token budget (US-2). With these two stories alone, a PBJ-side validator dispatch can receive the CMS rules it cites — the load-bearing capability that defends the validator pilot window.

US-3 (edge graph + tag namespace) ships in the same minimal slice because dispatch injection requires the new edge types to express "task X cites reference Y". US-4 (re-ingest idempotency + supersede), US-5 (wiki projection), and US-6 (PDF/XLS adapter stubs) are independently testable add-ons that are not load-bearing for the validator pilot.

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

### User Story 6 — Format adapters: PDF + XLS stubs (Priority: P3)

The markdown adapter is first-class for the validator pilot. PDF and XLS direct adapters ship as **stubs** — present in the codebase, exit-2 with a clear "use the markdown floor" pointer, and a parallel issue tracking when they should graduate. This story exists to declare the adapter seam without committing to extraction work.

**Why this priority**: P3. Out-of-band PDF→markdown extraction is already covered by the consumer project's path-B floor; in-tree direct adapters are a future concern. Stubs prevent the seam from being designed away by accident.

**Independent Test**: Invoke the PDF adapter with a fixture PDF path; assert exit 2 with a stderr message naming the markdown-floor convention as the documented workaround; assert the stub is registered in the adapter dispatch table so a future implementation can replace it without a parallel registration step.

**Acceptance Scenarios**:

1. **Given** a fixture PDF file, **When** the PDF adapter stub is invoked directly, **Then** it exits 2 with a "stub: use markdown floor; see <doc-path>" stderr message, and the orchestrator's adapter registry lists `pdf` and `xls` with `status: stub`.
2. **Given** the markdown adapter, **When** the same adapter registry is inspected, **Then** `markdown` is listed with `status: live`.

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
- **FR-13 (adapter-seam)**: The codebase MUST register a format-adapter dispatch table with at minimum three entries: `markdown` (status: live), `pdf` (status: stub), `xls` (status: stub). Stub adapters exit 2 with a clear "use the markdown floor" message naming the documented external-extraction convention. Satisfies US-6.
- **FR-14 (no-binary-storage)**: The orchestrator MUST NOT copy, ingest, or persist binary source files (PDF, XLSX, DOCX) into `.orchestrator/` or `knowledge/` paths. Provenance frontmatter MAY reference an external path; that path is treated as opaque metadata. Satisfies the explicit Non-Goal on PDF binary storage and prevents repository bloat.
- **FR-15 (backwards-compat-dispatch)**: For any task plan that does not declare `topic_tags` or `applies_to_field`, the dispatched context payload MUST be byte-identical to the pre-feature payload. A `golden-baseline diff` test enforces this at the same shape as M030 SC-11. Satisfies US-2 acceptance scenario 3 and CON-1.

## Success Criteria

- **SC-1 (ingest-fixture-roundtrip)**: Running the new reference-ingest command against a fixture reference root with N≥10 markdown files (covering all four taxonomy categories) writes N chunks under the expected paths, the knowledge index lists all N, and the command exits 0. Mechanically verified by `tests/test-reference-ingest-fixture.sh` (or equivalent) with a fixture corpus checked into `tests/fixtures/`.
- **SC-2 (frontmatter-preservation)**: For every fixture input, the emitted chunk's frontmatter fields `source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field` are byte-identical to the source. Mechanically verified by a post-ingest assertion script that walks `knowledge/reference/**/*.md` and diffs against fixture inputs.
- **SC-3 (dispatch-injection-budget)**: A synthetic task plan declaring `topic_tags: [<fixture-tag>]` and `reference_token_budget: 4000` produces a dispatch payload whose reference section is ≤4000 tokens (measured by the same tokenizer used elsewhere in the orchestrator) and contains ≥1 chunk. Verified by an inspection-mode dispatch test that prints payload byte counts.
- **SC-4 (graph-edge-traversal)**: `traverse-graph.sh` invoked at depth=1 from a spec chunk declaring `cites: [REF-...]` returns the cited reference chunk with the correct edge label. Mechanically verified by a fixture spec + reference + traverse-and-grep test.
- **SC-5 (idempotent-re-ingest)**: Re-running ingest on an unchanged fixture corpus produces a `git status` that reports zero modified files under `knowledge/reference/`. Mechanically verified.
- **SC-6 (supersede-chain)**: Mutating one fixture file's body and re-ingesting produces (a) a new versioned chunk file, (b) the prior chunk's frontmatter gains `superseded_by:`, (c) the index hot-file shows both versions with the chain tip marked. Mechanically verified.
- **SC-7 (backwards-compat)**: A task plan without `topic_tags` and without `applies_to_field` produces a dispatch payload byte-identical to the pre-feature payload (golden-baseline diff). Mechanically verified by the same shape M030 SC-11 uses.
- **SC-8 (wiki-projection-nav)**: After ingest + wiki build, the rendered site nav contains a `Reference` section with at least the four taxonomy categories present in the fixture. Mechanically verified by a grep against the rendered HTML / nav YAML.
- **SC-9 (adapter-stub-exit-codes)**: PDF and XLS adapter stubs exit 2 with stderr containing the documented markdown-floor pointer; the markdown adapter exits 0 on a fixture markdown file. Mechanically verified.
- **SC-10 (no-binary-leak)**: A test fixture containing a binary file in the reference root is rejected (or ignored) without copying or persisting any bytes from the binary into `.orchestrator/` or `knowledge/`. Mechanically verified by checksumming the destination tree before/after.

## Non-Goals

- **NG-1 (no-vector-retrieval)**: This feature does NOT introduce vector / embedding-based retrieval. The retrieval primitive remains BFS + scope-filter against tagged chunks. Rationale: BFS over tagged chunks has been load-bearing for spec content for two milestones; vector retrieval is a parallel, orthogonal investment that should be evaluated independently when scope warrants.
- **NG-2 (no-external-q-and-a-integration)**: Out-of-tree Q&A tools (NotebookLM and similar) are not consumed or produced by this feature. Rationale: reference-corpus ingest delivers structured chunks consumable by the orchestrator's existing dispatch path; external Q&A is a parallel concern with its own orchestration.
- **NG-3 (no-binary-source-storage)**: Binary source files (PDF, XLSX, DOCX) are not stored, ingested, or persisted by this feature. The markdown floor is the only ingestion contract. Rationale: binary storage bloats the repo, breaks `git diff` review, and conflates this feature with extraction tooling.
- **NG-4 (no-auto-extraction-pipeline)**: This feature does NOT include extraction pipelines (PDF→markdown, XLS→markdown, OCR). Path-B extraction is handled externally by the consumer project. Rationale: scope discipline; the consumer project is already independently landing the markdown floor; layering an in-tree extractor would double-build.
- **NG-5 (no-llm-rewrite-during-ingest)**: Ingest does not summarize, paraphrase, or LLM-rewrite reference body content. Bodies are stored verbatim. Rationale: provenance fidelity (operators must trust that REF-* matches the source); a future "summarized references" surface would be a separate, gated feature.

## Constraints

- **CON-1 (no-regression-on-pre-feature-payloads)**: Existing `orchestrator:ingest`, scope-filter, dispatch context-builder, and `traverse-graph.sh` MUST continue to operate byte-identically when no reference content is present and no plan declares `topic_tags` / `applies_to_field`. This is a backwards-compatibility hard gate; SC-7 enforces.
- **CON-2 (cli-first-bash)**: New commands and scripts MUST be Bash 3.2 / POSIX-sh (matching `commands/ingest.md`'s `Bash 3.2 compatible` constraint at `commands/ingest.md:130`). Optional `jq` dependency permitted (matches existing project convention). Rationale: portability + reproducibility (Principle IX).
- **CON-3 (text-only-tests)**: All test fixtures MUST be markdown / text. No binary fixtures. Rationale: text-only tests run identically across CI and developer machines, are diffable in code review, and align with NG-3.
- **CON-4 (idempotency-mandatory)**: Every command introduced by this feature MUST be idempotent on disk state — re-running with unchanged inputs produces zero modifications. Mirrors R012 (idempotent commands) at `commands/ingest.md:105`.
- **CON-5 (no-spec-chunk-schema-change)**: Existing spec-chunk frontmatter / file layout / chain-walking rules MUST NOT change. New edge types and the `[source:...]` tag namespace are additive (existing chunks remain valid without modification). See Knowledge-Layer Boundary below.

### Knowledge-Layer Boundary (M033-reference-corpus-ingest vs. M020 / M011)

This milestone owns: `knowledge/reference/**` (new directory tree), the reference-ingest command and its scripts, the format-adapter dispatch table, the new edge types in the graph schema declaration, the `[source:...]` tag namespace, the `reference:` recipe section in the dispatch context-builder, the wiki nav generator's reference section, and the per-source provenance frontmatter contract.

This milestone does NOT own: the existing spec-chunk classifier (M011 — `scripts/knowledge/ingest-spec.sh`); existing edge types `relates_to` / `supersedes` (declared by M011/M020); existing scope-tag namespaces `[project]` / `[milestone:...]` / `[phase:...]` / `[spec:...]` (M011); `KNOWLEDGE-INDEX.md` rebuild mechanics (M011 — `scripts/knowledge/rebuild-index.sh`, which this milestone re-uses without modification); BFS traversal mechanics (M020 — `scripts/knowledge/traverse-graph.sh`, extended additively for new edge types); the markdown-shape probe / normalize-spec / fidelity gate (M011/P07 — out of scope here, since reference content is already markdown by construction).

Additive extensions to existing files (e.g., `traverse-graph.sh` learns the new edge types) are owned by this milestone; the schema declaration these scripts read is a single SSOT (Principle XI) that this milestone amends in one place.

## Assumptions

- **A-1 (markdown-floor-exists)**: Consumer projects normalize PDFs/XLS/DOCX to markdown externally before ingest. The PBJ Analyzer project is independently landing this floor; this feature builds on top.
- **A-2 (frontmatter-authored-by-extractor)**: The provenance frontmatter (`source`, `published`, etc.) is authored upstream by whatever produces the markdown floor. This feature validates presence, not derives values.
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
- **Principle XIV (No Speculative Complexity)**: Vector retrieval, NotebookLM integration, binary storage, and auto-extraction are explicit Non-Goals. The seam for PDF/XLS adapters is registered as a stub (FR-13) — declarative but non-functional — exactly the minimum required to avoid designing the seam away by accident.
- **Principle XV (Surgical Precision)**: The Knowledge-Layer Boundary section names the exact write-sites this milestone claims and the existing files extended additively (e.g., traverse-graph schema). Re-ingest never auto-edits spec or memory chunks; affected chunks surface as `REVIEW:` advisories (FR-11).

## Open Questions (defer to planning)

- **#Q-1 (milestone-slot)**: Where does this feature slot in the roadmap? Three viable framings, decision deferred to `orchestrator:roadmap`: (a) own milestone (proposed M036 — naming TBD; latest pre-launch slot, gated against the post-M035 launch event); (b) extension of M020 (knowledge-layer maturation — already closed; would require a re-open / M020.1 numbering); (c) a deferred-post-launch milestone with the validator-pilot window served by an in-place patch on the consumer side. The 2026-05-15 pilot window strongly biases toward (a) with aggressive scope; (c) is the safest re-launch posture but punts on the consumer's deadline.
- **#Q-2 (relevance-ordering-signal)**: When dispatch injection has more matched chunks than fit the budget, how is priority computed? Options: (i) frontmatter-declared `priority:` integer; (ii) BFS-distance from the task's spec scope; (iii) `published` recency (newest wins); (iv) hybrid. Each has tradeoffs (declarative is operator-burden; BFS-distance requires graph-walk every dispatch; recency is wrong for glossaries). Defer to plan-phase; capture decision in DECISIONS.md.
- **#Q-3 (versioning-model)**: For sources that publish in parallel versions (CMS publishes Q1 / Q2 / Q3 and operators must cite a specific quarter), is the supersede chain the right model — or does the corpus need parallel-version retention (multiple "live" versions, not a chain)? Default proposal: supersede chain with explicit `version:` frontmatter as the operator-facing handle (still cite-able even after supersession via the versioned filename). Alternative: parallel `REF-cat-id@2024-q1.md` / `REF-cat-id@2024-q3.md` siblings with a "latest" pointer. Defer to plan-phase.
- **#Q-4 (storage-table-vs-files)**: The existing knowledge layer is file-based (markdown chunks under `knowledge/spec/`). Should reference chunks land in the same shape (`knowledge/reference/<cat>/REF-*.md`) for full architectural symmetry, or is there a SQLite table (mentioned in the input brief) that this work plugs into? Default proposal: same file shape as spec chunks — minimum delta from current architecture, maximum reuse of `rebuild-index.sh`. If a SQLite layer exists or is planned, the planner reconciles. Defer.
- **#Q-5 (fidelity-gate-posture)**: Should reference ingest go through a Conversus fidelity gate analogous to M011/P07's source-vs-normalized deliberation? Three positions: (a) NO — markdown is verbatim, no LLM step to gate; (b) YES per-source-type — cms-rule warrants gating, training-material does not; (c) YES universal — even verbatim ingest benefits from a "did all chunks emit" verifier. Default proposal: (a) for the minimal slice (verbatim transport, no need for fidelity gate), with a clear seam for adding gating later if fidelity-of-extraction concerns arise. Defer to plan-phase; this affects whether the conversus adapter is a dependency of P01.
- **#Q-6 (dependencies-on-m013-m014-gate-work)**: The brief asks whether dependencies on M013–M014's gate work need to be called out. Initial reading: NO — those gates fire on spec-shape conformity and section-contract fidelity, neither of which apply to reference content (which has its own taxonomy + provenance contract, not the spec-template Section Contract). But: the dual-write helper (M014) and the M027 metrics surface ARE useful integration points. Defer to plan-phase to enumerate the integration list precisely.
- **#Q-7 (tag-namespace-collision-policy)**: What happens if a spec author uses `[source:cms-pbj-2024-q3]` as a scope tag on a spec chunk that does not factually derive from that source? The system has no factual-grounding verifier. Default proposal: scope tags are operator-asserted; ingest does not verify factual accuracy; mis-tags are an operator concern surfaced by review, not by the engine. Capture in DECISIONS.md regardless of how the planner resolves.

## Dependencies

- **Knowledge tree (M011 / M020)** — `knowledge/` directory tree, `KNOWLEDGE-INDEX.md` mechanics, `scripts/knowledge/rebuild-index.sh`, `scripts/knowledge/traverse-graph.sh`. Re-used; this feature additively extends.
- **Dispatch context-builder (M005 / M018)** — `scripts/dispatch/scope-filter.sh`, `build-context.sh` (or successor), `context-recipe.yaml`. Extended with a `reference:` section.
- **Tokenizer (M018 compression-tier)** — used by the token-budget governor (FR-8).
- **Wiki tooling (M012 / M032)** — MkDocs integration. M032 (in queue) is the active distribution-and-init milestone for wiki tooling; depending on milestone-slot resolution (#Q-1), this feature may need to land before or after M032's delivery. Plan-time concern.
- **Markdown-floor convention (consumer-side, PBJ Analyzer)** — extraction is upstream, not in scope. Documented as A-1.

## Downstream Consumers (informational, not binding)

- **PBJ Analyzer validator pilot (consumer project)** — the immediate consumer; pilot window 2026-05-15. Validator agents dispatched by the consumer's orchestrator instance receive scoped CMS rules + SME training content via this feature.
- **Future M-N (cross-corpus discovery / Q&A surface)** — a possible later milestone surfacing the reference graph to operators directly (search, browse, ask). Out of scope here but enabled by this feature's graph integration.
- **Constitution amendment (any future milestone)** — Principle X (Templating Over Inference) could be expanded with a worked example referencing the `reference:` recipe section once shipped.

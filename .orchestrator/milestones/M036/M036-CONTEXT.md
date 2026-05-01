---
schema_version: "1.0"
type: context-draft
milestone: "M036"
feature_ref: "033-reference-corpus-ingest"
status: "finalized (amended 2026-05-01)"
finalized_at: "2026-04-30"
amended_at: "2026-05-01"
---

# M036 Context Draft

## Amendment Record (2026-05-01)

**Trigger**: 2026-05-01 working-session discussion clarified that PBJ Analyzer has **no path-B markdown-floor extractor** — neither internally nor externally. The original spec (2026-04-30) was authored on the explicit assumption A-1 that "consumer projects normalize PDFs/XLS/DOCX to markdown externally before ingest." That assumption was incorrect.

**Consequence**: Extraction is now **orchestrator-owned** as a first-class capability across three tiers. This affects the spec, this context draft, and the roadmap. See `specs/033-reference-corpus-ingest/spec.md` Amendment Record for the per-section diff. Roadmap restructured 2026-05-01 from 7 phases → 10 phases under an M036a/M036b split.

**Decisions newly resolved at amendment-time**:

- **Extraction ownership** — orchestrator owns Tier 0 (manifest + binary preservation), Tier 1 (deterministic shell adapters: PDF/DOCX/XLSX/Markdown), Tier 2 (LLM-driven structured Markdown via M030 routing + conversus fidelity gate). NG-3, NG-4, NG-5 inverted/narrowed accordingly.
- **Tier model** — Tier 0/1/2 architecture explicitly defines the retrieval contract per document. Source-type defaults + per-document override. Explicit upgrade only (no implicit/lazy promotion at dispatch time, per Principle VI).
- **#Q-3 versioning model** — supersede chain (was deferred). Matches existing spec-chunk pattern; preserves change-over-time queries; older versions cite-able via versioned filenames.
- **#Q-5 fidelity-gate posture** — tiered (was deferred). Tier 0/1 deterministic, not gated. Tier 2 LLM extraction gated by conversus deliberation (PASS/BLOCK).
- **Format set** — adds DOCX (Word) to PDF + XLS (now XLSX). Markdown remains a passthrough adapter. Total live Tier 1 adapters: 4.
- **Milestone-split (#Q-11)** — M036a (pre-launch urgent, P00–P07, defends 2026-05-15 PBJ pilot) + M036b (post-launch, P08–P09, wiki projection + operator-facing scale UX). Was: single milestone slot at "post-launch fast-follow."
- **New plan-phase open questions** — #Q-8 (per-category default tier thresholds), #Q-9 (binary size cap + external-storage hook schema), #Q-10 (extraction queue concurrency).
- **New hard dependencies** — M030 (closed 2026-05-01) for Tier 2 model routing; conversus adapter (M011/P07, shipped) for Tier 2 fidelity gate; external shell tooling (`pdftotext`, `pandoc`, Excel parser) for Tier 1.

**Why this amendment instead of a new spec**: The bones of the original spec (taxonomy, frontmatter contract, edge types, tag namespace, dispatch injection, idempotency invariant) are unchanged. The amendments are localized to extraction ownership, the tier model, three NG inversions, and four FRs (with five new FRs added). Heavy in-place amendment preserves artifact continuity — spec ID 033 / milestone M036 / evaluation / context draft all stay valid. A fresh spec would have rewritten ~70% of unchanged content.

## Architectural Framing (resolved at roadmap-time)

## Architectural Framing (resolved at roadmap-time)

### Milestone slot

This work lands as **M036** — its own milestone, sequential after the queued M031–M035. Three positions were considered (spec Open Question #Q-1):

- **(a) Own milestone M036 (chosen)** — the seven open questions, the cross-cutting graph + dispatch + wiki concerns, and the 2026-05-15 PBJ validator pilot deadline justify a dedicated roadmap deliberation.
- (b) Re-open M020 as M020.1 — rejected; closed milestones are not idiomatic to re-open in this project.
- (c) Defer post-launch — rejected; the validator pilot window is the load-bearing demand signal that justifies the work now.

**Launch-posture decision** *(amended 2026-05-01)*: M036 splits into **M036a (pre-launch urgent)** + **M036b (post-launch)**:

- **M036a** (P00–P07, 8 phases) — defends the 2026-05-15 PBJ validator pilot. Inserts ahead of M035 P02–P06 (publishing pipeline) if launch event slips past mid-May. Critical path: P00 → P01 → P02 → P03 → P04 → P05 → P07 (7 phases on the critical path; P06 idempotency is required for production but not for the first-run pilot dispatch).
- **M036b** (P08–P09, 2 phases) — post-launch, demand-driven. P08 wiki projection (depends on M032 closure). P09 operator-facing scale UX (REVIEW queue, change-over-time queries, supersede chain at scale). Ships when validator-pilot feedback surfaces concrete operator pain.

The original "post-launch fast-follow" framing was based on the (now-invalidated) assumption that PBJ owned extraction. With orchestrator-owned extraction load-bearing for the pilot, the M036a portion must precede mid-May regardless of where the launch event lands.

### Phase decomposition strategy

Three SDD flows mapped to phases (per evaluation):

1. **Ingest layer** — own phases for taxonomy + frontmatter contract, ingest command, idempotent re-ingest. Foundation.
2. **Graph + dispatch integration** — own phases for graph schema extension + tag namespace, scope-filter wiring, dispatch payload + token-budget governor. Backwards-compat-gated.
3. **Wiki projection + adapter seam** — own phases for wiki nav generator and the format-adapter dispatch table with PDF/XLS stubs. Distinct surfaces.

Risk-ordered: graph-schema extension is the highest-risk phase (touches multiple downstream consumers); ingest layer is medium (new directory tree, but isolated); wiki + adapter seam are lower (additive, well-bounded).

### Dependencies on prior milestones

Inventoried at roadmap-time, deferred to plan-phase for the precise integration points:

- **M011 (spec-management) / M020 (knowledge-layer maturation)** — knowledge tree, `rebuild-index.sh`, `traverse-graph.sh`. Re-used; additively extended. **Hard dependency** on the existing spec-chunk machinery being functional (it is — both closed).
- **M005 / M018 (dispatch + compression-tier)** — context recipe, scope-filter, dispatch context-builder, tokenizer. Re-used for the `reference:` payload section and budget governor. **Hard dependency** on the recipe schema being declarative (Principle X) — already true.
- **M012 / M032 (wiki tooling)** — MkDocs integration. M032 is **in queue** (pre-launch). **Soft dependency**: M036 wiki-projection phase consumes M032's `--with-wiki` plumbing; if M036 lands before M032 wraps, this phase blocks. Roadmap calls this out as a sequencing dependency.
- **M013 / M014 (GitHub native + spec management gate work)** — initial reading: **NO hard dependency** (per spec Open Question #Q-6). M013/M014's gates fire on spec-shape conformity and Section Contract fidelity, neither of which apply to reference content (which has its own taxonomy + provenance contract). Soft integration points (dual-write helper, M027 metrics surface) are useful but not load-bearing.
- **M027 (cost+quality observability)** — used additively: ingest emits `unit_close` records; dispatch payload emits `reference_chunks_injected`, `reference_tokens_used` fields. Soft dependency.
- **M030 (adaptive model selection)** — soft. Reference-injection touches dispatch payload; the byte-equality invariant SC-11 from M030 is the harness shape this feature's SC-7 inherits.

### Runtime + portability constraints

- CON-2: Bash 3.2 / POSIX-sh + optional jq. No new runtime deps.
- CON-3: text-only test fixtures. No binaries in the repo.
- CON-1 + FR-15 + SC-7: backwards-compat is a hard gate. Golden-baseline diff harness required.

## Decisions Deferred to Plan-Phase *(updated 2026-05-01)*

These remain Open Questions in the spec; roadmap explicitly does NOT resolve them:

- **#Q-2** Relevance-ordering signal for token-budget governance — research at the dispatch-integration phase (P07).
- **#Q-4** Storage shape (file-based vs SQLite table) — initial inclination is file-based (minimum delta); plan-phase confirms at P04.
- **#Q-7** Tag-namespace collision policy — captured as a DECISION at plan-phase regardless of resolution.
- **#Q-8** *(added 2026-05-01)* Per-category default-tier thresholds — research at P02 (extract command); capture in `references/reference-source-types.yaml`.
- **#Q-9** *(added 2026-05-01)* Binary-storage size cap + external-storage hook schema — research at P02; default 10MB confirmed at amendment time.
- **#Q-10** *(added 2026-05-01)* Extraction queue concurrency model — research at P02; sequential default sufficient for PBJ's 30-doc cohort.

Open Questions resolved at roadmap-time / amendment-time (NOT deferred):

- **#Q-1** (milestone slot) — resolved here (M036a/M036b split).
- **#Q-3** (versioning model) — resolved at amendment 2026-05-01: supersede chain.
- **#Q-5** (fidelity-gate posture) — resolved at amendment 2026-05-01: tiered (Tier 2 gated, Tier 0/1 deterministic).
- **#Q-6** (M013/M014 dependencies) — resolved at original roadmap creation: no hard dependency.
- **#Q-11** (M036a/M036b phase partition) — resolved at amendment 2026-05-01 via roadmap restructure.

## Constitution Check (roadmap-level)

- **Principle III (Design Before Code)**: roadmap surfaces the seven load-bearing ambiguities; plan-phase MUST resolve them per principle.
- **Principle XIV (No Speculative Complexity)**: PDF/XLS stubs (FR-13) are minimum-seam; vector retrieval / NotebookLM / binary storage are explicit Non-Goals.
- **Principle XV (Surgical Precision)**: phase boundary maps will declare exact write-sites; existing chunks/edges are extended additively, not modified.

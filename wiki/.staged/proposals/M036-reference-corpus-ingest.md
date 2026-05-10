# Proposal: [M036](../milestones/M036/index.md) — Reference-Corpus Ingest *(amended 2026-05-01)*

**Captured**: 2026-04-30 during a roadmap-fit assessment driven by PBJ Analyzer (downstream consumer) corpus needs
**Amended**: 2026-05-01 — extraction-ownership flip (PBJ has no path-B extractor, orchestrator owns extraction); tier model added; DOCX added; #Q-3 / #Q-5 resolved; milestone split into **M036a (pre-launch urgent, P00–P07) + M036b (post-launch, P08–P09)**.
**Shape**: Milestone split (10 phases total). M036a P00 foundation → P01 Tier 1 adapters → P02 Tier 0 + extract command → P03 Tier 2 + conversus gate → P04 ingest → {P05 graph (parallel), P06 idempotency, P07 dispatch injection}. M036b: P08 wiki projection (blocked by [M032](../milestones/M032/index.md)), P09 operator-facing scale UX. See full roadmap at [`.orchestrator/milestones/M036/M036-ROADMAP.md`](../milestones/M036/M036-ROADMAP.md).
**Predecessors**: [M011](../milestones/M011/index.md) (spec-management — chunker + classifier conventions), [M020](../milestones/M020/index.md) (knowledge-layer maturation — graph schema, traverser, index), [M005](../milestones/M005/index.md) / [M018](../milestones/M018/index.md) (dispatch context-builder, recipe schema, tokenizer), [M012](../milestones/M012/index.md) / M032 (wiki tooling — soft dep on M032 for P08 in M036b), [M027](../milestones/M027/index.md) (observability — `unit_close` + JSONL fields), **[M030](../milestones/M030/index.md) (closed 2026-05-01 — hard dep for M036a P03 Tier 2 model routing)**, **conversus adapter from M011/P07 (hard dep for M036a P03 fidelity gate)**
**Spec**: `specs/033-reference-corpus-ingest/spec.md` — authored 2026-04-30 via `orchestrator:specify`; **amended 2026-05-01** (extraction-ownership flip + tier model + M036a/M036b split — see spec Amendment Record)
**Evaluation**: [`.orchestrator/milestones/M036/M036-EVALUATION.md`](../milestones/M036/M036-EVALUATION.md) — Tier C (auto). 7 user stories (US-7 added 2026-05-01 for tiered extraction command), 20 FRs (5 added at amendment: FR-16/17/18/19/20), 3 distinct SDD flows.
**Context draft**: [`.orchestrator/milestones/M036/M036-CONTEXT.md`](../milestones/M036/M036-CONTEXT.md) — finalized 2026-04-30, **amended 2026-05-01**. Resolves milestone-slot (#Q-1, M036a/M036b), #Q-3 (supersede chain), #Q-5 (tiered fidelity gate), and M013/[M014](../milestones/M014/index.md) dependency posture (#Q-6); defers six plan-phase-scoped open questions to phase planning (#Q-2, #Q-4, #Q-7, #Q-8, #Q-9, #Q-10).

## Goal *(amended 2026-05-01)*

Extend the orchestrator's knowledge layer from spec-chunk + memory to **spec + memory + reference**. Ingest non-spec reference materials — regulatory PDFs/Word/Excel, SME-authored training content, glossaries — into a new `reference/` chunk family with source-provenance frontmatter (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`), three new edge types (`cites`, `derived_from`, `applies_to_field`) alongside existing `relates_to` / `supersedes`, a `[source:...]` tag namespace alongside `[project]` / `[milestone:...]` / `[phase:...]` / `[spec:...]`, and dispatch context-injection that pulls reference chunks scoped by topic / `applies_to_field` under a token-budget governor.

**Orchestrator-owned tiered extraction** *(amended 2026-05-01)*: source documents (PDF / Word / Excel / Markdown) flow through three tiers — Tier 0 (manifest + original binary preservation + summary), Tier 1 (deterministic shell-out plain text via PDF/DOCX/XLSX/MD adapters), Tier 2 (LLM-driven structured Markdown via M030 routing under conversus fidelity gate). Tier policy declared per-source-type with per-document override; explicit upgrade only (no implicit/lazy promotion at dispatch — Principle VI).

The retrieval primitive remains BFS + scope-filter (no vector / embeddings — explicit Non-Goal). Re-ingest is idempotent with content-hash + supersede chain matching `commands/ingest.md`'s spec-chunk pattern.

## Why now (demand signal) *(amended 2026-05-01)*

PBJ Analyzer (consumer project at `/Users/brettkellgren/Sites/pbj-central-mono-repo`) has a corpus of **~30 PDF + Word docs** (MVP-critical knowledge-graph cohort) plus an unknown set of Excel files, plus SME-authored training content (PBJ Circle blog from Don Feige + Jenn) that needs to be graph-queryable so dispatched validator agents can pull authoritative rules scoped to the validation task. **PBJ has no consumer-side extractor** — neither internal nor external. The orchestrator must own extraction; this is the production path from raw source documents to ingested reference chunks.

The PBJ validator pilot window starts **2026-05-15**. Without M036a (P00 → P07 critical path), validator agents work blind to authoritative rules, or operators must hand-paste CMS excerpts on every dispatch. The M036a slice (US-1 + US-2 + US-3 + US-6 + US-7) defends the pilot window.

## Why split: M036a pre-launch urgent / M036b post-launch *(amended 2026-05-01)*

The original framing positioned M036 as a single post-launch fast-follow. With orchestrator-owned extraction load-bearing for the PBJ pilot (no path-B exists), the extraction + ingest + dispatch-injection stack must precede mid-May regardless of where the launch event lands. The wiki projection and operator-facing scale UX remain genuinely demand-driven post-launch work.

**M036a (pre-launch urgent, 8 phases)** — P00 foundation, P01 Tier 1 adapters, P02 Tier 0 + extract command, P03 Tier 2 + conversus gate, P04 ingest, P05 graph schema, P06 idempotency mechanism, P07 dispatch injection. Critical path defends 2026-05-15 PBJ pilot. May insert ahead of [M035](../milestones/M035/index.md) P02–P06 (publishing pipeline) if launch event slips past mid-May.

**M036b (post-launch, 2 phases)** — P08 wiki projection (depends on M032 closure), P09 operator-facing scale UX (REVIEW queue, change-over-time queries, supersede chain at scale). Demand-driven; ships when validator-pilot feedback surfaces concrete operator pain.

Three rationales for the split:

1. **Demand-evidence boundary** — extraction + ingest + dispatch are the load-bearing capability PBJ needs n=1 today. Wiki + scale UX are operator-comfort surfaces that benefit from real-pilot feedback before being designed.
2. **M032 dependency** — wiki projection (P08) genuinely depends on M032 closure. Splitting it into M036b cleanly resolves the cross-milestone block.
3. **Pre-launch / post-launch boundary** — M036a is "make PBJ pilot work"; M036b is "make corpus management ergonomic at scale." Two distinct definition-of-done surfaces; separate milestones make the boundary explicit.

Slot: **M036a pre-launch insertion** + **M036b post-launch fast-follow** alongside M009 / M023 / M034 / M010.

## Phase shape *(amended 2026-05-01 — full roadmap at `M036-ROADMAP.md`)*

```
M036a (pre-launch urgent):

                                    ┌─→ P05 (graph) ──→ P07 (dispatch injection)
P00 (foundation) ──→ P01 (Tier 1) ──→ P02 (Tier 0 + extract) ──→ P03 (Tier 2 + gate)
                                                     │                  │
                                                     └─→ P04 (ingest) ──→ P06 (idempotency)

M036b (post-launch):

P04, P05 ──→ P08 (wiki projection — blocked by M032)
P06 ──────→ P09 (operator-facing scale UX)
```

**M036a (8 phases)**:

- **P00 (foundation, low risk)** — taxonomy SSOT (cms-rule, training-material, glossary, regulatory-doc) + provenance frontmatter contract + tier-policy schema + adapter registry seam + edge-type / tag-namespace declarations. No dependencies.
- **P01 (Tier 1 live adapters, medium risk)** — live `pdftotext` / `pandoc` / Excel-parser / Markdown adapters. External shell tooling probe.
- **P02 (Tier 0 + extract command, high risk)** — `orchestrator:extract` synchronous Tier 0/1 path; manifest schema; binary preservation + size-cap governance; summary generation.
- **P03 (Tier 2 LLM extraction + conversus gate, high risk)** — M030 task-type=extraction routing; conversus extractor-advocate vs. fidelity-advocate deliberation; PASS promotes to chunk store, BLOCK retains rationale.
- **P04 (ingest layer, medium risk)** — `scripts/knowledge/ingest-reference.sh` + classifier + chunk emission. Consumes Tier 0/1/2 outputs.
- **P05 (graph schema extension, high risk)** — additive support in `traverse-graph.sh` and `scope-filter.sh` for new edge types and `[source:...]` tag namespace; regression guard for existing edges.
- **P06 (idempotency + supersede chain, medium risk)** — content-hash gating at extract + ingest, supersede chain mechanism, REVIEW advisories.
- **P07 (dispatch injection + token-budget governor, high risk — backwards-compat-gated)** — declarative `reference:` recipe section, token-budget governor, golden-baseline diff harness (M030 SC-11 shape).

**M036b (2 phases)**:

- **P08 (wiki projection, low risk)** — MkDocs nav under `Reference > <category>`, cross-doc rendering of `cites:`. Blocked by M032 closure.
- **P09 (scale UX, medium risk)** — REVIEW queue + change-over-time queries + supersede chain at scale + tier-upgrade-advisory consumer.

**Critical path for 2026-05-15 PBJ pilot**: P00 → P01 → P02 → P03 → P04 → P05 → P07 (7 phases of M036a). P06 needed for production but not first-run pilot. M036b does not gate the pilot.

## Plan-phase open questions *(updated 2026-05-01)*

Resolved at roadmap-time / amendment-time (M036-CONTEXT.md):
- **#Q-1** milestone slot → **M036a (pre-launch urgent) + M036b (post-launch)** *(amended 2026-05-01)*
- **#Q-3** versioning model → **supersede chain** *(resolved at amendment)*
- **#Q-5** fidelity-gate posture → **tiered: Tier 0/1 deterministic, Tier 2 conversus-gated** *(resolved at amendment)*
- **#Q-6** M013/M014 dependencies → **NO hard dependency** (gates fire on spec-shape + Section Contract; reference content has its own taxonomy + provenance contract); soft integration points only
- **#Q-11** M036a/M036b phase partition → resolved at amendment via roadmap restructure

Deferred to plan-phase per spec.md:
- **#Q-2** relevance-ordering signal for token-budget governor → research at P07
- **#Q-4** storage shape (file-based vs SQLite table) → confirm at P04 (default: file-based, minimum delta)
- **#Q-7** tag-namespace collision policy → DECISION at P05 regardless of resolution
- **#Q-8** *(added 2026-05-01)* per-category default-tier thresholds → research at P02
- **#Q-9** *(added 2026-05-01)* binary-storage size cap + external-storage hook schema → research at P02 (default 10MB confirmed at amendment)
- **#Q-10** *(added 2026-05-01)* extraction queue concurrency model → research at P02 (sequential default sufficient for PBJ's 30-doc cohort)

## Non-Goals *(amended 2026-05-01 — see spec for full text)*

- **NG-1**: no vector/embedding retrieval *(unchanged)*
- **NG-2**: no NotebookLM / external Q&A integration *(unchanged)*
- **NG-3-NEW**: governed binary preservation — original binaries preserved at Tier 0 below 10MB cap; external-storage hook above; gitignored by default *(inverted from "no binary storage")*
- **NG-4-NEW**: orchestrator owns Tier 0/1/2 extraction; OCR for image-only PDFs + automated translation + content paraphrase remain out of scope *(inverted from "no auto-extraction")*
- **NG-5-NEW**: no LLM rewrite at Tier 0/1; Tier 2 LLM extraction permitted under conversus fidelity gate; content summarization / paraphrase still out of scope *(narrowed)*

## Source material

- Spec: `specs/033-reference-corpus-ingest/spec.md`
- Roadmap: [`.orchestrator/milestones/M036/M036-ROADMAP.md`](../milestones/M036/M036-ROADMAP.md)
- Evaluation: [`.orchestrator/milestones/M036/M036-EVALUATION.md`](../milestones/M036/M036-EVALUATION.md)
- Context: [`.orchestrator/milestones/M036/M036-CONTEXT.md`](../milestones/M036/M036-CONTEXT.md)
- Consumer corpus: PBJ Analyzer at `/Users/brettkellgren/Sites/pbj-central-mono-repo` (CMS regulatory PDFs/XLS + SME PBJ Circle training content)
- Existing infrastructure to extend: M011/M020 knowledge layer (`knowledge/spec/**`, `scripts/knowledge/rebuild-index.sh`, `scripts/knowledge/traverse-graph.sh`); M005/M018 dispatch (`scripts/dispatch/scope-filter.sh`, context recipe, tokenizer); M012/M032 wiki tooling

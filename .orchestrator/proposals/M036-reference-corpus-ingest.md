# Proposal: M036 — Reference-Corpus Ingest

**Captured**: 2026-04-30 during a roadmap-fit assessment driven by PBJ Analyzer (downstream consumer) corpus needs
**Shape**: Milestone (7 phases — P00 foundation; P01/P02/P06 concurrent post-foundation; P03/P04/P05 third wave). See full roadmap at `.orchestrator/milestones/M036/M036-ROADMAP.md`.
**Predecessors**: M011 (spec-management — chunker + classifier conventions), M020 (knowledge-layer maturation — graph schema, traverser, index), M005 / M018 (dispatch context-builder, recipe schema, tokenizer), M012 / M032 (wiki tooling — soft dep on M032 for P05), M027 (observability — `unit_close` + JSONL fields), M030 (byte-equality regression-harness shape via SC-11)
**Spec**: `specs/033-reference-corpus-ingest/spec.md` — authored 2026-04-30 via `orchestrator:specify` (Standard intensity, shape-lint 10/10 PASS)
**Evaluation**: `.orchestrator/milestones/M036/M036-EVALUATION.md` — Tier C (auto). 6 user stories, 15 FRs, 3 distinct SDD flows.
**Context draft**: `.orchestrator/milestones/M036/M036-CONTEXT.md` — finalized 2026-04-30. Resolves milestone-slot (#Q-1) and M013/M014 dependency posture (#Q-6); defers five plan-phase-scoped open questions to phase planning.

## Goal

Extend the orchestrator's knowledge layer from spec-chunk + memory to **spec + memory + reference**. Ingest non-spec reference materials — regulatory PDFs/XLS that were normalized to markdown floors externally, SME-authored training content, glossaries — into a new `reference/` chunk family with source-provenance frontmatter (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`), three new edge types (`cites`, `derived_from`, `applies_to_field`) alongside existing `relates_to` / `supersedes`, a `[source:...]` tag namespace alongside `[project]` / `[milestone:...]` / `[phase:...]` / `[spec:...]`, and dispatch context-injection that pulls reference chunks scoped by topic / `applies_to_field` under a token-budget governor.

The retrieval primitive remains BFS + scope-filter (no vector / embeddings — explicit Non-Goal). The markdown floor is the ingest contract (PDF/XLS direct adapters ship as registered stubs — explicit minimum-seam under Principle XIV). Re-ingest is idempotent with content-hash + supersede chain matching `commands/ingest.md`'s spec-chunk pattern.

## Why now (demand signal)

PBJ Analyzer (consumer project at `/Users/brettkellgren/Sites/pbj-central-mono-repo`) has a corpus of CMS regulatory PDFs/XLS plus SME-authored training content (PBJ Circle blog from Don Feige + Jenn) that needs to be graph-queryable so dispatched validator agents can pull authoritative rules scoped to the validation task at hand. The PBJ project is independently landing a "markdown floor" — PDFs/XLS normalized to `.orchestrator/knowledge/reference/{source}/{slug}.md` with frontmatter, wired into MkDocs. M036 builds **on top of** that floor; it does not redesign extraction.

The PBJ validator pilot window starts **2026-05-15**. Without M036, validator agents work blind to authoritative rules, or operators must hand-paste CMS excerpts on every dispatch. The minimal slice (US-1 + US-2 + US-3 / phases P00 + P01 + P02 + P04) defends the pilot window.

## Why post-launch fast-follow (not pre-launch insertion)

The pre-launch queue (M031 → M032 → M033 → M029 → M035) targets first-time users on small-to-medium projects. M036's scenario — a corpus-heavy validator workflow against authoritative external sources — is a **power-user workflow** specific to consumer projects with their own reference material. Pre-launch dogfooding for M036 would require either synthetic fixtures or driving the work entirely from PBJ Analyzer; the latter blurs orchestrator-launch readiness with consumer-project delivery.

Three secondary reasons:

1. **Demand n≥1 today** — PBJ Analyzer is the only known consumer with this need. Ship on demand evidence, not on speculation (Principle XIV applies to roadmap as well as code).
2. **Composes with already-shipped infrastructure** — M020 graph + M018 dispatch + M027 metrics are all live. M036 reaps their outputs.
3. **2026-05-15 deadline pressure is real but bounded** — if the launch event slips past the validator pilot window, M036 may insert ahead of M035 P02–P06 (the publishing pipeline phases) for the consumer's benefit. This is a sequencing-risk callout, not a default.

Slot: **post-launch fast-follow** alongside M009 / M023 / M034 / M010 in the demand-driven bucket. Insert-ahead pressure exists if PBJ pilot deadline forces it.

## Phase shape (full roadmap at `M036-ROADMAP.md`)

```
                    ┌─→ P03 (idempotency / supersede)
P00 (foundation) ──→ P01 (ingest) ──┤
                    │               └─→ P04 (dispatch injection)
                    │                    ↑
                    └─→ P02 (graph) ─────┘
                    │   │
                    │   └─→ P05 (wiki projection — blocked by M032)
                    │       ↑
                    │       └── P01 (chunks)
                    │
                    └─→ P06 (adapter stubs)
```

- **P00 (foundation, low risk)** — taxonomy SSOT (cms-rule, training-material, glossary, regulatory-doc) + provenance frontmatter contract + adapter registry seam + edge-type / tag-namespace declarations. No dependencies.
- **P01 (ingest layer, medium risk)** — `scripts/knowledge/ingest-reference.sh` + classifier + chunk emission + fixture corpus.
- **P02 (graph schema extension, high risk)** — additive support in `traverse-graph.sh` and `scope-filter.sh` for new edge types and `[source:...]` tag namespace; regression guard for existing edges.
- **P03 (idempotent re-ingest, medium risk)** — content-hash, supersede chain, REVIEW advisories.
- **P04 (dispatch injection, high risk — backwards-compat-gated)** — declarative `reference:` recipe section, token-budget governor, golden-baseline diff harness (M030 SC-11 shape).
- **P05 (wiki projection, low risk)** — MkDocs nav under `Reference > <category>`, cross-doc rendering of `cites:`. Blocked by M032 closure.
- **P06 (adapter stubs, low risk)** — markdown=live, pdf=stub, xls=stub. Minimum seam.

**Critical path for 2026-05-15 PBJ pilot**: P00 → P01 → P02 → P04 (4 phases). P03 / P05 / P06 do not gate the pilot.

## Plan-phase open questions (deferred per Principle III)

Resolved at roadmap time (M036-CONTEXT.md):
- #Q-1 milestone slot → **own milestone M036, post-launch fast-follow**
- #Q-6 M013/M014 dependencies → **NO hard dependency** (gates fire on spec-shape + Section Contract; reference content has its own taxonomy + provenance contract); soft integration points only

Deferred to plan-phase per spec.md:
- #Q-2 relevance-ordering signal for token-budget governor → research at P04
- #Q-3 versioning model (supersede chain vs parallel-version retention) → research at P01 / P03
- #Q-4 storage shape (file-based vs SQLite table) → confirm at P01 (default: file-based, minimum delta)
- #Q-5 fidelity-gate posture (yes / no / per-source-type) → research at P01 (default: no for minimal slice; seam preserved)
- #Q-7 tag-namespace collision policy → DECISION at P02 regardless of resolution

## Non-Goals (carried from spec)

- NG-1: no vector/embedding retrieval
- NG-2: no NotebookLM / external Q&A integration
- NG-3: no binary source storage (PDF/XLSX never enter `.orchestrator/` or `knowledge/`)
- NG-4: no auto-extraction pipelines (path-B handles externally)
- NG-5: no LLM-rewrite during ingest (provenance fidelity)

## Source material

- Spec: `specs/033-reference-corpus-ingest/spec.md`
- Roadmap: `.orchestrator/milestones/M036/M036-ROADMAP.md`
- Evaluation: `.orchestrator/milestones/M036/M036-EVALUATION.md`
- Context: `.orchestrator/milestones/M036/M036-CONTEXT.md`
- Consumer corpus: PBJ Analyzer at `/Users/brettkellgren/Sites/pbj-central-mono-repo` (CMS regulatory PDFs/XLS + SME PBJ Circle training content)
- Existing infrastructure to extend: M011/M020 knowledge layer (`knowledge/spec/**`, `scripts/knowledge/rebuild-index.sh`, `scripts/knowledge/traverse-graph.sh`); M005/M018 dispatch (`scripts/dispatch/scope-filter.sh`, context recipe, tokenizer); M012/M032 wiki tooling

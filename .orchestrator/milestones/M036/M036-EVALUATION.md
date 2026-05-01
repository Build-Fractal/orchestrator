---
schema_version: "1.0"
type: evaluation
milestone: "M036"
feature_ref: "033-reference-corpus-ingest"
feature_spec: "specs/033-reference-corpus-ingest/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-30"
spec_slug: "033-reference-corpus-ingest"
metrics_source: "raw_spec"
---

# M036 Evaluation

## Classification

- **Tier**: C
- **Source**: auto (analysis of spec structural elements)
- **Next command**: `orchestrator:discuss` then `orchestrator:roadmap`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 14 |
| Functional requirements | 15 |
| Success criteria | 10 |
| Constraints | 5 |
| Non-goals | 5 |
| Open questions (deferred to planning) | 7 |
| Estimated SDD flows | 3 |

## Reasoning

This feature decomposes naturally into three distinct SDD flows that cannot share a single context window or planning pass:

1. **Reference-corpus ingest layer** (US-1, US-4, FR-1..FR-4, FR-9..FR-11) — defines the new `reference/` chunk family, taxonomy, provenance frontmatter, idempotent re-ingest, and supersede chain. Self-contained against the existing knowledge tree; touches `knowledge/reference/**` and a new ingest command. Independent verification (SC-1, SC-2, SC-5, SC-6).

2. **Graph + dispatch integration** (US-2, US-3, FR-5..FR-8, FR-15) — extends the graph schema with three new edge types (`cites` / `derived_from` / `applies_to_field`), adds the `[source:...]` tag namespace, and wires reference-chunk injection into the dispatch context-builder under a token-budget governor. Touches the context recipe, scope-filter, traverse-graph, and the dispatch pipeline. Backwards-compat is a hard gate (SC-7) requiring its own golden-baseline harness.

3. **Wiki projection + adapter seam** (US-5, US-6, FR-12..FR-14) — surfaces the corpus through MkDocs and registers the format-adapter dispatch table with stub PDF/XLS adapters. Distinct surface (wiki nav generator) and distinct testing convention (rendered HTML / nav YAML asserts).

Each of these flows requires its own clarify → plan → tasks → implement cycle. Cross-flow coordination is non-trivial (the ingest layer's edge-type emissions must match the schema declaration the graph integration extends; the wiki projection consumes both the chunk shape and the edge graph). The seven Open Questions enumerate load-bearing ambiguities that must be resolved before plan-phase begins (table-storage shape, relevance-ordering signal, versioning model, fidelity-gate posture, milestone-slot timing, dependency calls on M013/M014, tag-namespace policy).

The 2026-05-15 PBJ Analyzer validator pilot window establishes a hard external deadline for the minimal slice (US-1 + US-2 + US-3); roadmap decomposition must defend that window with a tight phase ordering. This is exactly the cross-phase coordination Tier C exists for.

## Complexity Factors

- **Cross-cutting schema change**: adding three edge types touches the graph SSOT, the traverser, scope-filter, and the wiki nav generator simultaneously. The minimum-delta-to-current-architecture default (Open Question #Q-4 — same file shape as spec chunks) keeps blast radius contained, but the planner must still verify each consumer.
- **Backwards-compat gate as hard constraint**: CON-1 + FR-15 + SC-7 require a golden-baseline diff harness (M030 SC-11 shape) for the dispatch payload. This is a non-trivial test investment that must land in the same flow as the dispatch integration.
- **External deadline (2026-05-15)**: PBJ validator pilot. Drives milestone-slot placement (Open Question #Q-1 — own milestone (M036) vs M020.1 vs deferred-post-launch); roadmap-time decision.
- **Token-budget governor algorithm undecided**: Open Question #Q-2 names four candidate signals (declared priority / BFS-distance / recency / hybrid). Plan-phase research required.
- **Markdown-floor dependency on consumer project**: A-1 + A-2 — the upstream extraction layer is owned by the PBJ Analyzer project, not this orchestrator. Milestone schedule must reconcile against the consumer's floor-delivery schedule.
- **Five explicit Non-Goals constrain scope**: vector retrieval, NotebookLM, binary storage, auto-extraction, LLM-rewrite-during-ingest. Plan-phase must respect these as hard scope boundaries.
- **Adapter seam design under Principle XIV**: Stub adapters (FR-13) are the minimum required to declare the seam without speculative implementation. Plan-phase decides exactly what registration table and what stub exit shape.

## Provisional Milestone Slot

This evaluation provisionally assigns **M036**, the next sequential milestone ID after the closed M030 and the queued M031–M035. Open Question #Q-1 in the spec defers final slot resolution to `orchestrator:roadmap`:

- **(a) Own milestone M036** — recommended path given the cross-cutting nature, the 2026-05-15 deadline, and the seven open questions worth a dedicated roadmap deliberation. Requires explicit launch-posture decision (post-launch fast-follow vs. pre-launch insertion).
- **(b) M020.1** — would require re-opening a closed milestone; not idiomatic for this project.
- **(c) Deferred post-launch** — safest re-launch posture but punts on the consumer's deadline.

The roadmap step should commit to one of these and update CLAUDE.md / milestone-summary.md accordingly.

---
schema_version: "1.0"
type: evaluation
milestone: "M020"
feature_ref: "025-knowledge-layer-maturation"
feature_spec: "specs/025-knowledge-layer-maturation/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-23"
metrics_source: "raw_spec"
---

# M020 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: orchestrator:discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 14 |
| Functional requirements | 10 |
| Estimated SDD flows | 3+ |

Counts were taken from the raw spec body (`specs/025-knowledge-layer-maturation/spec.md`); spec 025 has not been ingested via `orchestrator:ingest`, so `spec-metrics.sh`'s chunk output (which reflects prior-ingested specs, not spec 025) was not used.

## Reasoning

Spec 025 (M020 — Knowledge Layer Maturation) is unambiguously Tier C:

- **Multiple SDD flows required**: the spec delivers four distinct affordances — a dispatch-callable query surface (US-1), a candidate→graduate review workflow extending the minimal graduate.sh guard (US-2), review-queue surfacing in `orchestrator:status` (US-3), plus Jaccard clustering in consolidate (US-4) and a preferences layer with precedence (US-5). Each affordance carries its own surface, schema touchpoints, and verification gates; they cannot all fit in a single SDD flow.
- **Cross-phase coordination**: the spec explicitly holds schema authority over `knowledge/spec/**` and `knowledge/**/MEM*.md` (FR-9, Knowledge-Layer Boundary section) on behalf of downstream milestones ([M024](../../milestones/M024/index.md) universal intake, [M019](../../milestones/M019/index.md) Tier 2+3 observability, [M018](../../milestones/M018/index.md) context compression). This boundary requires roadmap decomposition so schema-evolution changes land in the correct phase.
- **Autonomous dispatch appropriate**: the Minimal Slice (US-1 + US-2 + US-3) closes the dogfood loop; subsequent user stories layer on top. Full orchestrator machinery (autonomous mode, crash recovery, knowledge consolidation) is appropriate to manage the phased delivery.
- **Complex dependency graph**: the spec depends on [M012](../../milestones/M012/index.md) (closed — spec wiki), M019 Tier 1 (closed — observability emitter), [M021](../../milestones/M021/index.md) (closed — shape-guard), and a pre-M020 minimum-viable `graduate.sh` subset (per D011/D013). Downstream consumers span M024, M019 Tier 2+3, M018, and M009.

## Complexity Factors

- **Schema authority**: M020 owns `knowledge/**` frontmatter evolution during its lifetime. Any field change, vocabulary change, or structural change lands via a D-row + a schema-evolution note. This is a load-bearing governance commitment that touches multiple downstream milestones.
- **Review-workflow semantics**: the candidate → graduate → archived state machine with cluster-level operations and decision-history append is non-trivial; multiple fixtures + acceptance scenarios (see SC-1..SC-8) gate its correctness.
- **Jaccard clustering**: introduces an algorithmic concern (feature vector, threshold) whose defaults are pinned (threshold 0.7 per A-5; feature vector = title + topic + tags[] + first-paragraph-50-tokens per CON-5) but whose validation lands at M020/P01 kickoff against live knowledge entries.
- **Dispatch-read-only invariant**: FR-8 + CON-1 + NG-2 enforce that dispatches consume the query surface without mutation; this constraint crosscuts multiple phases and must be regression-tested.
- **Gate-deferred upstream dependency**: spec 025's conversus Pass 3 gate is deferred pending upstream conversus PRs #28 + #29; evaluate proceeds per D019 infrastructure-blocked exception, with a re-gate expected once the PRs merge.

## Next Steps

Per Tier C classification, the next orchestrator command is **`orchestrator:discuss`** (run in this same handoff as Task D). Discuss produces a `M020-CONTEXT.md` that gates `orchestrator:roadmap`. Roadmap is explicitly out of scope for this session.

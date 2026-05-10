---
schema_version: "1.0"
type: d011-evaluation
milestone: "M012"
phase: "P02"
decision: "D011"
---

# D011 Mechanical Evaluation — M012/P02 close

Per [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 and [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md)
AD-1, this evaluation counts how many of D011's three criteria M012 ships.
The count is mechanical: it does not reassess the decision, it records the
outcome of the decision-in-effect.

## Criteria

| # | Criterion | Shipped in M012? | Evidence |
|---|-----------|------------------|----------|
| a | Cross-refs to `knowledge/**/MEM*.md` | **Yes** | M012/P02/T01 (scanner extension) + M012/P02/T02 (stub + nav generation) + M012/P02/T03 (link checker validates resolution). Rendered wiki resolves `knowledge/<cat>/MEM###.md` file-path references to rendered stub routes; see `wiki/README.md` "Link resolution" section. |
| b | Reviewed/unreviewed state per page | **No** | Explicitly deferred to [M020](../../../../milestones/M020/index.md) per AD-1 (speculative complexity for a dogfood wiki — Constitution XIV). No review-state UI, metadata, or workflow ships in M012. |
| c | Dispatch-callable query surface | **No** | Explicitly deferred to M020 per AD-1. The wiki is a read-only rendering surface; no programmatic query API, no MCP/CLI query tool, no index-as-service. |

## Outcome

**1 of 3 criteria shipped → M020 promoted** per D011's trigger rule
(≤ 1 of 3 → promote as a committed milestone). Status: M020 promoted.

## Downstream implication

Post-M012 the roadmap is updated to position M020 between [M014](../../../../milestones/M014/index.md) and [M019](../../../../milestones/M019/index.md)
Tier 2/3, per D011's framing (see [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 for the
positioning rationale). That roadmap update is NOT part of M012/P02 —
M012's phase closes with this record emitted; the roadmap adjustment is a
consolidation-time action (`speckit.orchestrator.consolidate` on M012
close, or whenever the roadmap is next regenerated).

## References

- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) — D011 (trigger rule + criteria definitions).
- [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md) — AD-1 (criteria selection rationale).
- [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — cross-cutting-concern bullet committing this evaluation to P02.
- `.orchestrator/milestones/M012/phases/P02/P02-PLAN.md` — D011-EVALUATION artifact listed in Artifacts and Key Links.

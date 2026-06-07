---
schema_version: "1.0"
type: evaluation
milestone: "M034"
feature_ref: "044-interactive-review-gates"
feature_spec: "specs/044-interactive-review-gates/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-06-06"
---

# M034 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: /orchestrator-discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 11 |
| Functional requirements | 15 |
| Estimated SDD flows | 4 |

`metrics_source: raw_spec` (spec not ingested; counts taken from the authored spec).

## Reasoning

M034 is unambiguously Tier C — multiple complete SDD flows requiring roadmap
decomposition, cross-phase coordination, and a real dependency graph:

- **Four phases with hard dependencies.** P00 (decision-packet schema + conversus
  producer) is the shared contract; P01 (CC interactive walkthrough → REVIEW.md →
  SIGNOFF) depends on P00's schema; P02 (auto-mode policies + headless QUESTIONS.md
  fallback + boundary-translation packet type) layers on P01; P03 (Cursor MCP
  review-gate server) is gated on #Q-5 (server lifecycle) and depends on the
  runtime-routing seam. This is not a single linear flow — each phase is its own
  SDD cycle with distinct verification.
- **Net-new architecture.** A versioned schema, a new lifecycle stage
  (`interactive-review.sh`), three per-runtime renderers routed through
  `dispatch-interface.sh`, and a standalone stdio MCP server — net-new surfaces
  spanning the dispatch, lifecycle, and packaging layers.
- **Cross-phase coordination is load-bearing.** 6 binding pre-planning conditions
  (PC-1..PC-6) from the conversus gate cut across phases; P00 carries two P0
  conditions (PC-1 calling convention, PC-2 CC execution-context) that gate P01.
- **Boundary maps required.** Consolidates M009 FR-6/FR-8 and touches the
  M014/M025/M029/M033/conversus seams; the M034↔M038/M040 knowledge-layer boundary
  is explicitly drawn in the spec.

A single-context (Tier A) or single-flow (Tier B) classification cannot carry the
roadmap decomposition, autonomous dispatch, and crash-recovery this milestone needs.

## Complexity Factors

- New decision-packet schema as a shared contract consumed by every downstream story.
- A standalone MCP server (FR-10) with its own lifecycle question (#Q-5 → P03).
- Multi-runtime renderer parity (CC AskUserQuestion / Cursor MCP elicitation /
  headless QUESTIONS.md) routed uniformly through `dispatch-interface.sh`.
- Conversus-as-producer integration with a strict-when-declared failure mode (PC-2
  / FR-12) and an external OSS dependency on the dogfooder's machine.
- Two P0 pre-planning conditions (PC-1, PC-2) that block P00→P01, including the
  RISK-5 CC interactive-vs-headless execution-context determination requiring
  inspection of `scripts/dispatch/adapters/backend/cc.sh`.
- Demand-driven by a live Cursor dogfooder testing both interactive and headless,
  so both the interactive (MCP) and headless (fallback) paths are load-bearing.

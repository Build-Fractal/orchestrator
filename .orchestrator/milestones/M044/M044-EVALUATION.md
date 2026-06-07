---
schema_version: "1.0"
type: evaluation
milestone: "M044"
feature_ref: "045-knowledge-activation-reliability"
feature_spec: "specs/045-knowledge-activation-reliability/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-06-07T01:08:32Z"
metrics_source: "raw_spec"
---

# M044 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: orchestrator:roadmap

> Tier C confirmed. The spec is conversus-validated and gate-shaped; its design questions (DQ-1…DQ-8) are resolved and binding (CON-1). The Tier C discussion gate is satisfied by the upstream brief's 16-agent cooperative deliberation (`.orchestrator/conversus/knowledge-activation/summary/final.md`) — no fresh `orchestrator:discuss` context draft is required for the P0 slice. Roadmap may proceed directly.

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 15 |
| Functional requirements | 10 |
| Estimated SDD flows | 2+ |

> Counts are from the raw spec (`metrics_source: raw_spec`; spec not yet ingested). User stories US-1…US-5. FRs: FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-8 (G-1 slice), FR-9 (enforcement-warning half), FR-11, FR-15 (the P0 membership set; FR-7/FR-10/FR-12/FR-13/FR-14 are forward-pointed P1/M040-track Non-Goals). Acceptance scenarios: US-1(3) + US-2(3) + US-3(4) + US-4(3) + US-5(2) = 15. Success criteria SC-1…SC-12 (12).

## Reasoning

M044 is Tier C — multiple coordinated SDD flows requiring roadmap decomposition, a dependency graph, and boundary maps. The P0 hotfix slice spans **five distinct subsystems** that cannot be planned or built in a single context window:

1. **Producer/consumer format contract** (FR-1/FR-2) — unify `append-decision.sh`/`append-knowledge.sh` with `scope-filter.sh` `filter_decisions`/`filter_knowledge` + the compression `kf_filter_stream`; locked by a byte-asserted round-trip oracle (AC-1/SC-1).
2. **Resilient rebuild** (FR-3/FR-4) — per-entry skip-and-warn in `rebuild-index.sh`, a bounded unguarded-command audit, and the scoped archive glob in two sites (`resolve-entries.sh`, `rebuild-index.sh`).
3. **Fail-loud consumer + index-free fallback** (FR-5/FR-11) — `build-context.sh` degradation WARNING + provenance header + grep-over-raw fallback (budget-bounded via the M036a governor) + a canonical `get_index_path`/`get_db_path` resolver.
4. **Capture-by-default** (FR-6/FR-8 G-1 slice) — Quick-intensity explicit-decision capture + a bounded Decisions digest in the Quick inject, shipped in one change set.
5. **Fail-loud observability** (FR-9 enforcement-warning half / FR-15) — 0-MEM-on-mature-project warning + a single consolidated `orchestrator:doctor` check reconciling `papercut-doctor-knowledge-gap-surface.md`.

The cross-subsystem dependencies are real: FR-1's canonical format is the contract the FR-3 rebuild must keep readable, the FR-5 fallback consumes, and the FR-8 capture writes; FR-15's observable inject surface is a build-prerequisite for the AC-1 round-trip oracle. The intra-P0 build sequence (alarm first → BUG-A + capture) is itself a dependency ordering that demands roadmap-level coordination. Five user stories, ten FRs, fifteen acceptance scenarios, and twelve success criteria all exceed the Tier B single-flow ceiling.

## Complexity Factors

- **Cross-cutting contract** — FR-1's canonical decision/knowledge format is consumed by the rebuild, the consumer fallback, and the capture write; a change to it ripples across ≥4 scripts and must be locked by a CI round-trip oracle (three-shape reconciliation: producer / consumer-comment / consumer-awk).
- **Binding upstream resolutions** — DQ-1…DQ-8 (CON-1) and the Principle-I budget guardrail (CON-2) constrain the solution space; the planner must honor them rather than re-deriving.
- **Determinism on the guarantee path** (CON-3) — grep fallback + corpus-gate evidence artifact must be byte-reproducible (`LC_ALL=C`, stable order, no wall-clock in artifact bodies).
- **Surgical-precision edits** (CON-4) — FR-4 drops only the bare `*/archive/*` false-match while preserving the genuine `knowledge/archive/` cold-storage exclusion (`rebuild-index.sh:6`).
- **Reconcile-not-duplicate** (CON-5) — FR-15's doctor check must fold `papercut-doctor-knowledge-gap-surface.md` into one consolidated surface, not add a second.
- **Plan-time open questions** — four (#Q-1 canonical column order + migration posture; #Q-2 stale-detection mechanism; #Q-3 doctor reconcile-vs-supersede; #Q-4 provenance-header version field) resolve at plan-phase against the live dogfood corpus.
- **Read-into-payload budget governance** — every FR-5/FR-6 payload-read path routes through the M036a token governor (consumed read-only); capture-write (disk) is free/unbudgeted.

---
schema_version: "1.0"
type: evaluation
milestone: "M042"
feature_ref: "042-corpus-exhaustion-gate"
feature_spec: "specs/042-corpus-exhaustion-gate/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-30T00:00:00Z"
metrics_source: "raw_spec"
---

# M042 Evaluation

## Classification

- **Tier**: C
- **Source**: auto (analysis)
- **Next command**: /orchestrator-roadmap

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 14 |
| Functional requirements | 14 |
| Estimated SDD flows | 1 (multi-phase) |

## Reasoning

The corpus-exhaustion gate is a reusable cross-cutting capability: a new deterministic sweep engine + gate adapter + artifact contract (P01), pre-finalize hooks into six existing commands + a doctor lint (P02), an LLM semantic judge with auto-resolve (P03), and telemetry (P04). The work spans distinct implementation units that each fit their own context window — the engine, the adapter, the config + docs, the per-command hooks, the judge, and the telemetry record dispatch separately. It modifies the finalization flow of six commands and introduces a contract (the store manifest + artifact format) that downstream projects depend on, which is what pushes it to Tier C rather than B: the manifest is a versioned contract, and the gate participates in multiple commands' state transitions.

The bounded core (P01) is the load-bearing slice and ships independently with zero LLM cost — it is the deterministic grep sweep + read-before-ask enforcement. P03 (the judge) and P04 (telemetry) are demand-driven and carry an unresolved absorption decision with M040 (#Q-1); they are roadmapped but not built in the initial pass.

Estimated 4 phases: (P01) deterministic gate engine + adapter + artifact + config + docs + acceptance battery; (P02) six caller pre-finalize hooks + doctor lint; (P03) batched LLM judge + auto-resolve under conversus fidelity shape; (P04) telemetry over the M019 stream. Linear dependency chain — each phase builds on the prior phase's contract.

## Complexity Factors

- **Downstream contract**: the store manifest + artifact frontmatter format is consumed by every project that opts in — versioned, must stay stable. Addressed by FR-3/FR-5 and the bundled default manifest.
- **Cross-command modification**: six existing commands gain a pre-finalize gate step (P02) — each a documented finalization-section addition mapping BLOCK to a pause, low risk individually, coordinated as one phase.
- **Graceful degradation across broken indexes**: real downstream signal — a project's `knowledge.db` rebuild has been broken since 2026-05-07. CON-3/CON-6 require fall-back-to-grep with a recorded caveat, never a silent skip or a deadlock.
- **LLM judge cost + correctness**: P03 batches one call per packet (CON-5) and must guard the false-negative class (#Q-3) where a wrongly-`ANSWERED` question is hidden from the human.
- **M040 overlap**: P03's two-agent-sweep + PASS|BLOCK + human-gated-apply plumbing overlaps M040's decision-contradiction gate; the absorption decision (#Q-1) is deferred to queue-entry and does not block P01/P02.

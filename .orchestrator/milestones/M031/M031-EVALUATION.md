---
schema_version: "1.0"
type: evaluation
milestone: "M031"
feature_ref: "034-right-sized-entry"
feature_spec: "specs/034-right-sized-entry/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-01"
metrics_source: "raw_spec"
---

# M031 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 4 |
| Acceptance scenarios | 12 |
| Functional requirements | 19 |
| Estimated SDD flows | 4–5 (P00 empirical baseline + ≥4 implementation phases + verification) |

Additional shape:
- Non-goals: 8
- Constraints: 7
- Success Criteria: 14
- Open Questions: 19 (8 original + 11 gate-deferred mitigations)

## Reasoning

M031 (right-sized entry) is a Tier C milestone. Three independent factors converge on this classification:

1. **Functional-requirement count (19 FRs)** is well above the Tier B ceiling. Tier B is "one SDD flow, multiple contexts, 2–5 phases"; M031's 19 FRs span four distinct functional clusters (knowledge-unconditional FR-1..5, Tier A+ middle flow FR-6..9, universal entry FR-10..13, drift-fix + observability FR-14..19) plus a P00 empirical-gate flow that gates the first cluster's merge.

2. **Cross-phase dependency graph requires roadmap decomposition.** US1 + US4 form the load-bearing minimal slice; US2 builds on US1 (each Tier A+ dispatch must inject knowledge per US1) and US3 builds on US1 + US2 (universal entry routes to Tier A+ as one destination). The minimal-slice + sequential-dependency shape is exactly the case the orchestrator's roadmap surface was designed to coordinate.

3. **Empirical-gate phase (P00) precedes implementation merges per CON-5.** The proposal explicitly carries a P00 empirical-baseline phase whose output (a 20-task fixture corpus + JSONL comparison) gates FR-1/2/3 merge. P00 is itself an SDD flow (specify the corpus shape → plan the harness → implement → verify the hypothesis); its outcome blocks downstream phases. This is the "multiple distinct SDD cycles" shape Tier C is defined for.

The Standard-intensity adversarial gate (`conversus.sh gate spec-pressure-test`) returned BLOCK with 5 P0 spec amendments deferred to discuss; addressing those amendments is itself part of the discuss-phase work and increases (not decreases) the multi-flow shape. The arbiter's verdict was "proceed with conditions" — core architecture survived intact (traversal-aggressiveness dial, M024 reuse, three-dispatch Tier A+ shape, CON-5 empirical gate); the conditions are prose-level amendments wired into discuss/roadmap/P00.

## Complexity Factors

- **Constitutional load-bearing claim** (Principle I + VII). M031 fixes a misread of Principle I (Context Minimization = total task tokens, not payload bytes) that today violates Principle VII (Knowledge Compounds) for every Quick dispatch. The empirical gate (CON-5 + SC-11) is the constitutional safeguard; it must be designed correctly before implementation can ship.
- **Cross-milestone interface contract** (MIT-04 / `--meta-out` sidecar). `build-context.sh` metadata is consumed by M031, M029 (where renderer), and M036 (reference-corpus ingest). The interface decision belongs at M031 because it is the first author; deferring fragments three milestones.
- **Strict scope guardrails** (NG-1..8 + SC-12 scope-guard verifier). M031's diff must touch zero of: knowledge/** schema, scripts/cost/, scripts/dispatch/adapters/router/, scripts/auto/loop/. Tier C orchestration is what enforces this mechanically.
- **Existing-project backward-compat** (FR-16 `auto_proceed` flip + RISK-10 compound-change communication). The flip changes behavior on first post-M031 dispatch for implicit-default operators; comms strategy (MIT-11) needs roadmap-level decision.
- **CC-only launch posture** (CON-6). Codex CLI / Cursor parity defers to M009 post-launch. The acceptance battery and verifier scripts must be POSIX-bash so M009 can extend without rewrite.
- **Composes with M030 + M033 + M029** as part of the pre-launch sequence. M033 lands the user; M031 keeps them productive on small tasks; M029 renders Tier A+ flows. Roadmap decisions need to surface the integration boundaries.

## Integration With Existing Milestones (informational)

- **M020 (knowledge layer maturation, closed)** — provides the graph + indexer M031 consumes; no schema changes.
- **M018 (context compression layer, closed)** — provides tier-1 + tier-2 compression M031 ensures applies to Quick payloads.
- **M024 (universal intake & routing, closed)** — provides the input-shape classifier M031 extends with `tier_a_plus`.
- **M027 (cost+quality observability, closed)** — JSONL stream + efficiency-footer; M031's new `payload_breakdown` records flow into existing surfaces.
- **M030 (adaptive model selection, closed 2026-05-01)** — composes on Tier A+ dispatches (Sonnet/Haiku defaults).
- **M028 (autonomous hardening v3, closed 2026-04-29)** — hook portability + shape-guard inherited.

## Recommended Next Command

`orchestrator:discuss` — M031 is Tier C; the discussion gate must produce a context draft that captures (a) operator decisions on the 5 P0 gate-deferred amendments, (b) Q-1 through Q-8 architectural decisions surfaced in the spec, (c) explicit naming choice for the universal entry surface (verbless vs. `:do`), and (d) approval-flow conventions for Tier A+. Once the context draft is finalized, `orchestrator:roadmap` decomposes the work into phases and `orchestrator:plan-phase P00` kicks off the empirical-baseline phase.

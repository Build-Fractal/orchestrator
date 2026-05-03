---
schema_version: "1.0"
type: evaluation
milestone: "M033"
feature_ref: "036-project-onboarding-experience"
feature_spec: "specs/036-project-onboarding-experience/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-03"
metrics_source: "raw_spec"
discuss_required: true
paired_with: "M032"
---

# M033 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss`

## Metrics (raw_spec)

| Metric | Count |
|--------|-------|
| User stories | 8 |
| Acceptance scenarios | ~40 (averaging ~5 per story) |
| Functional requirements | 23 (22 original + FR-23 added per MIT-003) |
| Success criteria | 17 |
| Constraints | 6 |
| Non-goals | 16 |
| Open questions | 11 (10 original + #Q-11 added per MIT-005) |
| Folded mitigations | 7 (MIT-001..MIT-007) |

## Reasoning

M033 (project onboarding experience) is unambiguously a Tier C milestone. Three independent factors converge on this classification:

1. **Functional-requirement count (23 FRs) and user-story count (8) span a four-branch decision tree.** Tier B is "one SDD flow"; M033 has at least four parallel sub-flows (greenfield-empty / greenfield-with-materials / existing-codebase / migrating) plus a friendly-tester gate that is itself a phase-spanning empirical protocol. The minimal slice (US-1 + US-2) is itself two new commands (`orchestrator:start` + `orchestrator:constitution`); subsequent stories add three more new commands (`orchestrator:ingest-codebase`, `orchestrator:materials-intake`, `orchestrator:ideation`, `orchestrator:customblock-draft`).

2. **Paired-launch coordination with M032 (CON-1) requires roadmap-level decomposition with explicit per-phase coordination.** M033/P05 invokes M032's `--with-wiki` gate; M033's grilling-shell writes inline into M032's `wiki/glossary.md`; SC-9 has explicit two-mode (P01..P04 stub / P05 real) acceptance contract per MIT-001. The integration testing cadence across the three load-bearing seams cannot fit a single phase.

3. **Friendly-tester pass (US-8 / SC-15 / FR-19) is the load-bearing gate the launch sequencing amendment makes non-negotiable for milestone close.** This is empirical work (recruiting 1–2 outsiders, 30 minutes each, structured friction capture, validate-report.sh mechanical gate) that runs in parallel with implementation phases and gates milestone close — exactly the multi-flow shape Tier C is defined for.

## Complexity Factors

- **Distribution surface integrity (Principle XVI, pending amendment)**: M033 is the *first content-authoring* compliance test for Principle XVI (M032 was the asset-distribution test). FR-6's standalone-gate verifier is the mechanical enforcement; CON-3 makes the invariant explicit. Zero `speckit.*` dependencies in any M033-shipped surface.
- **Cross-milestone interface contract with M032 (CON-1 three load-bearing seams)**: shared install-bundle surface, `--with-wiki` failure-propagation contract (FR-15 ↔ M032 FR-11), `wiki/glossary.md` format. Bidirectional pairing — neither milestone closes without the other's surface stable.
- **Cold-start UX risk (CON-2)**: cannot be dogfooded against this repo (which is not a cold start); synthetic test fixtures are weak signal. The friendly-tester pass on the four init branches is the only adequate validation; SC-15 codifies the gate.
- **Grilling-protocol shell as reusable architectural surface (FR-17)**: a single uniform `ask_one` API consumed by FR-3, FR-9, FR-10, FR-13. Sequential-never-batched is a hard architectural invariant (CON-5). The wiring of `partial-answers.yml` as `[<context-file>]` for live contradiction detection (per MIT-007) is the load-bearing seam between FR-10 and FR-17.
- **Knowledge-layer boundary spanning M020 / M031 / M032 / M033**: FR-7 writes into M020's existing knowledge-graph kinds (no new kinds); FR-7 + FR-8 produce MEMs that M031's `build-context.sh --profile=quick` consumes; FR-18 writes inline into M032's `wiki/glossary.md`. Four-way boundary documented explicitly in the spec.
- **CC-only launch posture (NG-equivalent)**: M033's interactive flows (FR-3 / FR-9 / FR-10 / FR-13) inherit M030's adaptive model routing for surgical-character tasks; M030's closure is a hard upstream dependency.
- **Conversus gate verdict was BLOCK with 7 surviving disputes (P0+6×P1 mitigations folded as MIT-001..MIT-007)**: all amendments are spec-text (no architectural redesign), but they distribute work across phases — MIT-001 (P0) blocks P01 planning lock; MIT-003 fixture creation is a P01 deliverable; MIT-007 contradiction-detection wiring blocks P02 lock. Phase-distributed mitigation work is itself a Tier C signal.

## Integration With Existing Milestones (informational)

- **M032 (wiki distribution, paired-pre-launch)** — bidirectional dependency per CON-1. Three load-bearing seams. Spec 035 just promoted to Ready-for-discuss (2026-05-03).
- **M031 (right-sized entry, closed 2026-05-01)** — provides the universal `orchestrator <task>` entry that consumes the knowledge graph FR-7 seeds. SC-3 verifies the seeded graph is consumable via `build-context.sh --profile=quick`.
- **M030 (adaptive model selection, closed 2026-05-01)** — provides routing for surgical-character tasks (FR-3 / FR-9 / FR-10 / FR-13).
- **M020 (knowledge layer maturation, closed 2026-04-25)** — provides the knowledge-kind taxonomy that FR-7 / FR-8 write into.
- **M015 (standalone cutover, closed)** — provides `orchestrator:migrate --from <kind>` that FR-11 pre-fills the flag for.
- **M013 (GitHub native integration, closed)** — provides `orchestrator:github-init` that FR-16 pass-throughs to.
- **M014 / spec 035 dual-write Recent Changes contract** — FR-21 inherits the dual-write helper.
- **M027 / M019 observability infrastructure** — FR-22's structured records consume the existing JSONL append + cost-rollup consumers.

## Recommended Next Command

`orchestrator:discuss` — M033 is Tier C; the discussion gate must produce a context draft that captures (a) the M032+M033 paired-launch coordination model (three load-bearing seams) — coherent with M032's discuss output, (b) the friendly-tester pass recruiting plan + by-when (Open Question #Q-1, launch sequencing amendment) — explicit pre-roadmap requirement, (c) the 11 Open Questions resolution pass (especially #Q-1 friendly-tester recruiting, #Q-9 fixture-vs-real-project, #Q-10 paired-launch integration cadence, #Q-11 sentinel path convention), (d) the RISK-006 arbiter ruling confirmation that the disambiguation-question implementation extension is within P01 scope, (e) phase placement of MIT-003 fixture creation (P01 deliverable, not P04) and MIT-006 disambiguation-question implementation (P01 deliverable). Once the context draft is finalized, `orchestrator:roadmap` decomposes the work into phases.

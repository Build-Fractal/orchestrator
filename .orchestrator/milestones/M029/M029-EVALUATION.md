---
schema_version: "1.0"
type: evaluation
milestone: "M029"
feature_ref: "037-roadmap-visibility-cli-ux"
feature_spec: "specs/037-roadmap-visibility-cli-ux/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-05T19:36:41Z"
metrics_source: "raw_spec"
---

# M029 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 6 |
| Acceptance scenarios | 12 |
| Functional requirements | 14 |
| Estimated SDD flows | 3+ (P01 resolver+headline, P02 at-rest tree+cost column, P03 live-tail+preflight+`--auto-chain`) |

`metrics_source: raw_spec` — `scripts/state/spec-metrics.sh` reports `spec_chunks_present=true` but the chunk counts (3 stories / 0 FRs / 10 acceptance) reflect a stale prior ingest, not this spec. Counts above are derived from direct read of `specs/037-roadmap-visibility-cli-ux/spec.md`.

## Reasoning

The spec describes a multi-phase rendering / composition milestone with clearly staggered priority tiers and a substantial planning surface that cannot fit in a single SDD flow:

- **Phase decomposition is explicit in the brief**: P01 ships the invocation-context resolver + the `orchestrator:status` headline + `--format=json`; P02 ships the at-rest `orchestrator:where` tree renderer with the M027-sourced cost column + graceful pre-M019 degradation; P03 ships `--live` tail mode + the compression-savings marker + the auto preflight summary + `--auto-chain` on `orchestrator:start`. Each phase has its own design contracts (`references/status-headline-shape.md`, `references/status-json-schema.md`), fixtures (`tests/m029-acceptance/fixtures/where-mixed-state.golden`), and acceptance battery slice — Tier B's "one SDD flow, multiple contexts" shape cannot absorb that without losing the per-phase verification cadence M027/M028's cost+autonomy-hardening track depends on.
- **Cross-phase coordination required**: FR-1's resolver is load-bearing for FR-2/FR-3/FR-5/FR-7 (single-resolve discipline per Principle XI). FR-7's live-tail consumes FR-5's at-rest tree. FR-9's preflight consumes M027's `predictive-surface.sh` output that FR-5 already wires for the cost column. Boundary maps + dependency ordering across phases are required to keep the resolver from being re-implemented per surface.
- **Conversus Pass-3 gate emitted advisory BLOCK with 11 surviving disputes**: 5 P0 items (#Q-G1 through #Q-G5: FR-9 non-interactive behavior, SC-8 oracle interface verification, FR-3 ANSI-in-JSON policy, FR-8 5% threshold rationale, FR-13 cross-milestone data model) deferred to `orchestrator:discuss`; 4 P1 items (#Q-G6 through #Q-G9) deferred to plan-phase. Tier C's mandatory `orchestrator:discuss` gate is exactly the surface designed to absorb that load before roadmap decomposition.
- **Read-only-discipline guard (CON-1, SC-14) and anti-coupling guard (FR-11/FR-12, SC-13)** require cross-phase invariants enforced by an acceptance battery (SC-11) — the kind of milestone-grain validation Tier C's `validate-milestone.sh` + `M029-VALIDATED` marker discipline is built for.
- **Downstream-consumer load-bearing**: M035 ships `--format=json` as a post-install verification surface; `external-tool-adapters` (post-launch) consumes the schema. Schema-versioning policy (#Q-4) has cross-milestone reach. Tier C's milestone-summary + consolidation cadence is the right place to track the schema as a stable public contract.

The combination of multi-phase decomposition, cross-phase resolver dependency, conversus-gate P0/P1 backlog requiring discuss-phase resolution, and milestone-grain acceptance battery puts this clearly into Tier C territory.

## Complexity Factors

- **Multi-phase decomposition implicit in spec**: The brief ships P01/P02/P03 as named phases with distinct deliverables, design contracts, and fixtures. Roadmap decomposition is required.
- **Single-resolve invariant (FR-1) crosses every phase**: Every command rendered by M029 reads `detect-invocation-context.sh`'s output. Cross-phase boundary discipline.
- **Five P0 disputes deferred to `orchestrator:discuss`**: #Q-G1..#Q-G5 must resolve before roadmap. Tier C's discuss gate is mandatory; Tier B has no such gate.
- **Pre-M019 / pre-M027 graceful-degradation invariants (FR-6 / CON-3)**: Cross-version compatibility surface that needs explicit fixture coverage in the acceptance battery.
- **Read-only discipline + anti-coupling guards (CON-1, FR-11, FR-12, SC-13, SC-14)**: Milestone-grain invariants enforceable only via the M029 acceptance battery (SC-11).
- **Public-contract schema work (`references/status-json-schema.md` per #Q-4)**: Schema versioning is a contract for M035 packaging + post-launch `external-tool-adapters`. Long-lived surface; needs Tier C's consolidation cadence.
- **Compression-savings 5% threshold (FR-8) requires evidence resolution (#Q-G4)**: Either cite measurement, annotate as heuristic with review trigger, or make config-knob-driven. Discuss-phase decision.
- **Live-tail latency methodology (#Q-G9, SC-7) deferred to P03 planning**: Measurement harness + percentile + retry policy not yet defined. Plan-phase responsibility.
- **Cross-milestone feature-grouping (FR-13, #Q-G5)**: Data-model decision (frontmatter vs. parent-field reverse-lookup vs. external manifest) carries the load-bearing structure for any feature-spans-milestones rendering. Discuss-phase decision.

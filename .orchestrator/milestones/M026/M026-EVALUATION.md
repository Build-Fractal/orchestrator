---
schema_version: "1.0"
type: evaluation
milestone: "M026"
feature_ref: "027-conversus-oss-migration"
feature_spec: "specs/027-conversus-oss-migration/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-23"
metrics_source: "raw_spec"
---

# M026 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss` (Tier C gate before roadmap)

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 15 |
| Functional requirements | 13 |
| Estimated SDD flows | 2+ |

## Reasoning

This migration classifies as Tier C — Multiple SDD Flows, Full Orchestration — for five
load-bearing reasons that compound:

1. **Cross-repo touchpoints**. The work spans three repos at the boundary: this
   orchestrator, `~/Sites/conversus-oss` (OSS), and `~/Sites/conversus` (paid). Each is
   read-only from M026, but the orchestrator's contract with each is load-bearing and
   must be verified (parity matrix, FR-9) across at least two SDD cycles — one for the
   audit, one for the implementation + regression test — to guard the invariants that
   M011/M013/M014 and future M018/M023/M024 consumers depend on.

2. **Multi-affordance scope**. Five distinct user stories (US-1 resolver-flip,
   US-2 edition env var + escape hatch, US-3 parity audit + pass-through invariants,
   US-4 edition-aware diagnostics, US-5 doc updates across six surfaces) cannot
   reasonably fit in a single context window or a single SDD flow. The Minimal Slice
   pins US-1+US-2+US-3 as Phase 1 load-bearing; US-4+US-5 layer on as a second SDD
   cycle.

3. **Rollback concerns + cross-cut with in-flight specs**. Five open questions
   (#OQ-1..#OQ-5) touch on-flight work: spec 025 (M020) `Ready-for-discuss-gate-deferred`
   state, spec 026 (M014 three-pass shell) sequencing, upstream PR #28/#29 status in OSS,
   pipx venv path drift, and mechanical paid-detection rule depth. Each requires
   operator decision at discuss-finalize. A Tier B "one SDD flow" posture cannot
   reconcile that many external decision points without discussion gating.

4. **Dependency graph + boundary map required**. Six doc surfaces must be kept in sync;
   the adapter shares invariants with five production callers; the JSONL `edition` field
   lands additively and is consumed by M019 Tier 2+3 rollups downstream. Tier C's
   roadmap decomposition with phase-level boundary maps is the right shape.

5. **Constitution III (Design Before Code) + XV (Surgical Precision) load**. The
   resolver-order edit is ~10 lines of bash but the design work around it — parity
   matrix, invariant preservation, escape-hatch discovery surface, edition-aware
   diagnostics — is non-trivial and must land before code per the spec's own Constitution
   Check. That's the shape Tier C's `discuss → roadmap → plan-phase → dispatch` flow
   exists for.

SDD flow count: at minimum 2 (audit + implementation). Plausibly 3 if US-4's
edition-aware diagnostics and US-5's doc updates split into their own phase during
roadmap decomposition. D016's forward roadmap puts committed milestones at Tier C by
convention; this migration follows that convention.

## Complexity Factors

Five factors above Tier B's ceiling:

- **5 user stories × 13 FRs × 15 acceptance scenarios** — counts alone exceed the Tier B
  "one SDD flow fits multiple contexts" envelope. Tier C's roadmap+phase decomposition is
  the right shape.
- **Cross-repo read-only coupling** to two external trees (`~/Sites/conversus-oss`,
  `~/Sites/conversus`) whose divergence the parity matrix (FR-9) exists to quantify. This
  is a multi-SDD-cycle investigation.
- **Five load-bearing invariants preserved** (CON-1..CON-5). Each is a cross-milestone
  contract (M011 adapter, M013 UAT gate, M014 three-pass, D019 TODO pre-flight, bash
  3.2 compat). Landing any of them wrong corrupts ≥3 downstream phases.
- **Eight open questions** (#OQ-1..#OQ-8) — above the Tier C discuss-gate threshold
  where operator review is required before roadmap decomposition.
- **Seven downstream consumers** (DC-1..DC-7) including the active in-flight specs 025
  and 026, plus future M018/M019/M023/M024 work. The dependency graph is not linear.

## Metrics Source

`metrics_source: raw_spec` — spec 027 has not been ingested into knowledge chunks; counts
are from regex against the authored spec body.

## Cross-Cutting Notes

- **D016 slotting**: this milestone (M026) was not in the D016 forward-roadmap framing.
  The spec proposes slotting it BEFORE spec 026's M014 shell-impl phase (i.e., before
  the next M014 extended phase lands), based on #OQ-2's Option A recommendation. That
  proposal is an Open Question for discuss-finalize — the operator makes the final
  sequencing call.
- **D019 preservation**: M026 must not touch the TODO pre-flight, the `--strict` flag
  semantics, or the 0/1/2 exit-code contract. CON-1 + FR-5 + FR-6 + FR-7 are the
  explicit commitments.
- **In-flight specs**: 025 (M020 knowledge-layer, `Ready-for-discuss-gate-deferred`)
  and 026 (M014 three-pass shell impl, Draft) have open assumptions this migration
  could invalidate. Noted in spec's Open Questions; not modified by M026.

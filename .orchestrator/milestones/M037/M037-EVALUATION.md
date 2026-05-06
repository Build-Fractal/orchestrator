---
schema_version: "1.0"
type: evaluation
milestone: "M037"
feature_ref: "038-wiki-team-feedback-ready"
feature_spec: "specs/038-wiki-team-feedback-ready/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-06"
metrics_source: "raw_spec"
---

# M037 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `/orchestrator-discuss`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 9 |
| Acceptance scenarios | 36 |
| Functional requirements | 15 |
| Estimated SDD flows | 2 |

(Counts derived from raw spec; `spec-metrics.sh` returned stale chunks from a previously ingested spec — `metrics_source: raw_spec` recorded.)

## Reasoning

M037 is unambiguously Tier C — multiple SDD flows with explicit phase decomposition and cross-phase coordination:

- **Two phases declared in the spec itself** — P01 (US-1..US-5: ship-it minimum, the load-bearing slice US-1+US-2+US-4 plus US-3+US-5 sharing template-territory cost) and P02 (US-6..US-9: round-3.5 polish, gated on first PBJ feedback signal per #Q-6).
- **P02 entry is signal-gated, not calendar-gated** — the spec defers bucket-mapping (US-6), knowledge-card config shape (US-8), and section-shape choices to a real-world feedback loop. That is multi-flow orchestration: each phase needs its own context, planning, dispatch, and verification cycle, separated by an external signal.
- **Planning-artifact gates inside FR-10 (DISP-1, arbiter-ruled)** — planning must produce a managed-key namespace list as an explicit cross-referenced artifact before implementation, with operator-confirmation flagging for any consumer-config-collision keys. This is the kind of pre-implementation decision-packet work that requires a dedicated planning unit.
- **Cross-phase coupling** — P02's US-6 (tag-driven nav subgrouping) composes with P01's US-2 (`version:` → nav title), and US-8's card grid reuses US-1's template. This is a dependency graph, not a flat task list.
- **Hard upstream dependencies on M032 (closed 2026-05-05) and M036a (closed 2026-05-02)** — M037 reads chunk frontmatter shapes (`version:`, `topic_tags:`, `external_pointer:`) produced by M036a's pipeline and modifies the install-template / wiki-tooling surfaces shipped by M032. Multiple constraints (CON-1..CON-4) govern the touch radius.
- **Conversus arbitration already shaped the spec** — MIT-01..MIT-03 P0 mitigations and DISP-1 planning gate were folded post-arbiter-resolution. The spec presupposes a discuss → roadmap → plan-phase chain capable of carrying these as explicit artifacts.

## Complexity Factors

- **9 user stories across 2 phases** with a declared minimal-slice (US-1+US-2+US-4) and ride-along stories (US-3, US-5) sharing template-territory.
- **15 functional requirements** spanning template-emit logic, projection-time transforms, install-template merge semantics, and authoring-convention promotion.
- **12 success criteria** including a `BATTERY: pass=N fail=0` aggregator (SC-12) and live-consumer evidence capture (SC-11 PBJ-central `orchestrator:update` survival).
- **4 hard constraints**: CON-1 (zero-new-plugin-deps in P01), CON-2 (projection-not-source-mutation), CON-3 (operator-authored-keys-survive — referenced by FR-9's MIT-03 P0 back-reference), CON-4 (default-branch-fallback-to-main).
- **7 open questions** explicitly deferred to planning, including #Q-3 (consumer-project rollout strategy for DR-### heading-shape), #Q-4 (clobber-fix-scope across template files), and #Q-6 (P02 trigger-condition + knowledge-card config shape).
- **Pre-launch urgency** — jumps queue ahead of M035 because PBJ-central is the live dogfood signal for the entire orchestrator process and opens the wiki this week; wiki noise would contaminate the validation loop.
- **Knowledge-layer boundary discipline** — explicit "M037 vs. M020/M036a" boundary section enumerates what M037 claims vs. what it must not touch (chunk schema, edge-type catalogue, tier-0/1/2 extraction adapters).

Tier C activates the full orchestrator: discuss → roadmap → plan-phase per phase → autonomous/manual dispatch → verify → consolidate, with crash recovery and milestone-grain `unit_close` reporting.

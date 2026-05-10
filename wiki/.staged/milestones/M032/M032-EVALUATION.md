---
schema_version: "1.0"
type: evaluation
milestone: "M032"
feature_ref: "035-wiki-distribution-init-integration"
feature_spec: "specs/035-wiki-distribution-init-integration/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-05-03"
metrics_source: "raw_spec"
discuss_required: true
---

# M032 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss`

## Metrics (raw_spec)

| Metric | Count |
|--------|-------|
| User stories | 8 |
| Acceptance scenarios | ~30 (averaging ~4 per story) |
| Functional requirements | 22 |
| Success criteria | 14 |
| Constraints | 6 |
| Non-goals | 12 |
| Open questions | 6 (5 resolved at clarify 2026-05-03 + 1 deferred per NG-11) |

## Reasoning

M032 (wiki distribution + init integration) is unambiguously a Tier C milestone. Three independent factors converge on this classification:

1. **Functional-requirement count (22 FRs) and user-story count (8) are well above Tier B ceilings.** Tier B is "one SDD flow, multiple contexts, 2–5 phases"; M032's 22 FRs span four distinct functional clusters: (a) managed bundle infrastructure FR-1..FR-4; (b) wiki-init command + scopes FR-5..FR-12; (c) wiki tooling extensions FR-13..FR-20; (d) collision invariant + fixture discipline FR-21..FR-22.

2. **Paired-launch coordination with [M033](../../milestones/M033/index.md) (CON-3) requires roadmap-level decomposition.** The 2026-05-03 launch sequencing amendment makes M032+M033 a single workstream with three load-bearing seams (shared install-bundle surface, `--with-wiki` failure-propagation contract, `wiki/glossary.md` format). Continuous integration testing across the seams cannot be a single phase — it requires per-phase coordination with M033.

3. **The 11 conversus-mitigation amendments (MIT-001..MIT-011) carry phase-distributed work.** SC-12's three-category battery format, FR-22's dual-oracle hierarchy, FR-9's read-before-write Pages guard, FR-14's non-empty-legacy-content branch, and the FR-6 self-application gate all touch different phases of the implementation; the milestone close discipline (SC-12 `skip=0`, SC-14's signed-attestation gate) is itself phase-spanning.

## Complexity Factors

- **Distribution surface integrity (Principle XVI, pending amendment)**: M032 is the *first* milestone exercising Invariants 2 (force-include discipline) and 3 (end-to-end install testing) against a project-local-asset surface, not user-global skills/hooks. The bundle-shape decision is constitutionally load-bearing.
- **CON-4 byte-identical migration discipline**: every existing consumer's first post-M032 install must produce byte-identical output — the [M025](../../milestones/M025/index.md) pinned-sha gate extended to project-asset surface. Bootstrapping policy for pre-M032 consumers (FR-2 / MIT-006) is the load-bearing test of this discipline.
- **CON-5 live-fixture-discipline**: FR-21 mandates a live throwaway GH repo for the deploy end-to-end test, the explicit M013/[M014](../../milestones/M014/index.md) counter-pattern. SC-5 + SC-12 + SC-13 + SC-14 form the milestone-close gate that closes the M013/M014 verification-skip failure mode.
- **CON-6 glossary-load-bearing-for-M033**: FR-15 + FR-16 (glossary path convention + adapter) MUST land in M032 because M033's grilling protocol commits to writing inline as terms resolve. Cross-milestone interface contract that cannot defer.
- **CC-only launch posture (CON-1)**: Codex CLI / Cursor pass-through is in-scope at the bundle/install layer (FR-2 covers all three installers); live `--deploy` testing exercises only the CC path; multi-runtime parity defers to M009 post-launch.
- **POSIX-only symlink mode (NG-9 / FR-3)**: Windows fails closed; aligns with CC-only posture.

## Integration With Existing Milestones (informational)

- **M025 (installer coexistence, closed 2026-04-23)** — provides the user-global skills/hooks pinned-sha gate that FR-2's project-asset migration extends.
- **[M020](../../milestones/M020/index.md) (knowledge layer maturation, closed 2026-04-25)** — provides the knowledge-kind taxonomy that FR-16's `lookup-mems.sh --kind=glossary` adapter binds against.
- **[M031](../../milestones/M031/index.md) (right-sized entry, closed 2026-05-01)** — provides the Quick/Standard/Full profile contract that FR-16's glossary adapter respects.
- **[M030](../../milestones/M030/index.md) (adaptive model selection, closed 2026-05-01)** — milestone-close discipline (acceptance battery + `validate-milestone.sh` + signed attestation) is the precedent SC-12 + SC-13 + SC-14 model against.
- **[M013](../../milestones/M013/index.md) (GitHub native integration, closed)** — `--with-github-integration` future flag (FR-13) consumes the same `--with-<feature>` flag pattern.
- **M033 (project onboarding experience, paired-pre-launch)** — invokes `--with-wiki` from M033/P05 (CON-3); writes inline into `wiki/glossary.md` from M033's grilling protocol.

## Recommended Next Command

`orchestrator:discuss` — M032 is Tier C; the discussion gate must produce a context draft that captures (a) the M032+M033 paired-launch coordination model (three load-bearing seams: shared install-bundle, `--with-wiki` failure-propagation, glossary format), (b) the integration-testing cadence across the seams (M033 spec #Q-10), (c) the 5 spec-clarify-resolved Open Questions (#Q-1..#Q-5) re-confirmation, (d) the FR-6 self-application gate scheduling within paired phases. Once the context draft is finalized, `orchestrator:roadmap` decomposes the work into phases.

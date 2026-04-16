---
schema_version: "1.0"
type: evaluation
milestone: "M015"
feature_ref: "015-standalone-cutover"
feature_spec: "specs/015-standalone-cutover/spec.md"
tier: "C"
tier_source: "override"
created_at: "2026-04-15T00:00:00Z"
---

# M015 Evaluation

## Classification

- **Tier**: C (overridden from auto-classified Tier B)
- **Source**: override
- **Next command**: speckit.orchestrator.auto

## Tier Override Note

Auto-classification (2026-04-15) returned Tier B based on scope criteria — single SDD flow, ~4 sequential phases, no complex dependency graph. The tier was manually overridden to C the same day to unlock `orchestrator-auto` autonomous execution mode, which is gated to Tier C only per FR-054 (enforced in `find-active-milestone.sh:77` and `commands/auto.md` step 3).

The override preserves all existing planning artifacts (roadmap, P01 plan, T01–T04 task plans). Tier C normally requires a finalized context draft before roadmap generation, but that gate fires before roadmap generation — since the roadmap already exists, the gate is not re-crossed.

The Tier C autonomous machinery (loop, crash recovery, knowledge consolidation pipeline) is slightly over-specified for a 4-task linear cutover, but it is non-harmful — the loop iterates four times and exits at milestone completion.

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 18 |
| Functional requirements | 19 |
| Estimated SDD flows | 1 |

## Reasoning

M015 (Standalone Cutover) is a single cohesive feature: remove the spec-kit extension host, reframe documentation, migrate state from `.specify/orchestrator/` to `.orchestrator/`, and validate end-to-end. Decomposes into ~4 sequential phases (host removal → docs reframe → state migration → end-to-end validation), each of which fits its own context window but is too large to share one. This is the textbook Tier B shape: one SDD flow, multi-context, sequential phases, developer-driven transitions.

Not Tier A: the work clearly spans multiple contexts and multiple discrete deliverables — host removal, docs, state migration, and validation are independently verifiable units.

Not Tier C: there are no multiple distinct SDD cycles, no complex dependency graph requiring autonomous scheduling, no cross-phase coordination beyond simple sequencing. The phases form a strict linear chain (P01 → P02 → P03 → P04) with one validation gate at the end.

## Complexity Factors

- **Single-direction migration**: Hard cutover with no rollback feature flag (per M007 no-graceful-degradation rule). Lowers complexity at the design level (no dual code paths) but raises the bar for end-to-end validation in P04.
- **Two distinct removal surfaces**: Spec-kit-as-host (extension.yml, hooks, dogfooded slash commands, spec-kit templates/scripts) is removed entirely; spec-kit-as-migration-source (`scripts/migrate/adapters/speckit.sh` and friends) is preserved. The cutover must not conflate these — a meaningful complexity factor that justifies P03/P04 separation.
- **State move includes constitution**: `.specify/memory/constitution.md` moves to `.orchestrator/memory/constitution.md` and is referenced by multiple commands and references — touch surface is broader than a typical state move.
- **Resolver edit drops a rule**: `scripts/state/resolve-root.sh` rule 4 (the `.specify/orchestrator/` bridge) is removed, requiring careful renumbering and verification that rules 1–3 and the former rule 5 still produce the same resolution semantics.
- **Test fixtures need disposition decisions**: `scripts/verify/m002-p07-extension-registration.sh` and `tests/fixtures/verify-{pass,fail}/extension.yml` either delete or rewrite — judgment call inside the cutover.
- **Documentation reframe spans 6 files**: README, CLAUDE.md, and 4 reference/getting-started docs. Mechanical but breadth requires a dedicated phase.
- **Pre-req validation already satisfied**: M003 P07/P08 ran end-to-end via `orchestrator-auto` in Claude Code native mode, confirming the standalone runtime works. Removes a major risk that would otherwise warrant Tier C.

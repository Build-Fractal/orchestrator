---
schema_version: "1.0"
type: roadmap
milestone: "M998"
feature_ref: "037-roadmap-visibility-cli-ux"
tier: "C"
created_at: "2026-05-05"
---

# M998 — SC-5 Mixed-State Fixture Milestone

This is a synthetic milestone tree used only by
`tests/m029-acceptance/p02-sc5-where-mixed-state.sh` to exercise the FR-5
at-rest tree renderer (`scripts/diagnostics/render-position.sh`) against a
deterministic, byte-stable fixture covering all four glyph states
(`✓ ▶ ◇ ✗`). It is NOT a real milestone — do not import its content into
KNOWLEDGE.md or surface it in operator-facing tooling.

The fixture mimics the orchestrator state-shape that
`scripts/state/find-active-milestone.sh`, `read-roadmap.sh`, and
`render-position.sh` probe: a roadmap at the milestone root, four phases
spanning all four glyph states (✓/▶/✗/◇), and a synthetic execution-log
carrying M019 Tier 1 `dispatch_usage` records so the per-row cost column
is populated for the in-flight phase, plus a `verify_result` record with
`result: fail` for P03 so the renderer derives P03 as `✗`.

## Phases

- [x] **P01**: Completed phase — has P01-SUMMARY.md → renders as `✓`.
- [ ] **P02**: In-flight phase — no P02-SUMMARY.md, four tasks → renders
      as `▶`. Tasks include one ✓ (T01-x has SUMMARY) and three ▶ (T02-y,
      T03-z, T04-w each have PLAN only).
- [ ] **P03**: Failed phase — execution-log carries a `verify_result`
      record with `result: fail` for P03 → renders as `✗`.
- [ ] **P04**: Pending phase — empty directory (no PLAN, no tasks) →
      renders as `◇`.

## Notes

- Tier C — fixture mirrors the canonical M029 tier so any tier-aware code
  paths exercise the same branch as the production rendering.
- Execution-log timestamps are pinned at `2026-05-05T20:00:00Z` so the
  `timestamp-strip.sh` (#Q-G6) normalizer produces a reproducible
  byte-stable golden across runs.
- Cost values in `dispatch_usage` records are pinned constants
  (`estimated_cost_usd: 0.018`) so the per-row cost cell is deterministic.

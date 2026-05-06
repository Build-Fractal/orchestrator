---
schema_version: "1.0"
type: roadmap
milestone: "M998"
feature_ref: "037-roadmap-visibility-cli-ux"
tier: "C"
created_at: "2026-05-06"
---

# M998 — SC-8 Auto-Preflight Standard Fixture Milestone

Synthetic milestone tree used only by
`tests/m029-acceptance/p03-sc8-auto-preflight.sh` to exercise the FR-9
documented preflight contract surface against a deterministic fixture.
Not a real milestone — do not import into KNOWLEDGE.md or surface in
operator-facing tooling.

## Phases

- [x] **P01**: Completed phase — has P01-SUMMARY.md so `summarize-milestone.sh`
      emits `phases_complete=1`.
- [ ] **P02**: Pending phase — empty directory, no PLAN, no tasks. Counted
      in `phase_count` but not `phases_complete`.
- [ ] **P03**: Pending phase — empty directory. Counted in `phase_count`
      but not `phases_complete`.

## Notes

- Tier C — fixture mirrors the canonical M029 tier so any tier-aware code
  paths exercise the same branch as the production rendering.
- `intensity: standard` declared in EVALUATION frontmatter so the SC-8
  Quick-vs-Standard contract surface is exercisable.
- `execution-log.jsonl` carries M019 Tier 1 `dispatch_usage` records so
  M027's cost-rollup has data to consume (not strictly required by SC-8
  but mirrors the where-mixed-state.fixture shape).

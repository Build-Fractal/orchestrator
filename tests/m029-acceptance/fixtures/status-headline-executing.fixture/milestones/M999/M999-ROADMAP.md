---
schema_version: "1.0"
type: roadmap
milestone: "M999"
feature_ref: "999-m029-p01-status-fixture"
tier: "C"
created_at: "2026-05-05"
---

# M999 — SC-2 Headline Fixture Milestone

This is a synthetic milestone tree used only by `tests/m029-acceptance/p01-sc2-headline.sh`
to exercise the FR-2 status headline block against a deterministic, byte-stable
fixture. It is NOT a real milestone — do not import its content into KNOWLEDGE.md
or surface it in operator-facing tooling.

The fixture mimics the orchestrator state-shape that `derive-phase.sh`,
`read-roadmap.sh`, and `find-active-milestone.sh` probe: roadmap at the
milestone root, one completed phase with a P##-SUMMARY.md, one in-flight
phase without a summary. The execution log carries one valid M019 Tier 1
`dispatch_usage` record + one `unit_close` record so the embedded
M027 efficiency footer has data to roll up.

## Phases

- [x] **P01**: Completed phase — "Has P01-SUMMARY.md so derive-phase.sh sees this as complete."
- [ ] **P02**: In-flight phase — "No P02-SUMMARY.md, so the milestone derives to executing state."

## Notes

- Tier C — fixture mirrors the canonical M029 tier so any tier-aware code paths
  exercise the same branch as the production headline rendering.
- The execution log timestamp is fixed at `2026-05-05T20:00:00Z` so the
  `last_dispatch` recency token in the headline regex is reproducible across
  test runs (the SC-2 script computes recency relative to a frozen reference
  time when the env var is set, otherwise falls back to actual `now - timestamp`).

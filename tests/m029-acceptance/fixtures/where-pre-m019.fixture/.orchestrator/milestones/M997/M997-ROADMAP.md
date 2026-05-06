---
schema_version: "1.0"
type: roadmap
milestone: "M997"
feature_ref: "037-roadmap-visibility-cli-ux"
tier: "C"
created_at: "2026-05-05"
---

# M997 — SC-6 Pre-M019 Fixture Milestone

This is a synthetic milestone tree used only by
`tests/m029-acceptance/p02-sc6-where-pre-m019.sh` to exercise FR-6 / CON-3
graceful degradation: a milestone with NO execution-log.jsonl (or an
empty one) simulates a milestone that pre-dates M019 Tier 1 emission.

The renderer MUST omit the per-row cost column entirely (no blank column,
no `cost=` token) AND emit nothing on stderr when rendering this fixture.

It is NOT a real milestone — do not import its content into KNOWLEDGE.md
or surface it in operator-facing tooling.

## Phases

- [x] **P01**: Completed phase — has P01-SUMMARY.md → renders as `✓`.

## Notes

- No `execution-log.jsonl` is shipped with this fixture; `_rp_has_m019_tier1`
  returns 1 (not present), and `_rp_cost_column` returns the empty string,
  silently suppressing the cost column.
- Tier C — fixture mirrors the canonical M029 tier.

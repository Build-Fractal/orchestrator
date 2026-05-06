---
schema_version: "1.0"
type: roadmap
milestone: "M999"
feature_ref: "999-m029-p01-status-json-fixture"
tier: "C"
created_at: "2026-05-05"
---

# M999 — SC-3 JSON Fixture Milestone

This is a synthetic milestone tree used only by `tests/m029-acceptance/p01-sc3-format-json.sh`
to exercise the FR-3 `--format=json` renderer (`scripts/diagnostics/render-status-json.sh`)
against a deterministic, byte-stable fixture. It is NOT a real milestone — do not
import its content into KNOWLEDGE.md or surface it in operator-facing tooling.

The fixture mirrors the SC-2 fixture in shape: roadmap at the milestone root, one
completed phase with a P##-SUMMARY.md, one in-flight phase without a summary. The
execution log carries one valid M019 Tier 1 `dispatch_usage` record + one `unit_close`
record so the JSON renderer's headline-field collection has data to populate.

This is the SC-3 happy-path fixture. The companion `status-json-degraded.fixture/`
carries an intentionally-corrupt execution-log.jsonl so the renderer can exercise
the AD-2 degraded-state envelope.

## Phases

- [x] **P01**: Completed phase — "Has P01-SUMMARY.md so derive-phase.sh sees this as complete."
- [ ] **P02**: In-flight phase — "No P02-SUMMARY.md, so the milestone derives to executing state."

## Notes

- Tier C — fixture mirrors the canonical M029 tier so any tier-aware code paths
  exercise the same branch as the production JSON rendering.
- The execution log timestamp is fixed at `2026-05-05T20:00:00Z` so the renderer's
  `last_dispatch_recency` field is deterministic relative to a frozen reference
  time.

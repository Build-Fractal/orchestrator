---
schema_version: "1.0"
type: roadmap
milestone: "M999"
feature_ref: "999-m029-p01-status-json-degraded-fixture"
tier: "C"
created_at: "2026-05-05"
---

# M999 — SC-3 Degraded-State JSON Fixture Milestone

This is a synthetic milestone tree used only by `tests/m029-acceptance/p01-sc3-format-json.sh`
to exercise the FR-3 / AD-2 degraded-state envelope of the JSON renderer
(`scripts/diagnostics/render-status-json.sh`). It is NOT a real milestone — do not
import its content into KNOWLEDGE.md.

The companion `status-json-executing.fixture/` exercises the happy path. This
fixture mixes valid + intentionally-corrupt JSONL lines so the renderer can
extract partial data AND emit `state: "degraded"` with a `parse_errors` array
populated by line number.

## Phases

- [x] **P01**: Completed phase
- [ ] **P02**: In-flight phase

## Notes

- Tier C — same as the happy-path fixture.
- The execution log carries deliberately-malformed lines mixed with valid
  records. Detail in `execution-log.jsonl` (the renderer reads it line-by-line
  and reports invalid lines via `parse_errors`).

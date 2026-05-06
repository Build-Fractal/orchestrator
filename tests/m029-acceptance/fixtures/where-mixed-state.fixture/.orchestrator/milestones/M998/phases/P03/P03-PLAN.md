---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M998"
---

# P03 — Failed Fixture Phase

Synthetic phase plan used only by the SC-5 mixed-state fixture. Paired
with a `verify_result` record in the milestone's execution-log.jsonl that
carries `phase: P03` + `result: fail`, driving the renderer's
`_rp_phase_glyph` to return `✗` for this phase.

No tasks subdir, so the renderer does not emit any task rows beneath this
phase line.

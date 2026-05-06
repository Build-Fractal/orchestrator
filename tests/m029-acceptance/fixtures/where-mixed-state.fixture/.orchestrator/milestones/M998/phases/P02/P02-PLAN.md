---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M998"
---

# P02 — In-flight Fixture Phase

Synthetic phase plan used only by the SC-5 mixed-state fixture. Carries
four tasks designed to exercise the renderer's per-row task glyph logic
inside an in-flight (▶) phase:

- T01-x: ✓ — PLAN + SUMMARY both present.
- T02-y: ▶ — PLAN present, no SUMMARY.
- T03-z: ▶ — PLAN present, no SUMMARY.
- T04-w: ▶ — PLAN present, no SUMMARY.

The renderer's `_rp_phase_glyph` returns `▶` for P02 because P02-SUMMARY.md
is absent and P02-PLAN.md (this file) is present.

The four task rows appear under P02 because the renderer expands tasks
ONLY for in-flight (▶) phases (FR-13 active-only-task-rows behavior).

---
schema_version: "1.0"
type: evaluation
milestone: "M996"
feature_ref: "037-roadmap-visibility-cli-ux"
intensity: "quick"
tier: "C"
tier_source: "auto"
created_at: "2026-05-06"
---

# M996 — SC-9 Quick-Intensity Fixture Evaluation

Synthetic evaluation document used only by the SC-9 auto-preflight
quick-intensity fixture. Carries `intensity: quick` so
`summarize-milestone.sh` emits `intensity=quick`. Carries
`feature_ref: 037-roadmap-visibility-cli-ux` so the renderer's reverse-
lookup advisory associates this fixture milestone with the M029 spec.

The Quick-intensity assertion lives at the documented contract surface
in `commands/auto.md` ("Quick intensity suppresses the block —
`Preflight Summary` does NOT appear on stderr before `AUTO:READY`"). This
fixture's job: provide a milestone tree the renderer + summarize can
read without crashing, with `intensity=quick` rendered in the output, so
SC-9 can negative-assert the documented invariant against a real fixture
shape.

No real evaluation was performed.

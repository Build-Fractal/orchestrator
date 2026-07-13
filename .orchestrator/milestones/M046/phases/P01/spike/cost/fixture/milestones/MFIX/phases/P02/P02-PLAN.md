---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "MFIX"
name: "Fixture phase two"
---

# P02 — Fixture phase two (throwaway cadence-probe fixture)

One trivial task. For this phase the stub also seeds one clearly-labeled
SYNTHETIC dispatch_usage record carrying estimated_cost_usd, so the probe
observes both unit_close cost shapes: null (P01, pure stub) and non-null
(P02, upstream telemetry present).

## Must-Haves

### Truths

- The fixture task summary exists after the stub dispatch.
  - Check: `true`

### Artifacts

- .orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/phases/P02/tasks/T01-SUMMARY.md

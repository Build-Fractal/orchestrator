---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "MFIX"
name: "Fixture phase one"
---

# P01 — Fixture phase one (throwaway cadence-probe fixture)

One trivial task. The dispatch stub in drive-segment.sh writes the task
summary via the real write-summary.sh, which is the production unit_close
emission path under measurement.

## Must-Haves

### Truths

- The fixture task summary exists after the stub dispatch.
  - Check: `true`

### Artifacts

- .orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/phases/P01/tasks/T01-SUMMARY.md

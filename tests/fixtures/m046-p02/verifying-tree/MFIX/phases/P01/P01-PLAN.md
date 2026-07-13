---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "MFIX"
name: "Fixture phase"
---

# P01 — Fixture phase (throwaway M046/P02 marker fixture)

One trivial task, already complete (T01-SUMMARY.md checked in). With no
P01-VERIFICATION.md and no P01-SUMMARY.md the derived state is
verifying/summarizing, which drives auto-loop.sh to the
`AUTO:PHASE_COMPLETE phase=P01` / exit-0 leg the P02 verifiers pin.

## Must-Haves

### Truths

- The fixture task summary exists.
  - Check: `true`

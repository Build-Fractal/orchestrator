---
schema_version: "1.0"
type: roadmap
milestone: MFIX
tier: C
---

# MFIX Roadmap — M046/P02 marker-mechanism fixture (throwaway)

Synthetic 1-phase milestone for the M046/P02 outcome-marker verifiers.
The active phase P01 has all task summaries present but no P01-SUMMARY.md,
so derive-phase.sh yields verifying/summarizing and auto-loop.sh emits
`AUTO:PHASE_COMPLETE phase=P01` with exit 0. Verifiers ALWAYS run against
scratch copies of this tree (auto-loop mutates milestone trees); never run
auto-loop.sh against this checked-in copy.

## Phases

- [ ] **P01**: Fixture phase — "fixture demo"
  - Risk: low
  - Depends: none

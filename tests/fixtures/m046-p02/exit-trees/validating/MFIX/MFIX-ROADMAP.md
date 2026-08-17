---
schema_version: "1.0"
type: roadmap
milestone: MFIX
tier: C
---

# MFIX Roadmap — M046/P02 exit-battery `validating` fixture (throwaway)

Synthetic 1-phase milestone for the SC-9 exit battery. P01 is checked AND
phases/P01/P01-SUMMARY.md exists (roadmap↔disk consistent, so the drift
guard passes), no MFIX-VALIDATED marker exists, so derive-phase.sh yields
`validating` and auto-loop.sh emits `AUTO:MILESTONE_VALIDATING` with
exit 0 → marker `validating`. Verifiers ALWAYS run against scratch copies.

## Phases

- [x] **P01**: Fixture phase — "fixture demo"
  - Risk: low
  - Depends: none

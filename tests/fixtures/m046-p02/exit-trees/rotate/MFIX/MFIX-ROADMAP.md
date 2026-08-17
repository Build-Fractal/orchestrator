---
schema_version: "1.0"
type: roadmap
milestone: MFIX
tier: C
---

# MFIX Roadmap — M046/P02 exit-battery `rotate` fixture (throwaway)

Synthetic 1-phase milestone for the SC-9 exit battery. Driven with
`--step=X` (context check). The sibling orchestrator.lock (at
MILESTONE_DIR/../orchestrator.lock) carries startedAt=2020-01-01 so all
three outcome-bearing execution-log records count toward session weight
(weight=3). The battery sets SPECKIT_ORCHESTRATOR_SESSION_WEIGHT_LIMIT=1
(read-config's layer-1 env override), so context-monitor.sh reports
CONTEXT:ROTATE → exit 14 → marker `rotation P01` (phase resolved from this
roadmap's active phase). Verifiers ALWAYS run against scratch copies.

## Phases

- [ ] **P01**: Fixture phase — "fixture demo"
  - Risk: low
  - Depends: none

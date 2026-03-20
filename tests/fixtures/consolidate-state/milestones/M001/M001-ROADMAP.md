---
milestone: M001
feature_ref: "001-test-consolidation"
tier: C
---

## Phases

- [x] **P01**: Foundation Phase — "Extension foundation complete"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml, scripts/setup.sh
    - Consumes: none

- [x] **P02**: State Machine Phase — "State derivation complete"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/derive-phase.sh
    - Consumes: P01/extension.yml

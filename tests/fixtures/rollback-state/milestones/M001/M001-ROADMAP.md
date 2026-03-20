---
milestone: M001
feature_ref: "001-test-feature"
tier: C
---

## Phases

- [x] **P01**: Foundation Phase — "Extension foundation is installed and working"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml, scripts/setup.sh
    - Consumes: none

- [ ] **P02**: Dependent Phase — "Depends on P01 for state derivation"
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/derive-phase.sh
    - Consumes: P01/extension.yml

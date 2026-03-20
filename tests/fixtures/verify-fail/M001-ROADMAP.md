---
milestone: M001
feature_ref: "001-speckit-orchestrator"
tier: C
---

## Phases

- [ ] **P01**: Extension Foundation — "Developer can install the extension and see all commands registered"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml, scripts/missing-script.sh
    - Consumes: none

- [ ] **P02**: State Machine Core — "Developer can scaffold and see state derivation"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/derive-phase.sh
    - Consumes: P01/extension.yml

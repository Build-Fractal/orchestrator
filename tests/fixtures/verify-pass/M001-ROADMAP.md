---
milestone: M001
feature_ref: "001-speckit-orchestrator"
tier: C
---

## Phases

- [x] **P01**: Extension Foundation — "Developer can install the extension and see all commands registered"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml, scripts/setup.sh
    - Consumes: none

- [ ] **P02**: State Machine Core — "Developer can scaffold and see state derivation"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/derive-phase.sh, scripts/state/read-config.sh
    - Consumes: P01/extension.yml

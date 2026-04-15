---
milestone: M001
feature_ref: "001-speckit-orchestrator"
tier: C
---

## Phases

- [x] **P01**: Orchestrator Foundation — "Developer can read project instructions and derive state from disk"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: CLAUDE.md, scripts/state/derive-phase.sh
    - Consumes: none

- [ ] **P02**: State Machine Core — "Developer can scaffold and see state derivation"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/read-roadmap.sh, scripts/state/read-config.sh
    - Consumes: P01/CLAUDE.md

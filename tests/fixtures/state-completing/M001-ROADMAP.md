---
milestone: M001
feature_ref: "001-speckit-orchestrator"
feature_spec: "specs/001-orchestrator/spec.md"
vision: "Core orchestration engine with state machine, dispatch, and verification"
tier: C
created_at: "2026-03-19T10:00:00Z"
updated_at: "2026-03-19T13:00:00Z"
---

## Phases

- [x] **P01**: Extension Foundation — "Developer can install the extension and see all 10 commands registered"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml (validated manifest), commands/*.md (10 command stubs)
    - Consumes: none

- [x] **P02**: State Machine Core — "Developer can scaffold a milestone and see state derivation working"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/*.sh (derive-phase, read-roadmap, check-lock, read-config)
    - Consumes: P01/extension.yml (command registration)

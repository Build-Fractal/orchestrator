---
phase: P02
milestone: M001
goal: "Implement file-based state machine with 9-state derivation"
demo_sentence: "Developer can scaffold a milestone and see state derivation working"
risk: high
depends_on: [P01]
---

## Must-Haves

### Truths
- derive-phase.sh outputs correct state for all 9 states

### Artifacts
- scripts/state/derive-phase.sh (min 40 lines)

## Tasks

### T01: derive-phase.sh — Core state derivation
Implement 9-state derivation logic.

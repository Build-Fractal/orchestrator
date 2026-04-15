---
phase: P01
milestone: M001
goal: "Set up orchestrator foundation"
demo_sentence: "Developer can read project instructions and derive state from disk"
risk: low
depends_on: []
---

## Must-Haves

### Truths
- CLAUDE.md documents the project layout and key files
  - Check: `grep -q 'Key Files' CLAUDE.md`
- The derive-phase script documents the orchestrator namespace
  - Check: `grep -q 'orchestrator' scripts/state/derive-phase.sh`

### Artifacts
- CLAUDE.md (min 5 lines, contains "Key Files")
- scripts/state/derive-phase.sh (min 3 lines)

### Key Links
- scripts/lifecycle/auto-loop.sh → scripts/state/derive-phase.sh (references state derivation)

## Tasks

### T01: Establish foundation
Document project layout and wire state derivation.

## Files Likely Touched
- CLAUDE.md
- scripts/state/derive-phase.sh

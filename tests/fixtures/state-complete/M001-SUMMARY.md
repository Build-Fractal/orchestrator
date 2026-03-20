---
id: M001
parent: null
milestone: M001
provides:
  - "Speckit orchestrator extension: state machine, dispatch, verification"
key_files:
  - extension.yml
  - scripts/state/derive-phase.sh
key_decisions:
  - "D001: File-presence-based state derivation"
  - "D002: POSIX sh for portability"
patterns_established:
  - "File-presence state derivation at scripts/state/"
drill_down_paths:
  - .specify/orchestrator/milestones/M001/phases/P01/P01-SUMMARY.md
  - .specify/orchestrator/milestones/M001/phases/P02/P02-SUMMARY.md
duration: "2h"
verification_result: pass
completed_at: "2026-03-19T15:00:00Z"
---

# M001: Core Orchestration Engine

Milestone complete — state machine, dispatch pipeline, and verification ladder implemented.

## Phase Rollup

### P01: Extension Foundation
Extension manifest with 10 commands.

### P02: State Machine Core
9-state derivation from file presence.

---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M008"
provides:
  - "detect-speckit.sh — spec-kit presence detection with integration mode toggle"
requires:
  - "none (independent task)"
affects:
  - "P04/T06"
key_files:
  - "scripts/state/detect-speckit.sh"
key_decisions:
  - "none"
patterns_established:
  - "feature-toggle probe — inspects filesystem signals and env to produce integration_mode verdict"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P04/tasks/T02-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-14T16:22:54Z"
---

Created detect-speckit.sh probing for spec-kit presence via .specify/ directory, constitution, and speckit CLI. Emits speckit_installed and integration_mode key=value pairs. Enables P07 init to decide whether to bridge or remain standalone.

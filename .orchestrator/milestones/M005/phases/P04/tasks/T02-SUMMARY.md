---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M005"
provides:
  - "run-doctor.sh wired to run check-instructions.sh conformance check"
requires:
  - "from:P04/T01 what:scripts/diagnostics/check-instructions.sh"
affects:
  - "P04"
key_files:
  - "scripts/diagnostics/run-doctor.sh"
key_decisions:
  - "AD-4"
patterns_established:
  - "none"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P04/tasks/T02-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-13T00:43:57Z"
---

Added run_check call for Instruction Conformance to run-doctor.sh diagnostic sequence, invoking check-instructions.sh.

---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M008"
provides:
  - "intensity-analyze.sh — natural-language task description analyzer producing scope/risk/complexity classification with recommended intensity"
requires:
  - "none (independent task)"
affects:
  - "P01/T03"
key_files:
  - "scripts/engine/intensity-analyze.sh"
key_decisions:
  - "none"
patterns_established:
  - "natural-language scope/risk/complexity pattern matching via keyword tables"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P01/tasks/T02-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-14T14:31:16Z"
---

Created intensity-analyze.sh analyzer. Classifies task descriptions along three axes using keyword pattern matching: scope (trivial/moderate/large), risk_level (low/medium/high), complexity (simple/moderate/complex). Outputs recommended_intensity via decision matrix with risk escalation rule (trivial+high-risk → Standard).

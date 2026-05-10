---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P05"
milestone: "M008"
provides:
  - "speckit.sh — spec-kit format adapter (read-only) mapping tasks.md/plan.md to orchestrator native"
requires:
  - "from:P05/T05 what:native.sh format interface"
affects:
  - "P05/T07"
key_files:
  - "scripts/dispatch/adapters/format/speckit.sh"
key_decisions:
  - "one-directional read — reject --write explicitly to prevent polluting spec-kit artifacts"
patterns_established:
  - "one-directional foreign-format adapter — exits 4 on write attempt; bridges spec-kit to orchestrator native without reverse mapping"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T06-PLAN.md"
duration: "6m"
verification_result: "pass"
completed_at: "2026-04-14T17:13:32Z"
---

Created speckit.sh one-directional format adapter. --probe checks for spec-kit marker files. --read maps tasks.md/plan.md format to orchestrator native task-plan format. --write rejected with exit 4 preserving FR-015 integration-mode-only semantics.

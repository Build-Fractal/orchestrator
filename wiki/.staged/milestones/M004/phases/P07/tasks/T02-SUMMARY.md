---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P07"
milestone: "M004"
provides:
  - "Registration of check-recipe.sh in run-doctor.sh (as non-advisory check) and extension.yml (as executable script)"
requires:
  - "from:P07/T01 what:check-recipe.sh"
affects:
  - "P07/T03 (verification task)"
key_files:
  - "scripts/diagnostics/run-doctor.sh, extension.yml"
key_decisions:
  - "Placed Recipe Conformance after Run ID Coverage and before Task Plan Shape (advisory); marked non-advisory (4th arg 0) since recipe conformance is a structural requirement"
patterns_established:
  - "New diagnostic checks added between last non-advisory check and first advisory check in run-doctor.sh"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P07/tasks/T02-PLAN.md"
duration: "3m"
verification_result: "pass"
completed_at: "2026-04-13T21:21:55Z"
---

Registered check-recipe.sh in two places: (1) run-doctor.sh gained a run_check call for Recipe Conformance at line 112, positioned after Run ID Coverage and before Task Plan Shape, non-advisory so it counts toward the pass/fail score; (2) extension.yml gained a script entry for scripts/diagnostics/check-recipe.sh with executable:true, placed after check-plans.sh. Both grep verifications pass.

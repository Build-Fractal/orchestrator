---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P07"
milestone: "M008"
provides:
  - "P07 Bash 3.2 compat scan (comment-aware) + hermetic-only static gate + full onboarding e2e under 120s budget"
requires:
  - "from:P07/T01 what:detect-project.sh,from:P07/T02 what:project-instruction.md+init.md,from:P07/T03 what:init-project.sh,from:P07/T04 what:reinit-handler.sh"
affects:
  - "M008 completion"
key_files:
  - "scripts/verify/m008-p07-bash32-compat.sh,scripts/verify/m008-p07-hermetic-only.sh,scripts/verify/m008-p07-integration-e2e.sh"
key_decisions:
  - "120-second wall-clock budget enforced in e2e — validates SC-005 (<5min first task) with generous margin"
patterns_established:
  - "end-to-end onboarding test with wall-clock budget enforcement + hermetic-only static gate preventing real-home writes"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P07/tasks/T05-PLAN.md"
duration: "<1m"
verification_result: "pass"
completed_at: "2026-04-14T22:57:11Z"
---

Final M008 task: Bash 3.2 compat scan (comment-aware) + hermetic-only static gate (grep-based check that P07 verifiers only write under mktemp fixtures, never real HOME) + full onboarding end-to-end test. E2E: fresh mktemp project → init-project.sh → verify config.yml + CLAUDE.md + 12 skills installed → reinit --mode update preserves custom section. Wall-clock budget under 120s validates SC-005 (<5min first task). Closes out M008 standalone-orchestrator milestone.

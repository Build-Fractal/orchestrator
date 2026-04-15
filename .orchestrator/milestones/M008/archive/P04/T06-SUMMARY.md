---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P04"
milestone: "M008"
provides:
  - "P04 Bash 3.2 compat scan + hermetic standalone e2e test proving SC-004"
requires:
  - "from:P04/T01 what:resolve-root.sh,from:P04/T02 what:detect-speckit.sh,from:P04/T03 what:config-system.sh,from:P04/T04 what:migrate-state.sh,from:P04/T05 what:derive-phase.sh refactor+namespace-aliases.sh"
affects:
  - "P05/all,P06/all,P07/all"
key_files:
  - "scripts/verify/m008-p04-bash32-compat.sh,scripts/verify/m008-p04-standalone-e2e.sh"
key_decisions:
  - "none"
patterns_established:
  - "hermetic standalone e2e — runs full workflow in mktemp fixture with no spec-kit present, validates SC-004"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P04/tasks/T06-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-14T16:43:33Z"
---

Final P04 task: Bash 3.2 compatibility scan across P04 scripts + hermetic standalone e2e that exercises the full state/config/detect pipeline in a throwaway project directory with no spec-kit present. Validates SC-004 (orchestrator functions standalone) and confirms state lands under .orchestrator/ in fresh standalone projects.

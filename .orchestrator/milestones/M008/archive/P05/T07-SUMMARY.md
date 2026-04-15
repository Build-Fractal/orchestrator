---
schema_version: "1.0"
type: task-summary
id: "T07"
parent: "P05"
milestone: "M008"
provides:
  - "P05 Bash 3.2 compat scanner (comment-aware) + integration e2e across runtime+format+dispatch"
requires:
  - "from:P05/T01 what:detect-runtime.sh,from:P05/T02 what:claude-code.sh,from:P05/T03 what:codex.sh,from:P05/T04 what:cursor.sh,from:P05/T05 what:native.sh,from:P05/T06 what:speckit.sh,from:P02/T05 what:dispatch-interface.sh"
affects:
  - "P06/all,P07/all"
key_files:
  - "scripts/verify/m008-p05-bash32-compat.sh,scripts/verify/m008-p05-integration-e2e.sh"
key_decisions:
  - "compat scanner excludes comment lines — prevents false positives on documented non-use of forbidden constructs"
patterns_established:
  - "comment-aware compat scan pattern — grep -vE '^[[:space:]]*#' to exclude comment lines before forbidden-construct checks"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T07-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-14T17:17:15Z"
---

Final P05 task: Bash 3.2 compatibility scanner (comment-aware to avoid false positives) + integration e2e. E2E flow: detect-runtime → hermetic register → native.sh read → speckit.sh read → dispatch-interface.sh with local-agent backend. Validates FR-006/007/008 across the whole P05 surface.

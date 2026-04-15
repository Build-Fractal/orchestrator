---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P06"
milestone: "M004"
provides:
  - "Fixed PROJECT_ROOT detection in check-must-haves.sh to use root markers (extension.yml/.git) instead of walk-up-to-phases-parent; added engine integration (emit_event VERIFY_START/VERIFY_COMPLETE, emit_result on EXIT trap)"
requires:
  - "from:P02 what:lib/errors.sh and lib/events.sh"
affects:
  - "P06/T05 (verification task)"
key_files:
  - "scripts/verify/check-must-haves.sh"
key_decisions:
  - "Used root marker algorithm (extension.yml or .git) as primary detection with old phases-parent walk-up as fallback for test fixtures without markers; corrected lib path from ../../lib to ../lib matching actual scripts/ directory layout"
patterns_established:
  - "Root marker detection pattern for PROJECT_ROOT; EXIT trap for emit_result; ORCH_RUN_ID guard for standalone safety"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P06/tasks/T01-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-13T19:11:41Z"
---

Fixed the PROJECT_ROOT detection bug where the walk-up-to-phases-parent algorithm resolved to the milestone directory instead of the repo root for real orchestrator phase paths (.specify/orchestrator/milestones/M004/phases/P06/). Replaced with a root-marker algorithm that walks up looking for extension.yml or .git, with the old algorithm as fallback for test fixtures. Added engine integration: sourced lib/errors.sh and lib/events.sh, added EXIT trap for emit_result, emit_event VERIFY_START after plan validation, and VERIFY_COMPLETE before exit. All guarded by ORCH_RUN_ID check for standalone safety. Corrected lib path from ../../lib to ../lib to match the actual directory structure (scripts/verify -> scripts/lib). All three test fixtures (verify-pass, verify-fail, verify-scope) pass. Event/result emission confirmed working with ORCH_RUN_ID set.

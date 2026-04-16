---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "M015/P03"
milestone: "M015"
provides:
  - "ALLOW_P03_DOCS tightened to sentinel __P03_COMPLETE_NEVER_MATCH__; all 7 P03 + P02 sweep + must-haves PASS"
requires:
  - "T02 primary reframe, T03 wider sweep"
affects:
  - "P04 end-to-end validation"
key_files:
  - "scripts/verify/m015-p02-no-stale-state-refs.sh"
key_decisions:
  - "Seal allow-list via never-match sentinel rather than empty string — keeps grep -Ev regex syntactically valid while disabling the tolerance"
patterns_established:
  - "Seal-by-sentinel: when an allow-list regex has served its purpose, replace its body with __NAME_NEVER_MATCH__ so the surrounding negation stays valid but tolerates nothing"
drill_down_paths:
  - ".orchestrator/milestones/M015/phases/P03/tasks/T04-PLAN.md"
duration: "6"
verification_result: "pass"
completed_at: "2026-04-15T17:15:38Z"
---

Swept all 17 previously allow-listed docs for remaining .specify/orchestrator and .specify/memory/constitution references — every file returned 0, so no surgical fixes were needed. Replaced the 17-token ALLOW_P03_DOCS regex in scripts/verify/m015-p02-no-stale-state-refs.sh with the sentinel __P03_COMPLETE_NEVER_MATCH__ and updated the comment block to mark the allow-list sealed; any future re-introduction of legacy paths in those docs will correctly FAIL the P02 sweep. Full verification suite passes 16/16 on check-must-haves plus all 6 P03 verifiers and the P02 no-stale-state-refs sweep.

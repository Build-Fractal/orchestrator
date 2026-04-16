---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "M015/P03"
milestone: "M015"
provides:
  - "13 wider docs swept + new docs/migrating-from-speckit.md + ALLOW_MIGRATION updated"
requires:
  - "T01 verify scripts + T02 primary reframe"
affects:
  - "T04 closeout"
key_files:
  - "scripts/AGENTS.md,docs/migrating-from-speckit.md,scripts/verify/m015-p02-no-stale-state-refs.sh"
key_decisions:
  - "Migration guide structured as 8-section user journey. ALLOW_SELF_REFERENCE extended to cover m015-p03-*.sh + m015-p03-helpers/*.txt. docs/migrating-from-speckit.md added to ALLOW_MIGRATION (permanent migration-context doc)."
patterns_established:
  - "n/a"
drill_down_paths:
  - ".orchestrator/milestones/M015/phases/P03/tasks/T03-PLAN.md"
duration: "8"
verification_result: "pass"
completed_at: "2026-04-15T16:59:43Z"
---

Resumed after transient API 500 failure interrupted prior attempt. 12 of 13 wider-docs sweeps were already done pre-interruption; finished the remaining scripts/AGENTS.md ref (line 512 constitution path) and created docs/migrating-from-speckit.md (147 lines, 9 H2 sections). Updated P02 sweep allow-lists: ALLOW_MIGRATION now includes the new migration doc, and ALLOW_SELF_REFERENCE now covers m015-p03-*.sh + m015-p03-helpers/*.txt so the newly-added P03 verify scripts and immutable changelog snapshot are tolerated. All 6 verifiers pass.

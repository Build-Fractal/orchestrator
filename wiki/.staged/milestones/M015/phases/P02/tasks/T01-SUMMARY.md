---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M015/P02"
milestone: "M015"
provides:
  - "7 new verify scripts under scripts/verify/m015-p02-*.sh (6 migration gates + 1 parse-check helper)"
requires:
  - "P01 complete"
affects:
  - "T02/T03/T04/T05 verification"
key_files:
  - "scripts/verify/m015-p02-state-tree-migrated.sh, scripts/verify/m015-p02-constitution-moved.sh, scripts/verify/m015-p02-resolver-no-bridge.sh, scripts/verify/m015-p02-resolver-resolves-new.sh, scripts/verify/m015-p02-no-stale-state-refs.sh, scripts/verify/m015-p02-doctor-clean.sh, scripts/verify/m015-p02-t01-parse-check.sh"
key_decisions:
  - "Write verify scripts before migration (validation-as-task pattern MEM011); scripts designed to FAIL pre-migration and PASS post-T02–T05; only parse-check runs in this task (bash -n, not execution)"
patterns_established:
  - "Pre-migration verify scaffolding: author gating scripts first, confirm bash -n parse, defer execution until downstream tasks land the state changes they verify"
drill_down_paths:
  - ".specify/orchestrator/milestones/M015/phases/P02/tasks/T01-PLAN.md"
duration: "8"
verification_result: "pass"
completed_at: "2026-04-15T12:00:04Z"
---

Wrote P02 verification scaffolding before any destructive state move: six verify scripts that gate migration completion (state-tree-migrated, constitution-moved, resolver-no-bridge, resolver-resolves-new, no-stale-state-refs, doctor-clean) plus a parse-check helper. All seven scripts use AD-19 single-script-file shape, are executable, and pass bash -n. No state was moved and no runtime files were modified — the verify scripts are pre-migration scaffolding that FAIL by design until T02–T05 complete.

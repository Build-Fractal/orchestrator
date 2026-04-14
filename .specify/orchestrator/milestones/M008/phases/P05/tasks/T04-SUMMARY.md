---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M008"
provides:
  - "cursor.sh — Cursor runtime adapter (probe/register/hook-config) with --project-dir scope"
requires:
  - "from:P05/T01 what:detect-runtime.sh,from:P04/T05 what:namespace-aliases.sh"
affects:
  - "P05/T07,P06/all"
key_files:
  - "scripts/dispatch/adapters/runtime/cursor.sh"
key_decisions:
  - "project-scoped not HOME-scoped — Cursor uses .cursor/rules/ in project dir"
patterns_established:
  - "project-scoped runtime adapter — --project-dir flag drives all writes, matches HOME-guard safety model"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T04-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-14T17:07:13Z"
---

Created cursor.sh runtime adapter. Cursor scopes rules per-project under .cursor/rules/ so adapter uses --project-dir flag (not HOME). Same probe/register/hook-config interface as claude-code/codex. All tests use mktemp project dir.

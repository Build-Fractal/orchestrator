---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M008"
provides:
  - "migrate-state.sh — hard one-shot .specify/orchestrator/ → .orchestrator/ migration tool with --dry-run"
requires:
  - "from:P04/T01 what:resolve-root.sh"
affects:
  - "P04/T06,P07/all"
key_files:
  - "scripts/migrate/migrate-state.sh"
key_decisions:
  - "hard migration per project memory (no dual code paths) — move not copy, refuse populated destination"
patterns_established:
  - "hermetic migration test — always use mktemp -d fixtures, never run against live project trees"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P04/tasks/T04-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-14T16:26:16Z"
---

Created migrate-state.sh implementing one-shot hard migration from .specify/orchestrator/ to .orchestrator/. Move semantics (not copy). --dry-run flag shows plan without moving. Refuses to overwrite populated destination. Preserves file permissions and timestamps via mv. Never invoked against this project during P04 execution; migration deferred to P07 init flow or manual invocation.

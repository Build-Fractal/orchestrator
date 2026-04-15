---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M008"
provides:
  - "3 runtime installers (claude-code, codex, cursor) delegating to P05 adapters with shared flag contract"
requires:
  - "from:P05/T02 what:claude-code.sh,from:P05/T03 what:codex.sh,from:P05/T04 what:cursor.sh,from:P06/T02 what:bundle"
affects:
  - "P06/T05,P07/all"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh"
key_decisions:
  - "installers delegate to P05 runtime adapters — no duplicate install logic; shared flag contract (--dry-run, --force, --project-dir, --verbose)"
patterns_established:
  - "thin installer pattern — delegates runtime-specific work to adapter, only adds bundle config + hook wiring on top"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P06/tasks/T03-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-14T17:43:05Z"
---

Created 3 runtime installers delegating to P05 adapters. Each handles: runtime adapter --register invocation, bundle config/ copy to state root, --hook-config output written to runtime's hook location. Shared flag contract (--dry-run, --force, --project-dir, --verbose) with exit codes 0/1/2/3. All integration tests hermetic — no real HOME writes.

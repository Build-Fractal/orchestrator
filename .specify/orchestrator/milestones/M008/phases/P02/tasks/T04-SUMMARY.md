---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M008"
provides:
  - "local-codex.sh — Codex CLI SDK backend adapter (probe mode + uniform interface fallback when codex absent)"
requires:
  - "from:P02/T01 what:dispatch-result.md schema,from:P02/T01 what:dispatch-error.md schema"
affects:
  - "P02/T05"
key_files:
  - "scripts/dispatch/adapters/backend/local-codex.sh"
key_decisions:
  - "none"
patterns_established:
  - "uniform-interface fallback — adapter always emits dispatch-result even when backend unavailable, with status=failure rather than exiting with error"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P02/tasks/T04-PLAN.md"
duration: "67s"
verification_result: "pass"
completed_at: "2026-04-14T15:32:24Z"
---

Created local-codex.sh Codex CLI adapter. --probe mode reports availability based on codex CLI presence on PATH. Normal mode attempts codex invocation; when codex absent, emits dispatch-result with status=failure preserving uniform interface contract. TODO(M008-P02) marker for runtime CLI arg validation. Satisfies FR-010 second local backend requirement.

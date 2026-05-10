---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P02"
milestone: "M008"
provides:
  - "dispatch-interface.sh — uniform backend-agnostic dispatch entry point with filename-based routing and structured error synthesis"
requires:
  - "from:P02/T01 what:dispatch-result.md,from:P02/T01 what:dispatch-error.md,from:P02/T02 what:backend-registry.sh,from:P02/T03 what:local-agent.sh,from:P02/T04 what:local-codex.sh"
affects:
  - "P02/T06,P03/all,P05/all"
key_files:
  - "scripts/dispatch/dispatch-interface.sh"
key_decisions:
  - "filename-based adapter routing — zero backend-specific code in core per SC-003"
patterns_established:
  - "uniform dispatch interface — single entry point, adapter resolution purely by filename, structured result on stdout and structured error on stderr with distinct exit codes"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P02/tasks/T05-PLAN.md"
duration: "1m18s"
verification_result: "pass"
completed_at: "2026-04-14T15:35:04Z"
---

Created dispatch-interface.sh — the uniform dispatch entry point. Resolves backend via --backend flag or backend-registry.sh default. Invokes ${ADAPTERS_DIR}/${backend}.sh as subprocess with task-plan/payload/intensity-metadata. Emits structured dispatch-result on stdout and structured dispatch-error on stderr (distinct exit codes 2-6: missing-args=2, unknown-backend=3, adapter-failure=4, timeout=5, invalid-result=6). Satisfies FR-009 (uniform interface) and SC-003 (zero core edits to add new backend).

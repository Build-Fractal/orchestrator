---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M008"
provides:
  - "backend-registry.sh — auto-discovery of dispatch backend adapters with availability probing"
requires:
  - "none (independent task)"
affects:
  - "P02/T05"
key_files:
  - "scripts/dispatch/backend-registry.sh"
key_decisions:
  - "none"
patterns_established:
  - "filename-based adapter auto-discovery — anything in adapters/backend/*.sh is a registered backend (no central registry file)"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P02/tasks/T02-PLAN.md"
duration: "3m"
verification_result: "pass"
completed_at: "2026-04-14T15:18:41Z"
---

Created backend-registry.sh implementing filename-based adapter discovery in scripts/dispatch/adapters/backend/. Probes each adapter with --probe flag, collects available=true adapters, emits backends_available= and default_backend= key=value pairs. Supports --list and --probe subcommands. Satisfies FR-011 (register backends without modifying core).

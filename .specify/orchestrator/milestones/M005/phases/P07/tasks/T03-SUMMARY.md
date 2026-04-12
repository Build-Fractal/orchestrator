---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P07"
milestone: "M005"
provides:
  - "scripts/lifecycle/write-permissions.sh host translator, scripts/diagnostics/check-permissions.sh drift detector"
requires:
  - "from:P07/T02 what:generate-permissions.sh canonical JSON output"
affects:
  - "T04,P06"
key_files:
  - "scripts/lifecycle/write-permissions.sh,scripts/diagnostics/check-permissions.sh"
key_decisions:
  - "AD-13,AD-10,AD-7,AD-16"
patterns_established:
  - "additive merge for user-authored settings, DOCTOR:PERMISSIONS structured drift output"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P07/tasks/T03-PLAN.md"
duration: "128s"
verification_result: "pass"
completed_at: "2026-04-12T21:30:36Z"
---

Created write-permissions.sh (175 lines) — reads canonical JSON from stdin or file, detects target host, writes .claude/settings.json with provenance markers. When target exists without _generated_by marker, merges additively per AD-13 (never removes user entries). Created check-permissions.sh (128 lines) — drift detector comparing current settings to generator output. Emits DOCTOR:PERMISSIONS status=ok|drift|missing gaps=N stale=N. Supports --quiet flag. Both scripts source errors.sh and events.sh.

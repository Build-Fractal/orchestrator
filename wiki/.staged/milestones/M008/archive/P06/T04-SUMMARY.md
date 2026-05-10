---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M008"
provides:
  - "check-update.sh — offline-safe version checker with graceful degradation"
requires:
  - "from:P06/T02 what:packaging/bundle/manifest.yml"
affects:
  - "P06/T05,P07/all"
key_files:
  - "scripts/lifecycle/check-update.sh"
key_decisions:
  - "offline-safe — network failure emits installed_version + latest_version=unknown rather than exiting with error"
patterns_established:
  - "version check with graceful offline degradation — never fails when remote unreachable"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P06/tasks/T04-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-14T17:46:16Z"
---

Created check-update.sh reading installed version from packaging/bundle/manifest.yml and attempting to fetch latest from .invalid TLD placeholder (infrastructure for M010). Network failure emits latest_version=unknown and update_available=unknown, never exits with error. Produces human-readable update_instructions when update detected.

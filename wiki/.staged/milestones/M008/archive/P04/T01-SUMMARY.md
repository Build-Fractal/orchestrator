---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M008"
provides:
  - "resolve-root.sh — canonical orchestrator state root resolver with 5-rule precedence"
requires:
  - "none (independent task)"
affects:
  - "P04/T03,P04/T04,P04/T05,P04/T06"
key_files:
  - "scripts/state/resolve-root.sh"
key_decisions:
  - "read-only resolver — never creates directories; 5-rule precedence ensures backward compatibility bridge for .specify/orchestrator/"
patterns_established:
  - "pure resolver pattern — reads from env/config/filesystem, emits path to stdout, zero side effects"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P04/tasks/T01-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-14T16:21:20Z"
---

Created resolve-root.sh implementing the canonical orchestrator state root resolution with 5-rule precedence: (1) ORCHESTRATOR_ROOT env var, (2) state_root in config.yml, (3) existing .orchestrator/, (4) bridge to existing .specify/orchestrator/, (5) default .orchestrator/. Read-only — never creates directories (config-system.sh T03 is first writer). Hermetic verifications use mktemp -d fixtures.

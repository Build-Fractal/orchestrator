---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "M015/P02"
milestone: "M015"
provides:
  - "resolver reduced from 5 rules to 4; bridge rule removed; .specify/orchestrator/config.yml probe removed from Rule 2; redundant state_root: declaration removed from .orchestrator/config.yml"
requires:
  - "T02, T03 migrations complete"
affects:
  - "T05 sweep"
key_files:
  - "scripts/state/resolve-root.sh, .orchestrator/config.yml"
key_decisions:
  - "Removed state_root: from .orchestrator/config.yml to resolve T02/T04 plan collision (see DECISIONS.md)"
patterns_established:
  - "Config file declares overrides, not canonical location; Rule 3 directory existence is authoritative"
drill_down_paths:
  - ".orchestrator/milestones/M015/phases/P02/tasks/T04-PLAN.md"
duration: "15"
verification_result: "pass"
completed_at: "2026-04-15T13:00:19Z"
---

Resolver rewrite from attempt 1 held: Rule 2 now probes only .orchestrator/config.yml, and the bridge rule is gone. Attempt 1 failed m015-p02-resolver-resolves-new.sh because T02 had preserved state_root: ".orchestrator" inside the config, causing Rule 2 (config) to win over Rule 3 (directory existence). Resolved by deleting that single line, making directory existence the canonical signal per spec Truth #4. Both P02 verifiers now pass; resolve-root.sh --verbose emits root=.orchestrator source=existing:.orchestrator. Cross-task scope widening recorded in DECISIONS.md D003.

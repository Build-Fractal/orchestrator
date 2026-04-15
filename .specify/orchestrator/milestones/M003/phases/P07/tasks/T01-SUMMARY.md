---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P07"
milestone: "M003"
provides:
  - "resolver-wired migrate.sh; transform scripts that consume target_root as the absolute orchestrator state root"
requires:
  - "from:M008/P04 what:scripts/state/resolve-root.sh (5-rule resolver, --absolute mode)"
affects:
  - "P07/T02,P07/T03,P07/T04,P07/T05"
key_files:
  - "scripts/migrate/migrate.sh,scripts/migrate/transform/milestone-rollup.sh,scripts/migrate/transform/active-milestone.sh,scripts/migrate/transform/milestone-tiering.sh"
key_decisions:
  - "AD-13"
patterns_established:
  - "invoke-not-source for set -u resolver scripts; export resolved root via env var for downstream verify scripts"
drill_down_paths:
  - ".specify/orchestrator/milestones/M003/phases/P07/tasks/T01-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-14T00:00:00Z"
---

Threaded the M008 5-rule resolver through the migration pipeline. migrate.sh now invokes scripts/state/resolve-root.sh --absolute when --output is not supplied, exports MIGRATE_TARGET_ROOT, and mkdir -p's the resolved root. The four transform scripts that previously appended .specify/orchestrator/ to target_root now write directly under ${target_root}/milestones/... — semantics of target_root changed (absolute orchestrator state root) without changing any transform script signature. Sanity scan confirms zero hardcoded .specify/orchestrator matches in scripts/migrate/migrate.sh or scripts/migrate/transform/. CLI contract preserved: --help exits 0, --path on missing dir exits 1 with the existing 'Source path does not exist' error, --output still wins over the resolver. Smoke test produced expected log line '[INFO] Target root (from --output): /tmp/p07-t01-smoke'.

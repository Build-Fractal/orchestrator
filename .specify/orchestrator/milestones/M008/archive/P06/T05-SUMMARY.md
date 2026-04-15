---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P06"
milestone: "M008"
provides:
  - "P06 Bash 3.2 compat scan (comment-aware) + hermetic end-to-end packaging integration test"
requires:
  - "from:P06/T01 what:generate-skills.sh,from:P06/T02 what:build-bundle.sh,from:P06/T03 what:3 installers,from:P06/T04 what:check-update.sh"
affects:
  - "P07/all"
key_files:
  - "scripts/verify/m008-p06-bash32-compat.sh,scripts/verify/m008-p06-integration-e2e.sh"
key_decisions:
  - "none"
patterns_established:
  - "full packaging e2e — regenerate skills + build bundle + hermetic install + verify across all 3 runtimes"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P06/tasks/T05-PLAN.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-04-14T17:49:49Z"
---

Final P06 task: Bash 3.2 compatibility scan + end-to-end integration test. E2E flow regenerates 12 skills, rebuilds bundle, hermetically installs via each of 3 runtime installers (Claude Code + Codex + Cursor with --project-dir), verifies 12 skills placed correctly, verifies config/ placed at state root, runs check-update.sh in offline mode. Validates FR-017/018/019 across full packaging surface.

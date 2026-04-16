---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M015/P01"
milestone: "M015"
provides:
  - "extension.yml deleted; 9 .claude/commands/speckit.*.md deleted; .specify/scripts/bash/ deleted; .specify/templates/commands/ deleted; 6 root .specify/templates/*-template.md deleted; 4 verify scripts added under scripts/verify/m015-p01-*.sh; evaluate-preflight.sh fixed to pass --project-root flag to generate-permissions.sh and write-permissions.sh"
requires:
  - "none"
affects:
  - "P02 state migration, P03 doc reframe"
key_files:
  - "scripts/verify/m015-p01-no-extension-yml.sh, scripts/verify/m015-p01-no-speckit-commands.sh, scripts/verify/m015-p01-no-specify-bash.sh, scripts/verify/m015-p01-no-specify-templates.sh, scripts/lifecycle/evaluate-preflight.sh, extension.yml (deleted), .claude/commands/speckit.*.md (9 deleted), .specify/scripts/bash/ (deleted), .specify/templates/commands/ (deleted), .specify/templates/{agent-file,checklist,constitution,plan,spec,tasks}-template.md (6 deleted)"
key_decisions:
  - "FR-013 migration-adapter preservation honored (scripts/migrate/adapters/speckit.sh, scripts/state/detect-speckit.sh, scripts/dispatch/adapters/format/speckit.sh, commands/migrate.md untouched); M007 no-graceful-degradation (hard delete, no rename/shim/archive)"
patterns_established:
  - "Hard-delete cutover discipline: git rm for tracked files; no legacy/ rename; no compat shim; verify scripts use file-absence assertions"
drill_down_paths:
  - ".specify/orchestrator/milestones/M015/phases/P01/tasks/T01-PLAN.md"
duration: "15"
verification_result: "pass"
completed_at: "2026-04-15T05:55:16Z"
---

Hard-deleted the spec-kit extension host surface: extension.yml, 9 dogfooded /speckit.* slash commands, .specify/scripts/bash/ (5 helpers), .specify/templates/commands/ (9 templates), and 6 root-level spec-kit-style template files. Migration-source adapters under scripts/migrate/, scripts/state/detect-speckit.sh, scripts/dispatch/adapters/format/speckit.sh, and commands/migrate.md were preserved per FR-013. Added 4 verify scripts (all PASS). Fixed evaluate-preflight.sh, which was invoking generate-permissions.sh and write-permissions.sh with positional project-root (making them error on the unknown option and report permissions=error); both now use --project-root flag form. Fresh run of bash scripts/lifecycle/evaluate-preflight.sh . B now reports permissions=generated. All 4 verify scripts PASS and exit 0.

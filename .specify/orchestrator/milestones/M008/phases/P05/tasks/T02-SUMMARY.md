---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M008"
provides:
  - "claude-code.sh — Claude Code runtime adapter (probe/register/hook-config) with HOME guard"
requires:
  - "from:P05/T01 what:detect-runtime.sh,from:P04/T05 what:namespace-aliases.sh"
affects:
  - "P05/T07,P06/all"
key_files:
  - "scripts/dispatch/adapters/runtime/claude-code.sh"
key_decisions:
  - "HOME guard mandatory — adapters refuse HOME="" or HOME=/ to prevent root-directory writes"
patterns_established:
  - "runtime adapter HOME guard pattern + filename-based discovery (mirrors P02 backend pattern)"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T02-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-14T17:01:26Z"
---

Created claude-code.sh runtime adapter with --probe/--register/--hook-config/--dry-run interface. --register writes to $HOME/.claude/commands/orchestrator-<cmd>.md. HOME guard refuses empty or root paths. Verifications use mktemp HOME fixtures only.

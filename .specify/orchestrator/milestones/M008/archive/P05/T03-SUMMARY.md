---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M008"
provides:
  - "codex.sh — Codex CLI runtime adapter (probe/register/hook-config) with HOME guard"
requires:
  - "from:P05/T01 what:detect-runtime.sh,from:P04/T05 what:namespace-aliases.sh"
affects:
  - "P05/T07,P06/all"
key_files:
  - "scripts/dispatch/adapters/runtime/codex.sh"
key_decisions:
  - "AGENTS.md as Codex project instruction file equivalent of CLAUDE.md"
patterns_established:
  - "runtime adapter mirrors claude-code.sh pattern with AGENTS.md + ~/.codex/skills/ conventions"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P05/tasks/T03-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-14T17:04:30Z"
---

Created codex.sh runtime adapter following claude-code.sh pattern but with Codex conventions: AGENTS.md project instructions, $HOME/.codex/skills/ for skill registration, config.toml for hook wiring. HOME guard matches claude-code. All registration tests use mktemp HOME fixtures.

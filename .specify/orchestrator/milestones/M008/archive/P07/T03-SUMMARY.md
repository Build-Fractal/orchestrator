---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P07"
milestone: "M008"
provides:
  - "init-project.sh — top-level orchestrator:init entry point with detect→probe→generate→verify pipeline"
requires:
  - "from:P01/T01 what:detect-capabilities.sh,from:P05/T01 what:detect-runtime.sh,from:P07/T01 what:detect-project.sh,from:P04/T01 what:resolve-root.sh,from:P07/T02 what:project-instruction.md+commands/init.md,from:P06/T03 what:3 installers"
affects:
  - "P07/T04,P07/T05"
key_files:
  - "scripts/lifecycle/init-project.sh"
key_decisions:
  - "delegates to P01/P04/P05/P06 — no detection logic duplicated; hermetic tests only"
patterns_established:
  - "top-level pipeline delegation — init orchestrates detect/probe/generate/install through existing scripts rather than reimplementing"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P07/tasks/T03-PLAN.md"
duration: "2m"
verification_result: "pass"
completed_at: "2026-04-14T18:39:45Z"
---

Created init-project.sh top-level entry point. Pipeline: detect-runtime → detect-capabilities → detect-project → resolve-root → generate config.yml + project-instruction.md → install via runtime-specific installer. --dry-run shows plan without writes. --force overrides existing config check. Exit codes 0 success, 1 bad args, 2 detection failure, 3 install failure, 4 existing config (without --force). Completes in under 2 minutes per SC-005.

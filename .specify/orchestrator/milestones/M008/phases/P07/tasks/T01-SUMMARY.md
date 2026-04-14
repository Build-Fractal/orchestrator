---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P07"
milestone: "M008"
provides:
  - "detect-project.sh — project structure scanner for language/framework/CI/tools"
requires:
  - "none (independent task)"
affects:
  - "P07/T03,P07/T05"
key_files:
  - "scripts/lifecycle/detect-project.sh"
key_decisions:
  - "file-presence markers (package.json, Cargo.toml, go.mod, pyproject.toml, etc.) drive detection; no parsing of manifest contents"
patterns_established:
  - "project introspection via marker-file presence — zero parsing, fast, offline-safe"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P07/tasks/T01-PLAN.md"
duration: "12m"
verification_result: "pass"
completed_at: "2026-04-14T18:08:16Z"
---

Created detect-project.sh scanning project for language markers (package.json/Cargo.toml/go.mod/pyproject.toml/Gemfile), framework markers (next.config, vite.config, nuxt.config), CI config (.github/workflows, .gitlab-ci.yml, .circleci/config.yml, Jenkinsfile), and tools (docker-compose, Makefile, Taskfile). Emits key=value output for consumption by init-project.sh (T03).

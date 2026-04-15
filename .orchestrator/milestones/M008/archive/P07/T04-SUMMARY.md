---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P07"
milestone: "M008"
provides:
  - "reinit-handler.sh — re-initialization with update/reset/abort modes preserving user-edited sections"
requires:
  - "from:P07/T02 what:project-instruction.md markers,from:P07/T03 what:init-project.sh"
affects:
  - "P07/T05"
key_files:
  - "scripts/lifecycle/reinit-handler.sh,scripts/verify/m008-p07-reinit-preserves-custom.sh,scripts/verify/m008-p07-reinit-delegation.sh"
key_decisions:
  - "default mode is update (preserve existing user context) rather than reset — minimizes destructive re-init; reset delegates to init-project.sh --force rather than duplicating render logic; BSD awk multi-line values unsupported via -v so preserved block written to temp file and spliced via getline"
patterns_established:
  - "reinit-with-preservation — comment-delimited blocks and section-level awk surgery preserve user edits across regeneration; block-via-getline — multi-line awk splice uses temp-file + getline rather than -v var (BSD awk compatibility)"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P07/tasks/T04-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-14T22:51:15Z"
---

Created scripts/lifecycle/reinit-handler.sh (311 lines, mode 0755) with update/reset/abort modes and non-interactive default (exit 4 + REINIT: line when no --mode given). update mode preserves the <!-- BEGIN CUSTOM --> ... <!-- END CUSTOM --> block from the instruction file via an awk splice (temp-file + getline, BSD-compatible) and preserves user-added top-level fields in config.yml via a three-pass awk: strip project:/capabilities: blocks, update initialized_at in place, append freshly detected blocks. reset delegates to init-project.sh --force. abort exits 0 with no changes. Two verifiers (reinit-preserves-custom, reinit-delegation) both PASS; both are hermetic (mktemp -d for HOME and project dir). Integration verifiers m008-p07-hermetic-only / bash32-compat / integration-e2e are T05 scope and unaffected by this task. Bash 3.2 clean — no declare -A / mapfile / ${var,,}.

---
schema_version: "1.0"
type: phase-summary
id: "P07"
parent: "M004"
milestone: "M004"
provides:
  - "check-recipe.sh recipe conformance diagnostic for context-recipe.yaml validation, Registration of check-recipe.sh in run-doctor.sh (as non-advisory check) and extension.yml (as executable script), P07 verification report — all 9 truth checks pass, doctor integration confirmed, check-must-haves 16/16"
requires:
  - "from:P04 what:recipe-parser.sh, from:P02 what:lib/errors.sh and lib/events.sh, from:P07/T01 what:check-recipe.sh, from:P07/T01 what:check-recipe.sh, from:P07/T02 what:run-doctor.sh integration and extension.yml registration"
affects:
  - "P07/T02 (run-doctor registration), P07/T03 (verification task), Phase transition: gates P07 completion"
key_files:
  - "scripts/diagnostics/check-recipe.sh, scripts/diagnostics/run-doctor.sh, extension.yml, scripts/verify/m004-p07-recipe-exists.sh, scripts/verify/m004-p07-recipe-fields.sh, scripts/verify/m004-p07-recipe-sources.sh, scripts/verify/m004-p07-recipe-priorities.sh, scripts/verify/m004-p07-recipe-output.sh, scripts/verify/m004-p07-doctor-recipe.sh, scripts/verify/m004-p07-extension-recipe.sh, scripts/verify/m004-p07-events-existing.sh, scripts/verify/m004-p07-constitution-existing.sh"
key_decisions:
  - "Used is_in_list helper with heredoc iteration instead of case statement for extensibility; accepted .md suffix as valid source type to cover file-path sources like KNOWLEDGE.md and DECISIONS.md; emit_event and emit_result to stderr per convention, Placed Recipe Conformance after Run ID Coverage and before Task Plan Shape (advisory); marked non-advisory (4th arg 0) since recipe conformance is a structural requirement, All 9 verification helpers pass (19 assertions total). Doctor suite runs with Recipe Conformance check active. check-must-haves reports 16/16 pass."
patterns_established:
  - "DOCTOR:RECIPE output convention matching DOCTOR:HASHES and DOCTOR:EVENTS pattern; recipe section validation loop using parse_recipe_sections pipe-delimited output, New diagnostic checks added between last non-advisory check and first advisory check in run-doctor.sh, Phase verification before completion: run all truth helpers, then doctor integration, then check-must-haves"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P07/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P07/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P07/tasks/T03-SUMMARY.md"
duration: "14m"
verification_result: "pass"
completed_at: "2026-04-13T21:29:35Z"
observability_surfaces:
  - "check-recipe.sh emits DOCTOR:RECIPE status=ok|warn sections=N invalid=N to stdout; emits EVENT: and RESULT: to stderr when ORCH_RUN_ID is set"
---

P07 added recipe conformance diagnostics to the orchestrator's doctor suite. check-recipe.sh (211 lines) validates templates/context-recipe.yaml structure across 3 dimensions: required fields (source, priority, order, filter, cache_hint), valid source types (7 known types plus .md suffix), and valid priorities (required/compressible/optional). The check was registered in run-doctor.sh as a non-advisory check and in extension.yml. Pre-existing check-events.sh and check-constitution.sh (from M005/P07) were verified as already functional. Verification: 9 truth checks pass (19 assertions), doctor suite runs cleanly with recipe conformance, check-must-haves 16/16 pass.

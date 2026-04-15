---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P07"
milestone: "M004"
provides:
  - "check-recipe.sh recipe conformance diagnostic for context-recipe.yaml validation"
requires:
  - "from:P04 what:recipe-parser.sh, from:P02 what:lib/errors.sh and lib/events.sh"
affects:
  - "P07/T02 (run-doctor registration)"
key_files:
  - "scripts/diagnostics/check-recipe.sh"
key_decisions:
  - "Used is_in_list helper with heredoc iteration instead of case statement for extensibility; accepted .md suffix as valid source type to cover file-path sources like KNOWLEDGE.md and DECISIONS.md; emit_event and emit_result to stderr per convention"
patterns_established:
  - "DOCTOR:RECIPE output convention matching DOCTOR:HASHES and DOCTOR:EVENTS pattern; recipe section validation loop using parse_recipe_sections pipe-delimited output"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P07/tasks/T01-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-13T21:20:10Z"
---

Created check-recipe.sh diagnostic that validates context-recipe.yaml structure. Validates 3 dimensions: required fields (source, priority, order, filter, cache_hint), valid source types (7 known types plus .md suffix), and valid priorities (required, compressible, optional). All 5 verification scripts pass (12/12 assertions). Default recipe validates cleanly with 7 sections, 0 invalid. Script follows existing check-hashes.sh/check-events.sh conventions with DOCTOR:RECIPE structured output line. Engine integration (emit_event/emit_result) wrapped in ORCH_RUN_ID guard per P02 convention.

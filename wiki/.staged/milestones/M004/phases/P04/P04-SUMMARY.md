---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M004"
milestone: "M004"
provides:
  - "templates/context-recipe.yaml with 7 sections (state, knowledge, decisions, upstream, scope, task_plan, constraints), compression block with 3 graduated steps, manifest config, templates/hooks.yaml with 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE) and 6 hook entries, Extended templates/routing.yaml with fallback chains per tier, structured classification rules, fallback_config block, scripts/lib/recipe-parser.sh with 6 functions: read_recipe_field, parse_recipe_sections, parse_recipe_compression, parse_recipe_hooks, parse_recipe_fallback, resolve_recipe, scripts/verify/check-recipe-integration.sh — 40-check integration test validating recipe parser against all 3 YAML files"
requires:
  - "from:T01 what:templates/context-recipe.yaml, from:T02 what:templates/hooks.yaml, from:T03 what:templates/routing.yaml, from:T04 what:scripts/lib/recipe-parser.sh, from:T01 what:templates/context-recipe.yaml, from:T02 what:templates/hooks.yaml, from:T03 what:templates/routing.yaml"
affects:
  - "P04/T04 (recipe-parser.sh reads this file), P05 (build-context.sh refactored to consume this recipe), P04/T04 (recipe-parser.sh parses hooks), P02/P03 (engine uses hooks.yaml), P04/T04 (recipe-parser.sh reads fallback chains), P05 (select-model.sh refactored to use fallback chains), P04/T05 (integration verification), P05 (build-context.sh refactor uses parser), P07 (conformance diagnostics can extend this test)"
key_files:
  - "templates/context-recipe.yaml, templates/hooks.yaml, templates/routing.yaml, scripts/lib/recipe-parser.sh, scripts/verify/check-recipe-integration.sh"
key_decisions:
  - "Schema constrained to 2-level nesting for grep/sed/awk parsing; source types: computed, file paths, phase_summaries, phase_plan, task_plan, template, Hooks block by default (block_on_fail: true); knowledge_trigger disabled by default; phase_completeness is non-blocking, Fallback chain: heavy→standard→light; recoverable errors: rate_limit,timeout,overloaded; max_retries: 2, Pipe-delimited output format for list functions; sort-key prefix for order-based sorting; 3-level dotted path support for read_recipe_field, resolve_recipe path resolution assumes orch_root parent is one level below project root — edge case noted for future fix"
patterns_established:
  - "YAML recipe schema with source/priority/order/filter/cache_hint per section; comma-separated inline arrays instead of flow sequences, Hook entry schema: name/script/enabled/block_on_fail/description; Global hook_defaults block; Lifecycle point as top-level YAML key, Comma-separated fallback lists in YAML; structured classification with patterns+confidence per tier; fallback_config block pattern, YAML parser pattern: while-read loop with state machine (in_block flags), case-based indent detection, sed for field extraction; Double-sourcing guard (_RECIPE_PARSER_SOURCED); resolve_recipe specificity chain (task>phase>milestone>default), check() function with PASS/FAIL counters for integration testing; section-by-section test organization with summary line"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P04/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P04/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P04/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P04/tasks/T04-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P04/tasks/T05-SUMMARY.md"
duration: "763m"
verification_result: "pass"
completed_at: "2026-04-10T20:49:15Z"
observability_surfaces:
  - "check-recipe-integration.sh: 40 checks pass/fail count"
---

Phase P04 established the declarative YAML recipe system for the orchestrator. Created templates/context-recipe.yaml (103 lines) declaring 7 sections with source/priority/order/filter/cache_hint fields, compression block with 3 graduated steps, and manifest config. Created templates/hooks.yaml (84 lines) with 4 lifecycle points and 6 hook entries. Extended templates/routing.yaml (42 lines) with fallback chains per tier and structured classification rules. Built scripts/lib/recipe-parser.sh (481 lines) with 6 functions for Bash 3.2-compatible YAML parsing using grep/sed/awk only. Validated with scripts/verify/check-recipe-integration.sh running 40 integration checks — all pass. Schema constrained to 2-level nesting. No jq dependency. Constitution Principles X (Templating Over Inference), XI (Single Source of Truth), and XIII (Agent Instruction Schema) are now mechanically realized.

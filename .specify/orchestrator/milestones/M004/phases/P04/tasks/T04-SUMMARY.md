---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M004"
provides:
  - "scripts/lib/recipe-parser.sh with 6 functions: read_recipe_field, parse_recipe_sections, parse_recipe_compression, parse_recipe_hooks, parse_recipe_fallback, resolve_recipe"
requires:
  - "from:T01 what:templates/context-recipe.yaml, from:T02 what:templates/hooks.yaml, from:T03 what:templates/routing.yaml"
affects:
  - "P04/T05 (integration verification), P05 (build-context.sh refactor uses parser)"
key_files:
  - "scripts/lib/recipe-parser.sh"
key_decisions:
  - "Pipe-delimited output format for list functions; sort-key prefix for order-based sorting; 3-level dotted path support for read_recipe_field"
patterns_established:
  - "YAML parser pattern: while-read loop with state machine (in_block flags), case-based indent detection, sed for field extraction; Double-sourcing guard (_RECIPE_PARSER_SOURCED); resolve_recipe specificity chain (task>phase>milestone>default)"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P04/tasks/T04-PLAN.md"
duration: "456s"
verification_result: "pass"
completed_at: "2026-04-10T20:38:25Z"
---

Created scripts/lib/recipe-parser.sh (481 lines) with 6 functions for parsing YAML recipes. read_recipe_field reads any scalar by dotted path (1-3 segments). parse_recipe_sections lists all 7 sections sorted by order. parse_recipe_compression lists 3 compression steps. parse_recipe_hooks lists hooks at a lifecycle point. parse_recipe_fallback reads fallback chain for a tier. resolve_recipe implements FR-211 specificity resolution. All parsing via grep/sed/awk, no jq, Bash 3.2 compatible. Bug found and fixed during testing: duplicate-entry flush on block exit. 8 functional + 11 structural checks all pass.

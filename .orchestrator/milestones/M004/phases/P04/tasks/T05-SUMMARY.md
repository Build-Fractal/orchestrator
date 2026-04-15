---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P04"
milestone: "M004"
provides:
  - "scripts/verify/check-recipe-integration.sh — 40-check integration test validating recipe parser against all 3 YAML files"
requires:
  - "from:T04 what:scripts/lib/recipe-parser.sh, from:T01 what:templates/context-recipe.yaml, from:T02 what:templates/hooks.yaml, from:T03 what:templates/routing.yaml"
affects:
  - "P07 (conformance diagnostics can extend this test)"
key_files:
  - "scripts/verify/check-recipe-integration.sh"
key_decisions:
  - "resolve_recipe path resolution assumes orch_root parent is one level below project root — edge case noted for future fix"
patterns_established:
  - "check() function with PASS/FAIL counters for integration testing; section-by-section test organization with summary line"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P04/tasks/T05-PLAN.md"
duration: "161s"
verification_result: "pass"
completed_at: "2026-04-10T20:46:43Z"
---

Created scripts/verify/check-recipe-integration.sh (226 lines) with 40 integration checks covering all parser functions against all 3 YAML files. Validates: section parsing (7 sections, ordering, priorities), compression steps (3 types with parameters), hook parsing (all 4 lifecycle points, enabled/disabled states, block_on_fail), fallback chains (heavy/standard/light), field reading (1/2/3-level dotted paths), and recipe resolution (FR-211). All 40 checks pass. Double-sourcing safety confirmed. Bash 3.2 compatible.

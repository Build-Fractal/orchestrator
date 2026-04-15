---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M004"
provides:
  - "Extended templates/routing.yaml with fallback chains per tier, structured classification rules, fallback_config block"
requires:
  - "none"
affects:
  - "P04/T04 (recipe-parser.sh reads fallback chains), P05 (select-model.sh refactored to use fallback chains)"
key_files:
  - "templates/routing.yaml"
key_decisions:
  - "Fallback chain: heavy→standard→light; recoverable errors: rate_limit,timeout,overloaded; max_retries: 2"
patterns_established:
  - "Comma-separated fallback lists in YAML; structured classification with patterns+confidence per tier; fallback_config block pattern"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P04/tasks/T03-PLAN.md"
duration: "80s"
verification_result: "pass"
completed_at: "2026-04-10T20:28:48Z"
---

Extended templates/routing.yaml with fallback chains. Heavy tier falls back to standard then light. Standard falls back to light. Light has no fallback. Classification restructured with patterns (comma-separated match terms) and confidence thresholds per tier. Added fallback_config block with recoverable_errors (rate_limit, timeout, overloaded), max_retries (2), retry_delay_seconds (5). Existing fields preserved: history_weight 0.3, budget_ceiling_usd 50.00, all model IDs and context_budgets. 42 lines, all 9 verification checks pass.

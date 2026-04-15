---
schema_version: "1.0"
type: milestone-summary
id: "M004"
parent: "004-engine-architecture"
milestone: "M004"
provides:
  - "Engine architecture foundation: 5 shared libraries (errors.sh, events.sh, run-context.sh, guards.sh, hooks.sh), engine core (run.sh + checkpoint.sh), YAML recipe system (context-recipe.yaml, hooks.yaml, routing.yaml, recipe-parser.sh), recipe-driven refactored dispatch scripts (build-context.sh, compress-payload.sh, select-model.sh + section-handlers.sh), engine integration for 6 additional scripts (check-must-haves.sh, record-result.sh, record-telemetry.sh, aggregate-metrics.sh, classify-complexity.sh, phase-transition.sh), recipe conformance diagnostic (check-recipe.sh), constitution v2.0 (13 principles + ANTIPATTERNS.md)"
requires:
  - "spec-kit >=0.1.0, Bash 3.2+, git"
affects:
  - "Conversus integration (hook lifecycle points), future milestones (structured events, recipe-driven assembly)"
key_files:
  - "scripts/lib/errors.sh, scripts/lib/events.sh, scripts/lib/run-context.sh, scripts/lib/guards.sh, scripts/lib/hooks.sh, scripts/engine/run.sh, scripts/engine/checkpoint.sh, scripts/lib/recipe-parser.sh, templates/context-recipe.yaml, templates/hooks.yaml, scripts/dispatch/build-context.sh, scripts/dispatch/compress-payload.sh, scripts/dispatch/select-model.sh, scripts/diagnostics/check-recipe.sh, .specify/memory/constitution.md"
key_decisions:
  - "Closed 6-kind error taxonomy (CONFIG/STATE/DISPATCH/VERIFY/BUDGET/IO), 19-entry canonical event registry, YAML recipes parsed with grep/sed/awk (no jq), standalone detection via ORCH_RUN_ID guard, root-marker PROJECT_ROOT detection, EXIT trap with _RESULT_EMITTED guard pattern"
patterns_established:
  - "Double-sourcing guard in first 5 lines, emit_result on every exit path, emit_event at lifecycle boundaries, ORCH_RUN_ID standalone detection, recipe-driven context assembly, hook sandbox with chmod 444 frozen snapshots, chained EXIT traps for scripts with pre-existing cleanup"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P01/P01-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P02/P02-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P03/P03-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P04/P04-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P05/P05-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P06/P06-SUMMARY.md, .specify/orchestrator/milestones/M004/phases/P07/P07-SUMMARY.md"
duration: "4d"
verification_result: "pass"
completed_at: "2026-04-13T22:19:11Z"
observability_surfaces:
  - "All engine-path scripts emit EVENT: lines to stderr when ORCH_RUN_ID is set; RESULT: lines on every exit; record-result.sh adds run_id to execution-log.jsonl; aggregate-metrics.sh reports by_error_kind; check-recipe.sh emits DOCTOR:RECIPE"
---

M004 replaced implicit agent-driven coordination with a mechanical engine layer. P01 evolved the constitution to v2.0 (13 principles + ANTIPATTERNS.md). P02 delivered 5 shared libraries (errors, events, run-context, guards, hooks) totaling 647 lines. P03 built the engine core (run.sh pipeline coordinator + checkpoint.sh crash recovery). P04 designed the YAML recipe system (context-recipe.yaml, hooks.yaml, extended routing.yaml + recipe-parser.sh). P05 refactored 3 dispatch scripts to be recipe-driven while preserving identical output. P06 integrated 6 additional scripts with the library stack, fixing the PROJECT_ROOT detection bug and adding run_id/error_kind to JSONL. P07 added recipe conformance diagnostics. 38 dispatches across 7 phases, 0 task-level retries for P06+P07. All scripts maintain standalone compatibility via ORCH_RUN_ID guards (NFR-204).

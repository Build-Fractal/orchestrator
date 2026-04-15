---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M004"
provides:
  - "Engine integration for classify-complexity.sh and phase-transition.sh: lib sourcing, EXIT trap emit_result, emit_event at key lifecycle points"
requires:
  - "from:P02 what:lib/errors.sh and lib/events.sh"
affects:
  - "P07 (conformance checks)"
key_files:
  - "scripts/dispatch/classify-complexity.sh, scripts/lifecycle/phase-transition.sh"
key_decisions:
  - "Prefixed internal vars with underscore (_SCRIPT_DIR, _LIB_DIR, _CC_*, _PT_*) to avoid collisions with existing SCRIPT_DIR in phase-transition.sh"
patterns_established:
  - "EXIT trap pattern with _RESULT_EMITTED guard flag prevents double-emit; PHASE_START/PHASE_COMPLETE bracket pattern for lifecycle scripts"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P06/tasks/T04-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-13T20:47:39Z"
---

Added engine integration to classify-complexity.sh (dispatch script) and phase-transition.sh (lifecycle script). Both scripts now unconditionally source lib/errors.sh and lib/events.sh, register EXIT traps for emit_result (guarded by ORCH_RUN_ID), and emit events at key lifecycle points. classify-complexity.sh emits DISPATCH_START after task plan validation. phase-transition.sh emits PHASE_START after milestone ID derivation and PHASE_COMPLETE before TRANSITION:READY output. All engine calls are wrapped in ORCH_RUN_ID guards for standalone safety. Verified classify-complexity.sh still produces correct stdout output in standalone mode.

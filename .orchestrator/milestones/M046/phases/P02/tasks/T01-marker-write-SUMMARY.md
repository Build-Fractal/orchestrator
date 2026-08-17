---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M046"
provides:
  - "auto-loop.sh env-gated deterministic outcome-marker mechanism (ORCHESTRATOR_SELF_CONTINUE_MARKER=1 gate, atomic temp+rename write to $MILESTONE_DIR/.self-continue-outcome, exit-code + exit-0-substate keyed vocabulary), FR-17 legacy-parity golden + verifier, shared m046-p02 verifying-tree MFIX fixture"
requires:
  - "none (root task)"
affects:
  - "T02, T03 (battery consumes the marker mechanism), P04 (driver reads markers)"
key_files:
  - "scripts/lifecycle/auto-loop.sh, tools/verify/m046-p02-marker-unit.sh, tools/verify/m046-p02-legacy-parity.sh, tests/fixtures/m046-p02/verifying-tree/MFIX/, tests/fixtures/m046-p02/legacy-parity.golden"
key_decisions:
  - "CON-2 satisfied as one logical mechanism in two purely-additive insertions (writer function + EXIT trap after MILESTONE_DIR validation, substate-capture case at top of _auto_output funnel); git diff audit 54 insertions 0 deletions; exit-14 rotation phase word best-effort via read-roadmap active-phase; unknown exit codes and mid-segment exit-0 substates write nothing (last-write-wins)"
patterns_established:
  - "env-gated EXIT-trap outcome marker with atomic temp+rename and fully ${VAR:-}-guarded trap body; byte-equality golden parity verifier per M045 P03 precedent; scratch-copy-only fixture discipline for auto-loop invocations"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P02/"
duration: "540s"
verification_result: "pass"
completed_at: "2026-07-13T16:07:30Z"
---

Added the single CON-2-authorized additive change to scripts/lifecycle/auto-loop.sh: an env-gated (ORCHESTRATOR_SELF_CONTINUE_MARKER=1) deterministic outcome-marker write realized as two purely-additive insertions — a self-contained writer function plus EXIT trap installed right after MILESTONE_DIR validation, and a substate-capture case at the top of the existing _auto_output funnel — mapping the complete exit contract (0+PLANNING/PHASE_COMPLETE/MILESTONE_VALIDATING substates, 1 error, 2 budget, 3 stuck, 10 complete, 11 pause, 12 unexpected_state, 13 planning_failed, 14 rotation with best-effort phase word) to atomic temp+rename writes of $MILESTONE_DIR/.self-continue-outcome; git diff shows 54 insertions and 0 deletions, gate-absent behavior is byte-identical to the pinned legacy golden (no marker side effect), and verification is green: m046-p02-marker-unit 5/5 cases, m046-p02-legacy-parity 6/6 assertions, m045-p03-legacy-golden regression PASS.

---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M024"
provides:
  - "scripts/intake/approval-gate.sh --mode check-fast-path (read-only); scripts/verify/m024-p04-fast-path-check.sh"
requires:
  - "from:M024/P03/T02 what:scripts/intake/approval-gate.sh (verbs+helpers); from:M024/P01/T01 what:templates/intake-proposal.md (frontmatter keys scope_tier/intensity/conversus_gate/design_gate/low_confidence)"
affects:
  - "T03"
key_files:
  - "scripts/intake/approval-gate.sh,scripts/verify/m024-p04-fast-path-check.sh"
key_decisions:
  - "--mode flag chosen over fourth --verb so the operator-facing verb namespace stays mutating-only (per task plan); REC_CMD/PA reads gated on [ -z MODE ] so check-fast-path is orthogonal to verb preconditions"
patterns_established:
  - "Read-only programmatic surface alongside mutating verbs in the same script via --mode flag; fixed-order condition evaluation with first-failing-condition-wins reason slot (closed enum, MEM031); shasum pre/post + .bak-absence assertion as read-only invariant"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P04/tasks/T02-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-26T02:25:29Z"
---

Extended scripts/intake/approval-gate.sh with a fifth invocation surface, '--mode check-fast-path --proposal <path>', that reads scope_tier/intensity/conversus_gate/design_gate/low_confidence from the proposal frontmatter and emits exactly two stdout lines: 'fast_path_eligible=true|false' and 'reason=<token>'. Reason tokens are a closed enum of six (all-conditions-met, tier-not-A, intensity-not-Quick, conversus-gated, design-gated, low-confidence) evaluated in fixed order — first failing condition wins. Mode is fully read-only: no swap_line invocation, no .bak file, shasum pre/post equal (asserted in verify). The REC_CMD and pending_approval reads that the verb path requires are now gated on '[ -z $MODE ]' so the mode never trips on a fresh hand-crafted or in-flight proposal that lacks recommended_command. Exit codes: 0 for both eligible and ineligible verdicts, 1 for I/O errors (proposal not found), 2 for usage errors (missing --proposal/--mode/--verb, unknown mode value). Verify scripts/verify/m024-p04-fast-path-check.sh exercises six condition branches + read-only invariant + verb-path regression (approve still emits recommended_command_invoke=). All assertions pass on first run.

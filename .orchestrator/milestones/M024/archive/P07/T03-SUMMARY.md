---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "M024/P07"
milestone: "M024"
provides:
  - "proposal-emit.sh wired to design-gate-classify.sh + recommended_command guard against orphan orchestrator:design; approval-gate.sh accepts manual|skip verbs delegating to design-gate-degradation.sh; templates/intake-proposal.md gains pending_design_authored_manually transient key; 3 new verify scripts (skip-branch, manual-branch, approval-gate-design-verbs)"
requires:
  - "T01 (design-gate-classify.sh), T02 (design-gate-degradation.sh), P03 approval-gate.sh, P06 proposal-emit.sh axes-from infrastructure"
affects:
  - "T04 (schema D-row append for pending_design_authored_manually), T05 (suite + write-confinement)"
key_files:
  - "scripts/intake/proposal-emit.sh, scripts/intake/approval-gate.sh, templates/intake-proposal.md, scripts/verify/m024-p07-skip-branch.sh, scripts/verify/m024-p07-manual-branch.sh, scripts/verify/m024-p07-approval-gate-design-verbs.sh"
key_decisions:
  - "Recommended_command guard runs after axis resolution and uses inline (env-override + disk-probe) probe shape rather than --probe-only since proposal not yet rendered; DESIGN_AXES_DONE flag mirrors PARA/SPEC/QA pattern; manual/skip verbs in approval-gate forward stdout/stderr from design-gate-degradation.sh verbatim"
patterns_established:
  - "DESIGN_AXES_DONE deep-classifier skip flag; inline-probe-shape for pre-render guards; transient frontmatter key (pending_design_authored_manually) initialized false on every fresh emit, only mutator is manual-branch handler"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P07/tasks/T03-PAYLOAD.md"
duration: "240"
verification_result: "pass"
completed_at: "2026-04-26T13:06:25Z"
---

T03 wires the design-gate classifier and degradation paths into the existing intake pipeline. proposal-emit.sh now invokes design-gate-classify.sh (input + spec-path modes) after PARA/SPEC overrides, sets DESIGN_AXES_DONE=1 on classifier success, writes a deep-classifier rationale citing the token list, and applies a recommended_command guard that forces tier-derived fallback when design_gate=walkthrough but M023 has not shipped (probe = env override OR commands/design.md + Pass.N marker). approval-gate.sh adds manual|skip verbs that pre-validate design_gate=walkthrough then delegate to design-gate-degradation.sh, forwarding its exit code. templates/intake-proposal.md gains pending_design_authored_manually transient key, initialized false in proposal-emit.sh and swapped alongside the existing design_authored_manually slot. Three new verify scripts cover skip-branch frontmatter mutations, manual-branch halt+idempotent+follow-up flow, and approval-gate validation (rejects skip/manual on non-walkthrough proposals and on live M023 probe). All seven P07 verify scripts pass; P01 + P03 suites unchanged.

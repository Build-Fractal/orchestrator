---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M024/P07"
milestone: "M024"
provides:
  - "scripts/intake/design-gate-degradation.sh; scripts/verify/m024-p07-degradation-script.sh; scripts/verify/m024-p07-pinned-message.sh; scripts/verify/m024-p07-m023-probe.sh"
requires:
  - "P01 (proposal-emit.sh, intake-proposal.md template); P03 (route-to-specify.sh invoke-time probe pattern, sed -i.bak frontmatter mutation idiom)"
affects:
  - "P07/T03 (wires probe-only output into proposal-emit.sh recommended_command slot); P07/T04 (approval-gate.sh manual/skip verbs delegate here)"
key_files:
  - "scripts/intake/design-gate-degradation.sh,scripts/verify/m024-p07-degradation-script.sh,scripts/verify/m024-p07-pinned-message.sh,scripts/verify/m024-p07-m023-probe.sh"
key_decisions:
  - "Invoke-time M023 probe (no caching across invocations) per #DQ-2 option b; FR-7 message byte-pinned across three sites; M023_SHIPPED_PROBE_OVERRIDE closed enum stub|live for regression testing; pending_design_authored_manually transient frontmatter flag for manual-branch first/follow-up state; manual branch keeps pending_approval=true on completion (no auto-proceed)"
patterns_established:
  - "Two-mode pure-leaf script (probe-only emitter + branch-mode mutator); env-override matrix with synthetic ROOT for positive disk-probe testing; idempotent manual-branch follow-up (re-invoke until DESIGN.md exists)"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P07/tasks/T02-PAYLOAD.md"
duration: "300"
verification_result: "pass"
completed_at: "2026-04-26T13:02:12Z"
---

T02 ships the design-gate degradation path for pre-M023 checkouts. design-gate-degradation.sh runs the M023-shipping probe (env-override stub|live or disk probe of commands/design.md + Pass.<N> marker), and in branch mode emits the FR-7 pinned message to stderr before dispatching skip (mutates design_skipped=true, pending_approval=false, proceeded_at) or manual (first-invoke halts with pending_design_authored_manually=true; follow-up flips design_authored_manually=true + pending_approval=true once DESIGN.md exists at the expected path). Branch verbs reject if probe passes (M023 has shipped) or design_gate is not walkthrough — exit 2 with actionable error. Three verify scripts cover probe-only mode + branch validation, FR-7 byte-stability across the three pinned sites + stderr emission, and the env-override matrix with a synthesized ROOT proving positive disk-probe behavior. All three exit 0 with PASS lines.

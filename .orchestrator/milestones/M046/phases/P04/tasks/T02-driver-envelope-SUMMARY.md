---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M046"
provides:
  - "Envelope-integrated self-continue-drive.sh: --unattended flag (FR-6 default OFF, no config enable) plus --max-budget-usd/--max-continuations/--max-wall-clock-s/--segment-reserve-usd/--thrash-threshold/--watchdog-poll-s/--cost-log flags, sources scripts/lifecycle/unattended-envelope.sh, FR-13 in-driver fail-closed refuse-to-start gate (SELF_CONTINUE:REFUSE reason=caps-unset|caps-invalid, exit 2, no ledger no spawn, silent MAX_CONT=20 default DEAD on unattended path), backgrounded child plus foreground envelope_watchdog SIGKILL with 10-arg start_epoch for elapsed_s/cap_s wall-clock reason, hard-limit env exports into child (ORCHESTRATOR_UNATTENDED/_MAX_BUDGET_USD/_BUDGET_REMAINING_USD/_WALL_CLOCK_DEADLINE_EPOCH/_MAX_CONTINUATIONS), reserve-before-spawn then boundary true-up from claude -p JSON total_cost_usd else forfeit max(reserve,observed), kill-reason-to-distinct-terminal map (BUDGET_EXCEEDED/WALL_CLOCK_EXCEEDED/STOPPED stage=mid-segment vs generic CHILD_ABORT) with pre-spawn wall-clock and budget ceiling checks, FR-12 SELF_CONTINUE:THRASH terminal at default 2 no-progress segments (unattended-only); plus tools/verify/m046-p04-fail-closed.sh (SC-8, 7 cases direct-driver-bypass) and tools/verify/m046-p04-attended-parity.sh (FR-17 wrapper over 4 P02 driver verifiers)"
requires:
  - "scripts/lifecycle/unattended-envelope.sh (T01, 11 envelope_ functions), P02-hardened self-continue-drive.sh, four m046-p02 driver verifiers"
affects:
  - "T03 (budget-kill/reserve harnesses drive this), T04 (stop-file/thrash/wall-clock harnesses drive this), T05 (docs+suite -- commands/auto.md REFUSE/terminal-vocabulary doc mirror deferred here)"
key_files:
  - "scripts/lifecycle/self-continue-drive.sh, tools/verify/m046-p04-fail-closed.sh, tools/verify/m046-p04-attended-parity.sh, scripts/lifecycle/unattended-envelope.sh"
key_decisions:
  - "FR-17 byte-parity preserved by guarding every new runtime path behind UNATTENDED=true -- attended run_child line and P02 CHILD_ABORT block kept byte-identical (else-branch and untouched block), proven by legacy-parity golden 6/6 plus full P02 suite 11/11; fail-closed gate placed after OUTCOME_FILE block and BEFORE the capability probe and loop so refusal costs no ledger and no spawn; REFUSE shape chosen as SELF_CONTINUE:REFUSE reason=<library-first-word> to reuse envelope_caps_problems output verbatim; watchdog zombie-reaping verified on this macOS (kill -0 loop terminates on normal child exit, wait returns correct rc) before trusting the background-child+foreground-watchdog pattern; COST_BASELINE_LINES uses an if-block not [ -f ] && assign to stay set -e safe; reconcile runs BEFORE kill-reason mapping so the ledger is complete at terminal time and the envelope terminal precedes the generic CHILD_ABORT line; commands/auto.md doc mirror deferred to T05 (docs+suite) since no docs-shape verifier is in this task gate"
patterns_established:
  - "Envelope integration as an all-behind-UNATTENDED=true overlay on a hardened driver with the attended path byte-frozen and a dedicated FR-17 parity wrapper as the regression oracle; direct-driver-invocation-with-sentinel-stub as the SC-8 bypass-the-CLI fail-closed proof (refusal keeps sentinel absent, passing gate lets it appear); reason-file-first-word-to-distinct-terminal case mapping consuming the watchdog atomic handoff"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P04/"
duration: "1600s"
verification_result: "pass"
completed_at: "2026-07-13T17:47:29Z"
---

T02 wired the T01 envelope library into scripts/lifecycle/self-continue-drive.sh entirely behind an --unattended opt-in (FR-6 default OFF): eight new flags, an in-driver FR-13 fail-closed refuse-to-start gate (exit 2 SELF_CONTINUE:REFUSE with no ledger and no spawn, killing the silent MAX_CONT=20 default on the unattended path), a backgrounded child plus foreground envelope_watchdog SIGKILL passing the driver run-start epoch for elapsed_s/cap_s wall-clock reasons, hard-limit env exports into the child, reserve-before-spawn with segment-boundary true-up from the child JSON total_cost_usd (else forfeit max of reserve and observed), a kill-reason-to-distinct-terminal map (BUDGET_EXCEEDED/WALL_CLOCK_EXCEEDED/STOPPED stage=mid-segment vs generic CHILD_ABORT) plus pre-spawn wall-clock and budget ceilings, and the FR-12 THRASH terminal at the default 2 no-progress segments; FR-17 byte-parity held by guarding every new path behind UNATTENDED=true and freezing the attended run_child line and the P02 CHILD_ABORT block, proven by fail-closed 7/7, attended-parity 4/4, envelope-unit 32/32 regression, full P02 suite 11/11, and sh -n silent

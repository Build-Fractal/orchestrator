---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M046"
provides:
  - "scripts/lifecycle/unattended-envelope.sh sourceable POSIX-sh envelope library (side-effect-free at source time; 11 public functions: envelope_caps_problems FR-13 fail-closed caps validation with caps-unset-over-caps-invalid precedence and explicit-set flag so silent MAX_CONT defaults are rejected, envelope_ledger_init/reserve/reconcile/forfeit append-only budget-lease ledger, envelope_next_segment, envelope_spent_total one-awk-pass FR-8 math where reconcile/forfeit override reserve and bare reserve counts as spent, envelope_observed_cost non-null unit_close-only summation with line-offset baseline matched to the production write-summary.sh printf key shape, envelope_parse_total_cost fail-closed-empty total_cost_usd extraction, envelope_write_kill_reason atomic tmp.PID+mv-f write, envelope_watchdog stop-file/wall-clock/cost-derived-budget kill loop with reason-written-first-then-SIGKILL ordering),tools/verify/m046-p04-envelope-unit.sh 32-assertion unit verifier (SUMMARY: pass=32 fail=0) covering all functions plus 3 live-PID watchdog kill legs"
requires:
  - "scripts/knowledge/write-summary.sh _ws_emit_unit_close printf template key names,scripts/lifecycle/self-continue-drive.sh lines 109-113 P02 atomic temp+rename shape,P01 CADENCE-FINDINGS.md #Q-4 cost-source split (JSONL grain nullable / JSON result truth)"
affects:
  - "T02 (driver sources the lib), T03/T04 (harnesses exercise it)"
key_files:
  - "scripts/lifecycle/unattended-envelope.sh,tools/verify/m046-p04-envelope-unit.sh"
key_decisions:
  - "envelope_watchdog accepts an optional 10th arg start_epoch: with it the wall-clock reason is the full contract line elapsed_s=/cap_s= (T02 driver knows its start epoch); without it the line degrades honestly to now_epoch=/deadline_epoch= since elapsed is not derivable from deadline alone - the binding wall-clock-exceeded prefix is stable either way,watchdog uses a killed-flag so the kill reason is written exactly once then the loop only waits for kill -0 to fail,spent-total keyed by segment number with reconcile+forfeit amounts accumulating into a single override bucket per segment,no local keyword anywhere - underscore-prefixed per-function variable namespaces for bash-3.2/dash/ksh portability,verifier float compares use awk 1e-6 tolerance never string equality"
patterns_established:
  - "static-grep+behavioral-residue dual-leg atomic-write assertion reused from P02 applied to a library function,live-PID watchdog unit legs via backgrounded sleep and a delayed-append cost stub - no driver spawn and zero LLM spend,ledger append-only invariant asserted by re-running init and checking exactly one line added"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P04/"
duration: "420s"
verification_result: "pass"
completed_at: "2026-07-13T17:24:42Z"
---

T01 created scripts/lifecycle/unattended-envelope.sh, the sourceable POSIX-sh brain of the M046 P04 unattended envelope: fail-closed caps validation (FR-13, unset caps refuse with caps-unset missing=csv and an explicit-set flag so the silent MAX_CONT=20 default is never accepted), the append-only reserve-then-spend budget-lease ledger with one-awk-pass spent-total math where a reconcile or forfeit overrides its segment's reserve and an unreconciled reserve counts as spent (FR-8 fail-closed), a mid-segment observed-cost probe summing only numeric estimated_cost_usd values on unit_close records past a line baseline (matched to the production write-summary.sh printf template, null contributes 0 per P01 #Q-4), a fail-closed-empty total_cost_usd parser for the segment-boundary true-up, an atomic tmp.PID+mv-f kill-reason writer extending the P02 torn-marker guarantee, and the foreground watchdog loop that checks stop-file then wall-clock then cost-derived budget each tick and writes the reason first before SIGKILL (FR-7/FR-10/D016); the companion unit verifier tools/verify/m046-p04-envelope-unit.sh proves every contract in mktemp isolation including three live-PID kill legs and ends SUMMARY: pass=32 fail=0, with sh -n clean; one documented interface note: envelope_watchdog grew an optional trailing start_epoch arg because elapsed_s/cap_s in the contract's wall-clock reason line are not derivable from the deadline epoch alone - the 9-arg form keeps the binding wall-clock-exceeded prefix with epoch fields, and neither self-continue-drive.sh nor auto-loop.sh was touched (CON-2/CON-3 preserved for T02).

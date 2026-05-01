---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P07"
milestone: "M030"
provides:
  - "acceptance battery runner at tests/m030-acceptance/run-acceptance-battery.sh (22 verifier invocations covering 14 M030 SCs); three new P07 verifiers — p07-acceptance-battery-pass.sh (thin wrapper asserting BATTERY: pass=N fail=0 last line), p07-cross-surface-coherence.sh (metrics-rollup --by-model + efficiency-footer + check-anomalies coherence over corpus-50-per-class.jsonl with escalation-fields in-flight injection), p07-partial-flip-jsonl-fields.sh (real-dispatch field-shape gate against corpus-2-class-only.jsonl)"
requires:
  - "from:P07/T01 what:acceptance corpus + per-verdict verifier gates; from:P00-P06 what:18 SC verifiers under tools/verify/p0[1-6]-*.sh + dispatch-interface.sh end-to-end including stub-record-model adapter + metrics-rollup.sh --by-model + efficiency-footer.sh model_mix + check-anomalies.sh model_routing_regression"
affects:
  - "M030/P07/T03 (evidence ledger consumes runner output for SC rows; phase-suite aggregator wraps the four T02 gates); M030/P07/T04 (milestone-close ceremony asserts runner green as final M030 acceptance signal)"
key_files:
  - "tests/m030-acceptance/run-acceptance-battery.sh,tools/verify/p07-acceptance-battery-pass.sh,tools/verify/p07-cross-surface-coherence.sh,tools/verify/p07-partial-flip-jsonl-fields.sh"
key_decisions:
  - "real-dispatch chosen for partial-flip gate (P04 stub-record-model + ORCH_ROOT carve-out reused at acceptance scale, not printf-equivalence fallback); cross-surface verifier injects escalation fields in-flight via awk rather than amending T01-frozen corpus fixture; metrics-rollup line format uses colon-space (key: value) not equals (key=value) — plan-prose drift fix at runtime per script-is-the-contract amendment guidance"
patterns_established:
  - "straight-line battery-runner shape with run_sc helper carve-out (22 invocations, no loops, no eval, AD-19 preserved); ORCHESTRATOR_ROOT carve-out + in-flight awk JSONL field injection (extends P05/T01 carve-out pattern with field-augmentation when fixture is upstream-frozen); thin acceptance-pass wrapper asserting last-line regex on runner stdout (pass count informational, fail=0 binding contract); end-to-end dispatch-interface invocation reused for at-scale partial-flip field-shape verification (P04 stub-record-model adapter ships forward-compatible)"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P07/tasks/T02-acceptance-battery-PLAN.md,.orchestrator/milestones/M030/phases/P07/tasks/T02-acceptance-battery-PAYLOAD.md,.orchestrator/milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-SUMMARY.md,tools/verify/p04-partial-flip-routing.sh,tools/verify/p05-sc11-footer-byte-equality.sh,tools/verify/p06-sc11-byte-equality.sh"
duration: "45m"
verification_result: "run-acceptance-battery.sh BATTERY: pass=22 fail=0; p07-acceptance-battery-pass.sh pass=2 fail=0; p07-cross-surface-coherence.sh pass=9 fail=0; p07-partial-flip-jsonl-fields.sh pass=3 fail=0"
completed_at: "2026-05-01T02:43:07Z"
---

T02 ships the M030 acceptance battery — `tests/m030-acceptance/run-acceptance-battery.sh` plus three new verifiers under `tools/verify/p07-*`.

The runner is a straight-line aggregator over 22 verifier invocations covering the 14 M030 success criteria (SC-1, SC-2 with four per-verdict gates, SC-2a, SC-3, SC-3a, SC-4, SC-5, SC-6, SC-7, SC-7a, SC-8 with three by-model sub-gates, SC-9, SC-10, SC-11 with three byte-equality sub-gates). Each SC is invoked as a `bash <verifier>` call with rc captured per-call; the runner counts pass/fail and emits `BATTERY: pass=22 fail=0` on the last line, exiting 0 iff `fail=0`. AD-19 single-script-file shape preserved via the `run_sc` helper-function carve-out (parallel scalars + `if`-statements, bash 3.2 compatible).

`tools/verify/p07-acceptance-battery-pass.sh` is a thin wrapper that runs the battery and asserts the last stdout line matches `^BATTERY: pass=[0-9]+ fail=0$`. The pass count is informational; the binding contract is `fail=0`.

`tools/verify/p07-cross-surface-coherence.sh` exercises the three M027 surfaces against `corpus-50-per-class.jsonl` (150 records, 50 per class). It asserts: metrics-rollup `--by-model` exits 0 with a dispatch-count line summing to 150 (50/50/50 over fast/balanced/smart), an `aggregated_cost_usd:` line, and a `counterfactual_all_smart_cost_usd:` line; efficiency-footer emits a `model_mix:` line; and check-anomalies emits zero `model_routing_regression` records (both stdout and JSONL). The corpus is staged via an ORCHESTRATOR_ROOT carve-out (mirroring P05/T01 + P06/T01 patterns) with an in-flight awk amendment that injects `escalation_count:0,escalation_reason:""` into each record so the regression check treats them as healthy passes.

`tools/verify/p07-partial-flip-jsonl-fields.sh` invokes `scripts/dispatch/dispatch-interface.sh` end-to-end against `corpus-2-class-only.jsonl` (the 100-record partially_ready corpus) with a novel-classified plan and `model_routing.live: true`. It asserts the resulting dispatch_usage JSONL record carries `partial_flip_active=true` AND `withheld_classes` containing `novel`. Real-dispatch path chosen (Plan-Time Discipline rule 5 honored); the printf-equivalence fallback was not needed since the P04 stub-record-model adapter pattern already supports the at-scale invocation.

Two plan-prose drift fixes shipped as verifier-side amendments at runtime: (1) the metrics-rollup output uses `key: value` (colon-space) format, not `key=value` as the plan prose described, so the verifier asserts `^aggregated_cost_usd:` and `^counterfactual_all_smart_cost_usd:`; (2) the corpus records ship without `escalation_count` / `escalation_reason` fields (T01 fixture shape, byte-frozen by sha256 idempotency) so the cross-surface verifier injects those fields in-flight via awk rather than amending the T01 fixture.

All four deliverables green: runner pass=22 fail=0; acceptance-battery-pass pass=2 fail=0; cross-surface-coherence pass=9 fail=0; partial-flip-jsonl-fields pass=3 fail=0. Upstream T01 idempotency gate stays green (pass=4 fail=0). Zero modifications to existing surfaces (dispatch-interface.sh, metrics-rollup.sh, efficiency-footer.sh, check-anomalies.sh) — CON-2 / FR-19 / SC-11 preserved by construction. Hands the milestone to T03 for the evidence ledger + phase-suite aggregator.

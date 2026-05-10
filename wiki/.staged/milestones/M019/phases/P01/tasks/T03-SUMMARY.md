---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M019"
provides:
  - "scripts/dispatch/dispatch-interface.sh dispatch_usage JSONL emitter; _di_emit_dispatch_usage helper with pricing-degradation C4 handling; tmp-file cost capture that preserves _PRICING_WARNING_REASON across subshell boundary"
requires:
  - "from:P01/T01 what:scripts/lib/pricing.sh (pricing_estimate_cost_usd, pricing_warning_reason, pricing_last_updated, chars_to_tokens_quartile); from:P01/T01 what:scripts/verify/m019-schema.sh (dispatch_usage + source enum); from:P01/T02 what:fixture-mode log-path carve-out pattern"
affects:
  - "T04,T05,T06,P01"
key_files:
  - "scripts/dispatch/dispatch-interface.sh"
key_decisions:
  - "C4 never-abort-on-pricing-degradation; SC-1 exactly-one-dispatch_usage-per-dispatch; SC-6 byte-identical-stdout; C5 bash 3.2; MEM004 carve-out for dispatch-internal emitter"
patterns_established:
  - "tmp-file cost capture pattern — route pricing_estimate_cost_usd stdout to a mktemp file so module-scoped _PRICING_WARNING_REASON survives in the calling shell (subshell side-channel loss workaround); adapter-failed / adapter-malformed override warnings for pricing-independent error paths; post-BACKEND three-branch emit (backend_crashed exit 5; backend_malformed schema exit 6; backend_malformed type exit 6) plus happy-path emit = exactly one dispatch_usage per dispatch after BACKEND is resolved"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P01/tasks/T03-PAYLOAD.md, .orchestrator/milestones/M019/phases/P01/tasks/T03-PLAN.md, scripts/dispatch/dispatch-interface.sh"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-18T03:19:32Z"
---

T03 wires the second Tier 1 emitter: scripts/dispatch/dispatch-interface.sh now appends exactly one dispatch_usage JSONL record per invocation after BACKEND is resolved, paired with every payload_breakdown record written by build-context.sh (T02).

The record carries twelve fields: record_type, unitId (Mxxx/Pxx/Txx derived from the task-plan path via grep -oE; basename-fallback on miss), milestone, phase, task, backend (BACKEND resolved by the registry), input_tokens_estimate (wc -c of PAYLOAD divided by 4 via chars_to_tokens_quartile — AD-1), output_tokens_estimate (Tier 1 placeholder 0), estimated_cost_usd (pricing_estimate_cost_usd; JSON literal null on degradation), pricing_version (last_updated from pricing.yml; empty string on missing-file), model (ORCH_MODEL env or INTENSITY_METADATA model: key), source (estimate), and timestamp (ISO-8601 UTC). pricing_warning is present ONLY on the degradation path (missing | stale:Nd | no-rate:MODEL | adapter-failed | adapter-malformed).

Emission points: four in total. (1) Happy-path end, before echo adapter_output. (2) Adapter-crashed branch (exit 5) with pricing_warning=adapter-failed. (3) Adapter-malformed branch missing schema_version (exit 6) with pricing_warning=adapter-malformed. (4) Adapter-malformed branch missing type (exit 6) with pricing_warning=adapter-malformed. Pre-BACKEND branches (input_invalid exit 2; registry_error exit 3; backend_unavailable exit 4) do NOT emit, per SC-1 scope (every exit after BACKEND is resolved).

Key implementation note: the plan's suggested cost_usd=$(pricing_estimate_cost_usd ...) + warning=$(pricing_warning_reason) sequence loses the warning because command substitution is a subshell — the module-scoped _PRICING_WARNING_REASON is set in the subshell and dropped. Fix: route the cost through a mktemp file so pricing_estimate_cost_usd runs in the current shell; the side-channel then survives for the pricing_warning_reason read.

Verification evidence: three-scenario live probe (happy path, adapter-crash, pricing-missing) all produce exactly one record with expected shape; stdout is byte-identical to the adapter output (SC-6); m019-schema.sh validates 1/1 fixture record and 11/11 repo records as PASS; all four M008/P02 dispatch interface gates (routing, arguments, agnostic, bash32-compat, integration-e2e) still PASS; anti-pattern-lint.sh still PASS for agent-facing content (dispatch-interface.sh is infrastructure, not agent-facing).

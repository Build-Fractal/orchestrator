---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M030"
provides:
  - "dispatch-interface escalation loop fast-balanced-smart cap=2,_di_tier_at_rank helper,_di_emit_escalation_cap_hit helper,2 additive shadow-on JSONL fields (escalation_count integer 0..2 + escalation_reason verifier_fail-or-empty),escalation_cap_hit record (record_type+unitId+final_count=2+timestamp),5 new T03 verifiers (p04-sc4-escalation-sequence p04-sc5-escalation-cap p04-con5-no-fourth-record p04-con6-prior-records-bit-identical p04-escalation-fields-enum),references/model-routing.md Live Routing section + 2 new See Also bullets"
requires:
  - "T02"
affects:
  - "P05,P06,P07"
key_files:
  - "scripts/dispatch/dispatch-interface.sh,references/model-routing.md,tools/verify/p04-sc4-escalation-sequence.sh,tools/verify/p04-sc5-escalation-cap.sh,tools/verify/p04-con5-no-fourth-record.sh,tools/verify/p04-con6-prior-records-bit-identical.sh,tools/verify/p04-escalation-fields-enum.sh"
key_decisions:
  - "emit-then-increment ordering: success record on iteration N reads escalation_count=N (number of preceding failures); escalation_reason empty on success and verifier_fail on every failed attempt including cap-hit; CON-5 hard-cap enforced at adapter-invocation site (3rd failure stops loop before 4th adapter call); CON-6 verified via inode-preservation + first-2-lines hash equality after synthetic append (synchronous-dispatch proxy for mid-escalation byte-stability); shadow-off printfs UNTOUCHED (additive-only schema preserves SC-11 byte-equality); _DI_SHADOW_ROUTED + _DI_LIVE_MODEL_FLAG mutated in-place between iterations so _di_emit_dispatch_usage reads new tier values via parent-shell scope; happy-path emit at line 960 gated on escalation_active=0 to prevent duplicate dispatch_usage record on success path; escalation_count + escalation_reason declared at top-level (after ORCH_ROOT) so gate-block path inherits defaults (count=0 reason=empty); references/model-routing.md Live Routing co-locates with gate-verifier ship date mirroring P03/T03 Operator Overrides pattern"
patterns_established:
  - "MEM004 carve-out extends to dispatch-internal escalation loop body; awk section-walker re-resolves resolution.<tier>.claude-code in-loop without hardcoded literals (CON-3-clean); programmable fail-counter fixture adapter (stub-fail-n.sh) gates SC-4/SC-5/CON-5 via STUB_FAIL_COUNTER_FILE read-decrement + STUB_FAIL_COUNTER_INVOCATIONS_FILE side-channel for invocation-count assertions; tmp-file-staged head-shasum-cut chain unrolling (AP-009 compliant); inode-preservation check via stat -f %i (macOS) with stat -c %i fallback (Linux portability); per-scenario tmp_root + cleanup pattern reused from P03 verifiers"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P04/tasks/T03-escalation-loop-PLAN.md,.orchestrator/milestones/M030/phases/P04/tasks/T03-escalation-loop-PAYLOAD.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-30T17:51:35Z"
---

T03 amends scripts/dispatch/dispatch-interface.sh with the live-routing escalation loop and lands the five gate verifiers that prove SC-4 / SC-5 / CON-5 / CON-6 / escalation-fields-enum mechanically. Five deliverables ship as a single atomic commit.

Block A -- _di_tier_at_rank helper. Inserted after _di_tier_rank around line 188. Maps numeric rank (0/1/2) to symbolic tier (fast/balanced/smart). Inverse of _di_tier_rank, used by the escalation loop to compute next-higher tier on verifier failure.

Block B -- escalation loop wrapping the adapter invocation. Active only when M030_SHADOW_MODE=1 AND CLAUDECODE=1 AND _DI_LIVE_MODEL_FLAG non-empty (live-routing flip-gate cleared AND task class flippable). Otherwise the original single-shot invocation runs (preserves T02 + pre-T02 behavior). Loop semantics: on rc=0 emit happy-path dispatch_usage record + break; on rc!=0 with count<2 emit current record (verifier_fail) then increment count + recompute tier via _di_tier_at_rank + re-resolve _DI_LIVE_MODEL_FLAG via awk section-walker against templates/model-routing.yml (CON-3-clean); on rc!=0 with count>=2 emit final record (verifier_fail) + emit ONE escalation_cap_hit record + emit dispatch-error.md + exit 5. The cap is enforced at the adapter-invocation site -- no fourth adapter invocation is ever issued.

Block C -- printf format-string extension. Two shadow-on printfs (lines ~622 happy-path + ~660 degradation) gain the escalation_count (integer) and escalation_reason (string) fields after override_source. The two shadow-OFF printfs are untouched -- SC-11 byte-equality preserved (verified by p04-additive-schema.sh delegating to p02-additive-schema.sh).

Block D -- _di_emit_escalation_cap_hit helper. Sibling of _di_emit_dispatch_usage. Same log-file resolution chain, gated CC-only, append-only via >>, idempotent (caller guarantees one invocation per cap event). Emits a single-line JSON record with record_type=escalation_cap_hit, unitId, milestone, phase, task, final_count=2, timestamp.

Top-level shell-scoped state. escalation_count=0 and escalation_reason="" declared after ORCH_ROOT so _di_emit_dispatch_usage reads them via parent-shell scope (no signature change to the existing helper). The gate-block path (FR-9 / SC-2a / live: true with evidence_insufficient verdict) inherits the defaults -- its emitted record carries escalation_count=0, escalation_reason="".

Happy-path emit gating. The post-conformance happy-path emit at line ~960 is now gated on escalation_active=0. When the loop ran, the success record was already emitted inside the loop body; firing the post-conformance emit again would produce a duplicate dispatch_usage record (violating SC-1 + the SC-4 record-count assertion).

Five new verifiers:

- p04-sc4-escalation-sequence.sh (6 assertions) -- fail-twice-then-pass scenario. Asserts dispatch exits 0, exactly 3 dispatch_usage records, model_used sequence fast->balanced->smart (resolved at runtime from templates/model-routing.yml), record 3 escalation_count=2 + reason="".
- p04-sc5-escalation-cap.sh (6 assertions) -- fail-three-times scenario. Asserts dispatch exits nonzero, exactly 3 dispatch_usage records + 1 escalation_cap_hit, cap_hit final_count=2 + unitId match, every dispatch_usage carries escalation_reason=verifier_fail, record 3 count=2.
- p04-con5-no-fourth-record.sh (7 assertions) -- fail-four-times scenario. SC-5's six assertions plus an invocation-count check via the stub-fail-n STUB_FAIL_COUNTER_INVOCATIONS_FILE side-channel: the stub adapter is invoked exactly 3 times, never 4. This is the CON-5 hard-cap gate at the adapter-invocation site, not just the JSONL emit site.
- p04-con6-prior-records-bit-identical.sh (2 assertions) -- append-only invariant. Pre-creates the log file with :>, captures inode (stat -f %i on macOS, stat -c %i on Linux), runs dispatch (3 records appended via the loop), captures inode again, asserts equal (rules out mv/cp/swap shapes). Then computes SHA-256 of head -n 2 of the log, appends a synthetic line, recomputes SHA-256, asserts equal (proves prior records' bytes are stable across appends -- the file-system invariant CON-6 ultimately asserts). The head/shasum/cut chain is unrolled into tmp-file stages per AP-009.
- p04-escalation-fields-enum.sh (7 assertions) -- three scenarios in one verifier. Scenario A (no-failure, 1 record, count=0 reason=""). Scenario B (fail-twice-then-pass, 3 records, sequence 0/vf, 1/vf, 2/""). Scenario C (fail-three-times, 3 records, sequence 0/vf, 1/vf, 2/vf + cap_hit).

references/model-routing.md amendment. New Live Routing section between Operator Overrides and See Also. Documents activation (model_routing.live: true), the four-verdict gate table (ready/partially_ready/evidence_insufficient/block to action), the escalation chain (fast->balanced->smart, cap=2), the two new JSONL fields (escalation_count + escalation_reason with semantics + ordering), the extended override precedence chain (kill-switch supersedes live; live runs after override-resolution; plain-routed continues unchanged), the operator workflow shadow-to-live, and the CC-only launch posture. See Also gains 2 new bullets pointing at the 5 T03 verifiers + the stub-fail-n.sh fixture adapter.

Verification. All twelve P04 verifiers green: pass=1 p04-additive-schema; pass=6 p04-override-source-enum-extended; pass=3 p04-sc2a-shadow-gate-block; pass=3 p04-sc3-live-mechanical; pass=6 p04-partial-flip-routing; pass=7 p04-con3-live-closure; pass=4 p04-con4-live-killswitch; pass=6 p04-sc4-escalation-sequence (NEW); pass=6 p04-sc5-escalation-cap (NEW); pass=7 p04-con5-no-fourth-record (NEW); pass=2 p04-con6-prior-records-bit-identical (NEW); pass=7 p04-escalation-fields-enum (NEW). Total: 58 assertions across 12 verifiers, 0 fail. Upstream phase suites still green: p02-phase-suite pass=9 fail=0; p03-phase-suite pass=8 fail=0. T04 (phase-suite + close) takes the baton.

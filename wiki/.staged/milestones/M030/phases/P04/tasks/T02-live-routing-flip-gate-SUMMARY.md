---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M030"
provides:
  - "scripts/dispatch/dispatch-interface.sh _di_resolve_live_routing helper extracted top-level (idempotent via _DI_RESOLVED),live-routing branch with shadow-compare programmatic flip-gate (FR-9 / D-A2),per-class partial-flip authorization branching (D-A3),conditional --model <id> adapter passing via dual-invocation if/else,kill-switch live: true is inactive stderr warning (CON-4 compound),top-level shadow-gate-blocked dispatcher branch + exit code 7,tools/verify/p04-sc2a-shadow-gate-block.sh,tools/verify/p04-sc3-live-mechanical.sh,tools/verify/p04-partial-flip-routing.sh,tools/verify/p04-con3-live-closure.sh,tools/verify/p04-con4-live-killswitch.sh,override_source enum sixth value shadow_gate_blocked emitted on shadow-on dispatch_usage records (graduates p04-override-source-enum-extended.sh Scenario F to strict)"
requires:
  - "from:P04/T01 what:tests/fixtures/m030-p04 (5 plans + 3 configs + 3 corpora + round-trip-stage),from:P04/T01 what:scripts/dispatch/adapters/backend/stub-record-model.sh (--model recorder),from:P04/T01 what:tools/verify/p04-additive-schema.sh + p04-override-source-enum-extended.sh,from:P03/T02 what:scripts/dispatch/dispatch-interface.sh override-resolution block (kill-switch->plan->floor->none precedence chain),from:P02/T03 what:scripts/diagnostics/shadow-compare.sh --corpus flag (4-verdict aggregator),from:P01/T03 what:templates/model-routing.yml (routing/resolution SSOT for runtime tier resolution; CON-3 closure)"
affects:
  - "P04/T03,P04/T04"
key_files:
  - "scripts/dispatch/dispatch-interface.sh,tools/verify/p04-sc2a-shadow-gate-block.sh,tools/verify/p04-sc3-live-mechanical.sh,tools/verify/p04-partial-flip-routing.sh,tools/verify/p04-con3-live-closure.sh,tools/verify/p04-con4-live-killswitch.sh"
key_decisions:
  - "extract _di_resolve_live_routing as top-level helper (Option 1 from plan) so dispatcher can run gate-block before adapter invocation; idempotent helper via _DI_RESOLVED sentinel ensures emitter+dispatcher both call cheaply; M030_SHADOW_COMPARE_CORPUS env var as verifier seam (mirrors STUB_FAIL_COUNTER_FILE T01 pattern); dual adapter-invocation if/else preserves word-splitting safety per AD-19 (vs splicing dynamic flags); exit code 7 chosen for shadow_gate_blocked to disambiguate from adapter-failed=5 + adapter-malformed=6; live: true is inactive stderr warning placed inside the kill-switch branch alongside the existing min_tier inactive warning (CON-4 compound symmetry); shadow_gate_blocked verdict short-circuits BEFORE the routing-table awk extraction so no _DI_SHADOW_ROUTED is set (prevents leaking a tier into the shadow_routed JSONL field on gate-block); per-class authorization read-only of withheld_classes from shadow-compare verdict (D-A3 trust boundary; T02 does not re-validate)"
patterns_established:
  - "top-level resolution helper extracted alongside _di_tier_rank consumed by both dispatcher and emitter via top-level _DI_SHADOW_* / _DI_LIVE_* outputs; idempotency-via-sentinel pattern (_DI_RESOLVED=1 short-circuits second call); dual-invocation explicit if/else for conditional CLI flag passing (AD-19 word-split safe); env-var verifier seam (M030_SHADOW_COMPARE_CORPUS) for deterministic corpus injection without polluting CLI; per-stage tmp_root staging for multi-dispatch verifiers (partial-flip routing exercises 2 dispatches in one verifier); runtime-resolution-from-SSOT pattern carried forward (verifiers awk-extract resolution.fast.claude-code from templates/model-routing.yml rather than hardcode literals); HEAD-vs-working-tree per-pattern grep count CON-3 closure pattern reused from P03/T02; tolerant-to-strict graduation pattern (Scenario F flips from any-P03-enum to shadow_gate_blocked-only via observed-token semantics); shadow-gate-blocked exit code 7 for retry/operator escalation distinct from adapter failure modes"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P04/tasks/T02-live-routing-flip-gate-PLAN.md"
duration: "80m"
verification_result: "pass"
completed_at: "2026-04-30T17:16:36Z"
---

T02 amends `scripts/dispatch/dispatch-interface.sh` with the live-routing branch + programmatic flip-gate (FR-9 / D-A2), per-class partial-flip authorization (D-A3), and `--model <id>` adapter passing — closing the SC-2a / SC-3 / CON-3 / CON-4 gates. Five new verifiers ship co-scheduled with the artifact they gate (Plan-Time Discipline rule 2).

## What was built

1. **scripts/dispatch/dispatch-interface.sh — `_di_resolve_live_routing` helper extracted alongside `_di_tier_rank`.** The helper centralizes override resolution + live-routing + flip-gate logic so the dispatcher can run it BEFORE adapter invocation (the gate-block must fire before the adapter call). Idempotent via `_DI_RESOLVED` sentinel; outputs flow into top-level `_DI_SHADOW_*` (consumed by the emitter via local copies preserving the existing printf substitutions verbatim) and `_DI_LIVE_*` (consumed by the dispatcher for gate-block + `--model` flag passing). The kill-switch branch now additionally emits `model_routing_enabled=false: live: true is inactive` on stderr when both knobs are set (CON-4 / D-A5 compound). The shadow-on resolution block previously inside `_di_emit_dispatch_usage` is now a thin call to the helper followed by local-variable copies; the shadow-off printfs are byte-identical to pre-T02 (SC-11 preserved).

2. **Live-routing verdict branching inside the helper.** When `model_routing.live: true` AND no override fired, the helper invokes `bash scripts/diagnostics/shadow-compare.sh --corpus <path>` programmatically. The corpus path is `M030_SHADOW_COMPARE_CORPUS` (verifier seam, mirrors `STUB_FAIL_COUNTER_FILE` from T01) or falls back to the in-flight `execution-log.jsonl`. Verdict branching:
   - `evidence_insufficient` / `block` → `_DI_SHADOW_OVERRIDE_SOURCE=shadow_gate_blocked`, `_DI_LIVE_GATE_BLOCKED=1`. The dispatcher checks the sentinel before the adapter invocation; if set, emits `dispatch-error.md` (`error_type=shadow_gate_blocked`, `retry_eligible=true`, `escalation=operator`), appends the `dispatch_usage` JSONL record (so the gate-block is observable), and exits 7 (new code, disambiguates from `adapter-failed=5` / `adapter-malformed=6`).
   - `ready` → resolve `model_routed` + `model_used` via routing/resolution awk section-walkers; set `_DI_LIVE_MODEL_FLAG=$shadow_used`; the dispatcher passes `--model "$_DI_LIVE_MODEL_FLAG"` to the adapter.
   - `partially_ready` → set `partial_flip_active=true` + `withheld_classes=<csv>`; per-class authorization (D-A3): if the task's class is in `withheld_classes`, fall back to runtime default and leave `_DI_LIVE_MODEL_FLAG` unset (no `--model` passed); otherwise resolve and route live.

3. **Two adapter-invocation paths in the dispatcher.** Explicit if/else branch — with-`--model` and without — preserves word-splitting safety per AD-19 (a single dynamic-flag-splice would risk shell expansion bugs on the model id).

4. **Five new verifiers under `tools/verify/`:**
   - `p04-sc2a-shadow-gate-block.sh` — 3 assertions (nonzero exit + JSONL `shadow_gate_blocked` + adapter not invoked); gates SC-2a / FR-9 / D-A2.
   - `p04-sc3-live-mechanical.sh` — 3 assertions (JSONL `model_used` matches `resolution.fast.claude-code` resolved at runtime + stub-record-model received the same `--model` value + dispatch exit 0); gates SC-3.
   - `p04-partial-flip-routing.sh` — 6 assertions (3 per stage × 2 stages: mechanical flips, novel withheld); gates D-A3.
   - `p04-con3-live-closure.sh` — 7 patterns (claude-haiku- / claude-sonnet- / claude-opus- / gpt- / o1- / o3- / gemini-); HEAD-vs-working-tree per-pattern grep count comparison; gates CON-3.
   - `p04-con4-live-killswitch.sh` — 4 assertions (`override_source=disabled` + `model_used` matches runtime default + stderr names `live: true is inactive` + stderr names `min_tier: ... is inactive`); gates CON-4 / D-A5 / SC-7a-style compound.

## Verifier results

- `bash tools/verify/p04-additive-schema.sh` → SUMMARY: p04-additive-schema.sh pass=1 fail=0; exit 0.
- `bash tools/verify/p04-override-source-enum-extended.sh` → SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0; exit 0. **Scenario F graduated from tolerant to strict** post-amendment (override_source=shadow_gate_blocked observed).
- `bash tools/verify/p04-sc2a-shadow-gate-block.sh` → SUMMARY: p04-sc2a-shadow-gate-block.sh pass=3 fail=0; exit 0.
- `bash tools/verify/p04-sc3-live-mechanical.sh` → SUMMARY: p04-sc3-live-mechanical.sh pass=3 fail=0; exit 0.
- `bash tools/verify/p04-partial-flip-routing.sh` → SUMMARY: p04-partial-flip-routing.sh pass=6 fail=0; exit 0.
- `bash tools/verify/p04-con3-live-closure.sh` → SUMMARY: p04-con3-live-closure.sh pass=7 fail=0; exit 0.
- `bash tools/verify/p04-con4-live-killswitch.sh` → SUMMARY: p04-con4-live-killswitch.sh pass=4 fail=0; exit 0.

Regression: `p02-phase-suite.sh` pass=9 fail=0 + `p03-phase-suite.sh` pass=8 fail=0 (both green; SC-11 byte-equality + override-resolution chain preserved).

## Plan deviations

None of consequence. The plan offered two factorings (Option 1: extract `_di_resolve_live_routing` as top-level helper; Option 2: in-place `--resolve-only` flag) — Option 1 was chosen and implemented per the plan's recommendation. The helper is idempotent via `_DI_RESOLVED`. The kill-switch's existing `min_tier inactive` warning was preserved verbatim and the `live: true is inactive` warning was added next to it inside the helper (the in-emitter copy was removed because the helper now owns the resolution).

One micro-deviation worth recording: the plan suggested staging `phases/` carve-out via `ORCH_ROOT/phases/`; the existing P03 verifiers do that and T02's verifiers follow suit verbatim. The tmp_root is wiped at end-of-test rather than retained, which matches the P03 verifier shape.

## Files touched

- scripts/dispatch/dispatch-interface.sh — modified (helper extracted; emitter slimmed; dispatcher gains gate-block + conditional `--model`).
- tools/verify/p04-sc2a-shadow-gate-block.sh — new (3 assertions; shadow-gate-block enforcement).
- tools/verify/p04-sc3-live-mechanical.sh — new (3 assertions; live-routing happy path).
- tools/verify/p04-partial-flip-routing.sh — new (6 assertions; D-A3 per-class authorization).
- tools/verify/p04-con3-live-closure.sh — new (7 patterns; CON-3 closure).
- tools/verify/p04-con4-live-killswitch.sh — new (4 assertions; CON-4 / D-A5 / SC-7a-style compound).

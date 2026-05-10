---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P05"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p05/synthesize-corpus.sh (idempotent),tests/fixtures/m030-p05/live-routed-corpus.jsonl (23 records: 14 fast / 7 balanced / 2 smart),tests/fixtures/m030-p05/no-cost-rates-routing.yml (FR-15 fallback fixture),tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt (golden),tests/fixtures/m030-p05/footer-pre-m030-baseline.txt (golden),tools/verify/p05-sc11-rollup-byte-equality.sh (SC-11 byte-strict gate),tools/verify/p05-sc11-footer-byte-equality.sh (SC-11 byte-strict gate via ORCHESTRATOR_ROOT carve-out),tools/verify/p05-doctor-config-check.sh (SC-9 pass-through wrapper)"
requires:
  - "from:P02/T01 what:tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl (SC-11 baseline input),from:P01/T03 what:tools/verify/p01-routing-table-shape.sh (cost_rates-optional amendment target),from:P01/T04 what:tools/verify/p01-doctor-config-check.sh (delegation target for SC-9 wrapper),from:P04/T01 what:tests/fixtures/m030-p04/synthesize-corpora.sh (synthesizer pattern reference),from:HEAD what:scripts/diagnostics/metrics-rollup.sh + scripts/diagnostics/efficiency-footer.sh (pre-amendment baseline capture sources)"
affects:
  - "P05/T02"
key_files:
  - "tests/fixtures/m030-p05/synthesize-corpus.sh,tests/fixtures/m030-p05/live-routed-corpus.jsonl,tests/fixtures/m030-p05/no-cost-rates-routing.yml,tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt,tests/fixtures/m030-p05/footer-pre-m030-baseline.txt,tools/verify/p05-sc11-rollup-byte-equality.sh,tools/verify/p05-sc11-footer-byte-equality.sh,tools/verify/p05-doctor-config-check.sh,tools/verify/p01-routing-table-shape.sh"
key_decisions:
  - "contingent amendment applied: tools/verify/p01-routing-table-shape.sh check #3 relaxed to require only routing: + resolution: as top-level sections; cost_rates: is now OPTIONAL (FR-15 fallback path requires the rollup to handle absence at runtime; the malformed-fixture path in p01-doctor-config-check.sh keeps cost_rates: present so Scenario B coverage is unchanged); golden baselines captured via Strategy A (ORCHESTRATOR_ROOT carve-out for footer; --log flag direct for rollup); SC-11 gates ship byte-strict from the start (inverts P04/T01 pre-amendment-tolerant pattern -- the goldens themselves carry the contract); doctor-config-check wrapper uses delegate-and-pass-through shape per p04-additive-schema.sh precedent; idempotent synthesizer with deterministic timestamps (loop-index-derived)"
patterns_established:
  - "pre-amendment golden-baseline pattern: capture HEAD's unflagged output BEFORE amendment lands; verifier diffs post-amendment output against committed snapshot; ORCHESTRATOR_ROOT carve-out (mktemp -d + cp + trap-cleanup) for footer fixture-routing without modifying the footer's resolver; optional-section discipline for cost_rates: in routing-table-shape verifier (required vs optional split); cross-phase delegate-and-pass-through wrapper (P05/T01 doctor wrapper -> P01/T04 verifier; mirrors P04/T04 -> P02/T04)"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P05/tasks/T01-fixtures-and-baselines-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-30T18:55:41Z"
---

T01 ships before any work on scripts/diagnostics/metrics-rollup.sh or scripts/diagnostics/efficiency-footer.sh so the SC-11 byte-equality contract has a mechanical gate at the moment T02 amends them. Mirrors P02/T01 + P03/T01 + P04/T01 graduation pattern (verifier-before-deliverable). Five deliverable groups shipped as a single coherent commit.

## What was built

1. tests/fixtures/m030-p05/synthesize-corpus.sh -- idempotent live-routed-corpus synthesizer, Bash 3.2 compatible. Two scalar parallel arrays (no declare -A). Loop emits 14 fast / 7 balanced / 2 smart records via a single emit_record() function. Re-running produces byte-identical output (timestamp slot is the loop index, not wall-clock).

2. tests/fixtures/m030-p05/live-routed-corpus.jsonl -- 23 records, post-P04 dispatch_usage schema. Per-tier distribution: 14 fast / 7 balanced / 2 smart. Each record carries model_routed + model_used + classifier_confidence=high + partial_flip_active=false + withheld_classes="" + override_source=none + escalation_count=0 + escalation_reason="". Consumed by T02's --by-model verifiers.

3. tests/fixtures/m030-p05/no-cost-rates-routing.yml -- verbatim derivative of templates/model-routing.yml with the cost_rates: section removed. Used by T02's cost-rates-absent fallback verifier (FR-15: "cost rates not configured" warning + zero-savings line + exit 0).

4. tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt + footer-pre-m030-baseline.txt -- pre-amendment golden baselines captured against tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl (5 records, no model_routed field). Strategy A used for both: rollup invocation via --log flag direct; footer invocation via ORCHESTRATOR_ROOT carve-out (mktemp -d + cp + invoke + cleanup). Baselines are 1 line + 5 lines respectively; deterministic output.

5. tools/verify/p05-sc11-rollup-byte-equality.sh -- SC-11 gate. Invokes unflagged metrics-rollup.sh against the pre-M030 fixture, diffs stdout against rollup-pre-m030-baseline.txt. Pre-amendment HEAD passes by construction (golden was captured from this HEAD). T02 must preserve unflagged byte-equality for the gate to continue passing.

6. tools/verify/p05-sc11-footer-byte-equality.sh -- SC-11 gate. Stages ORCHESTRATOR_ROOT carve-out per-invocation (mktemp -d + cp + trap-cleanup). Invokes efficiency-footer.sh --milestone M001 against the carve-out, diffs against footer-pre-m030-baseline.txt. Same byte-strict shape as the rollup gate.

7. tools/verify/p05-doctor-config-check.sh -- thin pass-through wrapper to tools/verify/p01-doctor-config-check.sh. Mirrors the p04-additive-schema.sh delegate-and-pass-through pattern. Carries the SC-9 contract gate into the P05 phase-suite without re-implementing the underlying scenarios.

## Contingent amendment applied

Per T01 plan step 5, the cost-rates-absent fixture initially failed tools/verify/p01-routing-table-shape.sh check #3 ("top-level sections missing: cost_rates:"). Per the plan's contingent guidance, T01 amended the verifier to treat cost_rates: as OPTIONAL: required sections are now exactly {routing:, resolution:}; cost_rates: absence triggers the FR-15 fallback path in metrics-rollup --by-model (warning, not hard failure). When cost_rates: IS present, checks 5 + 8 continue to enforce closure + per-tier numeric-shape invariants. Backward-compatible: the shipped templates/model-routing.yml continues to pass with pass=8 fail=0. The malformed fixture in tools/verify/p01-doctor-config-check.sh (which has cost_rates: present + a turbo tier under routing.standard) continues to fail Scenario B as expected.

## Verification

- bash tools/verify/p05-sc11-rollup-byte-equality.sh -> SUMMARY: p05-sc11-rollup-byte-equality.sh pass=1 fail=0
- bash tools/verify/p05-sc11-footer-byte-equality.sh -> SUMMARY: p05-sc11-footer-byte-equality.sh pass=1 fail=0
- bash tools/verify/p05-doctor-config-check.sh -> exit 0 (delegates to p01-doctor-config-check.sh which emits pass=5 fail=0)
- bash tools/verify/p01-routing-table-shape.sh tests/fixtures/m030-p05/no-cost-rates-routing.yml -> pass=8 fail=0
- bash tools/verify/p01-routing-table-shape.sh -> pass=8 fail=0 (backward-compat with shipped table)
- bash tools/verify/p01-phase-suite.sh -> pass=7 fail=0 (P01 invariants unaffected)
- bash tools/verify/p02-phase-suite.sh -> pass=9 fail=0
- bash tools/verify/p03-phase-suite.sh -> pass=8 fail=0
- bash tools/verify/p04-phase-suite.sh -> pass=12 fail=0
- Idempotency: re-running synthesize-corpus.sh after the first run produces byte-identical live-routed-corpus.jsonl (verified via diff -q).

## Patterns established

- Pre-amendment golden-baseline pattern: capture the unflagged stdout BEFORE the amendment task lands, commit the snapshot as the contract; the byte-equality gate diffs post-amendment output against the snapshot. Inverts the P04/T01 pre-amendment-tolerant pattern (P05 gates are byte-strict from the start; the goldens themselves carry the contract).
- ORCHESTRATOR_ROOT carve-out via mktemp -d + cp + trap-cleanup for footer fixture-routing -- same shape T01 used for the baseline capture and now embedded in tools/verify/p05-sc11-footer-byte-equality.sh.
- Optional-section discipline for cost_rates: pre-existing routing-table-shape verifier required cost_rates: presence in check #3; T01 relaxed this so the FR-15 fallback path can be exercised with a realistic missing-section fixture without bypassing the shape verifier.
- Delegate-and-pass-through wrapper for cross-phase contract carry-over: tools/verify/p05-doctor-config-check.sh delegates to tools/verify/p01-doctor-config-check.sh (P04 already used this shape with p04-additive-schema.sh -> p02-additive-schema.sh).

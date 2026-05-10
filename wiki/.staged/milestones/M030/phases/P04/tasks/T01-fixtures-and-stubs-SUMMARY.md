---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p04/plans/ (5 fixture plans),tests/fixtures/m030-p04/configs/ (3 fixture configs),tests/fixtures/m030-p04/round-trip-stage/ (intensity-metadata.txt + payload.txt),tests/fixtures/m030-p04/shadow-corpus-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-empty.jsonl,tests/fixtures/m030-p04/synthesize-corpora.sh,scripts/dispatch/adapters/backend/stub-fail-n.sh (programmable fail-counter adapter),scripts/dispatch/adapters/backend/stub-record-model.sh (model-flag-recorder adapter),tools/verify/p04-additive-schema.sh (P02 SC-11 pass-through),tools/verify/p04-override-source-enum-extended.sh (6-scenario closed-enum gate pre-amendment-tolerant)"
requires:
  - "from:P02/T04 what:tools/verify/p02-additive-schema.sh + tools/verify/p02-phase-suite.sh (delegation target + green prereq),from:P02/T03 what:scripts/diagnostics/shadow-compare.sh --corpus flag (ready/partially_ready/evidence_insufficient verdicts; corpus sanity check),from:P03/T01 what:tests/fixtures/m030-p03/plans + configs + round-trip-stage (Scenarios A-E reuse these fixtures verbatim),from:P03/T01 what:tools/verify/p03-override-source-enum.sh (5-scenario harness pattern reference),from:P03/T02 what:scripts/dispatch/dispatch-interface.sh (pre-T02 form: shadow path + override-resolution block; ORCH_ROOT/phases carve-out),from:P01/T02 what:scripts/dispatch/classify-task.sh (classifier signature; novel-language lexicon),from:P01/T03 what:templates/model-routing.yml (routing-table SSOT; CON-3 closure),from:M019/P01/T05 what:scripts/dispatch/adapters/backend/stub.sh (minimal-conforming-adapter pattern reference)"
affects:
  - "P04/T02,P04/T03,P04/T04"
key_files:
  - "tests/fixtures/m030-p04/plans/plan-mechanical-no-override.md,tests/fixtures/m030-p04/plans/plan-fail-twice-then-pass.md,tests/fixtures/m030-p04/plans/plan-fail-three-times.md,tests/fixtures/m030-p04/plans/plan-fail-four-times.md,tests/fixtures/m030-p04/plans/plan-novel-class.md,tests/fixtures/m030-p04/configs/config-with-live-true.yml,tests/fixtures/m030-p04/configs/config-with-live-and-killswitch.yml,tests/fixtures/m030-p04/configs/config-with-live-false.yml,tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt,tests/fixtures/m030-p04/round-trip-stage/payload.txt,tests/fixtures/m030-p04/shadow-corpus-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p04/shadow-corpus-empty.jsonl,tests/fixtures/m030-p04/synthesize-corpora.sh,scripts/dispatch/adapters/backend/stub-fail-n.sh,scripts/dispatch/adapters/backend/stub-record-model.sh,tools/verify/p04-additive-schema.sh,tools/verify/p04-override-source-enum-extended.sh"
key_decisions:
  - "six-deliverable single-commit graduation-pattern ships before T02 emitter amendment so the new shadow_gate_blocked enum + SC-11 byte-equality contract are mechanically gated from the moment the diff lands; pre-amendment-tolerant predicate for Scenario F (PASS if shadow_gate_blocked OR any P03 enum value) graduates to strict the moment T02 starts emitting shadow_gate_blocked; Scenarios A-E reuse P03 fixtures verbatim (no duplication); Scenario F uses P04-specific plan + config; tmp_root staging via mktemp -d with /tmp fallback + ORCH_ROOT/phases carve-out (mirrors P03/T01); per-scenario tmp-file intermediates throughout (no cmd-pipe-grep-pipe-head chains per AP-009); shadow-corpus synthesizer committed to disk for reproducibility (idempotent; deterministic ascending timestamps); stub-fail-n read-decrement contract: counter=N -> N exit-1 invocations followed by exit-0 (counter=2 -> rc=1,rc=1,rc=0; CON-5 stops at 3 invocations regardless of counter starting >=3); stub-record-model writes --model flag value to env-configurable file path (CON-3 closure preserved -- adapter does NOT interpret model IDs); STUB_INVOCATION_SENTINEL_DIR documented in stub-fail-n now (rather than retrofit in T03) keeps adapter shape stable across phases; partially_ready corpus sets novel under-threshold (not mechanical/standard) per D-A3 safety because novel routing-default is smart (the conservative tier)"
patterns_established:
  - "six-deliverable graduation-pattern (P02/T01 + P03/T01 lineage extended): fixtures + configs + corpora + stage + stub adapters + tolerant gates ship as one commit BEFORE the emitter amendment; pre-amendment-tolerant Scenario F predicate (case statement accepts strict-token OR pre-amendment-fallback enum values) is a per-scenario shape (older P03 verifier was per-verifier-tolerant); shadow-corpus synthesizer-committed-to-disk for reproducibility (synthesis script + outputs both checked in); stub adapter --model flag accepted in T01 even though dispatch-interface.sh starts passing it only in T02 (forward-compatible adapter shape); ORCH_ROOT/phases carve-out exploited for fixture log-routing without restructuring tests/fixtures/ to encode uppercase M### tokens; per-scenario tmp_root + cleanup with mktemp -d fallback; AD-19 single-script-file shape preserved in all verifiers; MEM004 emitter-internal carve-out applied to stub adapters (pipes/awk permitted in adapter bodies)"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P04/tasks/T01-fixtures-and-stubs-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-30T16:31:36Z"
---

T01 ships before any work on scripts/dispatch/dispatch-interface.sh so the new sixth `override_source` enum value `shadow_gate_blocked` and the SC-11 byte-equality contract under live-mode amendments are mechanically enforced at the moment T02 amends the emitter. Six deliverable groups: (1) five fixture plans; (2) three overlay configs (live-true, live-and-killswitch, live-false); (3) three shadow corpora (ready / partially_ready / empty) plus an idempotent synthesizer; (4) round-trip stage; (5) two stub adapters (stub-fail-n, stub-record-model); (6) two pre-amendment-tolerant gates (p04-additive-schema, p04-override-source-enum-extended).

## What was built

1. tests/fixtures/m030-p04/plans/ -- five fixture plans:
   - plan-mechanical-no-override.md (T99/M999) -- baseline plan for live-routing happy path + Scenario F enum gate; classifier returns mechanical/high.
   - plan-fail-twice-then-pass.md (T97/M999) -- mechanical body; SC-4 escalation pass-after-retries demo input; pairs with stub-fail-n counter=2.
   - plan-fail-three-times.md (T96/M999) -- mechanical body; SC-5 escalation hard-cap demo; pairs with stub-fail-n counter=3.
   - plan-fail-four-times.md (T96/M999) -- mechanical body; CON-5 cap-is-hard demo; pairs with stub-fail-n counter=4 (asserts exactly 3 invocations recorded).
   - plan-novel-class.md (T95/M999) -- novel body (## Goal section uses `explore`, `design alternatives`, `evaluate alternatives`, `investigate options` -- high-precision novel lexicon); classifier returns novel/high; load-bearing for partial-flip routing (novel is the WITHHELD class per D-A3 safety).
   - All five classifications verified live: mechanical/high (×4) and novel/high (×1).

2. tests/fixtures/m030-p04/configs/ -- three overlay configs:
   - config-with-live-true.yml -- model_routing.live: true (live-routing happy path / Scenario F driver).
   - config-with-live-and-killswitch.yml -- model_routing_enabled: false + live: true + min_tier: smart (CON-4/D-A5 compound; kill switch wins).
   - config-with-live-false.yml -- model_routing.live: false (explicit pass-through baseline; asserts the live branch is gated correctly).

3. tests/fixtures/m030-p04/ -- three shadow corpora + idempotent synthesizer:
   - shadow-corpus-ready.jsonl (165 records: 55 mechanical/fast + 55 standard/balanced + 55 novel/smart; all classifier_confidence=high; variance=0; verdict ready).
   - shadow-corpus-partially-ready.jsonl (135 records: mechanical 55 + standard 55 + novel 25; novel under-threshold; D-A3-safe -> verdict partially_ready + withheld_classes=novel).
   - shadow-corpus-empty.jsonl (0 bytes; verdict evidence_insufficient).
   - synthesize-corpora.sh -- bash 3.2 compatible; deterministic timestamps (2026-04-30T00:00:NNZ); rerun produces byte-identical output. Each record contains the post-P03 22-field schema (5 P02 fields + override_source=none).
   - All three verdicts verified live against scripts/diagnostics/shadow-compare.sh --corpus.

4. tests/fixtures/m030-p04/round-trip-stage/ -- intensity-metadata.txt (intensity:standard, model:claude-opus-4-7) + payload.txt (475 bytes ascii, clears the 256-byte floor for chars_to_tokens_quartile estimation).

5. scripts/dispatch/adapters/backend/ -- two new stub adapters:
   - stub-fail-n.sh -- programmable fail-counter adapter. Reads STUB_FAIL_COUNTER_FILE (default /tmp/stub-fail-n-counter.txt); decrements per invocation; if pre-decrement value > 0 exits 1 with no stdout (fail signal); else emits conforming dispatch-result on stdout with exit 0. Side channels: STUB_FAIL_COUNTER_INVOCATIONS_FILE (per-invocation log, used by CON-5 verifier) and STUB_INVOCATION_SENTINEL_DIR (touch-file drop, reserved for T03 CON-6 verifier). Accepts --task-plan, --payload, --intensity-metadata, --model. Read-decrement contract verified live: counter=2 produces (rc=1, rc=1, rc=0).
   - stub-record-model.sh -- model-flag-recorder adapter. Always succeeds; writes the --model flag value (or `<no-model-flag>`) to STUB_RECORD_MODEL_FILE (default /tmp/stub-record-model.txt); emits conforming dispatch-result on stdout. Accepts --task-plan, --payload, --intensity-metadata, --model. Live verified: --model claude-haiku-4-5 round-tripped through the file.

6. tools/verify/ -- two pre-amendment-tolerant gates:
   - p04-additive-schema.sh -- thin pass-through wrapper over tools/verify/p02-additive-schema.sh. Mirrors the p03-additive-schema.sh shape exactly (reuse-not-rewrite). Pre-T02: passes against the unmodified emitter. Post-T02 + T03: must continue to pass (additive-only-when-shadow-on per CON-2/FR-19/SC-11). Live result: SUMMARY: p04-additive-schema.sh pass=1 fail=0.
   - p04-override-source-enum-extended.sh -- 6-scenario gate (A-E inherited from P03; F new). Scenarios A-D strict (none / disabled / plan_frontmatter / milestone_floor). Scenario E strict-zero (shadow-off must NOT emit override_source). Scenario F tolerant (PASS if shadow_gate_blocked OR any P03 enum value); pre-T02 falls through to override_source=none; T02's amendment will tighten Scenario F to strict shadow_gate_blocked the moment the live branch starts emitting that token. Live result: SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0 (Scenario F passes via the tolerant branch with override_source=none; strict branch will fire post-T02).

## Verifier results

- bash tools/verify/p04-additive-schema.sh -> SUMMARY: p04-additive-schema.sh pass=1 fail=0; exit 0.
- bash tools/verify/p04-override-source-enum-extended.sh -> SUMMARY: p04-override-source-enum-extended.sh pass=6 fail=0; exit 0.

Both verifiers green against the pre-T02 dispatch-interface.sh on HEAD.

## Pre-amendment-tolerant Scenario F predicate

The Scenario F predicate accepts EITHER the post-T02 strict token (shadow_gate_blocked) OR any pre-T02 P03 enum value (plan_frontmatter / milestone_floor / disabled / none) as PASS. Today (pre-T02), the dispatch falls through to the existing override-resolution chain and emits `none`; the tolerant branch fires. The moment T02 introduces the live branch and starts emitting `shadow_gate_blocked`, the strict branch fires. The verifier file is identical pre/post; the value-extraction case statement carries the dual semantic.

This mirrors the P02/T01 + P03/T01 graduation-pattern shape: ship the verifier before the deliverable, in tolerant mode; let the deliverable's amendment graduate the verifier from tolerant to strict by changing the observed token. The closed-enum invariant is locked at T01; T02 cannot regress it.

## Plan deviations

None. All 12 plan steps executed in order; all expected outputs match (165/135/0 corpus line counts; ready/partially_ready+withheld_classes=novel/evidence_insufficient verdicts; 5/5 classifier results; both gates green).

One micro-deviation worth noting for the record: the verifier prerequisite gate increments `pass` then immediately decrements it before the per-scenario tally so the final SUMMARY line reports exactly 6 (one per scenario A-F) rather than 7 (prereq + 6 scenarios). Cosmetic only -- exit code is unaffected.

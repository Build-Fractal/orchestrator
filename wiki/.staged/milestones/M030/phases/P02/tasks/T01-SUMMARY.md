---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh"
requires:
  - "from:P01 what:scripts/dispatch/dispatch-interface.sh,scripts/dispatch/adapters/backend/stub.sh,scripts/lib/pricing.sh,.orchestrator/config/pricing.yml"
affects:
  - "P02/T02"
key_files:
  - "tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/M001-T01-stage-PLAN.md,tests/fixtures/m030-p02/round-trip-stage/phases/P01/tasks/T01-stage-PAYLOAD.md,tests/fixtures/m030-p02/round-trip-stage/intensity-metadata.txt,tools/verify/p02-fixture-shape.sh,tools/verify/p02-additive-schema.sh"
key_decisions:
  - "SC-11 byte-equality verifier authored before T02 amends dispatch-interface.sh (graduation-verifier pattern reused from P01/T01); pricing-warning + adapter-failed shapes covered via fixture-presence grep only -- full round-trip would require stale-pricing-rate or crashing-adapter setup, both out-of-scope for byte-equality gate; payload sized to exactly 4096B so chars_to_tokens_quartile=1024 deterministically matches fixture record 1; round-trip plan basename includes M001 token so MILESTONE_ID regex extraction succeeds without restructuring tests/fixtures/ tree"
patterns_established:
  - "round-trip-byte-equality fixture pattern: committed payload+plan+intensity-metadata stage with deterministic byte length; ORCHESTRATOR_ROOT carve-out routes log to staged dir; timestamp-normalization sed before diff yields full byte-equality minus the dynamic field; tools/verify/p02-* slug-bearing filenames per project-owned-verifier-paths discipline; AD-19 single-script-file shape preserved with parallel grep-q + rc captures (no compound chains)"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P02/tasks/T01-additive-schema-fixture-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-30T13:40:49Z"
---

T01 ships the SC-11 byte-equality contract BEFORE T02 amends dispatch-interface.sh. Mirrors P01/T01's D-A4 timeline-graduation discipline: the additive-only invariant gets a mechanical gate that exists at the moment the dispatch-interface diff lands.

## What was built

1. tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl -- 5 canonical pre-M030 dispatch_usage records mirroring dispatch-interface.sh:283 (happy-path) and :298 (degradation-path) printf templates byte-for-byte. Records exercise: 3 happy-path shapes (model=claude-opus-4-7 with carry-forward zeros; with M018/P05 carry-forwards non-zero; with model=empty + M018/P06 tier3 non-zero); 1 stale-pricing degradation (estimated_cost_usd:null + pricing_warning:stale:135d); 1 adapter-failed degradation (pricing_warning:adapter-failed). Distinct unitId/backend/model tuples cover M001/M005/M019/M027/[M020](../../../../../milestones/M020/index.md) and stub/local-agent/local-codex.

2. tests/fixtures/m030-p02/round-trip-stage/ -- committed fixture-stage tree for the additive-schema round-trip harness: phases/P01/tasks/M001-T01-stage-PLAN.md (basename encodes M001 so MILESTONE_ID regex extraction at dispatch-interface.sh:334 succeeds without forcing the fixture under .orchestrator/milestones/), phases/P01/tasks/T01-stage-PAYLOAD.md (exactly 4096 bytes via awk-generated content -> input_tokens_estimate=1024 deterministically), intensity-metadata.txt (model: claude-opus-4-7).

3. tools/verify/p02-fixture-shape.sh -- 23-gate fixture-shape verifier (file-exists, line-count>=5, 15 required pre-M030 tokens present, 4 forbidden P02 tokens absent, all-records-start-with-record_type, all-records-end-with-brace). Bash 3.2, AD-19 single-script-file shape, tmp-file pattern for compound-chain avoidance.

4. tools/verify/p02-additive-schema.sh -- 6-gate SC-11 byte-equality verifier. Stages dispatch-interface.sh invocation under unset CLAUDECODE / unset M030_SHADOW_MODE / ORCHESTRATOR_ROOT=<stage>, captures the appended dispatch_usage line from <stage>/execution-log.jsonl, normalizes timestamps via sed on both sides, diffs against fixture record 1 (M001/P01/T01 happy-path). Asserts forbidden P02 tokens absent from the emitted record. WARN line documents pricing-warning/cost-null shapes covered by fixture-presence grep only.

## Verification

- bash tools/verify/p02-fixture-shape.sh -> SUMMARY: p02-fixture-shape.sh pass=23 fail=0, exit 0.
- bash tools/verify/p02-additive-schema.sh -> SUMMARY: p02-additive-schema.sh pass=6 fail=0, exit 0. WARN: pricing-warning + adapter-failed round-trip not exercised -- fixture-presence grep only.
- Idempotent re-run confirmed: cleanup `rm -f $LOG_FILE` at verifier end means second invocation re-stages cleanly.

## Patterns established

- Round-trip byte-equality fixture pattern: committed payload sized to deterministic byte length (4096B for 1024 tokens via chars_to_tokens_quartile); ORCHESTRATOR_ROOT carve-out at dispatch-interface.sh:242 routes the staged log; sed-normalize-timestamps both sides before diff yields full byte-equality minus the dynamic timestamp.
- Plan-basename MILESTONE_ID encoding: when a fixture milestone tree is impractical, encode the M### token in the plan filename so the dispatch-interface.sh:334 regex extraction succeeds without forcing the fixture under .orchestrator/milestones/.
- Co-scheduled gate before deliverable (graduation pattern from P01/T01): the additive-schema verifier is authored in T01 BEFORE T02 amends the emitter; T02's first verifier run after the amendment is the contract proof.

## Open notes for downstream (T02)

- T02 will amend dispatch-interface.sh to append model_routed/model_used/partial_flip_active/withheld_classes ONLY under M030_SHADOW_MODE=1 AND CLAUDECODE=1 (per CON-2/FR-19). The same p02-additive-schema.sh MUST continue to pass post-amendment -- that is the additive-only contract proof.
- Pricing-warning + adapter-failed round-trip shapes remain WARN (grep-only). T02's p02-shadow-emit.sh is expected to inherit this discipline for the shadow-on path where round-trip is impractical.
- The fixture's load-bearing property is field ORDER: byte-equality requires every field in the same position. If T02 inserts new fields BETWEEN existing fields rather than appending after timestamp, this verifier catches it on first run.

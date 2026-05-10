---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M030"
provides:
  - "scripts/diagnostics/shadow-compare.sh (4-verdict aggregator),tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,5 shadow-corpus JSONL fixtures,classifier_confidence additive field on dispatch-interface.sh shadow-on emit"
requires:
  - "from:T02 what:dispatch-interface.sh shadow-mode amendment + 4 additive fields;from:P01/T02 what:scripts/dispatch/classify-task.sh;from:P01/T03 what:templates/model-routing.yml + references/model-routing.md (stability-metric numerics 0.10/N=20/50)"
affects:
  - "P03,P04"
key_files:
  - "scripts/diagnostics/shadow-compare.sh,scripts/dispatch/dispatch-interface.sh,tools/verify/p02-shadow-compare-verdicts.sh,tools/verify/p02-partial-flip-enum.sh,tools/verify/p02-stability-metric-traceability.sh,tools/verify/p02-sc3a-roundtrip.sh,tools/verify/p02-shadow-emit.sh,tests/fixtures/m030-p02/shadow-corpus-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl,tests/fixtures/m030-p02/shadow-corpus-block.jsonl,tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl"
key_decisions:
  - "D-A1-4-verdict-closed-enum;D-A3-partial-flip-safety-smart-default-only;D-A7-SC-3a-write-path-correctness;classifier_confidence-field-end-to-end-in-P02-not-deferred-to-P03"
patterns_established:
  - "awk-section-walker-extended-to-tier-to-class-inverse-map;tmp-file-staging-for-routing-map-to-bypass-macos-awk-multiline-v-limit;SSOT-numeric-traceability-via-awk-line-content-predicate-not-grep-line-number-prefix;per-record-loop-unrolled-into-explicit-blocks-AD-19;classifier-confidence-end-to-end-from-classifier-emit-to-shadow-record-to-variance-aggregator"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P02/tasks/T03-shadow-compare-PLAN.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-30T14:20:45Z"
---

Authored shadow-compare.sh per FR-8/D-A1/D-A3 contract: per-class count + rolling-window variance over classifier_confidence (mapped high=1.0/medium=0.5/low=0.0); 4-verdict closed enum (ready, partially_ready, block, evidence_insufficient); partial_flip safety constraint (only smart-defaulted classes may be withheld). Inverse routing map class<->tier built via awk section-walker on templates/model-routing.yml (no jq, CON-3 honored). Stability thresholds 0.10/N=20/50 cited inline next to each numeric -- gated by p02-stability-metric-traceability.sh (uses awk line-content predicate to avoid line-number-prefix false matches that bit during initial implementation). 5 fixture corpora authored (ready=150, partially-ready=100, block=30, evidence-insufficient=0, sc3a-roundtrip=6 hand-authored against real M020/M030/M028/[M018](../../../../../milestones/M018/index.md) PLAN.md paths). dispatch-interface.sh amendment: added shadow_confidence shell variable sourced from classify-task.sh confidence= line + classifier_confidence format-string field on both shadow-on printf branches (happy + degradation). p02-shadow-emit.sh extended to assert classifier_confidence presence in Scenario A and absence in B/C. Eight P02 verifiers green: additive-schema 6/0, shadow-emit 17/0, con3-closure 7/0, append-only 4/0, shadow-compare-verdicts 4/0, partial-flip-enum 6/0, stability-metric-traceability 3/0, sc3a-roundtrip 6/0. CON-2/SC-11 byte-equality preserved (shadow-off branches unchanged). CON-3 closure: zero concrete model IDs in shadow-compare.sh body.

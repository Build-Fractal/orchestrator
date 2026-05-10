---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P07"
milestone: "M030"
provides:
  - "acceptance-corpus synthesizer at tests/m030-acceptance/shadow-corpus-fixtures.sh + four corpora (corpus-50-per-class.jsonl=150, corpus-zero.jsonl=0, corpus-2-class-only.jsonl=100, corpus-block.jsonl=60) exercising all four shadow-compare.sh D-A1 verdicts; five per-verdict verifier gates under tools/verify/p07-*"
requires:
  - "from:P07/T01 what:none (head of phase; consumes scripts/diagnostics/shadow-compare.sh + scripts/dispatch/dispatch-interface.sh record shape + templates/model-routing.yml class->tier mapping)"
affects:
  - "M030/P07/T02 (acceptance-battery runner delegates to T01 per-verdict gates rather than re-implementing verdict-extraction); M030/P07/T03 (cross-surface coherence consumes corpus-50-per-class.jsonl); M030/P07/T04 (acceptance-evidence ledger references T01 verifier outputs for SC-2 rows)"
key_files:
  - "tests/m030-acceptance/shadow-corpus-fixtures.sh,tests/m030-acceptance/corpus-50-per-class.jsonl,tests/m030-acceptance/corpus-zero.jsonl,tests/m030-acceptance/corpus-2-class-only.jsonl,tests/m030-acceptance/corpus-block.jsonl,tools/verify/p07-corpus-synthesizer-idempotent.sh,tools/verify/p07-corpus-50-per-class-ready.sh,tools/verify/p07-corpus-zero-evidence-insufficient.sh,tools/verify/p07-corpus-2-class-partially-ready.sh,tools/verify/p07-corpus-block.sh"
key_decisions:
  - "D-A1 (4-verdict closed enum at acceptance scale); D-A3 (conservative-by-construction: partially_ready withheld-class enumeration is the under-threshold class with default tier=smart, not the flippable set); shadow-compare.sh CLI is --corpus <path> (NOT M030_SHADOW_COMPARE_CORPUS env as plan prose suggested); block via count<CLASS_COVERAGE_MIN=50 alone (no confidence-alternation tuning needed)"
patterns_established:
  - "idempotent acceptance-corpus synthesizer with deterministic timestamps via loop-index (mirrors P05/T01 + P06/T01 shape); helper-function carve-out for sha256 portability (sha256sum vs shasum -a 256); per-verdict gate shape: tmp-file capture of shadow-compare.sh stdout then anchored grep against ^flip_recommendation=<verdict>$ — each gate dual-asserts (rc=0 + verdict line); plan-time amendment to verifier shape when script-emitted enumeration disagrees with plan prose (the script is the contract)"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-PLAN.md,.orchestrator/milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-PAYLOAD.md,scripts/diagnostics/shadow-compare.sh,scripts/dispatch/dispatch-interface.sh"
duration: "35m"
verification_result: "p07-corpus-synthesizer-idempotent.sh pass=4 fail=0; p07-corpus-50-per-class-ready.sh pass=2 fail=0; p07-corpus-zero-evidence-insufficient.sh pass=2 fail=0; p07-corpus-2-class-partially-ready.sh pass=3 fail=0; p07-corpus-block.sh pass=2 fail=0"
completed_at: "2026-05-01T02:29:55Z"
---

T01 ships the P07 acceptance-corpus foundation: an idempotent synthesizer at `tests/m030-acceptance/shadow-corpus-fixtures.sh` that produces four corpora (corpus-50-per-class.jsonl=150 records, corpus-zero.jsonl=0, corpus-2-class-only.jsonl=100, corpus-block.jsonl=60) exercising all four `shadow-compare.sh` D-A1 verdicts at acceptance scale; plus five per-verdict verifier gates under `tools/verify/p07-*` (synthesizer-idempotent + the four per-verdict gates). Synthesizer is bash 3.2 compatible with deterministic timestamps via loop-index and a portable record-emitter helper that mirrors the dispatch-interface.sh shadow-on emit shape (line 630) including the M030/P02 `character` additive field. Sha256-equality across two synthesizer invocations holds (idempotent gate pass=4). All four verdict gates fire against the existing `--corpus <path>` flag of shadow-compare.sh (the plan's M030_SHADOW_COMPARE_CORPUS env-var description was incorrect; corrected to the canonical CLI flag at runtime). The partially_ready enumeration line shipped by shadow-compare.sh is `withheld_classes=novel` (the under-threshold class with default tier=`smart`), NOT `flippable_classes=mechanical,standard` as the plan's prose loosely described — the verifier asserts the actual emitted shape per the plan's "script is the contract" amendment guidance. The block corpus (60 records, 20/class) drives stable_count=0 because count<CLASS_COVERAGE_MIN=50 for every class, falling through partially_ready (which requires stable_count>=2) into block — confidence-alternation tuning was not needed. All five gates exit 0 with `SUMMARY: <name> pass=N fail=0`. T01 must-haves checker confirms the 5 truth statements and all T01 artifact predicates PASS; the remaining FAILs belong to T02/T03/T04 deliverables (run-acceptance-battery.sh, partial-flip-jsonl-fields.sh, cross-surface-coherence.sh, acceptance-battery-pass.sh, acceptance-evidence-ledger.sh, p07-phase-suite.sh, M030-ACCEPTANCE-EVIDENCE.md, M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md) per step 11's expected MIXED output.

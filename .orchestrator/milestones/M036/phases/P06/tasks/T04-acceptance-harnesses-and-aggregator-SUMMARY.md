---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M036"
provides:
  - "tests/test-extract-idempotency.sh (SC-13 acceptance harness — manifest+source workspace; runs extract twice; asserts EXTRACTED on first run, byte-identical trees across two fresh-workspace runs, SKIPPED on third run against populated tree); tests/test-reference-reingest-idempotency.sh (SC-5 acceptance harness — re-uses M036/P04 fixture corpus, drives ingest twice with --no-index-rebuild, hash-snapshot pre/post tree comparison + SUMMARY emission both runs); tests/test-reference-supersede-chain.sh (SC-6 acceptance harness — drives full V1 extract → mutate source → V2 extract → ingest story; asserts V1 chunk, v2 chunk, superseded_by amendment in V1 frontmatter, SUPERSEDED stdout, ingest SUMMARY emission; REVIEW: emission opportunistic skip-counted because clean-repo graph has no citer); tools/verify/m036-p06-test-harness.sh (permissive harness-shape verifier — rc<=1 acceptable, asserts BATTERY: pass=N fail=N skip=N last-line shape); tools/verify/m036-p06-acceptance-harness-passes.sh (strict pass-rate gate — asserts each harness rc=0 specifically); tools/verify/m036-p06-p02-regression-pass.sh (selective 14-of-15 P02 sub-gate regression — excludes m036-p02-tier-2-deferred-error.sh whose semantics flipped at P03 close); tools/verify/m036-p06-p03-regression-pass.sh (full pass-through P03 phase-suite); tools/verify/m036-p06-p04-regression-pass.sh (full pass-through P04 phase-suite — load-bearing because P06 modifies ingest-reference.sh); tools/verify/m036-p06-p05-regression-pass.sh (full pass-through P05 phase-suite — confirms traverse-graph.sh + scope-filter.sh untouched); tools/verify/m036-p06-p07-regression-pass.sh (full pass-through P07 phase-suite — confirms chunk-store deltas do not perturb SC-3/SC-7 byte-identical-payload contracts); tools/verify/m036-p06-phase-suite.sh (16-gate aggregator wiring T01x3 + T02x4 + T03x2 + T04x7)"
requires:
  - "from:P06/T01 what:scripts/knowledge/extract-reference.sh+lib/extract-supersede.sh; from:P06/T02 what:scripts/knowledge/ingest-reference.sh+lib/ingest-review-advisory.sh; from:P06/T03 what:tests/fixtures/m036-p06-supersede-corpus/+9 verifiers; from:P02 what:m036-p02-phase-suite.sh+sample.md; from:P03 what:m036-p03-phase-suite.sh; from:P04 what:m036-p04-phase-suite.sh+m036-p04-reference-corpus/; from:P05 what:m036-p05-phase-suite.sh; from:P07 what:m036-p07-phase-suite.sh"
affects:
  - "P06 phase-close (16-gate aggregator green); M036 milestone-grain SC-5+SC-6+SC-13 acceptance now lockable"
key_files:
  - "tests/test-extract-idempotency.sh,tests/test-reference-reingest-idempotency.sh,tests/test-reference-supersede-chain.sh,tools/verify/m036-p06-test-harness.sh,tools/verify/m036-p06-acceptance-harness-passes.sh,tools/verify/m036-p06-p02-regression-pass.sh,tools/verify/m036-p06-p03-regression-pass.sh,tools/verify/m036-p06-p04-regression-pass.sh,tools/verify/m036-p06-p05-regression-pass.sh,tools/verify/m036-p06-p07-regression-pass.sh,tools/verify/m036-p06-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "Fifth instance of M036 acceptance-harness pattern (M036/P02/T04 SC-10 single-doc, M036/P03/T04 SC-11+SC-12 two-leg, M036/P04/T04 SC-1+SC-2 multi-fixture-corpus, M036/P07/T04 SC-3+SC-7 dispatch-injection, M036/P06/T04 SC-5+SC-6+SC-13 idempotency+supersede); permissive+strict gate split shape now M036-canonical (m036-p06-test-harness.sh asserts BATTERY shape with rc<=1 permissive; m036-p06-acceptance-harness-passes.sh asserts rc=0 strict; phase-suite wires both); skip-counted opportunistic-assertion pattern for SC-6 REVIEW: line (REVIEW emission depends on project graph state which is clean-repo-empty; harness emits SKIP: line + increments skip rather than failing — the helper-shape verifier in T02 covers the format-string contract); selective-gate-list cross-phase regression pattern carried verbatim (fourth instance: M036/P03/T03 + M036/P04/T04 + M036/P07/T03 + M036/P06/T04 — explicitly enumerates 14 of 15 P02 sub-gates excluding m036-p02-tier-2-deferred-error.sh whose semantics flipped at P03 close); full pass-through cross-phase regression shape (re-runs upstream phase-suite aggregator + inspects rc only) used for P03/P04/P05/P07 — load-bearing where P06 modifies the upstream surface (P04 ingest-reference.sh, P07 chunk-store consumer) and confirmation-only where P06 leaves the surface untouched (P03 fidelity gate, P05 traverse-graph.sh+scope-filter.sh); 16-gate phase-suite aggregator pattern reuse (M036/P02 15-gate + M036/P03 14-gate + M036/P04 13-gate + M036/P07 17-gate template); hash-snapshot-pre-post tree-equality pattern in SC-5 harness (find -type f + per-file sha256 + sort + diff -q snapshots is the load-bearing CON-4 assertion regardless of whether per-line SKIPPED reporting fires — extract-produced chunks may carry source-binary content_hash not body sha256 so SKIPPED emission is conditional but tree-byte-equality is unconditional); per-task mktemp -d workspace isolation with trap-cleanup carried forward from prior P##/T04 harnesses; CON-4 idempotency contract assertion at the harness layer (re-run-rc=0 + tree-byte-equality)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P06/tasks/T04-acceptance-harnesses-and-aggregator-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-02T20:39:16Z"
---

T04 lands the SC-5/SC-6/SC-13 milestone-grain acceptance harnesses + permissive+strict gate split + 5 cross-phase regression verifiers (P02 selective, P03/P04/P05/P07 full pass-through) + 16-gate P06 phase-suite aggregator. All 11 new files authored verbatim from plan, chmod +x'd, and verified.

Verification (all rc=0):
- m036-p06-test-harness.sh: pass=3 fail=0 (each harness emits well-formed BATTERY: pass=N fail=N skip=N with rc<=1).
- m036-p06-acceptance-harness-passes.sh: pass=3 fail=0 (each harness exits 0 specifically).
- m036-p06-p02-regression-pass.sh: pass=14 fail=0 (selective 14-of-15 sub-gates).
- m036-p06-p03-regression-pass.sh: pass=1 fail=0 (full pass-through).
- m036-p06-p04-regression-pass.sh: pass=1 fail=0 (full pass-through; load-bearing because P06 modifies ingest-reference.sh).
- m036-p06-p05-regression-pass.sh: pass=1 fail=0 (full pass-through; confirms traverse-graph.sh + scope-filter.sh untouched).
- m036-p06-p07-regression-pass.sh: pass=1 fail=0 (full pass-through; confirms P06 chunk-store deltas do not perturb SC-3/SC-7 byte-identical-payload contracts).
- m036-p06-phase-suite.sh: pass=16 fail=0 (T01x3 + T02x4 + T03x2 + T04x7 wired and green).

P06 is now phase-close-ready: all 16 sub-gates green, all 5 cross-phase regressions clean, all three milestone-grain SC harnesses pass with rc=0, BATTERY shape contract honored across all three. SC-6 REVIEW: assertion is skip-counted because clean-repo graph has no citer of the V1 fixture id (informational SKIP line; the T02 review-emission-end-to-end.sh verifier covers the format-string contract).

No mid-phase corrections. All scripts executed verbatim from plan; no deviations.

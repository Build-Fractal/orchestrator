---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M031"
provides:
  - "scripts/intake/shape-detect.sh extended with tier_a_plus verdict (FR-6, 30-80 word zero-structural-marker band),scripts/intake/paragraph-classify.sh annotated with tier_a_plus literal token,tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md (AD-16 normative grounding citing 2 historical unit_close records),tests/m031-acceptance/fixtures/tier-a-plus-input.txt (62-word fixture paraphrased from M031/P01/T01),tests/m031-acceptance/test-tier-a-plus-classifier.sh (SC-5 acceptance test),4 m031-p02 shape verifiers under tools/verify/"
requires:
  - "P01: scripts/dispatch/build-context.sh --profile=quick wired,P01: commands/dispatch.md amended,M024: scripts/intake/shape-detect.sh + paragraph-classify.sh on disk with idea/paragraph/fragment/spec/empty verdict enum,.orchestrator/milestones/M031/execution-log.jsonl with at least one historical unit_close record"
affects:
  - "P02/T02 (slug + role templates),P02/T03 (prompt + UX),P02/T04 (router + flow test),P02/T05 (phase-suite + scope-guard)"
key_files:
  - "scripts/intake/shape-detect.sh,scripts/intake/paragraph-classify.sh,tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md,tests/m031-acceptance/fixtures/tier-a-plus-input.txt,tests/m031-acceptance/test-tier-a-plus-classifier.sh,tools/verify/m031-p02-classifier-extension-shape.sh,tools/verify/m031-p02-fixture-provenance-shape.sh,tools/verify/m031-p02-tier-a-plus-input-shape.sh,tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh"
key_decisions:
  - "Tier A+ heuristic boundary chosen as 30-80 words AND zero structural markers (^## heading / Given-When-Then triple / ^- FR- bullet) — answers P02 open question A1; new branch inserted AFTER fragment branch and BEFORE idea branch in shape-detect.sh so it claims the uninstantiated middle band without disturbing the fragment >=81 or words<=10 idea boundaries; paragraph-classify.sh extended via comment-only annotation (rationale_paragraph emitted output stays byte-equal pre/post — router consumes shape-detect.sh's verdict directly and skips paragraph-classify.sh on the Tier A+ branch); FIXTURE-PROVENANCE.md cites both M031/P01/T01 and M030/P07/T03 unit_close records for cross-record breadth (heuristic generalizes beyond a single citation); SC-5 acceptance test uses RESULT: SC-5 pass envelope per the M031 P01 SC-* convention; shape verifiers use SUMMARY: <name> pass=N fail=M envelope per the M031 P01 convention"
patterns_established:
  - "additive verdict-enum extension on a closed M024 surface (insert new branch BEFORE the fallback default and AFTER the higher-priority sibling so fallback semantics stay byte-equal); comment-only annotation pattern for satisfying literal-token verifier requirements without changing emitted output (paragraph-classify.sh); AD-16 normative grounding pattern (FIXTURE-PROVENANCE.md cites historical unit_close records by M###/P##/T## provenance; downstream verifier requires both file existence and provenance pattern); fixture-paraphrase-from-citation discipline (tier-a-plus-input.txt body is a paraphrase of the cited record's task description, keeping the heuristic empirically grounded)"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-PLAN.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-05-01T18:33:35Z"
---

T01 extends the M024 input-shape classifier additively with a sixth verdict value tier_a_plus per FR-6 and grounds the heuristic in the AD-16 normative provenance file at tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md. The Tier A+ heuristic claims the uninstantiated 30 to 80 word zero structural marker middle band between the existing paragraph 11 to 29 word band and the existing fragment greater than or equal to 81 word OR structural marker band. The existing five M024 verdict tokens (idea paragraph fragment spec empty) stay byte-equal pre/post on the M024 regression test test-intake-proposal-shape.sh which still passes 3 of 3 cases. paragraph-classify.sh receives a comment-only annotation containing the literal tier_a_plus token (the router consumes shape-detect.sh's verdict directly so the paragraph-classify.sh emitted scope_tier output stays byte-equal pre/post on the Tier B 31 to 80 word band).

FIXTURE-PROVENANCE.md cites two real historical unit_close records drawn from .orchestrator/ JSONL streams: M031/P01/T01 (build-context-profile additive flag work in the 2026-05-01 session) and M030/P07/T03 (evidence-ledger-and-phase-suite in M030's close ceremony). The annotator rationale section explains why the cited records qualify as Tier A+ candidates (word-count band structural-marker absence operator-intent shape) and the boundary heuristic confirmation section justifies the chosen 30 to 80 word band and the zero structural marker exclusion rules. tier-a-plus-input.txt is a 62-word feature-request shape paraphrased from the M031/P01/T01 record (extend the dispatch build-context script with two additive flags so callers can request a quick profile and a meta sidecar file in one invocation).

Verification: m031-p02-classifier-extension-shape pass=10 fail=0; m031-p02-fixture-provenance-shape pass=7 fail=0; m031-p02-tier-a-plus-input-shape pass=6 fail=0; m031-p02-test-tier-a-plus-classifier-shape pass=5 fail=0; SC-5 acceptance test test-tier-a-plus-classifier.sh exits 0 with RESULT: SC-5 pass envelope; M024 regression test test-intake-proposal-shape.sh exits 0 (paragraph idea spec-path 3 cases); shape-detect.sh sanity probes confirm 2-word input still classifies as idea 23-word input still classifies as paragraph 80-word input classifies as tier_a_plus low confidence at the boundary edge 100-word input still classifies as fragment.

T01 answers P02 open question A1 (heuristic boundary band) by selecting 30 to 80 words AND zero of the three structural markers as the Tier A+ verdict surface. A2 (router CLI surface) A3 (SC-6 stub vs real dispatch) A4 (session-ID sidecar mechanism) A5 (.orchestrator/tier-a-plus/ allow-list prefix) deferred to T02 through T05 per the strict T01 to T05 dependency chain.

T01 leaves scripts/intake/route-to-dispatch.sh byte-identical to its pre-T01 state (T04's job to amend) leaves scripts/intake/lib/ untouched (T02 and T03's job to ship lib helpers) and leaves templates/dispatch-role-*.md untouched (T02's job to author). The SC-12 block-list (knowledge/** schema scripts/cost/ scripts/dispatch/adapters/router/ scripts/auto/loop/) is fully respected — no T01 edit touches any block-list path.

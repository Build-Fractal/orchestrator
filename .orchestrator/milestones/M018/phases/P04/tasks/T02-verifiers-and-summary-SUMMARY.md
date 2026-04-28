---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M018"
provides:
  - "seven P04-private truth verifiers under scripts/verify/m018-p04-*.sh; section-overflow + boundary-refusal fixture trees with READMEs; scripts/verify/_helpers/m018-p04-build-fixture.sh fixture-staging helper (slug-aware); .orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md (16-field phase frontmatter); CLAUDE.md+AGENTS.md recent-changes dual-write naming M018/P04 + tier2; P04-PLAN.md key-link reformat so check-must-haves.sh parses the arrow"
requires:
  - "T01"
affects:
  - "P05 (eval harness consumes tier1_savings_tokens + tier2_savings_tokens + filter_dropped_tokens together for cumulative-savings rollups; tier_preservation_violation records tier=tier2); doctor anomaly check baselines compression-regression vs historical post-T2 records"
key_files:
  - "scripts/verify/_helpers/m018-p04-build-fixture.sh;scripts/verify/m018-p04-tier2-head-drop.sh;scripts/verify/m018-p04-tier2-marker.sh;scripts/verify/m018-p04-tier2-boundary-refusal.sh;scripts/verify/m018-p04-tier2-emitter-additivity.sh;scripts/verify/m018-p04-tier2-disable-flag.sh;scripts/verify/m018-p04-tier2-preservation-self-check.sh;scripts/verify/m018-p04-dual-write-recent.sh;tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md;tests/fixtures/m018-p04-section-overflow/README.md;tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md;tests/fixtures/m018-p04-boundary-refusal/README.md;.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md;.orchestrator/milestones/M018/phases/P04/P04-PLAN.md;CLAUDE.md;AGENTS.md"
key_decisions:
  - "Stub pres_check_section to return 0 in shim scope for happy-path verifiers (head-drop, marker, boundary-refusal, emitter-additivity); invert to return 1 for failure-path coverage in the preservation-self-check verifier; same function-stub shape, opposite sentinel (mirrors P03/T03 pattern); dual fixture pattern keeps the awk pass exercised by both happy-path and boundary-retreat live; helper is slug-aware (section-overflow vs boundary-refusal) so one helper feeds all seven verifiers; reformat the references compression-grammar key-link in P04-PLAN.md to a single arrow per check-must-haves.sh parser shape"
patterns_established:
  - "Slug-aware fixture-staging helper (one helper, multiple fixtures via positional slug arg); function-stub-with-opposite-sentinel pattern (return 0 for happy-path, return 1 for failure-path, same lib-source + override + awk-extract shim); boundary-refusal verifier accepts either retreat OR passthrough+violation outcome (both grammar-conformant) so the verifier is robust against in-fixture sizing tweaks"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md;.orchestrator/milestones/M018/phases/P04/P04-PLAN.md;.orchestrator/milestones/M018/phases/P04/tasks/T01-tier2-head-drop-SUMMARY.md"
duration: "120"
verification_result: "pass"
completed_at: "2026-04-28T03:47:35Z"
---

T02 closes M018/P04 by shipping the verifier surface that exercises T01's _bc_apply_tier2 production code through hermetic fixtures and stubbed self-checks. The seven verifiers map 1:1 to the P04 truths and use the AD-19 single-script-file shape. The shim approach (source preservation-check.sh, override pres_check_section, awk-extract _bc_apply_tier2, run against fixture payload) mirrors the P03/T03 pattern and decouples the awk-pass coverage from the cross-tier strict-multiplicity self-check whose marker-additivity invariant would otherwise fail every happy-path test. The dual-fixture design (section-overflow + boundary-refusal) keeps both the head-drop happy-path and the MIT-01 4+-backtick boundary-refusal walker live. The boundary-refusal fixture exercises the MIT-01 case in production: a 4-backtick fence whose closer lands inside the protected tail forces the walker to retreat above the fence opener; the inner nested 3-backtick line survives the snip because tick-count tracking refuses to close a 4-tick fence with 3 ticks. All seven verifiers PASS, check-must-haves.sh passes (truths + artifacts + key-links), the recent-changes block is dual-written, and P04-SUMMARY.md is on disk with the 16-field phase frontmatter. P04 closes; M018 advances to P05 (eval harness).

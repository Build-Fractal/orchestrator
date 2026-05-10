---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M031"
provides:
  - "route-to-dispatch.sh extended additively with --verdict tier_a_plus mode (research/approval/plan/build chain via Quick-profile build-context.sh + role templates),unit_close JSONL schema additions tier_a_plus_role and aborted (additive optional fields),--dispatch-stub seam for SC-6 acceptance test,SC-6 end-to-end acceptance test tests/m031-acceptance/test-tier-a-plus-flow.sh,m031-p02-router-shape.sh + m031-p02-test-tier-a-plus-flow-shape.sh shape verifiers under tools/verify/"
requires:
  - "T01 (tier_a_plus classifier verdict),T02 (task-slug helper + three dispatch-role templates),T03 (tier-a-plus-prompt.sh helper with --yes / --session-id / exit codes 0/1/2)"
affects:
  - "P02/T05 (phase-suite aggregator + SC-12 scope-guard will fold the two new shape verifiers into the m031-p02-phase-suite.sh)"
key_files:
  - "scripts/intake/route-to-dispatch.sh,tests/m031-acceptance/test-tier-a-plus-flow.sh,tools/verify/m031-p02-router-shape.sh,tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh,templates/dispatch-role-research.md,templates/dispatch-role-plan.md,templates/dispatch-role-build.md,scripts/intake/lib/task-slug.sh,scripts/intake/lib/tier-a-plus-prompt.sh,scripts/dispatch/build-context.sh"
key_decisions:
  - "A2 router CLI surface: --verdict tier_a_plus --task DESC --yes --session-id ID --scratch-root DIR --dispatch-stub SCRIPT (--proposal/--verdict mutually exclusive),A3 stub-vs-real dispatch: --dispatch-stub flag + ORCH_DISPATCH_STUB env var (one shell argument; receives role/slug/desc/slug-dir positionals); SC-6 ships canned stub; production unset path invokes build-context.sh --profile=quick + role-template + AD-11 sidecar and stops at agent-runtime handoff (MEM018),A5 scratch prefix: .orchestrator/tier-a-plus/SLUG/ (matches T03 prompt helper); --scratch-root override for tests; ORCH_TIER_A_PLUS_LOG override for unit_close JSONL log path,docstring discipline: paraphrase forbidden command names so the router-shape grep stays strict per task plan step 6"
patterns_established:
  - "additive --verdict CLI mode on legacy positional router (preserves existing --proposal path byte-equal),per-role dispatch wrapper with stub-vs-real bifurcation,inline JSONL emitter for new schema additions (no new emitter introduced; Bash 3.2 string concatenation per existing convention),paraphrased-forbidden-token discipline (router-shape verifier grep stays strict by paraphrasing CON-4 command names in source docstrings),sandbox SC-6 with --dispatch-stub + --scratch-root + ORCH_TIER_A_PLUS_LOG env override (test exercises router shape without touching real .orchestrator/ tree)"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P02/tasks/T04-router-and-flow-test-PLAN.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-05-01T19:27:59Z"
---

T04 closes the Tier A+ middle-flow router. Three deliverables: (1) scripts/intake/route-to-dispatch.sh extended additively with a --verdict tier_a_plus mode that chains research/approval-prompt/plan/build dispatches; (2) tests/m031-acceptance/test-tier-a-plus-flow.sh (SC-6) drives the chain through a canned stub and asserts three unit_close records, three role artifacts, zero milestone scaffolding, zero locks, zero stdin consumption under --yes; (3) two shape verifiers under tools/verify/. All three verifiers exit 0 (router-shape pass=18 fail=0; flow-shape pass=11 fail=0; SC-6 RESULT pass). Open questions A2/A3/A5 resolved per the key_decisions field. Legacy single-dispatch path remains byte-equal (verified via tests/test-paragraph-intake.sh PASS: route-to-dispatch invoke line).

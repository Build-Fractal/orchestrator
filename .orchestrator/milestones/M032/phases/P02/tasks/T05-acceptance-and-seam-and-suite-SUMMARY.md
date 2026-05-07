---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P02"
milestone: "M032"
provides:
  - "tests/m032-acceptance/p02-wiki-init-default-scope.sh (SC-3); tests/m032-acceptance/p02-glossary-surface.sh (SC-7); tests/paired-m032-m033/seam-A.sh + seam-B.sh + seam-C.sh paired-launch contracts; tools/verify/m032-p02-acceptance-shape-sc3.sh + m032-p02-acceptance-shape-sc7.sh + m032-p02-seam-a-shape.sh + m032-p02-seam-b-shape.sh + m032-p02-seam-c-shape.sh + m032-p02-phase-suite.sh + m032-p02-scope-guard.sh; tools/verify/fixtures/m032-p02-baseline-ref.txt baseline captured"
requires:
  - "from:T01,T02,T03,T04 what:wiki-init.sh + init-project.sh --with-wiki passthrough + wiki/glossary.md + scripts/wiki/wiki-scan-sources.sh + scripts/wiki/wiki-generate-nav.sh + scripts/knowledge/lookup-mems.sh + tools/verify/lib/m032-p02-wiki-serve-probe.sh"
affects:
  - "P03 (verifier patterns); M033/P05 (consumes Seam-A/B/C contracts per CON-3); M032/P05 (acceptance battery picks up SC-3 + SC-7)"
key_files:
  - "tests/m032-acceptance/p02-wiki-init-default-scope.sh,tests/m032-acceptance/p02-glossary-surface.sh,tests/paired-m032-m033/seam-A.sh,tests/paired-m032-m033/seam-B.sh,tests/paired-m032-m033/seam-C.sh,tools/verify/m032-p02-acceptance-shape-sc3.sh,tools/verify/m032-p02-acceptance-shape-sc7.sh,tools/verify/m032-p02-seam-a-shape.sh,tools/verify/m032-p02-seam-b-shape.sh,tools/verify/m032-p02-seam-c-shape.sh,tools/verify/m032-p02-phase-suite.sh,tools/verify/m032-p02-scope-guard.sh,tools/verify/fixtures/m032-p02-baseline-ref.txt"
key_decisions:
  - "SC-3,SC-7,FR-5,FR-6,FR-11,FR-12,FR-15,FR-16,MIT-001,MIT-010,MIT-011,AD-19,SC-13,Q-4,Q-B"
patterns_established:
  - "paired-milestone seam-script convention under tests/paired-m032-m033/ shared by both M032 and M033 verifier suites; scope-guard first-run-captures-baseline pattern (mirrors P01 m032-p01-baseline-ref.txt precedent); SC-7 actual contract reified (Glossary follows Constitution, not second-top-level-entry) -- the payload awk count was off-by-one against the Home-prefix nav; Seam-B identity-leak assertion (NOT file-absence) -- install-claude-code stages wiki/ from REPO_ROOT before wiki-init runs, so file presence is expected and the load-bearing invariant is that the FIXTURE identity is not baked into mkdocs.yml; grep -c under set -eu in command-substitution requires || true fallback to avoid silent abort when count==0"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P02/tasks/T05-acceptance-and-seam-and-suite-PLAN.md,.orchestrator/milestones/M032/phases/P02/tasks/T05-acceptance-and-seam-and-suite-PAYLOAD.md"
duration: "180m"
verification_result: "pass"
completed_at: "2026-05-07T15:41:10Z"
---

T05 ships the verification surface that closes M032 P02. Five deliverable categories landed: (1) two milestone-grain SC acceptance scripts (SC-3 wiki-init default scope + SC-7 glossary surface) under tests/m032-acceptance/; (2) three paired-launch seam scripts under tests/paired-m032-m033/ encoding the shared M032 <-> M033 invariants for project_assets schema (Seam-A), --with-wiki failure-propagation (Seam-B), and wiki/glossary.md format invariant (Seam-C); (3) five T05 verifier shape pins under tools/verify/ (acceptance-shape-sc3, acceptance-shape-sc7, seam-a-shape, seam-b-shape, seam-c-shape); (4) m032-p02-phase-suite.sh straight-line aggregator chaining all twelve P02 sub-gates per AD-19; (5) m032-p02-scope-guard.sh + m032-p02-baseline-ref.txt fixture capturing the SC-13 scope discipline using committed-history-only diff per the P01 patterns-established lesson. All twelve phase-suite sub-gates PASS (pass=12 fail=0). All three seam scripts and both acceptance scripts exit 0. Three load-bearing course-corrections during implementation: (a) SC-7 nav check rewritten to assert entry-following-Constitution-is-Glossary rather than the payload literal second-top-level-entry awk -- the actual nav generator emits Home as #1, so Glossary is #3 overall but #2 of orchestrator-managed entries; (b) Seam-B step (d) rewritten from wiki/mkdocs.yml-absent to fixture-identity-not-baked-in -- install-claude-code stages wiki/ from REPO_ROOT BEFORE wiki-init runs, so file presence is expected; the load-bearing invariant is that wiki-init templating step did NOT fire against the fixture git remote; (c) SC-7 grep -c under set -eu silently aborted command-substitution when count==0 -- added || true fallback. Scope-guard captured baseline at prior commit and reports 13 in-scope paths with 0 violations after T05 commit lands. T05 modifies no T01..T04 deliverable per task constraint.

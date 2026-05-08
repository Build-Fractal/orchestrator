---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "M035/P00"
milestone: "M035"
provides:
  - "M032 SC-5 fixture-completeness fallback wired into wiki-init.sh --deploy step 2; D-RN-1 npm-name collision-check evidence captured at packaging/bundle/D-RN-1-evidence.txt; M035 P00 phase-suite aggregator (m035-p00-phase-suite.sh) authored per AD-19"
requires:
  - "from:M035/P00/T03 what:wiki-stubs-fresh diagnostic green-on-clean (drift gate landed)"
affects:
  - "M032 (SC-5 deferred-validation gap closed); M035/P02 (D-RN-1 binding feeds package.json authoring)"
key_files:
  - "scripts/lifecycle/wiki-init.sh,packaging/bundle/D-RN-1-evidence.txt,tools/verify/m035-p00-wiki-deploy-stage.sh,tools/verify/m035-p00-npm-collision-evidence.sh,tools/verify/m035-p00-phase-suite.sh"
key_decisions:
  - "D-RN-1=@build-fractal/orchestrator (unscoped 'orchestrator' on npm is TAKEN by orchestrator@0.3.8; @build-fractal scope AVAILABLE)"
patterns_established:
  - "missing-only stage-from-REPO_ROOT fallback for installer scripts where source-repo dirs may not have been bundled into PROJECT_DIR; phase-suite aggregator filename embeds milestone+phase prefix per AD-19 (m035-p00-phase-suite.sh)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P00/tasks/T04-m032-wiki-deploy-stage-and-npm-evidence-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-08T11:46:23Z"
---

Three deliverables shipped: (1) wiki-init.sh --deploy step 2 now stages $REPO_ROOT/scripts/wiki/wiki-deploy.sh into $PROJECT_DIR/scripts/wiki/wiki-deploy.sh when absent (closes M032 SC-5 fixture-completeness gap; existing-file behaviour unchanged). (2) packaging/bundle/D-RN-1-evidence.txt records the npm-name collision-check outcome: '@build-fractal/orchestrator' is AVAILABLE (404 from registry), unscoped 'orchestrator' is TAKEN (orchestrator@0.3.8, MIT). Resolution D-RN-1 = @build-fractal/orchestrator; downstream bindings: D-RN-2 = Build-Fractal/orchestrator (GH repo), D-RN-4 = build-fractal/orchestrator (Homebrew tap), C7 = @build-fractal/orchestrator (npm scope token). (3) tools/verify/m035-p00-phase-suite.sh aggregator authored per AD-19 (filename embeds m035-p00- to avoid prior milestone-clobber regression). Phase-suite battery: pass=5 fail=0 (m035-p00-bash32-collision + m035-p00-managed-gitignore + m035-p00-wiki-stubs-fresh + m035-p00-wiki-deploy-stage + m035-p00-npm-collision-evidence). One side-effect: T04 PAYLOAD landing on disk drifted wiki/docs/milestones/M035/phases/P00/index.md and wiki/mkdocs.yml; ran wiki-generate-stubs.sh + wiki-generate-nav.sh to regenerate (constitutes load-bearing dogfood of T03's wiki-stubs-fresh diagnostic — diagnostic correctly red-flagged drift, then green after regen).

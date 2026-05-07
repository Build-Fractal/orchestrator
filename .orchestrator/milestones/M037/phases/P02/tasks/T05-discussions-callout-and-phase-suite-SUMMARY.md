---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P02"
milestone: "M037"
provides:
  - "wiki/README.md First-deploy checklist org-level-discussions-redirect callout (FR-22b/SC-17),tests/m037-acceptance/p01-discussions-callout.sh SC-17 acceptance test,tools/verify/m037-p02-discussions-callout.sh FR-22b verifier,tools/verify/m037-p02-phase-suite.sh AD-19 straight-line aggregator (5 gates),tests/m037-acceptance/run-acceptance-battery.sh extended with explicit-invocation block for handoff-doc test scaffolds (BATTERY pass=10 skip=0 fail=0)"
requires:
  - "from:T01-T04 what:m037-p02 verifiers feedback-routing/workflow-pages-publishing/private-site-url/out-of-scope-collapse"
affects:
  - "M037 phase-close gate (T05 phase-suite is canonical P02-is-done signal); M037 milestone close gate consumes BATTERY pass=10 skip=0 fail=0"
key_files:
  - "wiki/README.md,tools/verify/m037-p02-discussions-callout.sh,tools/verify/m037-p02-phase-suite.sh,tests/m037-acceptance/p01-discussions-callout.sh,tests/m037-acceptance/run-acceptance-battery.sh"
key_decisions:
  - "FR-22b,SC-17,AD-19"
patterns_established:
  - "P02 phase-suite aggregator straight-line shape per AD-19 (5 gates x bash verifier-path + accumulator; mirrors m037-p01-phase-suite.sh and m029-p01-phase-suite.sh)"
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md"
duration: "~30m"
verification_result: "pass"
completed_at: "2026-05-07T16:11:38Z"
---

T05 ships the M037 P02 phase-close hygiene bundle: FR-22b README discussions-redirect callout + acceptance battery extension to BATTERY pass=10 skip=0 fail=0 + AD-19 straight-line phase-suite aggregator covering all five P02 verifiers. All three task-plan Verification commands exit 0. Phase-close gates green. P02 is ready to close. Phase-suite SUMMARY pass=5 fail=0; battery BATTERY pass=10 skip=0 fail=0; discussions-callout verifier SUMMARY pass=7 fail=0. README contribution is purely additive (org-level-redirect callout block ~15 lines between step 1 and step 2 of First-deploy checklist); upstream T02 workflow-publishing-cluster restructure already in working tree accounts for the bulk of git diff. Battery composition: 5 P01 tests + 3 P02 tests glob-matched as p01-*.sh (feedback-routing, out-of-scope-collapse, discussions-callout) + 2 explicit-invocation tests (test-wiki-init-workflow-mode, test-wiki-init-private-site-url). Phase-suite gates only P02 surface area; does NOT include m037-p01-phase-suite.sh per plan note.

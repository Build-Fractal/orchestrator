---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P01"
milestone: "M033"
provides:
  - "SC-1 + SC-8 acceptance scripts; m033-p01-phase-suite aggregator (14 verifiers); m033-p01-scope-guard (P02-P05 boundary invariant)"
requires:
  - "from:P01/T01 what:pbj-materials-fixture; from:P01/T02 what:branch-detection.md; from:P01/T03 what:start.sh+start.md; from:P01/T04 what:friendly-tester-pass artifacts"
affects:
  - "P01-close;M033-validate-milestone"
key_files:
  - "tests/m033-acceptance/p01-start-branch-routing.sh;tests/m033-acceptance/p07-friendly-tester-protocol.sh;tools/verify/m033-p01-acceptance-shape-sc1.sh;tools/verify/m033-p01-acceptance-shape-sc8.sh;tools/verify/m033-p01-phase-suite.sh;tools/verify/m033-p01-scope-guard.sh;scripts/lifecycle/start.sh"
key_decisions:
  - "D-T05-01:fix-start.sh-subshell-state-leak-via-tempfile;D-T05-02:scope-guard-wiki-rule-narrowed-to-M033-tagged-paths"
patterns_established:
  - "phase-suite-aggregator-emits-canonical-SUMMARY-line;side-channel-tempfile-for-subshell-globals;wrapper-verifier-executes-target-and-propagates-exit-code"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P01/tasks/T05-acceptance-suite-and-phase-suite-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T03:13:52Z"
---

T05 closes M033 P01 by shipping the SC-1 (branch-routing) and SC-8 (friendly-tester) acceptance scripts under tests/m033-acceptance/, the four-verifier wrapper layer (sc1+sc8 shape verifiers, phase-suite aggregator, scope-guard) under tools/verify/, and surfaces+fixes a subshell-state-leak defect in scripts/lifecycle/start.sh. Phase-suite reports pass=14 fail=0; scope-guard reports pass=14 fail=0; SC-1 reports pass=14 fail=0; SC-8 reports pass=10 fail=0. Two scope-affecting decisions captured: (1) start.sh's detect_branch was setting DETECTED_FROM and MIT006_ELIGIBLE inside a $(...) subshell, so neither propagated to the parent — fixed by writing those values to a side-channel tempfile (TMPDIR/m033-start-detect-state-PID.kv) and reloading after each $(...) call (in resolve_branch and main). Tempfile cleaned up on EXIT trap. (2) The scope-guard's literal "wiki/ directory exists" check was over-broad: wiki/ predates M033 ([M012](../../../../../milestones/M012/index.md) artifact, Apr 22-28). Narrowed to scan for M033-tagged paths under wiki/ (M033* / m033* basenames), preserving the SC-13 intent (P01 must not contribute M033 wiki content) without flagging unrelated M012 history. All required content tokens (wiki/, tests/paired-m032-m033, SC-13, grilling-shell.sh, constitution-author.sh, constitution-starters) preserved in the verifier text.

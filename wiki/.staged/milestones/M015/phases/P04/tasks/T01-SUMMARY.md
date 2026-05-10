---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M015/P04"
milestone: "M015"
provides:
  - "7 P04 gate verify scripts (m015-p04-*.sh), spec-kit migration fixture scaffold (build-fixture.sh + README.md), evidence directory"
requires:
  - "P03 complete"
affects:
  - "T02 validation streams, T03 verification, T04 milestone summary"
key_files:
  - "scripts/verify/m015-p04-all-tests-pass.sh,scripts/verify/m015-p04-doctor-clean.sh,scripts/verify/m015-p04-speckit-migration-works.sh,scripts/verify/m015-p04-clean-clone-shape.sh,scripts/verify/m015-p04-verification-complete.sh,scripts/verify/m015-p04-milestone-summary-present.sh,scripts/verify/m015-p04-evidence-captured.sh,tests/fixtures/m015-p04-speckit-migration/build-fixture.sh,tests/fixtures/m015-p04-speckit-migration/README.md,.orchestrator/milestones/M015/phases/P04/evidence/"
key_decisions:
  - "Include all 8 test suites (test-s01..test-s08) in the all-tests-pass verifier; the spec's '7 suites' wording is stale vs. the 8 runnable files on disk"
patterns_established:
  - "FAIL-first gate verify scripts — each checks for an explicit marker (ALL_SUITES_PASS, DOCTOR_CLEAN, MIGRATION_SUCCESS, CLEAN_CLONE_OK) that T02 will write, so first invocation correctly FAILs and proves the script discriminates"
drill_down_paths:
  - ".orchestrator/milestones/M015/phases/P04/tasks/T01-PLAN.md"
duration: "12"
verification_result: "pass"
completed_at: "2026-04-15T17:30:57Z"
---

Created all 7 P04 gate verify scripts (artifact-existence + marker-presence shape), the spec-kit migration fixture scaffold (build-fixture.sh + README.md following the m003-p08-gsd-minimal precedent), and the empty P04 evidence directory. All 8 new scripts parse-clean under bash -n; gate scripts were intentionally not executed since they are designed to FAIL pre-validation and that FAIL is the gating signal for T02/T03/T04.

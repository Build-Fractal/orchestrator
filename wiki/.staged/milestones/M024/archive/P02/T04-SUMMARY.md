---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "M024/P02"
milestone: "M024"
provides:
  - "tests/test-evaluate-spec-backcompat.sh; tests/test-m014-manifest-read.sh; scripts/verify/m024-p02-fixture-vs-live.sh; scripts/verify/m024-p02-write-confinement.sh; scripts/verify/m024-p02-suite.sh"
requires:
  - "from:M024/P02/T01 what:scripts/intake/spec-shape-classify.sh+proposal-emit.sh wiring; from:M024/P02/T02 what:scripts/intake/m014-manifest-read.sh; from:M024/P02/T03 what:tests/fixtures/evaluate-pre-m024-baseline.txt+SPEC_AXES_DONE wiring"
affects:
  - "M024/P02 (closes phase); M024/P03 via suite shape"
key_files:
  - "tests/test-evaluate-spec-backcompat.sh, tests/test-m014-manifest-read.sh, scripts/verify/m024-p02-fixture-vs-live.sh, scripts/verify/m024-p02-write-confinement.sh, scripts/verify/m024-p02-suite.sh"
key_decisions:
  - "Both phase tests use specs/028-universal-intake-routing for the spec-path/M014-shaped paths (T01-T03 deviation precedent); the backcompat verify path remains specs/023-github-native-integration via the per-task verify (raw-grep, classifier-bypass); template-pivot in test-m014-manifest-read.sh uses trap-guarded restore so an interrupt cannot leave templates/spec-template.md missing"
patterns_established:
  - "phase-suite shape (two phase-tests + every per-task verify in one runner); MEM002 parallel-array pass/fail tracking applied to spec-path tests; SB-3 atomic round-trip via trap-guarded restore for the M014 invoke-time-probe test"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P02/tasks/T04-PLAN.md,.orchestrator/milestones/M024/phases/P02/tasks/T04-PAYLOAD.md"
duration: "12m"
verification_result: "pass"
completed_at: "2026-04-26T02:08:34Z"
---

T04 closes M024/P02 with two phase-level regression tests plus three remaining verify scripts plus the suite runner. tests/test-evaluate-spec-backcompat.sh wraps the per-task baseline-diff verify (raw-grep against spec 023) and exercises the full proposal-emit path end-to-end with spec 028 — asserting input_shape=spec, scope_tier in A or B or C, recommended_command=orchestrator:roadmap. tests/test-m014-manifest-read.sh asserts six-line canonical-order output, --spec-path / --specs-dir parity, and the invoke-time [M014](../../../../milestones/M014/index.md) probe by parking templates/spec-template.md to /tmp under a trap-guarded restore (the only non-fixture disk mutation in P02 — round-trip is atomic on success, failure, and interrupt). scripts/verify/m024-p02-fixture-vs-live.sh diffs the P01 fixture key-list against the live reader output (per AD-4 direction a — the FR-15 canary). scripts/verify/m024-p02-write-confinement.sh greps the three intake-tree scripts for write ops and asserts targets resolve under .orchestrator/intake/, /tmp, or tests/fixtures/ (heuristic; subtle violations caught at consolidation review). scripts/verify/m024-p02-suite.sh runs both phase tests plus all six per-task verifies (spec-shape-classify, m014-manifest-read, fixture-vs-live, evaluate-spec-backcompat, spec-rationale, write-confinement) and reports a single PASS summary. All eight gates green on a clean checkout. DEVIATION FROM T04-PLAN: the plan named specs/023-github-native-integration as the spec-path target throughout the new tests; the spec-shape-classifier and M014 reader both require type:feature-spec frontmatter which 023 lacks. T01 and T02 already pivoted their per-task verifies to spec 028 for the same reason — T04 follows that precedent. The backcompat path (raw grep) is unaffected and still uses 023. SB-3 honored: the only non-fixture disk mutation is the templates/spec-template.md pivot in test-m014-manifest-read.sh, which is wrapped in a trap-guarded restore. AD-19 honored: every external invocation in the suite plus tests is a single-script-file shape; no inline compound bash.

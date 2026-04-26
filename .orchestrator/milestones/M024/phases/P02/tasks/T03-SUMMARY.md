---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "M024/P02"
milestone: "M024"
provides:
  - "tests/fixtures/evaluate-pre-m024-baseline.txt; scripts/intake/_capture-baseline.sh; scripts/verify/m024-p02-spec-rationale.sh; scripts/verify/m024-p02-evaluate-spec-backcompat.sh; scripts/intake/proposal-emit.sh SPEC_AXES_DONE wiring"
requires:
  - "from:M024/P02/T01 what:scripts/intake/spec-shape-classify.sh + (3b) spec hook in proposal-emit.sh"
affects:
  - "P02/T04,P02/T07"
key_files:
  - "scripts/intake/proposal-emit.sh, scripts/intake/_capture-baseline.sh, tests/fixtures/evaluate-pre-m024-baseline.txt, scripts/verify/m024-p02-spec-rationale.sh, scripts/verify/m024-p02-evaluate-spec-backcompat.sh"
key_decisions:
  - "Use spec 028 instead of plan-named spec 023 for spec-rationale verify (023 lacks type:feature-spec frontmatter required by spec-shape-classify); 023 still used for raw-grep backcompat baseline since that path bypasses the classifier"
patterns_established:
  - "SPEC_AXES_DONE sentinel mirroring PARA_AXES_DONE — input_shape+scope_tier+decomposition slots all swap to spec_rationale when set; baseline-fixture pattern (one-shot _capture script + diff-driven regression verify) keeps today-shape evaluate metrics frozen for downstream byte-compat"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P02/tasks/T03-PLAN.md, .orchestrator/milestones/M024/phases/P02/tasks/T03-PAYLOAD.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-26T02:02:49Z"
---

T03 captured the pre-M024 evaluate baseline (story=7, FR=18, AC=29 for spec 023) into tests/fixtures/evaluate-pre-m024-baseline.txt and wired the SPEC_AXES_DONE sentinel into scripts/intake/proposal-emit.sh — spec-branch inputs now overwrite the input_shape, scope_tier, and decomposition rationale/evidence slots with the spec_rationale string from T01's classifier, and the rationale-loop guard skips those three axes when the sentinel is set. Both new verify scripts pass: m024-p02-spec-rationale.sh confirms the input_shape slot no longer carries the P01 stub for spec inputs (uses spec 028 — see DEVIATION below), and m024-p02-evaluate-spec-backcompat.sh re-runs the same raw-spec grep counts and diffs byte-identical against the baseline. T01's existing m024-p02-spec-shape-classify.sh verify still passes — no regression on the shared emitter. DEVIATION from plan: the spec-rationale verify uses specs/028-universal-intake-routing/spec.md instead of the plan-named specs/023-github-native-integration/spec.md. Spec 023 predates M014 and lacks the type:feature-spec frontmatter that spec-shape-classify.sh requires; the emitter therefore silently leaves spec_rationale empty for 023, and no rationale gets wired. T01 and T02 hit the same gap and used spec 028 — T03 follows that precedent. Spec 023 is still used (correctly) by the backcompat baseline since that path is a raw grep regression and bypasses the classifier entirely. SB-3 write-confinement honored: capture script writes only to stdout; the only on-disk new file outside .orchestrator/intake/ is the committed baseline fixture.

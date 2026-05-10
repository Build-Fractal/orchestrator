---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P00"
milestone: "M030"
provides:
  - "40-plan classifier ground-truth fixture skeleton at tests/fixtures/m030-classifier-corpus/labels.yml (TBD labels — T02 fills); p00-corpus-shape.sh + p00-plans-exist.sh AD-19 verifiers under tools/verify/ (project-owned path)"
requires:
  - "from:P00/T01 what:none (head of phase; sources from .orchestrator/milestones/M-glob/archive/+phases/ T-glob-PLAN.md candidate pool — 433 closed-milestone plans, M028 + M030 excluded)"
affects:
  - "M030/P00/T02 (label-application pass against the locked corpus); M030/P00/T03 (README graduation + class-coverage verifier); M030/P01 (classify-task.sh authorship — D-A4 invariant)"
key_files:
  - "tests/fixtures/m030-classifier-corpus/labels.yml,tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md,tools/verify/p00-corpus-shape.sh,tools/verify/p00-plans-exist.sh"
key_decisions:
  - "D-A4 (independence-by-construction: classifier labels predate classifier code on disk); closed-milestone-only sourcing (in-flight bias guard); 40-plan floor with provisional class-diversity intent"
patterns_established:
  - "project-owned verifier path under tools/verify/ (AD-19 install-clobber containment); single-script-file Truth Check shape with awk-based shape walker + grep-based key probe; TBD-tolerant vocabulary check at skeleton phase that T02/T03 tighten"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P00/tasks/T01-source-pool-and-skeleton-PAYLOAD.md,tests/fixtures/m030-classifier-corpus/SELECTION-NOTES.md"
duration: "45m"
verification_result: "p00-corpus-shape.sh pass=6 fail=0; p00-plans-exist.sh pass=40 fail=0"
completed_at: "2026-04-30T04:33:56Z"
---

T01 sweeps .orchestrator/milestones/ for T-glob-PLAN.md candidates from closed milestones (excluded [M028](../../../../../milestones/M028/index.md) in-flight + M030 self), samples 40 plans across 21 milestones with class-diversity intent, writes the labels.yml skeleton with all entries at TBD, captures selection methodology in SELECTION-NOTES.md (graduates into README in T03), and ships two Bash 3.2-compatible verifiers (corpus-shape + plans-exist) under tools/verify/ — the project-owned path that prevents install-clobber risk. Both verifiers exit 0 against the T01-close skeleton (TBD-tolerant by design; T02 fills labels and T03 ships the strict class-coverage gate). D-A4 verified at start and end: scripts/dispatch/classify-task.sh absent on disk, satisfying the independence-by-construction invariant that anchors SC-10 audit trail.

---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M033"
provides:
  - "scripts/util/start-state-markers.sh marker primitives library; scripts/lifecycle/start.sh additive resume-on-partial-state extension; tests/m033-acceptance/p07-resume-on-partial-state.sh SC-12 acceptance script; three T02 verifiers under tools/verify/m033-p02-*"
requires:
  - "from:P01/T03 what:scripts/lifecycle/start.sh-P01-surface"
affects:
  - "P03,P04,P05"
key_files:
  - "scripts/util/start-state-markers.sh,scripts/lifecycle/start.sh,tests/m033-acceptance/p07-resume-on-partial-state.sh,tools/verify/m033-p02-start-state-markers-shape.sh,tools/verify/m033-p02-start-sh-resume-extension.sh,tools/verify/m033-p02-acceptance-shape-sc12.sh"
key_decisions:
  - "closed-7-name-subflow-enum-as-fenced-SSOT;idempotent-marker-write-preserves-first-completion-timestamp;init-invoked-marker-write-post-init-for-symmetry;resume-detection-block-exits-0-after-diagnostic-pending-P03-P04-P05-real-dispatch"
patterns_established:
  - "closed-enum-as-fenced-SSOT-grep-token-tripwire;idempotent-marker-with-first-write-timestamp-preservation;P01-preservation-gate-via-AD-15-cross-phase-regression-precedent-sub-step;additive-extension-discipline-no-touch-of-P01-behavior-paths"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P02/tasks/T02-start-state-markers-and-resume-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T03:40:14Z"
---

T02 ships the read-side and write-side primitives for the FR-20 sub-flow start-state marker convention plus the additive resume-on-partial-state extension to scripts/lifecycle/start.sh. The marker library exposes write, read, next, and clear subcommands over a closed 7-name enum (init-invoked, ideation, materials-intake, ingest-codebase, migrate-routed, constitution-authored, customblock-drafted) and stores marker files at .orchestrator/start-state/<name>.complete with idempotent first-write timestamp preservation. The start.sh extension adds the --no-resume escape valve, writes the init-invoked marker post-init for symmetry, and after branch resolution checks whether the current branch sub-flow is already complete. When complete, it emits the load-bearing diagnostic line start-state: resuming from <next> and exits zero, skipping the P01 stub. When --no-resume is set or no markers exist, the P01 baseline path is preserved verbatim. The SC-12 acceptance script exercises four scenarios end to end: primitive smoke for write read next, the resume diagnostic firing path, the --no-resume escape-valve restoring baseline, and the cleared-marker default-baseline path. Three verifiers cover library shape plus functional smoke, start.sh resume-extension shape with a P01-preservation gate sub-step that re-runs m033-p01-start-md-shape.sh per the AD-15 cross-phase regression precedent, and SC-12 acceptance script shape. Verification result: shape verifier pass=29 fail=0, resume-extension verifier pass=11 fail=0, SC-12 acceptance shape verifier pass=8 fail=0, SC-12 acceptance script pass=14 fail=0, P01 phase suite pass=14 fail=0 confirming zero regression, P01 SC-1 acceptance pass=14 fail=0 confirming behavioral preservation.

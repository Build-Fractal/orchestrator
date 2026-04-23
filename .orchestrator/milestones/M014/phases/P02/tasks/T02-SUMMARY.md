---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M014"
provides:
  - "scripts/lifecycle/init-project.sh project-identity dual-write; scripts/lifecycle/reinit-handler.sh project-identity dual-write; scripts/verify/m014-p02-init-dual-write.sh gate; scripts/verify/m014-p02-reinit-dual-write.sh gate"
requires:
  - "from:P01/T03 what:scripts/util/dual-write-runtime-md.sh; from:P02/T01 what:.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md"
affects:
  - "P02/T07 phase-suite; M014/P03 drift detection; M014/P04 consolidate dual-write"
key_files:
  - "scripts/lifecycle/init-project.sh,scripts/lifecycle/reinit-handler.sh,scripts/verify/m014-p02-init-dual-write.sh,scripts/verify/m014-p02-reinit-dual-write.sh"
key_decisions:
  - "Reinit verifier invokes reinit-handler directly with --mode update (init delegation without --mode exits 4 by design); outside-markers byte-preservation tested via helper re-invocation on reinit-produced file (not init→reinit diff) because reinit legitimately refreshes rendered template"
patterns_established:
  - "additive dual-write between runtime-native render and config.yml write; fallback to CLAUDE.md-only when AGENTS.md gated by dual_write_agents=false; SUMMARY line carries dual_writes=<N> observability field; helper-re-invocation byte-preservation test isolates SC-6a from legitimate reinit-template refresh"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P02/tasks/T02-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-22T23:25:43Z"
---

T02 patches init-project.sh and reinit-handler.sh with dual-write helper invocations for the project-identity region, and ships two hermetic gate verifiers. All four deliverables pass anti-pattern-lint, the SC-6a outside-invariant test continues to hold, and both new gates exit 0. Variable names in reinit-handler (RECOMMENDED_INTENSITY, CAP_SCORE) match init-project — planner risk flag did not materialize. One plan deviation: the reinit gate verifier invokes reinit-handler directly with --mode update instead of re-running init without --force, because init's reinit delegation passes no --mode and reinit-handler exits 4 by design without one. Also, the outside-markers preservation assertion was reshaped to test the SC-6a invariant via helper re-invocation on the reinit-produced CLAUDE.md, since the reinit path legitimately refreshes the rendered-template body (timestamp, project-type re-detection) which would make an init→reinit diff always fail. No live-repo mutations beyond the two target scripts and the two new verifiers.

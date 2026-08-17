---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M046"
provides:
  - "SC-9 non-stubbed full-exit-set battery m046-p02-marker-exit-contract.sh (11/11: exit-0 substates planning/phase_complete/validating plus 1/2/3/10/11/12/13/14, dual exit+marker assertion) and m046-p02-child-abort.sh (5/5 kill/crash/stall cases through the real driver) plus 11 checked-in fixture trees under tests/fixtures/m046-p02/exit-trees/"
requires:
  - "T01 env-gated marker writer in scripts/lifecycle/auto-loop.sh; T02 hardened scripts/lifecycle/self-continue-drive.sh with CHILD_RC truth table; tests/fixtures/m046-p02/verifying-tree base fixture"
affects:
  - "T04 (suite aggregates), P04 (marker contract proven for envelope)"
key_files:
  - "tools/verify/m046-p02-marker-exit-contract.sh, tools/verify/m046-p02-child-abort.sh, tests/fixtures/m046-p02/exit-trees/"
key_decisions:
  - "budget (exit 2) and rotate (exit 14) thresholds driven via read-config layer-1 env overrides SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET=1 / SPECKIT_ORCHESTRATOR_SESSION_WEIGHT_LIMIT=1 because auto-loop.sh passes no config files to read-config.sh so fixture-root config.yml is never consulted on this path; dispatch log records use the canonical event:dispatch fixture shape that budget-checker/stuck-detector literally grep (record-result dispatch_method shape does NOT match); planning-ok and planning-failed nest trees as root/milestones/MFIX so ORCH_ROOT resolves to a milestones-bearing root; planning-failed realized honestly via missing roadmap with phases/ present"
patterns_established:
  - "dual exit-code+marker-content assertion as the anti-false-pass mechanism for exit-contract batteries; whole-case-dir scratch staging (cp -R case dir, defensive marker rm) so sibling files like orchestrator.lock travel with the tree"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P02/"
duration: "1150s"
verification_result: "pass"
completed_at: "2026-07-13T16:31:55Z"
---

Built the SC-9 milestone-blocking non-stubbed exit battery: 11 checked-in fixture milestone trees under tests/fixtures/m046-p02/exit-trees/ drive the REAL scripts/lifecycle/auto-loop.sh to every exit code in its contract (exit-0 substates PLANNING/PHASE_COMPLETE/MILESTONE_VALIDATING plus 1 err-args, 2 budget, 3 stuck, 10 complete, 11 pause, 12 drift, 13 planning-failed, 14 rotate) with tools/verify/m046-p02-marker-exit-contract.sh asserting BOTH observed exit code AND exact marker content per case (SUMMARY: pass=11 fail=0), and tools/verify/m046-p02-child-abort.sh running kill-self/kill-after-marker/crash-no-marker/error-exit-with-marker/clean-no-marker through the REAL self-continue driver (SUMMARY: pass=5 fail=0); probe pass found that budget/rotate thresholds are only reachable via read-config layer-1 env overrides (auto-loop passes no config files) and that dispatch records must carry the quoted event:dispatch token, both recorded in the verifier header; T01 regressions m046-p02-marker-unit.sh (5/5) and m046-p02-legacy-parity.sh (6/6) stay green; no changes to auto-loop.sh or the driver were needed.

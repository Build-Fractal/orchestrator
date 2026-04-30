---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M028"
provides:
  - "No new artifacts authored. T04 is the phase-level close-out sweep — runs the full verification surface against the M028/P05 phase plan and produces empirical close-out evidence: (1) all six P05 Truth-Check leaves invoked individually emit final PASS lines and exit 0 (p05-fixture-permanent.sh, p05-downstream-fixture-shape.sh, p05-downstream-fixture-clean.sh, p05-corpus-replay-clean.sh, p05-run-all-clean.sh, p05-regression-gate.sh); (2) p05-regression-gate.sh end-to-end reports 'M028 close-out: 4/4 sub-gates clean' with all four sub-gates PASS (install-roundtrip rc=0 idempotency=98351856f438341650c0e6914bb41fa06612d2d766b4983618544a704f428f45 reversibility=EMPTY; corpus-replay-27-entry rc=0 tail=PASS:tests/run-prompt-corpus-replay.sh; per-finding-run-all rc=0 tail='M028: 7/7 findings verified (skipped: 0, failed: 0)'; downstream-fixture-replay rc=0 tail=PASS:tests/run-downstream-fixture.sh); (3) check-must-haves.sh against .orchestrator/milestones/M028/phases/P05 emits 42/42 PASS lines (6 truths + 27 artifact sub-assertions across 9 artifacts × 3 checks each + 9 key-links) and exits 0 — every Truth, every Artifact (existence + min-line-count + contains-pattern), every Key Link (source-references-target basename) clean; (4) run-all.sh reports 'M028: 7/7 findings verified (skipped: 0, failed: 0)' across the 8 per-finding verifiers (finding-A through finding-G plus G-classifier and G-wrapper)."
requires:
  - "from:P05/T01 what:tests/fixtures/downstream-project/.claude/settings.json + tests/fixtures/downstream-project/README.md + scripts/verify/m028/p05-fixture-permanent.sh + scripts/verify/m028/p05-downstream-fixture-shape.sh (CON-10 permanent fixture + Truth-Check leaves); from:P05/T02 what:tests/run-downstream-fixture.sh + scripts/verify/m028/p05-downstream-fixture-clean.sh (autonomous-loop replay harness + Truth-Check leaf, SC-3+SC-5); from:P05/T03 what:scripts/verify/m028/p05-regression-gate.sh + scripts/verify/m028/p05-corpus-replay-clean.sh + scripts/verify/m028/p05-run-all-clean.sh (close-out regression gate + two Truth-Check leaves, SC-1+SC-2+SC-4+SC-8); from:M028-baseline what:scripts/verify/check-must-haves.sh + scripts/verify/m028/run-all.sh (phase-level Tier-1 verifier + per-finding aggregator)."
affects:
  - "orchestrator-level phase-close + milestone-consolidate operations (T04's close-out evidence is the empirical input for phase-transition.sh / consolidate to advance M028 from executing to consolidating and to author the milestone summary); CI integration consumers of scripts/verify/m028/p05-regression-gate.sh (the consolidated CI-runnable close-out artifact)."
key_files:
  - "scripts/verify/m028/p05-regression-gate.sh,scripts/verify/check-must-haves.sh,scripts/verify/m028/run-all.sh,scripts/verify/m028/p05-fixture-permanent.sh,scripts/verify/m028/p05-downstream-fixture-shape.sh,scripts/verify/m028/p05-downstream-fixture-clean.sh,scripts/verify/m028/p05-corpus-replay-clean.sh,scripts/verify/m028/p05-run-all-clean.sh"
key_decisions:
  - "No new commits authored within T04 (per plan CON-7 / 'No new commits in this task' constraint — orchestrator handles the M028/P05 phase-boundary commit after the SUMMARY lands). T04 records empirical PASS counts (42/42 check-must-haves assertions; 4/4 close-out sub-gates; 7/7 per-finding verifiers; 6/6 P05 Truth-Check leaves) so the phase summary's verification_result field has citable evidence. No drift / dogfood findings surfaced during the sweep — T01-T03 deliverables passed cleanly on first invocation; CLAUDE.md hotfix queue not extended by this task."
patterns_established:
  - "Phase-level close-out task shape (mirrors M028/P04/T05): zero new deliverables, pure verification gate, runs (a) every Truth-Check leaf individually, (b) the consolidated regression gate end-to-end, (c) phase-level check-must-haves.sh, (d) the per-finding aggregator. Records empirical PASS counts in the task summary so phase-transition has citable evidence. Verification section invokes project-tree verifiers directly via 'bash <path>' single-stage invocations — no run-probe.sh wrapping (run-probe.sh is reserved for staged throwaway probes inside /tmp / /var/folders / <repo>/tmp/). All three Verification lines classify as 'allow' under the M028 shape classifier."
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P05/tasks/T04-close-out-sweep-PAYLOAD.md (full task plan with steps, verification, must-haves, constraints); .orchestrator/milestones/M028/phases/P05/P05-PLAN.md (the phase plan whose Truths/Artifacts/Key-Links T04 verifies); scripts/verify/m028/p05-regression-gate.sh (the consolidated CI-runnable close-out artifact)."
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-29T19:42:12Z"
---

T04 is the M028/P05 phase-level close-out sweep — pure verification gate, no new deliverables. Three Verification commands ran cleanly:

1. bash scripts/verify/m028/p05-regression-gate.sh -> exit 0; final line 'M028 close-out: 4/4 sub-gates clean'; all four sub-gates PASS (install-roundtrip with idempotency SHA 98351856...428f45 + reversibility=EMPTY; corpus-replay-27-entry; per-finding-run-all 7/7; downstream-fixture-replay).

2. bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P05 -> exit 0; 42 PASS lines (6 truths + 27 artifact sub-assertions [9 artifacts × {existence, min-line-count, contains-pattern}] + 9 key-links). Note: this version of check-must-haves.sh emits per-assertion PASS lines and exit 0 on all-pass — no final 'PASS: P05 must-haves: <N>/<N>' summary line; exit code is the contract.

3. bash scripts/verify/m028/run-all.sh -> exit 0; 8 per-finding verifiers PASS (finding-A through finding-G plus G-classifier and G-wrapper); final line 'M028: 7/7 findings verified (skipped: 0, failed: 0)'.

Round 1 individual Truth-Check leaves: all six P05 verifiers (p05-fixture-permanent, p05-downstream-fixture-shape, p05-downstream-fixture-clean, p05-corpus-replay-clean, p05-run-all-clean, p05-regression-gate) emit final PASS lines and exit 0.

No drift / dogfood findings. M028/P05 closes cleanly. M028 milestone is ready for orchestrator:consolidate.

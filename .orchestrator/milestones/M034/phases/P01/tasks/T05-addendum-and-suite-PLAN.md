---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M034"
name: "Phase-suite aggregator verifier"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- `tools/verify/m034-p01-schema-shape.sh` exists (T01 deliverable).
- `tools/verify/m034-p01-writer.sh` exists (T02 deliverable).
- `tools/verify/m034-p01-producer.sh` exists (T03 deliverable).
- `tools/verify/m034-p01-surfacing.sh` exists (T04 deliverable).
- `.orchestrator/milestones/M034/M034-P01-ADDENDUM.md` exists (authored at P01 plan-time — the PC-3/4/5 forward-design spec; NOT an executor deliverable). Confirmed on disk at plan-authoring time.

## Description

Author the phase-suite aggregator `tools/verify/m034-p01-phase-suite.sh` — the single entry point that `orchestrator:verify` and the phase Must-Have `Check:` commands invoke. It runs the four T01–T04 slice verifiers in order and asserts the PC-3/4/5 addendum (a plan-time artifact) is present and well-formed, so the whole P01 surface verifies from one command.

This task authors ONLY the aggregator. The PC-3/4/5 addendum was authored at plan-time by the planner (it required the full-milestone context Principle V withholds from a fresh executor); the aggregator merely asserts its presence + shape.

## Steps

1. Author `tools/verify/m034-p01-phase-suite.sh`. It MUST:
   - Resolve the repo root from the script location (`tools/verify/` → two levels up).
   - Run each slice verifier in turn, capturing exit codes; print each one's output:
     - `bash tools/verify/m034-p01-schema-shape.sh`
     - `bash tools/verify/m034-p01-writer.sh`
     - `bash tools/verify/m034-p01-producer.sh`
     - `bash tools/verify/m034-p01-surfacing.sh`
   - Assert `.orchestrator/milestones/M034/M034-P01-ADDENDUM.md` exists and contains all three of `PC-3`, `PC-4`, `PC-5` (the forward-design spec is present for P02).
   - Aggregate: if every slice verifier exited 0 and the addendum check passed, print `PASS: m034-p01 phase-suite (4/4 slices + addendum)` and exit 0. Otherwise print `FAIL: m034-p01 phase-suite — <which failed>` and exit 1.
   - Bash 3.2 single file. Invoke the slice verifiers with plain `bash <path>` (each is a repo-resident verifier — do NOT wrap in `run-probe.sh`, per plan-time discipline rule 4). Run them sequentially with captured exit codes inside the script body (loops/`if` inside a verifier script are fine; the AD-19 shape rules govern plan `Check:` lines, not verifier internals).

## Must-Haves

- The phase-suite aggregator runs all four slice verifiers and asserts the PC-3/4/5 addendum is present, passing iff the whole P01 surface is green.

## Verification

`bash tools/verify/m034-p01-phase-suite.sh`
`test -f .orchestrator/milestones/M034/M034-P01-ADDENDUM.md`
`grep -q "PC-5" .orchestrator/milestones/M034/M034-P01-ADDENDUM.md`

## Notes

Expected: `bash tools/verify/m034-p01-phase-suite.sh` prints `PASS: m034-p01 phase-suite (4/4 slices + addendum)` and exits 0; the `test`/`grep` commands exit 0. This aggregator is what `orchestrator:verify P01` and `scripts/verify/check-must-haves.sh` resolve the phase Must-Have `Check:` commands to — so it must exist and pass before phase close.

The aggregator is the LAST task because it depends on all four slice verifiers existing (plan-time discipline rule 2 — no forward verifier reference). The slice verifiers were each co-authored in their own task; this task only composes them.

## Inputs

### From Disk (Pre-existing)
- `tools/verify/m034-p01-schema-shape.sh` (T01) — prints `PASS: m034-p01 schema-shape` / exits 0 on success.
- `tools/verify/m034-p01-writer.sh` (T02) — prints `PASS: m034-p01 writer` / exits 0 on success.
- `tools/verify/m034-p01-producer.sh` (T03) — prints `PASS: m034-p01 producer` / exits 0 on success.
- `tools/verify/m034-p01-surfacing.sh` (T04) — prints `PASS: m034-p01 surfacing` / exits 0 on success.
- `.orchestrator/milestones/M034/M034-P01-ADDENDUM.md` — plan-time PC-3/4/5 forward-design spec; assert presence + the three PC tokens.

## Constraints

- Bash 3.2 / POSIX-sh single file (CON-1 / AD-19).
- Invoke repo-resident verifiers via plain `bash <path>`; never `run-probe.sh` (rule 4 — `run-probe.sh` exits 3 outside `/tmp` etc.).
- Do NOT re-author the addendum (plan-time artifact) or any slice verifier (T01–T04 deliverables).
- Milestone-prefixed filename (`m034-p01-...`) — project-owned, `tools/verify/` (AD-19 path + naming discipline).

## Expected Output

`tools/verify/m034-p01-phase-suite.sh` created; it passes once T01–T04 are complete and the PC-3/4/5 addendum is on disk.

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M028"
name: "Phase-level close-out sweep + final verification"
depends_on: ["T03"]
---

## Prerequisites

Plan-author empirically verified each path on disk at plan-authoring time:

- `scripts/verify/check-must-haves.sh` exists (the canonical phase-level Tier-1 verifier).
- [`.orchestrator/milestones/M028/phases/P05/P05-PLAN.md`](../../../../../milestones/M028/phases/P05/P05-PLAN.md) exists at plan-dispatch time (this very plan; written ahead of T04 by the orchestrator's plan-phase command).

Files this task creates from scratch:

(none — T04 is the close-out task; all M028/P05 deliverables are authored by T01-T03.)

Files this task verifies (T01-T03 deliverables, must exist by T04 dispatch time):

- `tests/fixtures/downstream-project/.claude/settings.json` (T01)
- `tests/fixtures/downstream-project/README.md` (T01)
- `tests/run-downstream-fixture.sh` (T02)
- `scripts/verify/m028/p05-fixture-permanent.sh` (T01)
- `scripts/verify/m028/p05-downstream-fixture-shape.sh` (T01)
- `scripts/verify/m028/p05-downstream-fixture-clean.sh` (T02)
- `scripts/verify/m028/p05-regression-gate.sh` (T03)
- `scripts/verify/m028/p05-run-all-clean.sh` (T03)
- `scripts/verify/m028/p05-corpus-replay-clean.sh` (T03)

## Description

T04 is the M028/P05 phase-level close-out sweep. No new deliverables — the task runs the full verification surface against the phase plan and confirms M028 closes cleanly:

1. Run every P05 Truth-Check leaf individually (six verifiers — `p05-fixture-permanent.sh`, `p05-downstream-fixture-shape.sh`, `p05-downstream-fixture-clean.sh`, `p05-regression-gate.sh`, `p05-run-all-clean.sh`, `p05-corpus-replay-clean.sh`).
2. Run the M028 close-out regression gate end-to-end (`p05-regression-gate.sh`) and confirm `M028 close-out: 4/4 sub-gates clean`.
3. Run the phase-level `check-must-haves.sh` against `.orchestrator/milestones/M028/phases/P05` and confirm every Truth, Artifact, and Key Link asserts cleanly.
4. Surface the close-out evidence as the M028 close-out summary in the dispatch return — the orchestrator's `phase-transition.sh` and milestone-summary tooling consume this evidence.

T04 is intentionally minimal in deliverable count because the phase's substantive deliverables are already in T01-T03; T04's role is the gate that confirms the phase is closed and the verification artifacts are CI-runnable. This mirrors the M028/P04/T05 close-out task shape.

## Steps

### Round 1 — Run each P05 Truth-Check leaf individually

1. Run each of the six P05 Truth-Check verifiers in dependency order. Confirm each emits a final `PASS:` line and exits 0:

   - `bash scripts/verify/m028/p05-fixture-permanent.sh` (T01).
   - `bash scripts/verify/m028/p05-downstream-fixture-shape.sh` (T01).
   - `bash scripts/verify/m028/p05-downstream-fixture-clean.sh` (T02).
   - `bash scripts/verify/m028/p05-corpus-replay-clean.sh` (T03).
   - `bash scripts/verify/m028/p05-run-all-clean.sh` (T03).
   - `bash scripts/verify/m028/p05-regression-gate.sh` (T03).

   Any FAIL is a phase-level regression — escalate to the responsible task (Step 1 verifiers map to T01; Step 2 verifiers to T02; Steps 3-6 to T03). Do not paper over a FAIL by editing the verifier; root-cause the deliverable.

### Round 2 — Run the close-out regression gate end-to-end

2. Run `bash scripts/verify/m028/p05-regression-gate.sh`. Confirm:
   - Exit 0.
   - Final line `M028 close-out: 4/4 sub-gates clean`.
   - All four sub-gate lines `PASS:` (install-roundtrip, corpus-replay-27-entry, per-finding-run-all, downstream-fixture-replay).

   If any sub-gate FAILs, inspect the preserved log at `${TMPDIR:-/tmp}/m028-p05-regression-gate-$$/<label>.log`. The four sub-gates are independent — install-roundtrip drift is a P02 regression; corpus-replay drift is a P03 regression; run-all drift is P02/P03/P04; downstream-fixture drift is P02/P03/P05.

### Round 3 — Run phase-level `check-must-haves.sh`

3. Run `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P05`. Confirm:
   - Exit 0.
   - Every Truth Check returns PASS.
   - Every Artifact assertion returns PASS (file exists, line count meets minimum, contains-pattern matches).
   - Every Key Link assertion returns PASS (source file references target file basename).
   - Final summary: `PASS: P05 must-haves: <N>/<N>` (the actual count is computed by `check-must-haves.sh` against the post-T03 phase plan; T04 author re-confirms the actual number after the sweep runs and records it in the task summary).

### Round 4 — Plan-time pre-validation + close

4. Plan-author confirms each `## Verification` line classifies as `allow` under the M028 classifier. All three lines are single-stage `bash <path>` invocations.

5. Do NOT create a git commit; the orchestrator handles phase-boundary commits at phase close.

## Must-Haves

This task addresses the phase Truth: the close-out gate must report `M028 close-out: 4/4 sub-gates clean` and `check-must-haves.sh` must report all PASS. T04 itself authors no new artifacts; it runs the close-out surface and validates phase completeness.

The task indirectly addresses every P05 phase Truth — each of the six Truth-Check leaves authored in T01-T03 is invoked here as part of the close-out sweep. T04's close-out validation IS the phase Truth-Check rollup.

## Verification

```bash
bash scripts/verify/m028/p05-regression-gate.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P05
```

```bash
bash scripts/verify/m028/run-all.sh
```

## Notes

Expected output of `bash scripts/verify/m028/p05-regression-gate.sh`:

- Header `M028 close-out regression gate -- 4 sub-gates` line.
- `tmp logs at:` path.
- Four `PASS:` lines (install-roundtrip, corpus-replay-27-entry, per-finding-run-all, downstream-fixture-replay).
- Final `M028 close-out: 4/4 sub-gates clean` line.
- Exit 0.

Expected output of `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P05`:

- One PASS line per Truth-Check (six Truth-Check leaves).
- One PASS line per Artifact entry (nine artifacts in the phase plan).
- One PASS line per Key Link entry (nine key links).
- Final summary line `PASS: P05 must-haves: <N>/<N>` (N total assertions; the count is computed by `check-must-haves.sh` against the phase plan and recorded in the task summary).
- Exit 0.

Expected output of `bash scripts/verify/m028/run-all.sh`:

- Eight `PASS:` lines (one per per-finding verifier).
- Final `M028: 7/7 findings verified (skipped: 0, failed: 0)` line.
- Exit 0.

If any of the three Verification lines FAILs, the phase is NOT closed. Failure modes:
- Regression gate FAIL → inspect the preserved sub-gate log; root-cause to the responsible upstream phase.
- `check-must-haves.sh` FAIL → some artifact / key-link / truth assertion missed; inspect the FAIL line for the specific assertion. Possible causes: artifact line count below minimum (rewrite the artifact to add documentation lines); key link target basename not present in source (add an explicit cross-reference comment); Truth-Check verifier returning non-zero (root-cause the underlying deliverable).
- `run-all.sh` FAIL → some per-finding verifier failed; inspect the verifier's individual output to identify the finding.

## Inputs

### From Previous Tasks

- All P05 deliverables (T01-T03). T04 reads no source files itself; it invokes the verifiers and harnesses.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — phase-level Tier-1 verifier.
  - Key API: `bash check-must-haves.sh <phase-dir>` reads the `<phase-dir>/P##-PLAN.md` Must-Haves section and runs each Truth-Check, asserts each Artifact (file existence + line count + contains-pattern), asserts each Key Link (source file references target file basename). Exits 0 on all-pass.
- `scripts/verify/m028/run-all.sh` (P03+P04) — per-finding aggregator.

## Constraints

- **CON-1 (AD-19)**: T04 authors no new scripts. The verifiers it invokes are AD-19 single-file shapes (already established in T01-T03).
- **CON-2 (bash 3.2 + POSIX sh)**: T04 runs no new bash code; the invoked verifiers honor CON-2.
- **CON-7 (no [M021](../../../../../milestones/M021/index.md) regression)**: T04's close-out sweep is the phase-level CON-7 gate — the corpus-replay sub-gate of the regression gate asserts strict-superset preservation.
- **Verification-section authoring**: `## Verification` invokes project-tree verifiers directly. No `run-probe.sh` wrapping.
- **Plan-time verifier-availability**: All three `## Verification` lines resolve to scripts pre-existing on disk (one P05-authored: `p05-regression-gate.sh` from T03; two M028-baseline: `check-must-haves.sh` and `run-all.sh`). Co-authoring discipline preserved.
- **Plan-time classifier-shape pre-validation**: All three `## Verification` lines are single-stage `bash <path>` invocations — `allow` verdict.
- **No new commits in this task**: The orchestrator handles the M028/P05 phase-boundary commit. T04 records its findings in the task summary; the commit + summary write are orchestrator-level operations.
- **Re-confirm assertion counts**: T04 author records the actual `check-must-haves.sh` PASS count in the task summary so the phase summary's `verification_result` field has empirical evidence to cite.

## Expected Output

After all three `## Verification` lines run cleanly, T04 has verified that M028/P05 closes:

1. The regression gate reports `M028 close-out: 4/4 sub-gates clean`.
2. `check-must-haves.sh` reports all PASS for the phase plan's Truths, Artifacts, and Key Links.
3. `run-all.sh` reports `M028: 7/7 findings verified (skipped: 0, failed: 0)`.

The M028 milestone is now ready for `orchestrator:consolidate` — the close-out evidence produced by T04 is the empirical input that consolidate uses to advance the milestone state from `executing` to `consolidating` and to write the milestone summary.

T04's task summary records:
- The three Verification line outputs verbatim.
- The actual `check-must-haves.sh` assertion count (`<N>/<N>`).
- Any drift / dogfood findings surfaced during the sweep (recorded as candidate CLAUDE.md hotfix entries for the orchestrator's next paper-cut sweep).

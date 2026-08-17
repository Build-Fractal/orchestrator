---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M046"
name: "Evidence consolidation + verdicts + phase verifiers"
depends_on: [T01, T02]
---

## Prerequisites

- T01 complete: `spike/hook/deny-drive.log` (≥6 `result=` lines) + `spike/hook/install-matrix.log` (2 `shape=` lines) on disk.
- T02 complete: `spike/cost/cadence.jsonl` (≥3 `unit_close` observations) + `spike/cost/CADENCE-FINDINGS.md` on disk.
- Pre-existing: `.orchestrator/milestones/M046/M046-ROADMAP.md` (P01 decision-gate text naming the routing consequences); `specs/047-auto-v2b-unified-serial/spec.md` (#Q-1/#Q-4 wording, FR-7/FR-8/FR-9); `tools/verify/` naming convention `m046-p01-<descriptor>.sh` (milestone-prefixed, per plan-phase naming rule).

## Description

Turn the T01/T02 raw evidence into the phase's decision-gate output: `P01-VIABILITY-EVIDENCE.md` with one **VERDICT line per question** and the explicit routing consequence for P04/P05, plus the five durable phase verifiers under `tools/verify/`. This is the artifact the roadmap's CON-6 decision gate reads; write it so a zero-context P04/P05 planner can consume the verdicts without re-reading the spike logs.

## Steps

1. **Read** all four T01/T02 evidence files end-to-end. Do not summarize from filenames — quote the actual case lines and timestamps into the evidence doc.

2. **Author** `.orchestrator/milestones/M046/phases/P01/P01-VIABILITY-EVIDENCE.md` (≥60 lines) with sections:
   - `## #Q-1 hook-install portability` — method (direct-drive + install matrix, isolated HOME), quoted results, then exactly one line matching `VERDICT: #Q-1 <PASS|NEGATIVE|PARTIAL> — <one-sentence consequence>`.
     - PASS → FR-9 proceeds as specced (M028-staged default-DENY PreToolUse hook); P05 consumes the probe's policy-file + matcher shape as its starting design.
     - NEGATIVE (either leg failed) → draft the explicit Decision row rerouting the FR-9 enforcement mechanism (per the roadmap decision-gate text) and STOP for operator review — do not let P05 start on a failed premise.
     - PARTIAL (deny/install legs pass, live-e2e deferred) → FR-9 proceeds; note `live-e2e` is discharged by SC-5 (already milestone-blocking, non-stubbed).
   - `## #Q-4 cost-read cadence` — method (stub-driven cadence probe + P00 citation), quoted ordering observations, then one line `VERDICT: #Q-4 <PASS|NEGATIVE|PARTIAL> — <consequence>` fixing the FR-7/FR-8 cost source split (e.g. "JSONL unit_close readable mid-segment at unit grain for completed-unit spend; `--output-format json` `total_cost_usd` is the authoritative per-segment reconcile — SC-3 precondition satisfied"). A NEGATIVE (records only at loop exit AND cost fields absent) fixes JSON-sole-source per the roadmap gate text — that is still a usable answer, state it as such.
   - `## Decision-gate routing` — one short paragraph per downstream phase (P04, P05) stating what they may now assume.
   - Cite both spike logs by relative path (these are the Key Links the phase plan declares).

3. **Author the five verifiers** (each bash 3.2, single-purpose, exit 0/1, `PASS:`/`FAIL:` line output; ~15–30 lines):
   - `tools/verify/m046-p01-viability-evidence.sh` — evidence file exists, ≥60 lines, contains BOTH `VERDICT: #Q-1` and `VERDICT: #Q-4` lines each carrying PASS/NEGATIVE/PARTIAL, plus a `## Decision-gate routing` section.
   - `tools/verify/m046-p01-hook-deny-proof.sh` — `deny-drive.log` exists; the three deny cases (`oos-write`, `oos-bash-gitpush`, `oos-mcp`) and `policy-missing-failclosed` all show `expected=2 actual=2 result=PASS`; the two allow cases show `expected=0 actual=0 result=PASS`.
   - `tools/verify/m046-p01-install-matrix.sh` — `install-matrix.log` has a `shape=A` and a `shape=B` line, each with `staged=1 merged=1 coexists=1 idempotent=1 uninstall_clean=1`.
   - `tools/verify/m046-p01-cadence-log.sh` — `cadence.jsonl` has ≥3 `unit_close` observations with `"t"` timestamps and ≥1 `loop_exit`; `CADENCE-FINDINGS.md` exists and names a recommended cost source.
   - `tools/verify/m046-p01-phase-suite.sh` — aggregator: runs the four above in sequence, prints per-verifier PASS/FAIL, exits 0 only on 4/4 (the M045 `m045-p0#-*` suite pattern; milestone-prefixed name per the P00-clobber lesson).

4. **Run** the phase suite and `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M046/phases/P01` — both must PASS before this task closes.

## Must-Haves

- The viability evidence artifact records a definite verdict for BOTH #Q-1 and #Q-4 with decision-gate routing consequences.
- All five `tools/verify/m046-p01-*.sh` verifiers exist and the phase suite passes 4/4.

## Verification

```bash
bash tools/verify/m046-p01-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M046/phases/P01
```

## Notes

Expected: phase suite prints four `PASS:` lines + a suite summary and exits 0; `check-must-haves.sh` reports all Truths/Artifacts/Key Links PASS. If either T01 or T02 produced a NEGATIVE result, this task still completes — its deliverable is the honest verdict + Decision-row draft + operator escalation note, not a forced PASS (the M045 P01 precedent: a correct "no" that reroutes is the spike's purpose).

## Inputs

### From Previous Tasks

- `spike/hook/deny-drive.log` (T01) — `case=<name> expected=<n> actual=<n> result=PASS|FAIL` lines; may carry an optional `case=live-e2e` or `live-e2e=deferred-to-SC-5` line.
- `spike/hook/install-matrix.log` (T01) — `shape=<A|B> staged= merged= coexists= idempotent= uninstall_clean=` flag lines.
- `spike/cost/cadence.jsonl` (T02) — JSON lines `{"t","event","record_type","unit","cost_present"}` + `loop_start`/`loop_exit` marks.
- `spike/cost/CADENCE-FINDINGS.md` (T02) — ordering findings + recommended FR-7/FR-8 source split + P00 citation.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M046/M046-ROADMAP.md` — decision-gate routing text to mirror in the evidence doc.
- `specs/047-auto-v2b-unified-serial/spec.md` — #Q-1/#Q-4 exact wording; FR-7/FR-8/FR-9 the verdicts bind to.
- `scripts/verify/check-must-haves.sh` — phase rollup runner (invoked in Verification, never cited as a Truth Check).

## Constraints

- Verdict lines MUST be grep-stable: `VERDICT: #Q-1 ...` / `VERDICT: #Q-4 ...` at line start.
- Verifiers: milestone-prefixed filenames under `tools/verify/` (project-owned path discipline); AD-19 single-invocation shapes; no dependency on any file outside the P01 tree + `tools/verify/`.
- A NEGATIVE verdict is a valid task outcome; forcing PASS language over failed evidence is a Principle II violation.

## Expected Output

`P01-VIABILITY-EVIDENCE.md` with two grep-stable VERDICT lines + decision-gate routing, five green verifiers including the 4/4 phase suite, and a clean `check-must-haves.sh` run — the phase is then ready for `orchestrator:verify` / phase close.

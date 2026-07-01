---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M045"
name: "Analyze measurements, author the viability evidence + verifiers, resolve #Q-1 / recommend #Q-2"
depends_on: ["T02"]
---

## Prerequisites

- T02 complete: `spike/segments.jsonl` holds ≥3 records spanning ≥2 rotation boundaries, each rotate record carrying a real context proxy + resume-correctness notes.

## Description

Turn the T02 measurements into the SC-6 decision: does in-session `ScheduleWakeup` re-entry give BOUNDED context relief (PASS → proceed to P02) or COMPOUNDING growth toward overflow (NEGATIVE → halt M045, route the process-fresh remainder to M-auto-v2b per spec CON-5)? Author the evidence artifact and the two project-owned verifiers the phase must-haves reference.

## Steps

1. Read `spike/segments.jsonl`. For the ordered rotate segments, extract the `context_proxy` trend:
   - **Bounded** = the proxy is flat, drops, or oscillates within a ceiling across re-entries (harness compaction is relieving context) → the mechanism is viable.
   - **Compounding** = the proxy grows monotonically across re-entries with no compaction relief (heads toward overflow) → the mechanism is NOT viable in-session; process-fresh (v2b) is required.
   - If only `weight-only`/`unavailable` proxies were capturable, say so plainly and downgrade confidence: `weight` resets by design and is NOT evidence of real LLM-context relief. In that case the verdict must be `PARTIAL` with an explicit statement of what a stronger measurement (real token/context readout) would require, and P02 inherits that as a follow-up rather than a settled PASS.
2. Read the resume-correctness notes from T02: did every re-entry resume the next segment purely from disk (spec CON-2)? Record any failure.
3. Author `.orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md` with these sections:
   - **Frontmatter/heading** naming milestone M045, phase P01, the #Q-1 question.
   - **Measurements** — a table of the segments (index, phase, status, context_proxy, proxy_kind).
   - **Correctness** — did each re-entry resume from disk? (the CON-2 dimension).
   - **Boundedness analysis** — bounded vs compounding, with the trend evidence.
   - **`VERDICT: PASS` | `VERDICT: NEGATIVE` | `VERDICT: PARTIAL`** on its own line, with a one-paragraph justification.
   - **#Q-1 resolution** — the answer, tied to the verdict.
   - **#Q-2 recommendation** — flag (`--self-continue`) vs `/loop` recipe as the primary arming surface, informed by what the run showed (a process-fresh lean favors the `/loop` recipe).
   - **Downstream routing** — if PASS/PARTIAL: P02 proceeds (PARTIAL carries the measurement caveat forward). If NEGATIVE: state the CON-5 route to M-auto-v2b and that P02–P04 do NOT proceed as scoped.
   - A line citing `spike/segments.jsonl` as the measurement source (satisfies the phase Key Link).
4. Author `tools/verify/m045-p01-viability-evidence.sh`:
   ```sh
   #!/usr/bin/env sh
   # Checks the P01 viability evidence carries a definite verdict backed by ≥2 boundaries.
   set -eu
   EV=".orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md"
   SEG=".orchestrator/milestones/M045/phases/P01/spike/segments.jsonl"
   test -f "$EV" || { echo "FAIL: evidence missing"; exit 1; }
   grep -Eq '^VERDICT: (PASS|NEGATIVE|PARTIAL)' "$EV" || { echo "FAIL: no VERDICT line"; exit 1; }
   ROT=$(grep -c '"status":"rotate"' "$SEG" 2>/dev/null || echo 0)
   [ "$ROT" -ge 2 ] || { echo "FAIL: <2 rotation boundaries (got $ROT)"; exit 1; }
   echo "PASS: viability evidence present with VERDICT and $ROT boundaries"
   ```
5. Author `tools/verify/m045-p01-segments-present.sh`:
   ```sh
   #!/usr/bin/env sh
   # Checks the spike captured ≥3 segments (≥2 boundaries).
   set -eu
   SEG=".orchestrator/milestones/M045/phases/P01/spike/segments.jsonl"
   test -f "$SEG" || { echo "FAIL: segments.jsonl missing"; exit 1; }
   N=$(grep -c 'segment' "$SEG" 2>/dev/null || echo 0)
   [ "$N" -ge 3 ] || { echo "FAIL: <3 segments (got $N)"; exit 1; }
   echo "PASS: $N segments captured"
   ```
6. `chmod +x` both verifiers. Run both and confirm `PASS:`.

## Must-Haves

- `P01-VIABILITY-EVIDENCE.md` exists (min 40 lines), carries a `VERDICT:` line, cites `segments.jsonl`.
- Both verifiers exist, are executable, and exit 0 against the authored evidence.
- The #Q-1 resolution and #Q-2 recommendation are explicit.

## Verification

`bash tools/verify/m045-p01-viability-evidence.sh`
`bash tools/verify/m045-p01-segments-present.sh`

## Inputs

### From Previous Tasks
- `spike/segments.jsonl` (from T02)
  - Key shape: one JSON object per line with fields `segment`, `phase`, `exec_log_lines`, `weight`, `limit`, `status` (`rotate`/`ok`/`complete`), `context_proxy`.

### From Disk (Pre-existing)
- `specs/046-self-continuing-auto/spec.md` — SC-6, CON-1, CON-2, CON-5, #Q-1, #Q-2 definitions to cite in the evidence.

## Constraints

- The verifiers are project-owned per-phase verifiers → MUST live under `tools/verify/` with the `m045-p01-` slug prefix (never `scripts/verify/`, never phase-only `p01-`). Per the plan-phase naming convention.
- A NEGATIVE or PARTIAL verdict is a legitimate outcome — do NOT bias the analysis toward PASS to keep the milestone alive. The whole point of P01 is an honest answer.

## Expected Output

`P01-VIABILITY-EVIDENCE.md` with a definite verdict + #Q-1/#Q-2 resolution, and two passing project-owned verifiers under `tools/verify/`.

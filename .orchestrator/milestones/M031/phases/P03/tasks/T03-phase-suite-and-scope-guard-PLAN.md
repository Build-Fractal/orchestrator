---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M031"
name: "P03 phase-suite aggregator + SC-12 scope-guard"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `tools/verify/m031-p03-do-md-shape.sh`, `tools/verify/m031-p03-do-entry-shape.sh`, `tools/verify/m031-p03-fastpath-shape.sh`, `tools/verify/m031-p03-passthrough-shape.sh` all exist, executable, exit 0.
- T02 complete: `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh`, `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh` both exist, executable, exit 0. SC-7 + SC-8 acceptance tests both pass.
- The P02 phase-suite + scope-guard (`tools/verify/m031-p02-phase-suite.sh`, `tools/verify/m031-p02-scope-guard.sh`) exist on disk and are read for shape inheritance — NOT modified by T03.
- The P01 phase-suite + scope-guard (`tools/verify/m031-p01-phase-suite.sh`, `tools/verify/m031-p01-scope-guard.sh`) exist on disk and are read for the MEM `hit_count`-only carve-out function shape — NOT modified by T03.

## Description

T03 ships the P03 phase-close gates: the phase-suite aggregator (chains every P03 sub-gate in T01 → T02 dependency order) and the SC-12 scope-guard (asserts the P03 diff stays inside the declared "Files Likely Touched" surface). Both inherit verbatim shapes from the P02 verifiers landed by P02/T05.

**Phase-suite shape** (mirrors P01/P02 straight-line aggregation, AD-19 compliant):
- 6 sub-gates from T01 + T02:
  1. `m031-p03-do-md-shape.sh` (T01)
  2. `m031-p03-do-entry-shape.sh` (T01)
  3. `m031-p03-fastpath-shape.sh` (T01)
  4. `m031-p03-passthrough-shape.sh` (T01)
  5. `m031-p03-test-universal-entry-trivial-shape.sh` (T02)
  6. `m031-p03-test-universal-entry-lowconf-shape.sh` (T02)
- 1 sub-gate from T03 itself:
  7. `m031-p03-scope-guard.sh` (T03 — last gate per the P01/P02 convention)
- Total: 7 sub-gates straight-line invoked. No array loops, no compound chains, no eval. Each gate's exit code is captured into a `pass`/`fail` accumulator. Aggregator emits `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M` and exits 0 iff `fail=0`. Does NOT short-circuit on a sub-gate failure (all 7 gates run regardless).

**Scope-guard shape** (mirrors P02/T05 dual-prefix permissive carve-out + MEM hit_count-only carve-out):
- **Block-list** (SC-12 verbatim): any working-tree diff (vs HEAD) touching `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/` is a block-list violation.
- **MEM hit_count carve-out** (P01/P02 verbatim): for diffs under `knowledge/(conventions|lessons|patterns)/MEM*.md`, if every `+`/`-` line matches `^[+-]hit_count: [0-9]+$`, the diff is treated as orchestrator-emitted hit-count drift, not a manual scope violation. Carve-out is counted in `mem_hitcount_carveouts`.
- **Dual-prefix permissive carve-out** (P02 verbatim): diffs under `.orchestrator/observability/` AND `.orchestrator/tier-a-plus/` are permissive — not block-list violations.
- **Allow-list**: the P03 "Files Likely Touched" surface (T01 + T02 deliverables) plus phase/task plan + summary paths under `.orchestrator/milestones/M031/phases/P03/`. Diffs outside the allow-list AND outside the carve-outs AND outside the block-list are reported as `out_of_scope` (pass per SC-12 — the SC-12 contract is block-list-only — but emitted as a warning so the operator notices unintended drift).
- Output: `SUMMARY: m031-p03-scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L`. Exit 0 iff `block_list_violations == 0`.

## Steps

1. **Read the P02 phase-suite for shape inheritance**. Open `tools/verify/m031-p02-phase-suite.sh`. Note:
   - `set -u` at the top.
   - `pass=0; fail=0` accumulators.
   - `emit_gate_result()` helper accepting `(rc, name)` and incrementing `pass` or `fail` based on rc.
   - Eleven gate blocks, each three lines: `bash <verifier-path>` then `rc=$?` then `emit_gate_result "$rc" "<name>"`.
   - Final block: `printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"` then `if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi`.

2. **Author `tools/verify/m031-p03-phase-suite.sh`** (executable, bash 3.2). Mirror the P02 shape exactly except:
   - 7 gate blocks instead of 11.
   - Sub-gate ordering matches the T01 → T02 → T03 dependency order:
     1. `tools/verify/m031-p03-do-md-shape.sh`
     2. `tools/verify/m031-p03-do-entry-shape.sh`
     3. `tools/verify/m031-p03-fastpath-shape.sh`
     4. `tools/verify/m031-p03-passthrough-shape.sh`
     5. `tools/verify/m031-p03-test-universal-entry-trivial-shape.sh`
     6. `tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh`
     7. `tools/verify/m031-p03-scope-guard.sh`
   - Header comment block (≥ 30 lines) documenting the gate ordering, the AD-19 straight-line discipline (no array loops, no compound chains, no eval), and a `# Key links (M031/P03):` block listing the 7 sub-gate basenames so phase-level key-link must-haves resolve via grep.
   - Final SUMMARY line `SUMMARY: m031-p03-phase-suite.sh pass=%d fail=%d`.
   - Exit 0 iff `fail == 0`.

3. **Read the P02 scope-guard for shape inheritance**. Open `tools/verify/m031-p02-scope-guard.sh`. Note:
   - The `git diff --name-only HEAD` invocation (or equivalent) for enumerating changed files.
   - The block-list pattern matcher (`case "$path" in knowledge/*|scripts/cost/*|scripts/dispatch/adapters/router/*|scripts/auto/loop/*) ...`).
   - The MEM hit_count carve-out function — checks every `+`/`-` line of the file's diff against `^[+-]hit_count: [0-9]+$` regex; if all match, count under `mem_hitcount_carveouts` instead of `block_list_violations`.
   - The permissive prefix carve-out (`.orchestrator/observability/*` and `.orchestrator/tier-a-plus/*`).
   - The allow-list for P02's files-likely-touched surface.
   - The final SUMMARY line shape: `SUMMARY: m031-p02-scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d`.

4. **Author `tools/verify/m031-p03-scope-guard.sh`** (executable, bash 3.2). Mirror the P02 shape exactly except:
   - **Allow-list** updated to the P03 "Files Likely Touched" surface (verbatim from P03-PLAN.md "Files Likely Touched" — 15 paths under `commands/`, `scripts/intake/`, `tests/m031-acceptance/`, `tools/verify/`):

     ```
     commands/do.md
     scripts/intake/do-entry.sh
     tests/m031-acceptance/fixtures/do-entry-stub.sh
     tests/m031-acceptance/fixtures/do-entry-trivial-input.txt
     tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt
     tests/m031-acceptance/test-universal-entry-trivial.sh
     tests/m031-acceptance/test-universal-entry-lowconf.sh
     tools/verify/m031-p03-do-md-shape.sh
     tools/verify/m031-p03-do-entry-shape.sh
     tools/verify/m031-p03-fastpath-shape.sh
     tools/verify/m031-p03-passthrough-shape.sh
     tools/verify/m031-p03-test-universal-entry-trivial-shape.sh
     tools/verify/m031-p03-test-universal-entry-lowconf-shape.sh
     tools/verify/m031-p03-phase-suite.sh
     tools/verify/m031-p03-scope-guard.sh
     ```

     Plus phase/task-plan/summary paths under `.orchestrator/milestones/M031/phases/P03/`.

   - **Block-list** preserved verbatim from P02: `knowledge/**` (with MEM hit_count carve-out), `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
   - **MEM hit_count-only carve-out** function copied verbatim from `tools/verify/m031-p02-scope-guard.sh`. The function tests every `+`/`-` line of a file's diff against the regex `^[+-]hit_count: [0-9]+$`; if all match, returns 0 (carve-out applies).
   - **Dual-prefix permissive carve-out** preserved verbatim from P02: `.orchestrator/observability/*` and `.orchestrator/tier-a-plus/*` paths are not block-list violations.
   - Header comment block (≥ 30 lines) documenting the SC-12 contract, the carve-outs (block-list, MEM hit_count, dual-prefix permissive), and the allow-list provenance.
   - Final SUMMARY line `SUMMARY: m031-p03-scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d`.
   - Exit 0 iff `block_list_violations == 0`.

5. **Co-author the `# Key links` doc-comment** in `tools/verify/m031-p03-phase-suite.sh` (mirrors the P01 build-context.sh + P02 route-to-dispatch.sh remediation pattern from commit `7624397`). The block lists the seven sub-gate basenames so the phase plan's Key Links must-haves resolve via `grep -q '<basename>' tools/verify/m031-p03-phase-suite.sh`:

   ```bash
   # Key links (M031/P03):
   #   - m031-p03-do-md-shape.sh                       (T01 do-md gate)
   #   - m031-p03-do-entry-shape.sh                    (T01 do-entry gate)
   #   - m031-p03-fastpath-shape.sh                    (T01 fastpath gate)
   #   - m031-p03-passthrough-shape.sh                 (T01 passthrough gate)
   #   - m031-p03-test-universal-entry-trivial-shape.sh (T02 SC-7 gate)
   #   - m031-p03-test-universal-entry-lowconf-shape.sh (T02 SC-8 gate)
   #   - m031-p03-scope-guard.sh                       (T03 scope-guard gate; last)
   ```

6. **Run the phase-suite + scope-guard locally to confirm exit 0**:

   ```bash
   bash tools/verify/m031-p03-phase-suite.sh
   bash tools/verify/m031-p03-scope-guard.sh
   ```

   The phase-suite must report `SUMMARY: m031-p03-phase-suite.sh pass=7 fail=0`. The scope-guard must report `block_list_violations=0`. If either fails, the failure is one of:
   - **A T01 or T02 deliverable is missing**: re-verify the upstream tasks shipped their artifacts.
   - **The scope-guard's allow-list does not cover a touched file**: check the working-tree diff against the allow-list and add any missed file. (If the missed file is correctly within scope, add it; if it is out-of-scope, revert the touch.)
   - **The scope-guard reports `block_list_violations > 0`**: the diff actually touches a forbidden path. Revert and reroute.
   - **MEM hit_count drift** is reported: this is an orchestrator-emitted side-effect from prior dispatches and is counted under `mem_hitcount_carveouts`, NOT `block_list_violations` — green pass.

7. **Verify the phase-level Tier 1 must-haves**:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P03/P03-PLAN.md
   ```

   Expect 0 FAIL.

8. **Verify the phase-level boundary map** (informational; may SKIP if no produce items declared):

   ```bash
   bash scripts/verify/check-boundary-map.sh .orchestrator/milestones/M031/phases/P03/P03-PLAN.md || true
   ```

## Must-Haves

This task addresses the following Must-Haves from `P03-PLAN.md`:
- "`tools/verify/m031-p03-phase-suite.sh` exists, is executable, invokes every P03 sub-gate ... emits `SUMMARY: m031-p03-phase-suite.sh pass=N fail=M`" (Truth #7; Check via `m031-p03-phase-suite.sh`)
- "`tools/verify/m031-p03-scope-guard.sh` exists, is executable, asserts the P03 diff does NOT touch any path under the SC-12 block-list" (Truth #8; Check via `m031-p03-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p03-phase-suite.sh
```

```bash
bash tools/verify/m031-p03-scope-guard.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P03/P03-PLAN.md
```

## Notes

- The phase-suite emits `SUMMARY: m031-p03-phase-suite.sh pass=7 fail=0` when every sub-gate is green — N is exactly 7 (4 from T01 + 2 from T02 + 1 from T03 itself).
- The scope-guard's `mem_hitcount_carveouts=K` field is informational (the value depends on cross-session MEM hit_count drift since HEAD); only `block_list_violations` is gated.
- AD-19 single-script-file invariant: each gate inside the phase-suite is invoked as a literal `bash <path>` line followed by `rc=$?`. NO `for` loops over arrays, NO `(...)` subshells, NO `&&`/`||` chains, NO `$(...)` containing pipes.
- Bash 3.2 (MEM001): no `declare -A`, no process substitution.
- D020 / CON-7: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- The phase-suite does NOT parse SUMMARY lines from sub-gates — it consumes exit codes only (mirrors P02 — parsing would couple the suite to envelope formatting; exit codes are the load-bearing contract).
- The scope-guard's allow-list does NOT include test-run scratch artifacts under `.orchestrator/tier-a-plus/` or `.orchestrator/observability/` — those land under the dual-prefix permissive carve-out and are not allow-list-gated.
- **Real-app smoke test pending** (plan-time discipline rule 5): T03's verifiers gate the phase-close shape, not the live runtime end-to-end. Production confirmation that `orchestrator:do <task>` works against a CC-installed consumer project is the M033 onboarding milestone's job; T03 + the P03 phase-suite confirm the contract surface.

## Inputs

### From Previous Tasks

- **T01: 4 shape verifiers** — `m031-p03-do-md-shape.sh`, `m031-p03-do-entry-shape.sh`, `m031-p03-fastpath-shape.sh`, `m031-p03-passthrough-shape.sh`. T03's phase-suite invokes each via `bash <path>`.
- **T02: 2 shape verifiers** — `m031-p03-test-universal-entry-trivial-shape.sh`, `m031-p03-test-universal-entry-lowconf-shape.sh`. T03's phase-suite invokes each via `bash <path>`.

### From Previous Phases

- **P01: `tools/verify/m031-p01-phase-suite.sh`** — read for the straight-line N-gate aggregation pattern (AD-19 compliant). T03 mirrors the shape with N=7 instead of N=9.
- **P01: `tools/verify/m031-p01-scope-guard.sh`** — read for the MEM `hit_count`-only carve-out function (`^[+-]hit_count: [0-9]+$` line-content check on `knowledge/(conventions|lessons|patterns)/MEM*.md` paths).
- **P02: `tools/verify/m031-p02-phase-suite.sh`** — read for the `emit_gate_result` helper shape and the SUMMARY line format.
- **P02: `tools/verify/m031-p02-scope-guard.sh`** — read for the dual-prefix permissive carve-out (`.orchestrator/observability/` + `.orchestrator/tier-a-plus/`) and the allow-list / block-list / carve-out wiring.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M031/phases/P03/P03-PLAN.md` — read for the "Files Likely Touched" allow-list surface.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: phase-suite gate invocations are straight-line `bash <path>` + `rc=$?` + `emit_gate_result`. No array loops, no compound chains, no eval.
- **No edits to T01 / T02 deliverables** in T03.
- **No edits to P01 / P02 verifiers** (`m031-p01-*.sh`, `m031-p02-*.sh`) in T03.
- **No edits to scripts/intake/ or commands/ or templates/** in T03.
- **CON-4 / DC-4**: T03 makes no orchestration-state writes.
- **CON-7 / D020 hygiene**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T03 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The scope-guard verifier itself MAY contain literal references to those paths (block-list patterns) — the carve-out logic distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T03 completes:

1. `tools/verify/m031-p03-phase-suite.sh` exists, executable, ≥ 70 lines, invokes 7 sub-gates straight-line, emits `SUMMARY: m031-p03-phase-suite.sh pass=7 fail=0`, exits 0.
2. `tools/verify/m031-p03-scope-guard.sh` exists, executable, ≥ 100 lines, asserts SC-12 block-list compliance with carve-outs, emits `SUMMARY: m031-p03-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K`, exits 0.
3. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P03/P03-PLAN.md` reports 0 FAIL.
4. No edits to any T01 or T02 deliverable.
5. No edits to any P01 or P02 verifier.

T03 leaves the P03 phase-close gate suite green. P03 is ready for verify+consolidate. The next phase (P04 — drift fix + observability + comms + acceptance battery aggregator) consumes the seven P03 sub-gates' SUMMARY contracts when wiring the milestone-grain acceptance battery (SC-14).

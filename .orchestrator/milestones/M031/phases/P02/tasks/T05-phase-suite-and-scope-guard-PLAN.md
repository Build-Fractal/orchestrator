---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M031"
name: "P02 phase-suite aggregator + SC-12 scope-guard for P02"
depends_on: ["T04"]
---

## Prerequisites

- T01 complete: 4 shape verifiers under `tools/verify/m031-p02-*.sh` plus SC-5 acceptance test on disk (verified by `bash tools/verify/m031-p02-classifier-extension-shape.sh` etc.).
- T02 complete: 2 shape verifiers (m031-p02-task-slug-shape.sh + m031-p02-role-templates-shape.sh) on disk.
- T03 complete: 2 shape verifiers (m031-p02-prompt-shape.sh + m031-p02-test-tier-a-plus-prompt-ux-shape.sh) plus SC-16 acceptance test on disk.
- T04 complete: 2 shape verifiers (m031-p02-router-shape.sh + m031-p02-test-tier-a-plus-flow-shape.sh) plus SC-6 acceptance test on disk.
- The M031 P01 scope-guard convention is on disk at `tools/verify/m031-p01-scope-guard.sh` (read for reference — T05's scope-guard inherits the block-list and the MEM `hit_count`-only carve-out).
- The M031 P01 phase-suite convention is on disk at `tools/verify/m031-p01-phase-suite.sh` (read for reference — T05's phase-suite inherits the straight-line N-gate aggregation pattern).

## Description

T05 ships two phase-close gates:

1. **`tools/verify/m031-p02-phase-suite.sh`** — straight-line aggregator chaining every P02 sub-gate from T01 through T04. Per AD-19 + the P01 phase-suite pattern: no array loops, no compound chains, no eval. Each sub-gate is a literal `bash <verifier>` invocation followed by a `rc=$?` and a per-gate `OK:`/`FAIL:` line. The final stdout line is `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M`. Exits 0 iff every sub-gate exits 0; gates do NOT short-circuit on failure (all gates run regardless so the operator sees the full report).

2. **`tools/verify/m031-p02-scope-guard.sh`** — SC-12 enforcement for the P02 diff. Inherits the P01 scope-guard's block-list verbatim:
   - `knowledge/**` (M020 owns)
   - `scripts/cost/` (M027 owns)
   - `scripts/dispatch/adapters/router/` (M030 owns)
   - `scripts/auto/loop/` (M021 owns)

   Inherits the MEM `hit_count`-only carve-out verbatim. The allow-list reflects the P02 "Files Likely Touched" surface plus the P02 phase + task plan + summary file paths plus the `.orchestrator/observability/` permissive prefix.

The phase-suite invokes EVERY P02 sub-gate, including the scope-guard itself as the final gate (so a clean diff is required for green).

P02 sub-gate inventory (twelve gates total):

```
T01: m031-p02-classifier-extension-shape.sh
T01: m031-p02-fixture-provenance-shape.sh
T01: m031-p02-tier-a-plus-input-shape.sh
T01: m031-p02-test-tier-a-plus-classifier-shape.sh
T02: m031-p02-task-slug-shape.sh
T02: m031-p02-role-templates-shape.sh
T03: m031-p02-prompt-shape.sh
T03: m031-p02-test-tier-a-plus-prompt-ux-shape.sh
T04: m031-p02-router-shape.sh
T04: m031-p02-test-tier-a-plus-flow-shape.sh
T05: m031-p02-scope-guard.sh
```

Eleven sub-gates plus the suite line itself. The phase-suite emits `SUMMARY: m031-p02-phase-suite.sh pass=N fail=M` where N + M = 11 on a clean run.

## Steps

1. **Read `tools/verify/m031-p01-phase-suite.sh`** for reference. The pattern is straight-line N-gate aggregation: each gate is a labeled `bash <verifier>` invocation followed by `rc=$?` then `emit_gate_result "$rc" "<verifier-name>"`. No array loops. The accumulator updates inside `emit_gate_result` (`pass=$(( pass + 1 ))` or `fail=$(( fail + 1 ))`). Final `printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"` then `exit 0` iff `fail=0` else `exit 1`.

2. **Author `tools/verify/m031-p02-phase-suite.sh`** (executable, bash 3.2). Mirror the M031 P01 phase-suite shape (118 lines on disk; T05's suite will be similar size). Required body (concrete shape):

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m031-p02-phase-suite.sh — M031 P02 phase-close gate suite.
   #
   # Aggregates all P02 sub-gates (T01 + T02 + T03 + T04 + T05) for the
   # right-sized-entry milestone (M031) and emits a single aggregate
   # SUMMARY line. Mirrors the m031-p01-phase-suite.sh straight-line
   # pattern (AD-19 compliant — no array loops, no compound chains).
   #
   # Sub-gates (in T01 → T05 dependency order):
   #   1. m031-p02-classifier-extension-shape.sh        (T01)
   #   2. m031-p02-fixture-provenance-shape.sh          (T01)
   #   3. m031-p02-tier-a-plus-input-shape.sh           (T01)
   #   4. m031-p02-test-tier-a-plus-classifier-shape.sh (T01)
   #   5. m031-p02-task-slug-shape.sh                   (T02)
   #   6. m031-p02-role-templates-shape.sh              (T02)
   #   7. m031-p02-prompt-shape.sh                      (T03)
   #   8. m031-p02-test-tier-a-plus-prompt-ux-shape.sh  (T03)
   #   9. m031-p02-router-shape.sh                      (T04)
   #  10. m031-p02-test-tier-a-plus-flow-shape.sh       (T04)
   #  11. m031-p02-scope-guard.sh                       (T05)
   #
   # Gates run sequentially; do NOT short-circuit on failure (operator
   # sees the full report). Exit 0 iff every sub-gate exits 0.

   set -u
   pass=0
   fail=0

   emit_gate_result() {
       rc="$1"
       name="$2"
       if [ "$rc" -eq 0 ]; then
           pass=$(( pass + 1 ))
           printf 'OK: %s\n' "$name"
       else
           fail=$(( fail + 1 ))
           printf 'FAIL: %s rc=%s\n' "$name" "$rc"
       fi
   }

   bash tools/verify/m031-p02-classifier-extension-shape.sh
   rc=$?
   emit_gate_result "$rc" "m031-p02-classifier-extension-shape.sh"

   bash tools/verify/m031-p02-fixture-provenance-shape.sh
   rc=$?
   emit_gate_result "$rc" "m031-p02-fixture-provenance-shape.sh"

   # ... (repeat for all 11 gates) ...

   printf 'SUMMARY: m031-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
       exit 0
   else
       exit 1
   fi
   ```

   Eleven `bash <verifier>` blocks. No loops, no compound chains. Final SUMMARY line + exit code.

3. **Read `tools/verify/m031-p01-scope-guard.sh`** for reference. The pattern is:
   - Walk `git diff --name-only HEAD` to collect changed paths.
   - For each path: check the block-list (HARD FAIL) → if MEM hit_count-only carve-out applies, soft pass → check the allow-list (PASS) → otherwise WARN out-of-allow-list.
   - Emit `SUMMARY: <name> pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L` final line.

4. **Author `tools/verify/m031-p02-scope-guard.sh`** (executable, bash 3.2). Inherit the P01 scope-guard's block-list pattern verbatim — including the MEM hit_count-only carve-out helper function. Replace the allow-list with P02's surface. Required allow-list (newline-delimited, exact-match):

   ```
   scripts/intake/shape-detect.sh
   scripts/intake/paragraph-classify.sh
   scripts/intake/route-to-dispatch.sh
   scripts/intake/lib/task-slug.sh
   scripts/intake/lib/tier-a-plus-prompt.sh
   templates/dispatch-role-research.md
   templates/dispatch-role-plan.md
   templates/dispatch-role-build.md
   tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md
   tests/m031-acceptance/fixtures/tier-a-plus-input.txt
   tests/m031-acceptance/test-tier-a-plus-classifier.sh
   tests/m031-acceptance/test-tier-a-plus-flow.sh
   tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
   tools/verify/m031-p02-classifier-extension-shape.sh
   tools/verify/m031-p02-fixture-provenance-shape.sh
   tools/verify/m031-p02-tier-a-plus-input-shape.sh
   tools/verify/m031-p02-task-slug-shape.sh
   tools/verify/m031-p02-role-templates-shape.sh
   tools/verify/m031-p02-prompt-shape.sh
   tools/verify/m031-p02-router-shape.sh
   tools/verify/m031-p02-test-tier-a-plus-classifier-shape.sh
   tools/verify/m031-p02-test-tier-a-plus-flow-shape.sh
   tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
   tools/verify/m031-p02-phase-suite.sh
   tools/verify/m031-p02-scope-guard.sh
   .orchestrator/milestones/M031/phases/P02/P02-PLAN.md
   .orchestrator/milestones/M031/phases/P02/tasks/T01-classifier-and-provenance-PLAN.md
   .orchestrator/milestones/M031/phases/P02/tasks/T02-slug-and-role-templates-PLAN.md
   .orchestrator/milestones/M031/phases/P02/tasks/T03-prompt-and-prompt-ux-test-PLAN.md
   .orchestrator/milestones/M031/phases/P02/tasks/T04-router-and-flow-test-PLAN.md
   .orchestrator/milestones/M031/phases/P02/tasks/T05-phase-suite-and-scope-guard-PLAN.md
   .orchestrator/milestones/M031/phases/P02/tasks/T01-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T02-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T03-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T04-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/tasks/T05-SUMMARY.md
   .orchestrator/milestones/M031/phases/P02/P02-SUMMARY.md
   ```

   Allow-list prefixes (permissive — for scratch + observability artifacts):
   - `.orchestrator/observability/`
   - `.orchestrator/tier-a-plus/` (per-flow scratch directories written during T04 router test runs)

   Block-list (inherited verbatim from P01):
   - `knowledge/`
   - `scripts/cost/`
   - `scripts/dispatch/adapters/router/`
   - `scripts/auto/loop/`

   MEM hit_count-only carve-out: copy the `is_mem_hitcount_only_carveout()` function from `tools/verify/m031-p01-scope-guard.sh` verbatim.

   Final stdout line: `SUMMARY: m031-p02-scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L`. Exit 0 iff `block_list_violations=0`; else exit 1.

5. **Run the phase-suite locally** to confirm exit 0 with all 11 sub-gates green:

   ```bash
   bash tools/verify/m031-p02-phase-suite.sh
   ```

   Expected output: `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0` (assuming T01–T04 all green).

6. **Run the scope-guard locally** to confirm a clean diff:

   ```bash
   bash tools/verify/m031-p02-scope-guard.sh
   ```

   Expected output: `SUMMARY: m031-p02-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K` for some `N` (allow-listed paths) and `K` (any orchestrator-emitted MEM hit_count drift carved out). `block_list_violations` MUST be 0; else T05 has hit a real scope violation that needs investigation, NOT a verifier-edit.

7. **Run the framework-owned `scripts/verify/check-must-haves.sh`** against the P02 phase directory to confirm phase-level Truths / Artifacts / Key Links all PASS:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/
   ```

8. **Confirm idempotency.** Run the phase-suite a second time and confirm identical exit 0 + identical SUMMARY line — the suite must be deterministic (no flake).

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "tools/verify/m031-p02-phase-suite.sh exists, executable, invokes every P02 sub-gate in order" (Truth #11; Check via `m031-p02-phase-suite.sh`)
- "tools/verify/m031-p02-scope-guard.sh exists, executable, asserts P02 diff stays within block-list" (Truth #12; Check via `m031-p02-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p02-phase-suite.sh
```

```bash
bash tools/verify/m031-p02-scope-guard.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/
```

## Notes

- The phase-suite emits `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0` on a fully-green run (11 sub-gates: 4 from T01, 2 from T02, 2 from T03, 2 from T04, 1 from T05's own scope-guard).
- Future maintainers extending P02 with additional gates MUST add the new verifier to the suite's gate list AND increment the expected `SUMMARY: pass=N` count expected by downstream consumers (P04 acceptance-battery aggregator).
- Two distinct envelope conventions in use across P02:
  - `RESULT: SC-N pass` / `RESULT: SC-N fail` for SC-* acceptance tests under `tests/m031-acceptance/test-tier-a-plus-*.sh`.
  - `SUMMARY: <verifier> pass=N fail=M` for shape verifiers under `tools/verify/m031-p02-*.sh`.
  Both are AD-19 compliant; downstream consumers can grep either.
- The `.orchestrator/tier-a-plus/` permissive-prefix carve-out in the scope-guard is the P02 equivalent of P01's `.orchestrator/observability/` carve-out — per-flow scratch artifacts that don't pollute the M031 diff signal.
- The MEM hit_count-only carve-out is inherited verbatim from P01 — orchestrator-emitted `hit_count:` line drift on `knowledge/(conventions|lessons|patterns)/MEM*.md` is a dispatch side-effect, not a manual P02 scope violation. Future milestones with similar dispatch side-effects can adopt the same pattern.
- D020 token hygiene (CON-7): comments and prose in the new files MUST NOT embed the scaffold-placeholder marker bracket-TODO byte pattern; paraphrase or escape.
- Bash 3.2 compatibility (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.

## Inputs

### From Previous Tasks

- All ten T01–T04 shape verifiers under `tools/verify/m031-p02-*.sh`. T05's phase-suite invokes each via `bash <path>` straight-line. Key API: each verifier exits 0 iff `fail=0`, emits `SUMMARY: <name> pass=N fail=M` final line.
- Three SC acceptance tests under `tests/m031-acceptance/test-tier-a-plus-*.sh` (SC-5 / SC-6 / SC-16). T05's phase-suite does NOT run these directly — it runs the shape verifiers that *gate* their existence/contract. The P04 acceptance-battery aggregator (downstream consumer) runs the SC tests.
- The new `scripts/intake/route-to-dispatch.sh` (T04 amended) — T05's scope-guard allow-lists this as a modify, not a create.

### From Disk (Pre-existing)

- `tools/verify/m031-p01-phase-suite.sh` — reference pattern for the straight-line N-gate aggregator. Read before authoring T05's phase-suite.
- `tools/verify/m031-p01-scope-guard.sh` — reference pattern for the SC-12 block-list + MEM hit_count carve-out. Read before authoring T05's scope-guard.
- `scripts/verify/check-must-haves.sh` — framework-owned phase-level Truths/Artifacts/Key Links verifier. T05 invokes it as the final phase-close confirmation.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **Single-script-file Truth Check shape** (AD-19): every gate in the phase-suite is a literal `bash <path>` invocation. No `for` loops, no compound chains, no `eval`.
- **Block-list inherited verbatim** from P01 — T05 MUST NOT relax `knowledge/`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. Future maintainers tempted to relax it MUST first amend the spec's "Boundary write-sites M031 delegates" section.
- **MEM hit_count-only carve-out inherited verbatim** from P01 — copy the `is_mem_hitcount_only_carveout()` function body unchanged.
- **Allow-list reflects the P02 surface** — exactly the files in P02-PLAN.md "Files Likely Touched" plus the P02 phase + task plan + summary paths.
- **No edits to upstream P02 deliverables** in T05 — T01–T04 outputs stay frozen. T05's only on-disk writes are the two new verifiers under `tools/verify/`.
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T05 completes:

1. `tools/verify/m031-p02-phase-suite.sh` exists, executable, exits 0 with `SUMMARY: m031-p02-phase-suite.sh pass=11 fail=0` (eleven sub-gates green).
2. `tools/verify/m031-p02-scope-guard.sh` exists, executable, exits 0 with `SUMMARY: m031-p02-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K`.
3. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P02/` exits 0 — every P02 phase-level Truth, Artifact, and Key Link is satisfied on disk.
4. The P02 diff against HEAD touches only files in the T05 scope-guard allow-list (plus permissive-prefix artifacts under `.orchestrator/observability/` or `.orchestrator/tier-a-plus/`) and zero paths under the block-list.

T05 closes P02 mechanically. The phase is then ready for `orchestrator:consolidate` (and downstream P03 + P04 work).

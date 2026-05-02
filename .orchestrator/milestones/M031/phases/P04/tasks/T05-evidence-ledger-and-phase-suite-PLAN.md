---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M031"
name: "M031-ACCEPTANCE-EVIDENCE.md evidence ledger + P04 phase-suite + P04 phase-grain scope-guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01–T04 complete: every P04 SC test exists and passes (SC-9, SC-10, AD-9, AD-19, SC-12 milestone-grain); the battery aggregator at `tests/m031-acceptance/run-acceptance-battery.sh` exists and reports `BATTERY: pass=N fail=0` (N = 15 under Option A, N = 16 under Option B); 11 P04 shape verifiers exist under `tools/verify/m031-p04-*-shape.sh` (T01: evaluate-md-drift / tier-definitions-drift / auto-proceed-default / changelog / test-doc-drift / test-auto-proceed; T02: doctor-compound-change / test-doctor-compound-change; T03: budget-drift / test-budget-drift; T04: test-scope-guard / battery / evidence-ledger).
- `.orchestrator/milestones/M030/M030-SUMMARY.md` and the M030 acceptance-evidence convention exist (read for shape reference — the M030 close authored a similar evidence record).
- `tools/verify/m031-p03-phase-suite.sh` and `tools/verify/m031-p03-scope-guard.sh` exist on disk — read for shape inheritance.
- `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` exists and records Option A or Option B (determines battery N).

## Description

T05 ships the milestone-close artifacts:

1. **`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`** — the green-run evidence ledger. T05 runs `bash tests/m031-acceptance/run-acceptance-battery.sh` and captures the output, then authors a Markdown file containing:
   - YAML frontmatter (schema_version, type=acceptance-evidence, milestone=M031, generated_at=<ISO-8601>).
   - The captured `BATTERY: pass=N fail=0` line verbatim.
   - A per-SC roll-up table (one row per gate, columns: ID / script-path / outcome).
   - The ISO-8601 timestamp of the green run.
   - A back-link to `tests/m031-acceptance/run-acceptance-battery.sh`.
   - A short prose section noting which SC-13 option was active.

   Mirrors the M030 evidence-ledger convention and the wider M031-SUMMARY.md convention.

2. **`tools/verify/m031-p04-phase-suite.sh`** — straight-line aggregator for every P04 sub-gate, in T01 → T05 dependency order. Mirrors the P01/P02/P03 phase-suite shapes: AD-19 single-script-file invocations, no array loops, no compound chains, no eval. Sub-gate inventory (13 gates):
   - T01 (6): evaluate-md-drift-shape, tier-definitions-drift-shape, auto-proceed-default-shape, changelog-shape, test-doc-drift-shape, test-auto-proceed-shape
   - T02 (2): doctor-compound-change-shape, test-doctor-compound-change-shape
   - T03 (2): budget-drift-shape, test-budget-drift-shape
   - T04 (3): test-scope-guard-shape, battery-shape, evidence-ledger-shape
   - T05 (1): m031-p04-scope-guard.sh (last gate per the P01/P02/P03 convention)

   Total: 13 sub-gates. Aggregator emits `SUMMARY: m031-p04-phase-suite.sh pass=N fail=M` and exits 0 iff `fail == 0`.

3. **`tools/verify/m031-p04-scope-guard.sh`** — phase-grain SC-12 verifier (distinct from the milestone-grain one at `tests/m031-acceptance/scope-guard.sh` shipped in T04). Inherits block-list + MEM hit_count carve-out + dual-prefix permissive carve-out verbatim from P01/P02/P03. Allow-list reflects the P04 "Files Likely Touched" surface (every T01–T05 deliverable) plus phase/task plan + summary paths under `.orchestrator/milestones/M031/phases/P04/` plus the milestone summary path `.orchestrator/milestones/M031/M031-SUMMARY.md` and the evidence ledger `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`.

## Steps

1. **Run the battery aggregator and capture its output**:

   ```bash
   bash tests/m031-acceptance/run-acceptance-battery.sh
   ```

   Capture the full stdout (use the agent runtime's standard output-capture mechanism — `bash <path> > /tmp/m031-p04-battery-output.txt 2>&1` is acceptable as a one-shot command if the runtime supports it).

   Confirm the final line is `BATTERY: pass=N fail=0`. If `fail > 0`, STOP — diagnose the failing SC and route back to the appropriate task (T01–T04) for remediation BEFORE authoring the evidence ledger.

2. **Read `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`** to determine the active option (A or B). Record the option in the evidence ledger.

3. **Read `.orchestrator/milestones/M030/M030-SUMMARY.md`** with the `Read` tool. Note the structure (frontmatter, body, sections). The M030 close also produced an acceptance-evidence record (likely embedded in the summary OR at a sibling path); read for the canonical shape.

4. **Author `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`** (≥ 30 lines). Body shape:

   ```markdown
   ---
   schema_version: "1.0"
   type: acceptance-evidence
   milestone: "M031"
   generated_at: "<ISO-8601 UTC timestamp from `date -u +%Y-%m-%dT%H:%M:%SZ`>"
   battery_path: "tests/m031-acceptance/run-acceptance-battery.sh"
   sc13_option: "<A or B as recorded in SC13-OPTION.md>"
   ---

   # M031 — Acceptance Evidence Ledger

   This document captures the green-run evidence for M031 (right-sized
   entry). It mirrors the M030 acceptance-evidence convention and serves
   as the milestone-close audit trail.

   ## Battery Result

   ```
   BATTERY: pass=N fail=0
   ```

   (N = 15 under Option A; N = 16 under Option B.)

   ## Per-SC Roll-Up

   | ID    | Path                                                       | Outcome |
   |-------|------------------------------------------------------------|---------|
   | SC-1  | tests/m031-acceptance/test-quick-injects-knowledge.sh      | PASS    |
   | SC-2  | tests/m031-acceptance/test-build-context-profile.sh        | PASS    |
   | SC-3  | tests/m031-acceptance/test-compression-applies-to-quick.sh | PASS    |
   | SC-5  | tests/m031-acceptance/test-tier-a-plus-classifier.sh       | PASS    |
   | SC-6  | tests/m031-acceptance/test-tier-a-plus-flow.sh             | PASS    |
   | SC-7  | tests/m031-acceptance/test-universal-entry-trivial.sh      | PASS    |
   | SC-8  | tests/m031-acceptance/test-universal-entry-lowconf.sh      | PASS    |
   | SC-9  | tests/m031-acceptance/doc-drift-verifier.sh                | PASS    |
   | SC-10 | tests/m031-acceptance/test-auto-proceed-default.sh         | PASS    |
   | SC-11 | tests/m031-acceptance/empirical-baseline.sh --compare      | PASS    |
   | SC-12 | tests/m031-acceptance/scope-guard.sh                       | PASS    |
   | SC-13 | tests/m031-acceptance/verify-baseline-ordering.sh          | <PASS or N/A under Option A> |
   | SC-15 | tests/m031-acceptance/test-quick-budget-median.sh          | PASS    |
   | SC-16 | tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh        | PASS    |
   | AD-9  | tests/m031-acceptance/test-doctor-compound-change.sh       | PASS    |
   | AD-19 | tests/m031-acceptance/test-budget-drift-warning.sh         | PASS    |

   ## Run Metadata

   - **Timestamp** (ISO-8601 UTC): `<copy from frontmatter generated_at>`
   - **SC-13 option active**: `<A or B>`
   - **Battery N**: `<15 or 16>`
   - **Battery aggregator path**: `tests/m031-acceptance/run-acceptance-battery.sh`

   ## Cross-References

   - Milestone roadmap: `.orchestrator/milestones/M031/M031-ROADMAP.md`
   - Milestone context: `.orchestrator/milestones/M031/M031-CONTEXT.md`
   - Milestone evaluation: `.orchestrator/milestones/M031/M031-EVALUATION.md`
   - Milestone summary: `.orchestrator/milestones/M031/M031-SUMMARY.md` (consolidated post-phase by `orchestrator:consolidate`)
   - Feature spec: `specs/034-right-sized-entry/spec.md`
   - Per-phase summaries: `.orchestrator/milestones/M031/phases/P0[0-4]/P0[0-4]-SUMMARY.md`
   ```

   The executor populates the timestamp from `date -u +%Y-%m-%dT%H:%M:%SZ` at write-time, transcribes the battery line verbatim from the captured output, and records the SC-13 option from `SC13-OPTION.md`.

5. **Read `tools/verify/m031-p03-phase-suite.sh`** with the `Read` tool. Note:
   - `set -u` at the top.
   - `pass=0; fail=0` accumulators.
   - `emit_gate_result()` helper accepting `(rc, name)`.
   - Seven gate blocks, each three lines: `bash <verifier-path>` then `rc=$?` then `emit_gate_result "$rc" "<name>"`.
   - Final block: `printf 'SUMMARY: m031-p03-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"` then `if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi`.

6. **Author `tools/verify/m031-p04-phase-suite.sh`** (≥ 80 lines, executable, bash 3.2). Mirror the P03 shape exactly except:
   - 13 gate blocks instead of 7.
   - Sub-gate ordering matches T01 → T02 → T03 → T04 → T05 dependency order:

     ```
     1.  tools/verify/m031-p04-evaluate-md-drift-shape.sh         (T01)
     2.  tools/verify/m031-p04-tier-definitions-drift-shape.sh    (T01)
     3.  tools/verify/m031-p04-auto-proceed-default-shape.sh      (T01)
     4.  tools/verify/m031-p04-changelog-shape.sh                 (T01)
     5.  tools/verify/m031-p04-test-doc-drift-shape.sh            (T01)
     6.  tools/verify/m031-p04-test-auto-proceed-shape.sh         (T01)
     7.  tools/verify/m031-p04-doctor-compound-change-shape.sh    (T02)
     8.  tools/verify/m031-p04-test-doctor-compound-change-shape.sh (T02)
     9.  tools/verify/m031-p04-budget-drift-shape.sh              (T03)
     10. tools/verify/m031-p04-test-budget-drift-shape.sh         (T03)
     11. tools/verify/m031-p04-test-scope-guard-shape.sh          (T04)
     12. tools/verify/m031-p04-battery-shape.sh                   (T04)
     13. tools/verify/m031-p04-evidence-ledger-shape.sh           (T04 verifier; gates T05's ledger)
     14. tools/verify/m031-p04-scope-guard.sh                     (T05; last gate)
     ```

     (14 gates total; the inventory in the Description above counts 13 sub-gates plus the phase-grain scope-guard as gate 14. The executor lays out 14 straight-line gate blocks.)

   - Header comment block (≥ 30 lines) documenting the gate ordering, the AD-19 straight-line discipline, and a `# Key links (M031/P04):` block listing the 14 sub-gate basenames so phase-level key-link must-haves resolve via grep.
   - Final SUMMARY line `SUMMARY: m031-p04-phase-suite.sh pass=%d fail=%d`.
   - Exit 0 iff `fail == 0`.
   - Does NOT short-circuit on a sub-gate failure (all 14 gates run regardless).

   `chmod +x tools/verify/m031-p04-phase-suite.sh`.

7. **Read `tools/verify/m031-p03-scope-guard.sh`** with the `Read` tool. Note:
   - The `git diff --name-only HEAD` invocation (or equivalent) for enumerating changed files.
   - The block-list pattern matcher.
   - The MEM hit_count carve-out function.
   - The dual-prefix permissive carve-out.
   - The allow-list block.
   - The final SUMMARY line shape.

8. **Author `tools/verify/m031-p04-scope-guard.sh`** (≥ 100 lines, executable, bash 3.2). Mirror the P03 shape exactly except:
   - **Allow-list** updated to the P04 "Files Likely Touched" surface (verbatim from P04-PLAN.md "Files Likely Touched"). Plus the milestone-summary path `.orchestrator/milestones/M031/M031-SUMMARY.md` (will be written by `orchestrator:consolidate` post-P04) and the evidence-ledger path `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` (T05 ships this in step 4 above). Plus phase/task-plan/summary paths under `.orchestrator/milestones/M031/phases/P04/`.
   - **Block-list** preserved verbatim from P03: `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
   - **MEM hit_count-only carve-out** copied verbatim.
   - **Dual-prefix permissive carve-out** preserved verbatim.
   - Header comment block (≥ 30 lines) documenting the SC-12 contract, the carve-outs, and the allow-list provenance.
   - Final SUMMARY line `SUMMARY: m031-p04-scope-guard.sh pass=%d fail=%d block_list_violations=%d mem_hitcount_carveouts=%d`.
   - Exit 0 iff `block_list_violations == 0`.

   `chmod +x tools/verify/m031-p04-scope-guard.sh`.

9. **Co-author the `# Key links` doc-comment** in `tools/verify/m031-p04-phase-suite.sh` (mirrors the P01/P02/P03 remediation pattern). The block lists the 14 sub-gate basenames so the phase plan's Key Links must-haves resolve via `grep -q '<basename>' tools/verify/m031-p04-phase-suite.sh`:

   ```bash
   # Key links (M031/P04):
   #   - m031-p04-evaluate-md-drift-shape.sh         (T01 evaluate.md drift gate)
   #   - m031-p04-tier-definitions-drift-shape.sh    (T01 tier-definitions.md drift gate)
   #   - m031-p04-auto-proceed-default-shape.sh      (T01 auto_proceed default gate)
   #   - m031-p04-changelog-shape.sh                 (T01 CHANGELOG entry gate)
   #   - m031-p04-test-doc-drift-shape.sh            (T01 SC-9 shape gate)
   #   - m031-p04-test-auto-proceed-shape.sh         (T01 SC-10 shape gate)
   #   - m031-p04-doctor-compound-change-shape.sh    (T02 doctor amendment gate)
   #   - m031-p04-test-doctor-compound-change-shape.sh (T02 AD-9 shape gate)
   #   - m031-p04-budget-drift-shape.sh              (T03 efficiency-footer amendment gate)
   #   - m031-p04-test-budget-drift-shape.sh         (T03 AD-19 shape gate)
   #   - m031-p04-test-scope-guard-shape.sh          (T04 milestone-scope-guard shape gate)
   #   - m031-p04-battery-shape.sh                   (T04 battery aggregator shape gate)
   #   - m031-p04-evidence-ledger-shape.sh           (T04 evidence-ledger shape gate; gates T05 artifact)
   #   - m031-p04-scope-guard.sh                     (T05 phase-grain scope-guard; last)
   ```

10. **Run the phase-suite + scope-guard locally to confirm exit 0**:

    ```bash
    bash tools/verify/m031-p04-phase-suite.sh
    ```

    ```bash
    bash tools/verify/m031-p04-scope-guard.sh
    ```

    The phase-suite must report `SUMMARY: m031-p04-phase-suite.sh pass=14 fail=0`. The scope-guard must report `block_list_violations=0`. If either fails, the failure is one of:
    - **A T01–T04 deliverable is missing**: re-verify the upstream tasks shipped their artifacts.
    - **The evidence-ledger-shape verifier is failing**: confirm step 4 (evidence ledger authoring) completed; the verifier asserts `M031-ACCEPTANCE-EVIDENCE.md` exists with the required substrings.
    - **The scope-guard's allow-list does not cover a touched file**: extend the allow-list.
    - **The scope-guard reports `block_list_violations > 0`**: the diff actually touches a forbidden path. Revert and reroute.
    - **MEM hit_count drift** is reported: orchestrator-emitted side-effect from prior dispatches; counted under `mem_hitcount_carveouts`, NOT `block_list_violations` — green pass.

11. **Verify the phase-level Tier 1 must-haves** (per the M031/P03 plan-time defect note: invoke with the phase **directory**, not a file):

    ```bash
    bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P04/
    ```

    Expect 0 FAIL.

12. **Verify the phase-level boundary map** (informational; may SKIP if no produce items declared):

    ```bash
    bash scripts/verify/check-boundary-map.sh .orchestrator/milestones/M031/phases/P04/
    ```

    SKIP is acceptable.

13. **Commit T05 deliverables** via `git commit -F <message-file>`. Suggested commit subject: `M031/P04/T05: M031-ACCEPTANCE-EVIDENCE.md + P04 phase-suite + scope-guard`.

## Must-Haves

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` exists post-phase, contains the literal output line `BATTERY: pass=N fail=0`" (Truth #13; Check via `m031-p04-evidence-ledger-shape.sh`)
- "`tools/verify/m031-p04-phase-suite.sh` exists, is executable, invokes every P04 sub-gate" (Truth #14; Check via `m031-p04-phase-suite.sh`)
- "`tools/verify/m031-p04-scope-guard.sh` exists, is executable, and asserts the P04 working-tree diff" (Truth #15; Check via `m031-p04-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p04-phase-suite.sh
```

```bash
bash tools/verify/m031-p04-scope-guard.sh
```

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P04/
```

## Notes

- The phase-suite emits `SUMMARY: m031-p04-phase-suite.sh pass=14 fail=0` when every sub-gate is green — N is exactly 14 (6 from T01 + 2 from T02 + 2 from T03 + 3 from T04 + 1 from T05 itself).
- The scope-guard's `mem_hitcount_carveouts=K` field is informational; only `block_list_violations` is gated.
- AD-19 single-script-file invariant: each gate inside the phase-suite is invoked as a literal `bash <path>` line followed by `rc=$?`. NO `for` loops over arrays, NO `(...)` subshells, NO `&&`/`||` chains, NO `$(...)` containing pipes.
- Bash 3.2 (MEM001): no `declare -A`, no process substitution.
- D020 / CON-7: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- The phase-suite does NOT parse SUMMARY lines from sub-gates — it consumes exit codes only (mirrors P02/P03 — parsing would couple the suite to envelope formatting; exit codes are the load-bearing contract).
- The scope-guard's allow-list does NOT include test-run scratch artifacts under `.orchestrator/tier-a-plus/` or `.orchestrator/observability/` — those land under the dual-prefix permissive carve-out and are not allow-list-gated.
- The evidence ledger's per-SC roll-up table is authored by transcribing the `BATTERY-PASS:` / `BATTERY-FAIL:` lines from the captured battery output. The order in the table mirrors the order in which the battery emits the lines (which mirrors the dependency order P01 → P02 → P03 → P04 → P00 baseline tail).
- The evidence ledger is sibling to the milestone summary `M031-SUMMARY.md` (which is authored by `orchestrator:consolidate` post-P04 close). The two together form the milestone audit trail.
- **Real-app smoke test pending** (plan-time discipline rule 5): T05's verifiers gate the phase-close shape, not the live runtime end-to-end. Production confirmation that an operator running `orchestrator:do <task>` against a CC-installed consumer project sees the expected behavior is the M033 onboarding milestone's job; T05 + the P04 phase-suite confirm the contract surface.

## Inputs

### From Previous Tasks

- **T01: 6 shape verifiers** under `tools/verify/m031-p04-*-shape.sh` — phase-suite invokes each.
- **T02: 2 shape verifiers** — phase-suite invokes each.
- **T03: 2 shape verifiers** — phase-suite invokes each.
- **T04: 3 shape verifiers** (test-scope-guard, battery, evidence-ledger) — phase-suite invokes each. The evidence-ledger verifier was authored at T04 close but only becomes load-bearing after T05 step 4 (the ledger authoring).
- **T04: `tests/m031-acceptance/run-acceptance-battery.sh`** — T05 step 1 invokes this to capture the green-run output for the evidence ledger.

### From Previous Phases

- **P01: `tools/verify/m031-p01-phase-suite.sh`** — read for the straight-line N-gate aggregation pattern (AD-19 compliant).
- **P02/P03: `tools/verify/m031-p02-phase-suite.sh` + `tools/verify/m031-p03-phase-suite.sh`** — read for the `emit_gate_result` helper shape and the SUMMARY line format.
- **P02/P03: `tools/verify/m031-p02-scope-guard.sh` + `tools/verify/m031-p03-scope-guard.sh`** — read for the dual-prefix permissive carve-out and the MEM hit_count carve-out.
- **`.orchestrator/milestones/M030/M030-SUMMARY.md`** (or sibling acceptance-evidence file) — read for the M030 evidence-ledger convention.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M031/phases/P04/P04-PLAN.md` — read for the "Files Likely Touched" allow-list surface.
- `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` — read for the active option (A or B).

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: phase-suite gate invocations are straight-line `bash <path>` + `rc=$?` + `emit_gate_result`. No array loops, no compound chains, no eval.
- **No edits to T01 / T02 / T03 / T04 deliverables** in T05.
- **No edits to P01 / P02 / P03 verifiers** (`m031-p01-*.sh`, `m031-p02-*.sh`, `m031-p03-*.sh`) in T05.
- **No edits to `scripts/intake/`, `scripts/dispatch/`, `commands/`, `references/`, `templates/`, `CHANGELOG.md`, `scripts/diagnostics/`** in T05.
- **CON-4 / DC-4**: T05 makes no orchestration-state writes (the evidence ledger is a milestone-close record, not a state-machine surface).
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T05 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The phase-grain scope-guard verifier itself MAY contain literal references to those paths (block-list patterns).
- **Verifier path discipline** (AD-19 + M032 Finding A): project-owned slug-bearing verifiers live under `tools/verify/`.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`.

## Expected Output

After T05 completes:

1. `.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md` (≥ 30 lines) — contains the `BATTERY: pass=N fail=0` line, the per-SC roll-up table, the ISO-8601 timestamp, and the back-link to the battery script.
2. `tools/verify/m031-p04-phase-suite.sh` (≥ 80 lines, executable) — invokes 14 sub-gates straight-line, emits `SUMMARY: m031-p04-phase-suite.sh pass=14 fail=0`, exits 0.
3. `tools/verify/m031-p04-scope-guard.sh` (≥ 100 lines, executable) — asserts SC-12 block-list compliance with carve-outs, emits `SUMMARY: m031-p04-scope-guard.sh pass=N fail=0 block_list_violations=0 mem_hitcount_carveouts=K`, exits 0.
4. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M031/phases/P04/` reports 0 FAIL.
5. No edits to any T01–T04 deliverable.
6. No edits to any P01–P03 verifier.

T05 leaves the M031 milestone ready for `orchestrator:verify` + `orchestrator:consolidate`. The phase-suite is green, the scope-guard is green, the battery is green, and the evidence ledger captures the audit trail. P04 closes M031.

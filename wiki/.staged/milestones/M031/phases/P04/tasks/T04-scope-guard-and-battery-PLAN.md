---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M031"
name: "Milestone-grain SC-12 scope-guard + acceptance battery aggregator (SC-14)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: SC-9 `tests/m031-acceptance/doc-drift-verifier.sh` exists and passes; SC-10 `tests/m031-acceptance/test-auto-proceed-default.sh` exists and passes.
- T02 complete: AD-9 `tests/m031-acceptance/test-doctor-compound-change.sh` exists and passes.
- T03 complete: AD-19 `tests/m031-acceptance/test-budget-drift-warning.sh` exists and passes.
- All P01–P03 SC scripts exist on disk under `tests/m031-acceptance/`:
  - SC-1 `test-quick-injects-knowledge.sh` (P01)
  - SC-2 `test-build-context-profile.sh` (P01)
  - SC-3 `test-compression-applies-to-quick.sh` (P01)
  - SC-5 `test-tier-a-plus-classifier.sh` (P02)
  - SC-6 `test-tier-a-plus-flow.sh` (P02)
  - SC-7 `test-universal-entry-trivial.sh` (P03)
  - SC-8 `test-universal-entry-lowconf.sh` (P03)
  - SC-11 `empirical-baseline.sh` (P00, invoked with `--compare`)
  - SC-13 `verify-baseline-ordering.sh` (P00, under Option B per AD-12)
  - SC-15 `test-quick-budget-median.sh` (P01)
  - SC-16 `test-tier-a-plus-prompt-ux.sh` (P02)
- The per-phase scope-guards exist on disk under `tools/verify/`: `m031-p01-scope-guard.sh`, `m031-p02-scope-guard.sh`, `m031-p03-scope-guard.sh` — read for shape inheritance.
- `tests/m030-acceptance/run-acceptance-battery.sh` exists and is the canonical battery-aggregator shape (read for the `run_sc` helper + final `BATTERY: pass=N fail=M` line + AD-19 single-script-file shape).
- The per-phase scope-guard's `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` records whether SC-13 is Option B (git-history check) or Option A (protocol note, drop from battery N).

## Description

T04 ships two milestone-close deliverables:

1. **Milestone-grain SC-12 scope-guard** — `tests/m031-acceptance/scope-guard.sh`. This is **distinct from** the per-phase `tools/verify/m031-p0X-scope-guard.sh` family. The per-phase scope-guards each enforce SC-12 against a **single phase's working-tree diff** (typically vs HEAD); the milestone-grain scope-guard enforces SC-12 against the **entire M031 milestone's diff** (typically the merge-base between the M031 work branch and the project's main branch, OR — equivalently for a working-tree dogfood — the same working-tree-vs-HEAD diff but with an allow-list reflecting every phase's "Files Likely Touched" surface). The verifier emits `RESULT: SC-12 pass` and exits 0 iff `block_list_violations == 0`. POSIX-bash per CON-6.

2. **SC-14 acceptance battery aggregator** — `tests/m031-acceptance/run-acceptance-battery.sh`. Mirrors the [M030](../../../../../milestones/M030/index.md) acceptance-battery convention at `tests/m030-acceptance/run-acceptance-battery.sh`. Chains every M031 SC script in literal-sequence `bash <path>` invocations (AD-19 — straight-line, no array loops, no compound chains). Captures rc per call into `pass` / `fail` accumulators via a `run_sc` helper. Emits a final `BATTERY: pass=N fail=M` line and exits 0 iff `fail == 0`. Sub-gate inventory (16 SC scripts under Option B; 15 under Option A):

   - SC-1: `test-quick-injects-knowledge.sh`
   - SC-2: `test-build-context-profile.sh`
   - SC-3: `test-compression-applies-to-quick.sh`
   - SC-5: `test-tier-a-plus-classifier.sh`
   - SC-6: `test-tier-a-plus-flow.sh`
   - SC-7: `test-universal-entry-trivial.sh`
   - SC-8: `test-universal-entry-lowconf.sh`
   - SC-9: `doc-drift-verifier.sh`
   - SC-10: `test-auto-proceed-default.sh`
   - SC-11: `empirical-baseline.sh --compare`
   - SC-12: `scope-guard.sh`
   - SC-13: `verify-baseline-ordering.sh` (Option B only — see Notes)
   - SC-15: `test-quick-budget-median.sh`
   - SC-16: `test-tier-a-plus-prompt-ux.sh`
   - AD-9: `test-doctor-compound-change.sh`
   - AD-19: `test-budget-drift-warning.sh`

   N ≥ 15 under Option B (16 entries). N ≥ 14 under Option A (drop SC-13).

T04 ALSO ships three shape verifiers under `tools/verify/`:

- `m031-p04-test-scope-guard-shape.sh` — asserts the milestone-grain `tests/m031-acceptance/scope-guard.sh` exists, contains the SC-12 block-list literals, contains the carve-out logic.
- `m031-p04-battery-shape.sh` — asserts the battery aggregator exists, contains the `BATTERY:` envelope, references every required SC script.
- `m031-p04-evidence-ledger-shape.sh` — asserts [`.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) exists with the `BATTERY:` line + per-SC roll-up. **At T04 close this verifier may report fail** because T05 has not yet authored the evidence ledger; the verifier becomes load-bearing once T05 completes. T04 ships the verifier itself; T05 ships the artifact it gates.

## Steps

1. **Read `tests/m030-acceptance/run-acceptance-battery.sh`** with the `Read` tool. Note:
   - `set -uo pipefail` at the top.
   - `SCRIPT_DIR` / `PROJECT_ROOT` resolution.
   - `pass=0; fail=0` accumulators.
   - `run_sc()` helper accepting `(label, path)`, invoking `bash "$path"`, capturing rc, incrementing pass/fail, emitting `BATTERY-PASS:` or `BATTERY-FAIL:`.
   - 22 sequential `run_sc "<label>" "$PROJECT_ROOT/<path>"` calls.
   - Final `printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"` and `exit` based on `fail`.
   - AD-19 compliance: every gate invocation is a literal `run_sc` call, no loops over arrays, no compound chains.

2. **Read `tools/verify/m031-p03-scope-guard.sh`** with the `Read` tool. Note:
   - The block-list pattern matcher (`case "$path" in knowledge/*|scripts/cost/*|...`).
   - The MEM `hit_count`-only carve-out function (regex `^[+-]hit_count: [0-9]+$` on `knowledge/(conventions|lessons|patterns)/MEM*.md` paths).
   - The dual-prefix permissive carve-out (`.orchestrator/observability/*` + `.orchestrator/tier-a-plus/*`).
   - The allow-list block.
   - The final `SUMMARY:` line with `block_list_violations=K mem_hitcount_carveouts=L` fields.

3. **Read `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`** to determine whether SC-13 is Option A or Option B. The battery aggregator's sub-gate inventory depends on this.

4. **Author `tests/m031-acceptance/scope-guard.sh`** (≥ 80 lines, executable, POSIX-bash). Mirror the per-phase scope-guard shape with these adjustments:
   - **Allow-list**: aggregate every phase's "Files Likely Touched" surface. A reasonable starting set (the executor refines from the actual phase plans):

     ```
     # P00 surface
     tests/m031-acceptance/fixtures/empirical-baseline/...
     tests/m031-acceptance/empirical-baseline.sh
     tests/m031-acceptance/verify-baseline-ordering.sh
     # P01 surface
     scripts/dispatch/build-context.sh
     commands/dispatch.md
     templates/orchestrator-config-default.yml
     tests/m031-acceptance/test-quick-injects-knowledge.sh
     tests/m031-acceptance/test-build-context-profile.sh
     tests/m031-acceptance/test-compression-applies-to-quick.sh
     tests/m031-acceptance/test-quick-budget-median.sh
     tools/verify/m031-p01-*.sh
     # P02 surface
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
     tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
     tests/m031-acceptance/test-tier-a-plus-flow.sh
     tools/verify/m031-p02-*.sh
     # P03 surface
     commands/do.md
     scripts/intake/do-entry.sh
     tests/m031-acceptance/fixtures/do-entry-stub.sh
     tests/m031-acceptance/fixtures/do-entry-trivial-input.txt
     tests/m031-acceptance/fixtures/do-entry-lowconf-input.txt
     tests/m031-acceptance/test-universal-entry-trivial.sh
     tests/m031-acceptance/test-universal-entry-lowconf.sh
     tools/verify/m031-p03-*.sh
     # P04 surface (this phase)
     commands/evaluate.md
     references/tier-definitions.md
     CHANGELOG.md
     scripts/diagnostics/run-doctor.sh
     scripts/diagnostics/efficiency-footer.sh
     tests/m031-acceptance/doc-drift-verifier.sh
     tests/m031-acceptance/test-auto-proceed-default.sh
     tests/m031-acceptance/test-doctor-compound-change.sh
     tests/m031-acceptance/test-budget-drift-warning.sh
     tests/m031-acceptance/scope-guard.sh
     tests/m031-acceptance/run-acceptance-battery.sh
     [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md)
     tools/verify/m031-p04-*.sh
     # Phase/task plan / summary paths under .orchestrator/milestones/M031/
     ```

   - **Block-list**: verbatim from per-phase scope-guards: `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`.
   - **MEM hit_count-only carve-out**: copy verbatim.
   - **Dual-prefix permissive carve-out**: copy verbatim.
   - **Final SUMMARY line**: `RESULT: SC-12 pass` (acceptance-test envelope) AND `SUMMARY: scope-guard.sh pass=N fail=M block_list_violations=K mem_hitcount_carveouts=L` (compatibility envelope so the battery aggregator + phase-suite + downstream consumers see consistent shapes).
   - **POSIX-bash discipline** (CON-6 / DC-7): use `[ "$a" = "$b" ]` not `[[ ]]`; `printf` not `echo -e`; arithmetic via `$(( ... ))`; no `declare -A`.

   `chmod +x tests/m031-acceptance/scope-guard.sh`.

5. **Author `tests/m031-acceptance/run-acceptance-battery.sh`** (≥ 80 lines, executable, bash 3.2). Mirror the M030 battery shape exactly. Body shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m031-acceptance/run-acceptance-battery.sh
   # M031/P04/T04 — SC-14 acceptance battery runner.
   #
   # Invokes every M031 SC verifier in literal sequence. Mirrors the M030
   # convention at tests/m030-acceptance/run-acceptance-battery.sh.
   # AD-19 single-script-file shape: each verifier is invoked as
   # `bash <path>` with rc captured per-call; no compound chains, no
   # loops, no eval.
   #
   # Final stdout line: `BATTERY: pass=N fail=M`. Exits 0 iff fail=0.

   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   pass=0
   fail=0

   run_sc() {
     local label="$1"
     local path="$2"
     local extra="${3:-}"
     if [ -n "$extra" ]; then
       bash "$path" $extra
     else
       bash "$path"
     fi
     local rc=$?
     if [ "$rc" -eq 0 ]; then
       pass=$((pass + 1))
       printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
     else
       fail=$((fail + 1))
       printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
     fi
   }

   # ---------- P01 SCs ----------
   run_sc "SC-1"  "$PROJECT_ROOT/tests/m031-acceptance/test-quick-injects-knowledge.sh"
   run_sc "SC-2"  "$PROJECT_ROOT/tests/m031-acceptance/test-build-context-profile.sh"
   run_sc "SC-3"  "$PROJECT_ROOT/tests/m031-acceptance/test-compression-applies-to-quick.sh"

   # ---------- P02 SCs ----------
   run_sc "SC-5"  "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-classifier.sh"
   run_sc "SC-6"  "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-flow.sh"
   run_sc "SC-16" "$PROJECT_ROOT/tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh"

   # ---------- P03 SCs ----------
   run_sc "SC-7"  "$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-trivial.sh"
   run_sc "SC-8"  "$PROJECT_ROOT/tests/m031-acceptance/test-universal-entry-lowconf.sh"

   # ---------- P04 SCs ----------
   run_sc "SC-9"  "$PROJECT_ROOT/tests/m031-acceptance/doc-drift-verifier.sh"
   run_sc "SC-10" "$PROJECT_ROOT/tests/m031-acceptance/test-auto-proceed-default.sh"
   run_sc "SC-12" "$PROJECT_ROOT/tests/m031-acceptance/scope-guard.sh"
   run_sc "AD-9"  "$PROJECT_ROOT/tests/m031-acceptance/test-doctor-compound-change.sh"
   run_sc "AD-19" "$PROJECT_ROOT/tests/m031-acceptance/test-budget-drift-warning.sh"

   # ---------- P01 budget median + P00 baseline + ordering ----------
   run_sc "SC-15" "$PROJECT_ROOT/tests/m031-acceptance/test-quick-budget-median.sh"
   run_sc "SC-11" "$PROJECT_ROOT/tests/m031-acceptance/empirical-baseline.sh" "--compare"
   run_sc "SC-13" "$PROJECT_ROOT/tests/m031-acceptance/verify-baseline-ordering.sh"

   # ---------- Aggregate ----------
   printf 'BATTERY: pass=%s fail=%s\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
     exit 0
   fi
   exit 1
   ```

   Notes on the `run_sc` helper:
   - The `extra` third positional argument carries trailing flags (e.g. `--compare` for SC-11). The helper splits it via `$extra` (unquoted) — bash 3.2 word-splitting is acceptable here because the arguments are author-controlled, not user input.
   - SC-13 is included unconditionally in this template; if `SC13-OPTION.md` records Option A, the executor REMOVES the `run_sc "SC-13" ...` line entirely (do NOT comment it out, do NOT leave it dead). The aggregator then has 15 entries and N ≥ 14.

   Note on the `set -uo pipefail` line: `pipefail` is bash-specific (not strict POSIX). The battery aggregator is bash-only (matches the M030 precedent); the milestone-grain scope-guard at step 4 is POSIX-bash for portability.

   `chmod +x tests/m031-acceptance/run-acceptance-battery.sh`.

6. **Author `tools/verify/m031-p04-test-scope-guard-shape.sh`** (≥ 20 lines, executable). Asserts:
   - `check_present tests/m031-acceptance/scope-guard.sh "SC-12"`
   - `check_present tests/m031-acceptance/scope-guard.sh "knowledge/"`
   - `check_present tests/m031-acceptance/scope-guard.sh "scripts/cost"`
   - `check_present tests/m031-acceptance/scope-guard.sh "scripts/dispatch/adapters/router"`
   - `check_present tests/m031-acceptance/scope-guard.sh "scripts/auto/loop"`
   - `check_present tests/m031-acceptance/scope-guard.sh "block_list_violations"`
   - `check_present tests/m031-acceptance/scope-guard.sh ".orchestrator/observability"`
   - `check_present tests/m031-acceptance/scope-guard.sh ".orchestrator/tier-a-plus"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-test-scope-guard-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

7. **Author `tools/verify/m031-p04-battery-shape.sh`** (≥ 25 lines, executable). Asserts the battery aggregator references every required SC script:
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "BATTERY:"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-quick-injects-knowledge.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-tier-a-plus-flow.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-universal-entry-trivial.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "doc-drift-verifier.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-auto-proceed-default.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "scope-guard.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-doctor-compound-change.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-budget-drift-warning.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "empirical-baseline.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-quick-budget-median.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "test-tier-a-plus-prompt-ux.sh"`
   - `check_present tests/m031-acceptance/run-acceptance-battery.sh "run_sc"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-battery-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

8. **Author `tools/verify/m031-p04-evidence-ledger-shape.sh`** (≥ 20 lines, executable). Asserts the evidence ledger exists with required substrings (the ledger itself is authored by T05; this verifier shipped at T04 close becomes load-bearing once T05 completes):
   - `check_present [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) "BATTERY:"`
   - `check_present [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) "M031"`
   - `check_present [.orchestrator/milestones/M031/M031-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M031/M031-ACCEPTANCE-EVIDENCE.md) "SC-"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-evidence-ledger-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

   **At T04 close this verifier WILL FAIL** (the evidence ledger does not yet exist — T05 authors it). T04's local-confirmation step (#9 below) acknowledges this expected failure; the verifier becomes load-bearing at T05 close.

9. **Run the battery + scope-guard + shape verifiers locally to confirm exit 0**:

   ```bash
   bash tests/m031-acceptance/scope-guard.sh
   ```

   ```bash
   bash tests/m031-acceptance/run-acceptance-battery.sh
   ```

   ```bash
   bash tools/verify/m031-p04-test-scope-guard-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-battery-shape.sh
   ```

   The battery should report `BATTERY: pass=15 fail=0` (Option A) or `BATTERY: pass=16 fail=0` (Option B). If any sub-gate fails, the failure is one of:
   - **A T01–T03 deliverable is missing**: re-verify the upstream tasks shipped their artifacts.
   - **A pre-P04 SC script is missing or broken**: re-run that phase's plan-phase to re-verify the prior-phase deliverable.
   - **The milestone-grain scope-guard's allow-list is too narrow**: extend the allow-list to cover the missing path.

   The `m031-p04-evidence-ledger-shape.sh` verifier is EXPECTED TO FAIL at T04 close (the ledger does not yet exist). T05 ships the ledger.

10. **Commit T04 deliverables** via `git commit -F <message-file>`. Suggested commit subject: `M031/P04/T04: SC-12 milestone-grain scope-guard + SC-14 acceptance battery aggregator`.

## Must-Haves

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`tests/m031-acceptance/scope-guard.sh` (SC-12 milestone-grain) exists, is executable, and exits 0 against the M031 working-tree diff" (Truth #11; Check via `m031-p04-test-scope-guard-shape.sh`)
- "`tests/m031-acceptance/run-acceptance-battery.sh` (SC-14) exists, is executable, chains every prior-phase SC script and every P04 SC script ... emits a final `BATTERY: pass=N fail=M` line" (Truth #12; Check via `m031-p04-battery-shape.sh`)

## Verification

```bash
bash tests/m031-acceptance/scope-guard.sh
```

```bash
bash tests/m031-acceptance/run-acceptance-battery.sh
```

```bash
bash tools/verify/m031-p04-test-scope-guard-shape.sh
```

```bash
bash tools/verify/m031-p04-battery-shape.sh
```

## Notes

- The milestone-grain scope-guard at `tests/m031-acceptance/scope-guard.sh` and the phase-grain scope-guards at `tools/verify/m031-p0X-scope-guard.sh` are intentionally separate. The acceptance-test family (under `tests/`) is the operator-facing surface invoked by `run-acceptance-battery.sh`; the verifier family (under `tools/verify/`) is the internal phase-suite gate. Both share the same block-list + carve-out logic but operate at different scopes (whole-milestone vs single-phase).
- The `m031-p04-evidence-ledger-shape.sh` verifier authored at T04 step 8 is expected to fail at T04 close because T05 has not yet authored the ledger. T04 ships the verifier as part of the surface contract; T05 ships the artifact.
- The battery aggregator's order matters for diagnostic legibility: P01 SCs first (foundation), then P02 (Tier A+), then P03 (universal entry), then P04 (drift + comms + observability), then P00 baseline tail (SC-11 / SC-13). This mirrors the dependency order so a failing run reads top-to-bottom as a phase-by-phase report.
- SC-13 inclusion depends on the Option A vs B selection in `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`. The template above includes SC-13; the executor consults the option file and removes the line if Option A is active.
- The scope-guard's POSIX-bash discipline (CON-6) means it can run under M009 multi-runtime audit later without rewrite. The battery aggregator uses bash-specific `set -uo pipefail` matching the M030 precedent; this is an explicit choice (the battery is bash-only by design).
- **Real-app smoke test pending** (plan-time discipline rule 5): the battery exercises every gate against in-repo fixtures + working-tree state. Production confirmation that an operator running the battery on a fresh clone of a downstream consumer project sees the same green pass is the [M033](../../../../../milestones/M033/index.md) onboarding milestone's job; T04's gates confirm the contract surface in this repo.

## Inputs

### From Previous Tasks

- **T01**: `doc-drift-verifier.sh` (SC-9), `test-auto-proceed-default.sh` (SC-10). Battery chains both.
- **T02**: `test-doctor-compound-change.sh` (AD-9). Battery chains it.
- **T03**: `test-budget-drift-warning.sh` (AD-19). Battery chains it.

### From Previous Phases

- **P00**: `tests/m031-acceptance/empirical-baseline.sh` (SC-11), `tests/m031-acceptance/verify-baseline-ordering.sh` (SC-13), `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md` (Option A vs B selector).
- **P01**: `tests/m031-acceptance/test-quick-injects-knowledge.sh` (SC-1), `test-build-context-profile.sh` (SC-2), `test-compression-applies-to-quick.sh` (SC-3), `test-quick-budget-median.sh` (SC-15).
- **P02**: `tests/m031-acceptance/test-tier-a-plus-classifier.sh` (SC-5), `test-tier-a-plus-flow.sh` (SC-6), `test-tier-a-plus-prompt-ux.sh` (SC-16).
- **P03**: `tests/m031-acceptance/test-universal-entry-trivial.sh` (SC-7), `test-universal-entry-lowconf.sh` (SC-8).
- **Per-phase scope-guards**: `tools/verify/m031-p01-scope-guard.sh`, `m031-p02-scope-guard.sh`, `m031-p03-scope-guard.sh` — read for block-list + carve-out shape inheritance.

### From Disk (Pre-existing)

- `tests/m030-acceptance/run-acceptance-battery.sh` — read as the canonical battery-aggregator template.
- `tools/verify/m031-p03-do-md-shape.sh` — read as the canonical shape-verifier template.

## Constraints

- **Bash 3.2 compatibility** (MEM001) for the battery + shape verifiers.
- **POSIX-bash compatibility** (CON-6 / DC-7) for the milestone-grain `tests/m031-acceptance/scope-guard.sh` so M009 can extend without rewrite.
- **AD-19 single-script-file shape** for Truth `Check:` invocations and verifier internals. The battery's `run_sc` helper invokes each gate as a literal `bash <path>` line — no array loops, no compound chains.
- **No edits to T01 / T02 / T03 deliverables** in T04.
- **No edits to per-phase verifiers (`m031-p01-*.sh`, `m031-p02-*.sh`, `m031-p03-*.sh`)** in T04.
- **No edits to `scripts/intake/`, `scripts/dispatch/`, `commands/evaluate.md`, `commands/dispatch.md`, `commands/do.md`, `references/tier-definitions.md`, `templates/`, `CHANGELOG.md`, `scripts/diagnostics/`** in T04. T04 ships only new files under `tests/m031-acceptance/` and `tools/verify/`.
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T04 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. The milestone-grain scope-guard verifier itself MAY contain literal references to those paths (block-list patterns) — the carve-out logic distinguishes "literal pattern in source" from "actual diff touches the path."
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`. Operator-facing acceptance tests live under `tests/m031-acceptance/`.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`.

## Expected Output

After T04 completes:

1. `tests/m031-acceptance/scope-guard.sh` (≥ 80 lines, executable, POSIX-bash) — exits 0 with `RESULT: SC-12 pass` AND `SUMMARY: scope-guard.sh pass=N fail=0 block_list_violations=0`.
2. `tests/m031-acceptance/run-acceptance-battery.sh` (≥ 80 lines, executable, bash) — exits 0 with `BATTERY: pass=N fail=0` (N = 15 under Option A, N = 16 under Option B).
3. `tools/verify/m031-p04-test-scope-guard-shape.sh` (≥ 20 lines, executable) — exits 0 with `SUMMARY: m031-p04-test-scope-guard-shape.sh pass=N fail=0`.
4. `tools/verify/m031-p04-battery-shape.sh` (≥ 25 lines, executable) — exits 0 with `SUMMARY: m031-p04-battery-shape.sh pass=N fail=0`.
5. `tools/verify/m031-p04-evidence-ledger-shape.sh` (≥ 20 lines, executable) — at T04 close this verifier is expected to FAIL because T05 has not yet authored `M031-ACCEPTANCE-EVIDENCE.md`. The verifier is shipped as the surface contract; the artifact lands at T05.

T04 leaves the milestone-close gate stack ready: scope-guard green, battery green, evidence-ledger verifier waiting for its artifact. T05 picks up with the evidence ledger + the P04 phase-suite + the P04 phase-grain scope-guard.

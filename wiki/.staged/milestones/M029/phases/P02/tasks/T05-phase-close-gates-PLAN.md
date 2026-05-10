---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M029"
name: "P02 close gates: phase-suite aggregator + acceptance battery + readonly-invariant + scope-guard"
depends_on: ["T04"]
---

## Prerequisites

- All P02 deliverables T01–T04 are on disk and their individual verifiers exit 0:
  - T01: `references/cross-milestone-feature-shape.md` + `tools/verify/m029-p02-cross-milestone-shape-contract.sh`.
  - T02: `scripts/diagnostics/summarize-milestone.sh` + `tools/verify/m029-p02-summarize-milestone-shape.sh`.
  - T03: `scripts/diagnostics/render-position.sh` + `commands/where.md` + `tools/verify/m029-p02-render-position-shape.sh` + `tools/verify/m029-p02-where-skill-shape.sh`.
  - T04: fixtures + acceptance scripts + the six T04 shape verifiers (`m029-p02-sc5-fixtures-shape.sh`, `m029-p02-sentinel-harness-shape.sh`, `m029-p02-sc{5,6,13,14}-shape.sh`).
- The P01 phase-suite aggregator at `tools/verify/m029-p01-phase-suite.sh` is on disk as the structural precedent.
- The P01 acceptance battery at `tests/m029-acceptance/p01-acceptance-battery.sh` is on disk as the battery-pattern precedent.
- The P01 readonly-invariant verifier at `tools/verify/m029-p01-readonly-invariant.sh` is on disk as the SC-14-precursor pattern; T05 ships the P02 counterpart.
- The P01 scope-guard at `tools/verify/m029-p01-scope-guard.sh` is on disk as the porcelain-classification pattern.
- No file currently lives at `tests/m029-acceptance/p02-acceptance-battery.sh`, `tools/verify/m029-p02-acceptance-battery-shape.sh`, `tools/verify/m029-p02-readonly-invariant.sh`, `tools/verify/m029-p02-scope-guard.sh`, or `tools/verify/m029-p02-phase-suite.sh` (path-collision rule 6 already checked at plan-authoring time — all clean).

## Description

T05 ships the **P02 close-gate scaffolding** — the four artifacts that mirror P01's close-gate slice (T06 of P01) but enforce P02's surfaces:

1. **`tests/m029-acceptance/p02-acceptance-battery.sh`** — wraps the four P02 SC acceptance scripts (SC-5, SC-6, SC-13, SC-14) and emits `BATTERY: pass=N fail=M` per the M030/[M031](../../../../../milestones/M031/index.md) acceptance-battery convention. Re-used by `validate-milestone.sh M029` (P03 deliverable) alongside the P01 + P03 batteries.

2. **`tools/verify/m029-p02-readonly-invariant.sh`** — extends the P01 sentinel-file precursor pattern (`m029-p01-readonly-invariant.sh`) to cover P02's render-position surface. Differs from the SC-14 acceptance script (which uses the AD-9 sentinel harness against the FIXTURE tree) by running against the LIVE project tree as a phase-close advisory; failures here surface drift introduced by P02 itself before close.

3. **`tools/verify/m029-p02-scope-guard.sh`** — enumerates `git status --porcelain=v1` output and classifies each touched path against the `## Files Likely Touched` declaration in `P02-PLAN.md`. Allowed paths are documented in the plan; denylisted paths (anywhere outside the declared scope) FAIL; unclassified paths emit `WARN:` (advisory only, not a hard fail). Mirrors `m029-p01-scope-guard.sh`.

4. **`tools/verify/m029-p02-phase-suite.sh`** — the canonical P02 close gate. Aggregates every P02 verifier in dependency order:
   - T01 gates: cross-milestone-shape-contract.
   - T02 gates: summarize-milestone-shape.
   - T03 gates: render-position-shape, where-skill-shape.
   - T04 gates: sc5-fixtures-shape, sentinel-harness-shape, sc5-shape, sc6-shape, sc13-shape, sc14-shape.
   - T05 gates: acceptance-battery-shape, readonly-invariant, scope-guard.

   Emits `OK:` / `FAIL:` per gate + final `SUMMARY: m029-p02-phase-suite.sh pass=N fail=M`. Exit 0 iff `fail=0`. Mirrors `m029-p01-phase-suite.sh`.

A fifth verifier — `tools/verify/m029-p02-acceptance-battery-shape.sh` — asserts the battery script itself has the right shape and that `BATTERY: pass=N fail=0` is the canonical exit line. This is the SHAPE check on the battery (as opposed to a behavioral run, which the phase-suite handles).

Total P02 phase-suite gate count: **13** (T01:1 + T02:1 + T03:2 + T04:6 + T05:3 = 13).

## Steps

1. **Author `tests/m029-acceptance/p02-acceptance-battery.sh`** (≥20 lines, executable, AD-19 single-script-file shape, bash 3.2). The battery:

   ```bash
   #!/usr/bin/env bash
   # tests/m029-acceptance/p02-acceptance-battery.sh
   # M029 / P02 acceptance battery — wraps the four P02 SC acceptance scripts.
   #
   # SC coverage: SC-5 (where mixed-state golden), SC-6 (pre-[M019](../../../../../milestones/M019/index.md) cost suppression),
   # SC-13 (anti-coupling guard), SC-14 (sentinel-file read-only invariant).
   #
   # Re-used by validate-milestone.sh M029 alongside the P01 + P03 batteries.
   # Mirrors tests/m029-acceptance/p01-acceptance-battery.sh.
   #
   # Bash 3.2 / MEM001. AD-19 straight-line bash.
   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   bash tests/m029-acceptance/p02-sc5-where-mixed-state.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-5\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-5\n'; fi

   bash tests/m029-acceptance/p02-sc6-where-pre-m019.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-6\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-6\n'; fi

   bash tests/m029-acceptance/p02-sc13-anti-coupling.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-13\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-13\n'; fi

   bash tests/m029-acceptance/p02-sc14-readonly.sh
   if [ $? -eq 0 ]; then pass=$(( pass + 1 )); printf 'OK: SC-14\n'; else fail=$(( fail + 1 )); printf 'FAIL: SC-14\n'; fi

   printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   `chmod +x`.

2. **Author `tools/verify/m029-p02-acceptance-battery-shape.sh`** (≥25 lines, executable, AD-19):
   - Asserts `[ -x tests/m029-acceptance/p02-acceptance-battery.sh ]`.
   - Asserts the script references each SC acceptance script: `p02-sc5-where-mixed-state.sh`, `p02-sc6-where-pre-m019.sh`, `p02-sc13-anti-coupling.sh`, `p02-sc14-readonly.sh`.
   - Asserts the canonical `BATTERY: pass=` literal appears.
   - Asserts the bash 3.2 token (`Bash 3.2` or `MEM001`) appears.
   - Asserts AD-19 token appears.
   - **Behavioral run**: invokes the battery and asserts it exits 0 with `BATTERY: pass=4 fail=0`. (This is load-bearing — it confirms every T01–T04 deliverable is actually green end-to-end.)
   - Emits `PASS:` per assertion + `SUMMARY: m029-p02-acceptance-battery-shape.sh pass=N fail=M`.

3. **Author `tools/verify/m029-p02-readonly-invariant.sh`** (≥30 lines, executable, AD-19, bash 3.2). Pattern after `m029-p01-readonly-invariant.sh`:
   - Writes a sentinel under `${TMPDIR:-/tmp}/m029-p02-readonly.$$.sentinel`.
   - Captures the sentinel's mtime via `stat`.
   - Invokes the P02 surfaces under test: a smoke run of `bash scripts/diagnostics/render-position.sh --milestone M029 > /dev/null` (against the live project tree) and a smoke run of `bash scripts/diagnostics/summarize-milestone.sh --milestone M029 --format=keys > /dev/null`.
   - Uses `find .orchestrator -type f -newer "$SENTINEL_FILE" ! -path '...'` to scan for any `.orchestrator/` file newer than the sentinel was when the smoke runs started. (The sentinel itself lives under `/tmp/`, NOT under `.orchestrator/` — this verifier is the project-tree variant, distinct from the SC-14 acceptance script which uses the in-tree sentinel against the FIXTURE.)
   - Asserts no offenders. `PASS: P02 read-only invariant held` on success; `FAIL:` per offender on failure.
   - Emits `SUMMARY: m029-p02-readonly-invariant.sh pass=N fail=M`. Exit 0 iff `fail=0`.

4. **Author `tools/verify/m029-p02-scope-guard.sh`** (≥40 lines, executable, AD-19, bash 3.2). Pattern after `m029-p01-scope-guard.sh`:
   - Captures `git status --porcelain=v1` output to `${TMPDIR:-/tmp}/m029-p02-scope.$$.list` via straight redirection.
   - Defines the **allowlist** (paths the P02 plan declares as `Files Likely Touched`):
     - `references/cross-milestone-feature-shape.md`
     - `scripts/diagnostics/summarize-milestone.sh`
     - `scripts/diagnostics/render-position.sh`
     - `commands/where.md`
     - `tests/m029-acceptance/fixtures/where-mixed-state.golden`
     - `tests/m029-acceptance/fixtures/where-mixed-state.fixture/...` (recursive)
     - `tests/m029-acceptance/fixtures/where-pre-m019.fixture/...` (recursive)
     - `tests/m029-acceptance/timestamp-strip.sh`
     - `tests/m029-acceptance/sentinel-harness.sh`
     - `tests/m029-acceptance/p02-sc{5,6,13,14}-*.sh`
     - `tests/m029-acceptance/p02-acceptance-battery.sh`
     - `tools/verify/m029-p02-*.sh`
     - `.orchestrator/milestones/M029/phases/P02/...` (plan/summary churn)
   - Defines the **denylist** (paths that must NEVER be touched by P02):
     - `commands/auto.md`, `commands/init.md`, `commands/dispatch.md` (M031/[M033](../../../../../milestones/M033/index.md) surfaces)
     - `scripts/lifecycle/auto-loop.sh` (Principle XV — M029 does not touch the auto loop)
     - `scripts/diagnostics/metrics-rollup.sh`, `scripts/diagnostics/efficiency-footer.sh`, `scripts/dispatch/predictive-surface.sh` ([M027](../../../../../milestones/M027/index.md) read-only consumer; CON-7 / AD-8)
     - `.orchestrator/integrations/github.json` (CON-4 / FR-11)
     - [`.orchestrator/KNOWLEDGE.md`](../../../../../knowledge.md), [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) ([M020](../../../../../milestones/M020/index.md) schema authority; CON-7)
   - Iterates each porcelain line; classifies as allow / deny / unclassified.
   - On any deny hit: `FAIL: scope violation by <path>`.
   - On unclassified: `WARN: unclassified path <path>` (advisory; not a hard fail per P01 precedent).
   - On allow only: `PASS: scope discipline held`.
   - Emits SUMMARY. Exit 0 iff no deny hits.

5. **Author `tools/verify/m029-p02-phase-suite.sh`** (≥80 lines, executable, AD-19 straight-line, bash 3.2). Pattern after `m029-p01-phase-suite.sh`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m029-p02-phase-suite.sh -- M029 P02 phase-close gate suite.
   #
   # Aggregates every P02 verifier from T01..T05 of the roadmap-visibility &
   # CLI-UX milestone (M029). validate-milestone.sh M029 (P03 deliverable)
   # consumes this suite alongside the P01 and P03 phase-suites.
   #
   # Sub-gates (in dependency order):
   #
   #   T01 -- cross-milestone data model:
   #     1. m029-p02-cross-milestone-shape-contract.sh
   #
   #   T02 -- summarize-milestone helper:
   #     2. m029-p02-summarize-milestone-shape.sh
   #
   #   T03 -- render-position + where skill:
   #     3. m029-p02-render-position-shape.sh
   #     4. m029-p02-where-skill-shape.sh
   #
   #   T04 -- fixtures + SC acceptance:
   #     5. m029-p02-sc5-fixtures-shape.sh
   #     6. m029-p02-sentinel-harness-shape.sh
   #     7. m029-p02-sc5-shape.sh
   #     8. m029-p02-sc6-shape.sh
   #     9. m029-p02-sc13-shape.sh
   #    10. m029-p02-sc14-shape.sh
   #
   #   T05 -- close gates:
   #    11. m029-p02-acceptance-battery-shape.sh
   #    12. m029-p02-readonly-invariant.sh
   #    13. m029-p02-scope-guard.sh
   #
   # Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
   # the suite emits a single aggregate SUMMARY at the end and exits 0 iff
   # every sub-gate exits 0.
   #
   # Bash 3.2 / MEM001. AD-19 straight-line bash. Mirrors m029-p01-phase-suite.sh.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

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
           printf 'FAIL: %s\n' "$name"
       fi
   }

   # ---------- T01 Gate 1: cross-milestone-shape-contract ----------
   bash tools/verify/m029-p02-cross-milestone-shape-contract.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-cross-milestone-shape-contract.sh"

   # ---------- T02 Gate 2: summarize-milestone-shape ----------
   bash tools/verify/m029-p02-summarize-milestone-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-summarize-milestone-shape.sh"

   # ---------- T03 Gate 3: render-position-shape ----------
   bash tools/verify/m029-p02-render-position-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-render-position-shape.sh"

   # ---------- T03 Gate 4: where-skill-shape ----------
   bash tools/verify/m029-p02-where-skill-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-where-skill-shape.sh"

   # ---------- T04 Gate 5: sc5-fixtures-shape ----------
   bash tools/verify/m029-p02-sc5-fixtures-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-sc5-fixtures-shape.sh"

   # ---------- T04 Gate 6: sentinel-harness-shape ----------
   bash tools/verify/m029-p02-sentinel-harness-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-sentinel-harness-shape.sh"

   # ---------- T04 Gate 7: sc5-shape ----------
   bash tools/verify/m029-p02-sc5-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-sc5-shape.sh"

   # ---------- T04 Gate 8: sc6-shape ----------
   bash tools/verify/m029-p02-sc6-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-sc6-shape.sh"

   # ---------- T04 Gate 9: sc13-shape ----------
   bash tools/verify/m029-p02-sc13-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-sc13-shape.sh"

   # ---------- T04 Gate 10: sc14-shape ----------
   bash tools/verify/m029-p02-sc14-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-sc14-shape.sh"

   # ---------- T05 Gate 11: acceptance-battery-shape ----------
   bash tools/verify/m029-p02-acceptance-battery-shape.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-acceptance-battery-shape.sh"

   # ---------- T05 Gate 12: readonly-invariant ----------
   bash tools/verify/m029-p02-readonly-invariant.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-readonly-invariant.sh"

   # ---------- T05 Gate 13: scope-guard ----------
   bash tools/verify/m029-p02-scope-guard.sh
   rc=$?
   emit_gate_result "$rc" "m029-p02-scope-guard.sh"

   # ---------- Aggregate summary ----------
   printf 'SUMMARY: m029-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

6. **`chmod +x` every new `.sh` file**.

7. **Run the phase-suite** — should exit 0 with `SUMMARY: m029-p02-phase-suite.sh pass=13 fail=0` after T05 completes. This is the canonical "P02 is done" signal.

## Must-Haves

This task addresses these P02 phase truths:
- The P02 phase-suite aggregator chains all P02 gate verifiers and emits `SUMMARY: m029-p02-phase-suite.sh pass=N fail=0` on success.

This task creates these P02 phase artifacts:
- P02 acceptance battery at `tests/m029-acceptance/p02-acceptance-battery.sh` — wraps SC-5/SC-6/SC-13/SC-14 acceptance scripts and emits `BATTERY: pass=N fail=M`.
- Battery shape verifier at `tools/verify/m029-p02-acceptance-battery-shape.sh` — mechanical battery-shape + behavioral end-to-end check.
- Read-only invariant verifier at `tools/verify/m029-p02-readonly-invariant.sh` — project-tree sentinel-file scan around P02 surfaces.
- Scope-guard verifier at `tools/verify/m029-p02-scope-guard.sh` — allowlist/denylist + WARN-on-unclassified classification of `git status --porcelain=v1`.
- P02 phase-suite aggregator at `tools/verify/m029-p02-phase-suite.sh` — 13-gate close gate.

## Verification

```bash
bash tools/verify/m029-p02-phase-suite.sh
```

## Inputs

### From Previous Tasks

- All T01–T04 verifiers (full list above in Description).
  - Key API: each verifier emits `SUMMARY: <name> pass=N fail=M` to stdout and exits 0 iff `fail=0`.
  - Behavioral contract: invocation from project root (`cd $PROJECT_ROOT; bash tools/verify/<name>`); no env-var dependencies; no positional args.
- Acceptance scripts under `tests/m029-acceptance/p02-sc{5,6,13,14}-*.sh` (from T04).
  - Key API: each emits `SUMMARY: <name> pass=N fail=0` and exits 0 on full SC pass.

### From Disk (Pre-existing)

- `tools/verify/m029-p01-phase-suite.sh` — structural precedent for the phase-suite aggregator.
- `tests/m029-acceptance/p01-acceptance-battery.sh` — battery-pattern precedent.
- `tools/verify/m029-p01-readonly-invariant.sh` — sentinel-file precursor pattern (T05 mirrors).
- `tools/verify/m029-p01-scope-guard.sh` — porcelain-classification precedent.
- `tools/verify/m031-p00-phase-suite.sh` — outer milestone precedent for the aggregator shape.

## Constraints

- **AD-19 straight-line bash**: every verifier MUST be straight-line (NO inline compound chains, NO plain subshells, NO `$(cmd | …)`, NO process substitution). The phase-suite aggregator pattern is `bash <verifier>; rc=$?; emit_gate_result "$rc" <name>` per gate — exactly the P01 precedent.
- **Bash 3.2 (MEM001)**: NO `declare -A`, NO `<<<` herestring, parallel indexed arrays for any per-item tracking.
- **Read-only verifier discipline**: `m029-p02-readonly-invariant.sh` writes its sentinel under `${TMPDIR:-/tmp}/` (run-probe.sh scope rule 4 domain), NOT under `.orchestrator/`.
- **Scope-guard advisory**: `WARN:` for unclassified paths, FAIL only for denylist hits. P01 precedent stands.
- **Per CON-7 + AD-8**: T05 introduces NO new schemas. The new `tests/m029-acceptance/*.sh` and `tools/verify/m029-p02-*.sh` files are the only artifacts.
- **Path-collision rule 6**: every artifact path checked at plan-authoring time — all clean.

## Expected Output

After T05 completes:
- `tests/m029-acceptance/p02-acceptance-battery.sh` exists, executable, exits 0 with `BATTERY: pass=4 fail=0`.
- `tools/verify/m029-p02-acceptance-battery-shape.sh` exists, executable, exits 0.
- `tools/verify/m029-p02-readonly-invariant.sh` exists, executable, exits 0.
- `tools/verify/m029-p02-scope-guard.sh` exists, executable, exits 0 (or with `WARN:` advisories only).
- `tools/verify/m029-p02-phase-suite.sh` exists, executable, exits 0 with `SUMMARY: m029-p02-phase-suite.sh pass=13 fail=0`.
- A summary file at [`.orchestrator/milestones/M029/phases/P02/tasks/T05-phase-close-gates-SUMMARY.md`](../../../../../milestones/M029/phases/P02/tasks/T05-phase-close-gates-SUMMARY.md) documents the deliverables.

## Notes

Expected phase-suite output:
```
OK: m029-p02-cross-milestone-shape-contract.sh
OK: m029-p02-summarize-milestone-shape.sh
OK: m029-p02-render-position-shape.sh
OK: m029-p02-where-skill-shape.sh
OK: m029-p02-sc5-fixtures-shape.sh
OK: m029-p02-sentinel-harness-shape.sh
OK: m029-p02-sc5-shape.sh
OK: m029-p02-sc6-shape.sh
OK: m029-p02-sc13-shape.sh
OK: m029-p02-sc14-shape.sh
OK: m029-p02-acceptance-battery-shape.sh
OK: m029-p02-readonly-invariant.sh
OK: m029-p02-scope-guard.sh
SUMMARY: m029-p02-phase-suite.sh pass=13 fail=0
```

`validate-milestone.sh M029` (P03 deliverable) chains the P01 phase-suite (14 gates) + the P02 phase-suite (13 gates) + the P03 phase-suite (TBD count) + the full SC-1..SC-14 acceptance battery. P02's contribution to the milestone validator is exactly the 13 gates above plus the 4 SC battery hits.

Why scope-guard runs as a phase-close gate (not a phase-entry gate): scope-guard reads `git status --porcelain=v1`, which only has signal AFTER deliverables land. Running it at phase entry would always pass trivially. P01 established the close-gate placement; P02 mirrors.

Why readonly-invariant runs against the LIVE project tree (not the fixture): SC-14 (T04's acceptance script) tests the renderer's read-only invariant against the FIXTURE tree as part of the acceptance battery. T05's `m029-p02-readonly-invariant.sh` complements that by running the renderer against the LIVE tree to catch any leak that only surfaces under real disk shapes (e.g., if `render-position.sh` accidentally writes a `.lock` file under `.orchestrator/` because of a race). The two checks are diagnostic-distinct, not redundant.

Future maintainers extending P02 with additional gates MUST update both the gate count in the phase-suite header comment AND the expected count in this task plan's expected output. The P01 precedent flagged this convention explicitly.

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P00"
milestone: "M027"
name: "phase-suite orchestrator (m027-rollup-schema.sh) + demo wiring"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `scripts/diagnostics/metrics-rollup.sh` (engine).
- T02 has shipped `tests/fixtures/m027-p00/` (fixture suite).
- T03 has shipped fourteen per-contract verifiers under `scripts/verify/m027-p00-*.sh`, each green against the T01+T02 substrate.
- Convention reference: `scripts/verify/m019-p01-phase-suite.sh` orchestrates eight M019/P01 gates and exits 0 on green; M027/P00 follows the same shape at larger scale (fourteen gates).

## Description

Ship `scripts/verify/m027-rollup-schema.sh` — the FR-15 / SC-2 phase-suite entry point. It runs every `m027-p00-*.sh` verifier in a fixed order and aggregates results. On green it exits 0 with a `PASS: m027-rollup-schema.sh <N> gates` line on stdout; on red it exits 1 with a `FAIL` line per failing gate. Also responsible for the demo wiring: the live-[M019](../../../../milestones/M019/index.md) row invocation that the phase's demo sentence asserts.

## Steps

1. **Create `scripts/verify/m027-rollup-schema.sh`**:
   - `#!/usr/bin/env bash` + `set -u`.
   - Resolve `PROJECT_ROOT` via `BASH_SOURCE`.
   - Define `GATES` as a plain-string list (parallel arrays, bash 3.2 safe) covering every per-contract verifier in dependency-friendly order (cheapest first, slowest last):
     1. `m027-p00-bash32-compat.sh`
     2. `m027-p00-zero-llm-token.sh`
     3. `m027-p00-rollup-cli-contract.sh`
     4. `m027-p00-input-schema.sh`
     5. `m027-p00-corrupt-line.sh`
     6. `m027-p00-pricing-warning.sh`
     7. `m027-p00-source-filter.sh`
     8. `m027-p00-aggregation-precedence.sh`
     9. `m027-p00-goodhart-pairing.sh`
     10. `m027-p00-pre-m019-additivity.sh`
     11. `m027-p00-fs-race.sh`
     12. `m027-p00-read-only.sh`
     13. `m027-p00-live-m019-row.sh`
     14. `m027-p00-perf-bound.sh` (last — most expensive)
   - For each gate: `bash "$PROJECT_ROOT/scripts/verify/$gate"`. Capture exit code. Maintain a `failed_gates` accumulator.
   - On green (all gates exit 0): print `PASS: m027-rollup-schema.sh 14 gates` to stdout, exit 0.
   - On red: print `FAIL: m027-rollup-schema.sh <N> failing gates: <space-separated names>` to stderr, exit 1.
   - Special-case: a `RELAX-CANDIDATE` annotation from `m027-p00-perf-bound.sh` is treated as a soft failure — the suite still exits 1 (the bound is not met) but the structured `RELAX-CANDIDATE` line is preserved on stdout so plan-phase / consolidate can act on it.

2. **`chmod +x scripts/verify/m027-rollup-schema.sh`**.

3. **Verify the live-row demo** — run `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` and capture stdout. The phase-summary at consolidate time will paste the resulting row into `P00-SUMMARY.md` as the demo evidence; this task just confirms the live invocation is green and emits the expected paired row.

4. **No new files outside the verifier set**. T04 does not edit the engine, the fixtures, or the per-contract verifiers — those are owned by T01, T02, and T03 respectively. T04 only orchestrates.

## Must-Haves

- File `scripts/verify/m027-rollup-schema.sh` exists, is executable, ≥ 30 lines, contains the literal string `m027-p00`.
- Running `bash scripts/verify/m027-rollup-schema.sh` exits 0 on green; exits 1 on red.
- On green the suite prints `PASS: m027-rollup-schema.sh 14 gates` (or with the actual gate count) to stdout.
- On red the suite prints `FAIL: m027-rollup-schema.sh ...` to stderr with one line per failing gate.
- The suite invokes every `m027-p00-*.sh` verifier from T03 (14 total).
- bash 3.2 compatible.
- The live-M019 demo invocation (`bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019`) exits 0 against this repo and prints a paired cost+quality milestone row.

## Verification

```bash
bash scripts/verify/m027-rollup-schema.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P00
bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019
```

The phase-suite must exit 0 with a PASS line on stdout. The phase-level must-haves check must exit 0 with all P00 must-haves green. The live demo must exit 0 with one paired cost+quality row on stdout. The `git diff --quiet` read-only invariant is exercised inside `m027-p00-read-only.sh`, which is part of the phase-suite — running it again here would conflict with this PLAN file's own in-flight edits.

## Inputs

### From Previous Tasks

- `scripts/diagnostics/metrics-rollup.sh` (from T01) — the engine being verified.
- `tests/fixtures/m027-p00/` (from T02) — fixture inputs to the per-contract verifiers.
- `scripts/verify/m027-p00-*.sh` (from T03) — the fourteen per-contract verifiers this task orchestrates.
  - Key API: each verifier exits 0 on green, 1 on red, 2 on misuse; emits PASS/FAIL line.
  - Behavioral contract: each verifier is read-only, hermetic, deterministic; cleans up its own scratch state.

### From Disk (Pre-existing)

- `scripts/verify/m019-p01-phase-suite.sh` — convention reference for phase-suite orchestrator shape.

## Constraints

- **AD-19 (script-file shape)**: the phase-plan `Check:` for the phase-suite gate is exactly `bash scripts/verify/m027-rollup-schema.sh` — single-script-file invocation. Internally, MEM004 emitter-internal carve-out permits the suite to use a `for gate in $GATES; do ...; done` loop and per-gate `$?` capture.
- **CON-7 (bash 3.2)**: parallel indexed arrays only; no `declare -A`. The suite itself is itself subject to the `m027-p00-bash32-compat.sh` gate it orchestrates.
- **CON-1 / FR-12 (read-only)**: the suite must not modify any tracked file. End-to-end `git diff --quiet` invariant covers this.
- **Stable gate order**: the gate list is fixed; reordering is a code change reviewed in a follow-up. Cheapest gates run first so failures surface fast; the perf-bound gate runs last.
- **Soft-failure surface**: `RELAX-CANDIDATE` from the perf gate is not silenced — the suite forwards it to its own stdout so plan-phase can act on it.
- **No regressions on M019 / earlier milestones**: the live-row demo runs against the live `.orchestrator/milestones/M019/execution-log.jsonl`. If that file does not contain valid M019 records, the live-row gate emits `SKIP` (per T03's `m027-p00-live-m019-row.sh` graceful-skip clause); the suite still passes provided every other gate is green. The `live-row` SKIP is acceptable for fresh clones; M019 dogfooding will populate the log over time.

## Expected Output

After this task:

1. `scripts/verify/m027-rollup-schema.sh` exists, ≥ 30 lines, executable, bash 3.2 compatible.
2. `bash scripts/verify/m027-rollup-schema.sh` exits 0 against the T01 engine + T02 fixtures + T03 verifiers; stdout contains the structured PASS line.
3. `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` exits 0 against this repo and prints one paired cost+quality row — the demo sentence is satisfied.
4. P00 phase-plan must-haves all pass under `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P00`.
5. Phase is ready for `orchestrator:verify` and consolidation; the SUMMARY will paste the live-row stdout and the suite PASS line as evidence.

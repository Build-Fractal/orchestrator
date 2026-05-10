---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P01"
milestone: "M029"
name: "P01 acceptance battery + phase-suite + scope-guard + read-only invariant verifier"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- T01..T05 have completed: every artifact named in the P01 plan's "Files Likely Touched" list exists on disk except the T06 deliverables. Verify with:
  - `[ -f references/status-headline-shape.md ]`
  - `[ -f references/status-json-schema.md ]`
  - `[ -f scripts/state/detect-invocation-context.sh ]`
  - `[ -f scripts/diagnostics/render-status-json.sh ]`
  - `[ -f commands/status.md ]` (modified additively in T03 + T04)
  - `[ -f commands/context.md ]`
  - `[ -f tests/m029-acceptance/p01-sc1-resolver.sh ]`
  - `[ -f tests/m029-acceptance/p01-sc2-headline.sh ]`
  - `[ -f tests/m029-acceptance/p01-sc3-format-json.sh ]`
  - `[ -f tests/m029-acceptance/p01-sc4-context.sh ]`
  - All twelve `tools/verify/m029-p01-*.sh` from T01..T05 exist.
- All upstream verifiers exit 0: T06 begins with the assumption that every upstream task's verifiers are green. If any upstream verifier is red, T06 cannot complete (the phase-suite aggregator will surface the upstream red).

## Description

T06 ships the **P01 close gate** — three new verifiers + the acceptance battery wrapper that aggregates the four SC scripts:

1. `tests/m029-acceptance/p01-acceptance-battery.sh` — chains the four SC scripts (`p01-sc1-resolver.sh`, `p01-sc2-headline.sh`, `p01-sc3-format-json.sh`, `p01-sc4-context.sh`) in dependency order. Emits `BATTERY: p01-acceptance pass=N fail=M` and exits 0 iff every SC script exits 0.

2. `tools/verify/m029-p01-acceptance-battery-shape.sh` — shape verifier for the battery wrapper.

3. `tools/verify/m029-p01-readonly-invariant.sh` — runs each P01 surface against a fixture under a sentinel-file mtime guard and asserts no `.orchestrator/` mutation. P01 precursor to the AD-9 / SC-14 mechanism (full SC-14 lands in P02).

4. `tools/verify/m029-p01-scope-guard.sh` — greps the staged diff for any out-of-claim path; FAILs if any P02/P03 deliverable, M013/M019/M020/[M027](../../../../../milestones/M027/index.md) surface, or other framework file outside the P01 Files Likely Touched list is touched.

5. `tools/verify/m029-p01-phase-suite.sh` — the P01 close-gate aggregator. Chains every P01 verifier in dependency order (T01 contracts → T02 resolver → T03 headline → T04 JSON renderer → T05 context skill → T06 battery + invariants + scope-guard) and emits `SUMMARY: m029-p01-phase-suite.sh pass=N fail=M`. Exit 0 iff every sub-gate passes.

The phase-suite is the canonical "P01 is done" gate. `validate-milestone.sh M029` will eventually consume this suite (in P03's milestone-close path) along with the M029 acceptance battery; for P01 in isolation, this suite stands as the close criterion.

## Steps

1. **Author `tests/m029-acceptance/p01-acceptance-battery.sh`** (≥30 lines, executable). Required structure:

   - Shebang `#!/usr/bin/env bash` + `set -u`.
   - Header comment naming SC-11 (M029 acceptance battery — the P01 slice; full battery `tests/m029-acceptance/run-acceptance-battery.sh` lands in P03 covering all 14 SCs).
   - `pass=0`, `fail=0` counters.
   - Function `_run_sc()` accepting a label + script path, runs the script, increments counters, prints `OK: <label>` / `FAIL: <label>`.
   - Linear (non-loop) invocations of the four SC scripts in dependency order:
     1. `bash tests/m029-acceptance/p01-sc1-resolver.sh` (SC-1)
     2. `bash tests/m029-acceptance/p01-sc2-headline.sh` (SC-2)
     3. `bash tests/m029-acceptance/p01-sc3-format-json.sh` (SC-3)
     4. `bash tests/m029-acceptance/p01-sc4-context.sh` (SC-4)
     The straight-line invocation pattern (per AD-19) — no `for` loops over arrays — mirrors `tools/verify/m031-p00-phase-suite.sh`.
   - Final `printf 'BATTERY: p01-acceptance pass=%d fail=%d\n' "$pass" "$fail"`.
   - Exit 0 iff `fail=0`; exit 1 otherwise.

2. **Author `tools/verify/m029-p01-acceptance-battery-shape.sh`** (≥25 lines, executable). The verifier:

   - Gates on `[ -f tests/m029-acceptance/p01-acceptance-battery.sh ]`.
   - Asserts the battery script is executable.
   - Asserts the battery script's body invokes all four SC scripts (greps for `p01-sc1-resolver.sh`, `p01-sc2-headline.sh`, `p01-sc3-format-json.sh`, `p01-sc4-context.sh`).
   - Asserts the battery emits `BATTERY:` (greps for the literal token).
   - Runs `bash tests/m029-acceptance/p01-acceptance-battery.sh` and asserts exit 0 + stdout contains `BATTERY: p01-acceptance pass=` + does NOT contain `fail=` followed by a non-zero digit.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-acceptance-battery-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

3. **Author `tools/verify/m029-p01-readonly-invariant.sh`** (≥35 lines, executable). The verifier:

   - Creates a working temp dir via `mktemp -d`. Sets up a minimal fixture (copies the SC-2 fixture, or constructs a minimal `.orchestrator/` shape inline).
   - Writes a sentinel file at `<tmpdir>/orch-root/.orchestrator/.m029-p01-sentinel` with the current ISO-8601 timestamp BEFORE any P01 surface runs. Uses `printf 'sentinel created %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > <sentinel-path>`.
   - Runs each P01 surface against the fixture in turn:
     - `bash scripts/state/detect-invocation-context.sh --tty=true --ci=false` (resolver — should not write)
     - `bash scripts/diagnostics/render-status-json.sh --orchestrator-root <fixture-root>` (JSON renderer — should not write)
     - The `commands/context.md` skill invocation (mock-invoked via the same script chain `commands/context.md` would drive — pragmatically, invoke `bash scripts/state/resolve-root.sh` + `bash scripts/state/find-active-milestone.sh` + the resolver; this approximates the skill's read pattern without requiring the harness)
     - The `commands/status.md` headline path (similar — invoke `bash scripts/state/derive-phase.sh`, `bash scripts/state/read-roadmap.sh`, etc.)
   - After each surface runs, asserts no file under `<tmpdir>/orch-root/.orchestrator/` has mtime newer than the sentinel (excluding the sentinel itself). Implementation: `find <tmpdir>/orch-root/.orchestrator/ -newer <sentinel-path> -not -path '*/.m029-p01-sentinel'`. Output of this find MUST be empty; non-empty output is a violation.
   - On any violation, prints the violating file paths to stderr and FAIL.
   - Cleanup `rm -rf <tmpdir>` on exit (trap).
   - Emits `PASS:` per surface + `SUMMARY: m029-p01-readonly-invariant.sh pass=N fail=M` + `note: P01 precursor to AD-9 / SC-14; full mechanism lands in P02`. Exit 0 iff `fail=0`.

4. **Author `tools/verify/m029-p01-scope-guard.sh`** (≥50 lines, executable). The verifier:

   - Determines the P01 staged-diff scope: runs `git diff --name-only --cached` (staged) and `git diff --name-only HEAD` (unstaged) — combine the two to get every file modified relative to HEAD. (For ad-hoc invocation against an already-committed phase, fall back to `git diff --name-only <BASE>..<HEAD>` where BASE is resolved as the commit immediately preceding M029/P01 work.)
   - Defines the allowlist (the P01 Files Likely Touched paths):
     - `references/status-headline-shape.md`
     - `references/status-json-schema.md`
     - `scripts/state/detect-invocation-context.sh`
     - `scripts/diagnostics/render-status-json.sh`
     - `commands/status.md`
     - `commands/context.md`
     - `tests/m029-acceptance/**` (every file under this dir is allowed)
     - `tools/verify/m029-p01-*.sh` (every M029-P01-prefixed verifier is allowed)
     - `.orchestrator/milestones/M029/**` (planning artifacts — phase plan + task plans + summaries)
   - Defines the denylist (files explicitly out of P01 claim):
     - `scripts/diagnostics/render-position.sh` — P02 deliverable
     - `scripts/diagnostics/summarize-milestone.sh` — P02 deliverable
     - `commands/where.md` — P02 deliverable
     - `commands/auto.md` — P03 modifies (preflight); P01 does NOT
     - `commands/start.md` — P03 modifies (`--auto-chain`); P01 does NOT
     - `scripts/diagnostics/metrics-rollup.sh` — M027 surface, read-only consumer only
     - `scripts/diagnostics/efficiency-footer.sh` — M027 surface, read-only consumer only
     - `scripts/dispatch/predictive-surface.sh` — M027 surface, P03 consumer
     - [`.orchestrator/KNOWLEDGE.md`](../../../../../knowledge.md) — [M020](../../../../../milestones/M020/index.md) owned
     - `.orchestrator/integrations/github.json` — [M013](../../../../../milestones/M013/index.md) owned
     - Any path matching `.orchestrator/milestones/M[0-9]+/execution-log.jsonl` — [M019](../../../../../milestones/M019/index.md) owned
   - For each modified file, asserts: matches the allowlist OR does NOT match the denylist. If a modified file is on the denylist, FAIL with the file path + the violation reason.
   - If a modified file matches neither allowlist nor denylist, emit a stderr `WARN:` advisory naming the file (the gate is conservative — surface unexpected paths rather than silently allow). The verifier exits 0 on WARN; only denylist hits exit non-zero.
   - Emits `PASS:` per allowlist match + `SUMMARY: m029-p01-scope-guard.sh pass=N fail=M warn=K`. Exit 0 iff `fail=0`.

5. **Author `tools/verify/m029-p01-phase-suite.sh`** (≥80 lines, executable). The aggregator:

   - Header comment naming the P01 close-gate role + the SC-11 contribution.
   - `pass=0`, `fail=0` counters; `emit_gate_result()` helper following the m031-p00 pattern.
   - Linear (non-loop) invocations of every P01 verifier in this exact order (matches the dependency graph and gives early-fail for upstream issues):

     **T01 — design contracts:**
     1. `bash tools/verify/m029-p01-headline-shape-contract.sh`
     2. `bash tools/verify/m029-p01-json-schema-contract.sh`

     **T02 — resolver:**
     3. `bash tools/verify/m029-p01-invocation-context-resolver-shape.sh`
     4. `bash tools/verify/m029-p01-sc1-shape.sh`

     **T03 — headline:**
     5. `bash tools/verify/m029-p01-status-headline-shape.sh`
     6. `bash tools/verify/m029-p01-sc2-shape.sh`

     **T04 — JSON renderer:**
     7. `bash tools/verify/m029-p01-render-status-json-shape.sh`
     8. `bash tools/verify/m029-p01-status-format-json-wiring.sh`
     9. `bash tools/verify/m029-p01-sc3-shape.sh`

     **T05 — context skill:**
     10. `bash tools/verify/m029-p01-context-skill-shape.sh`
     11. `bash tools/verify/m029-p01-sc4-shape.sh`

     **T06 — close gates:**
     12. `bash tools/verify/m029-p01-acceptance-battery-shape.sh`
     13. `bash tools/verify/m029-p01-readonly-invariant.sh`
     14. `bash tools/verify/m029-p01-scope-guard.sh`

     Fourteen sub-gates plus the suite's own SUMMARY line. Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics; the suite emits the aggregate SUMMARY at the end.

   - Final line: `printf 'SUMMARY: m029-p01-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"`.
   - Exit 0 iff `fail=0`.

6. **Run the phase-suite end-to-end** to confirm green: `bash tools/verify/m029-p01-phase-suite.sh`. Expected output: 14 `OK:` lines + the 14 sub-gate SUMMARY lines + final `SUMMARY: m029-p01-phase-suite.sh pass=14 fail=0`.

## Must-Haves

This task addresses these P01 phase truths:
- The P01 acceptance battery exists, chains all four SC scripts, and exits 0.
- The phase-suite aggregator exists, chains every P01 verifier in dependency order, and exits 0.
- The CON-1 / FR-14 read-only invariant holds for every P01 surface (mechanically verified via the sentinel-file precursor).
- The scope-guard invariant holds (no out-of-claim file is modified).

This task creates these P01 phase artifacts:
- `tests/m029-acceptance/p01-acceptance-battery.sh` — chains SC-1..SC-4 acceptance scripts.
- `tools/verify/m029-p01-acceptance-battery-shape.sh` — battery shape verifier.
- `tools/verify/m029-p01-readonly-invariant.sh` — CON-1 / FR-14 read-only invariant verifier.
- `tools/verify/m029-p01-scope-guard.sh` — out-of-claim-file modification guard.
- `tools/verify/m029-p01-phase-suite.sh` — P01 phase-suite aggregator (chains every P01 verifier).

## Verification

```bash
bash tools/verify/m029-p01-phase-suite.sh
```

## Inputs

### From Previous Tasks

- All T01..T05 deliverables are inputs for T06's chains. T06 does NOT modify them; it only invokes them via the battery + phase-suite.

  Specifically:
  - The four SC scripts (`p01-sc1-resolver.sh` through `p01-sc4-context.sh`) — invoked by `p01-acceptance-battery.sh`.
  - The twelve T01..T05 verifiers (`m029-p01-headline-shape-contract.sh` through `m029-p01-sc4-shape.sh`) — invoked by `m029-p01-phase-suite.sh`.

  Key API for each upstream verifier: invoked via `bash <path>`; emits per-assertion PASS/FAIL lines + final `SUMMARY:` line; exits 0 on all-pass, non-zero on any failure. The aggregator depends on the `SUMMARY:` line shape being byte-stable across upstream verifiers — ensure each task's verifier follows the convention.

### From Disk (Pre-existing)

- `tools/verify/m031-p00-phase-suite.sh` — pattern reference for the aggregator structure (linear `bash <path>` invocations + `emit_gate_result` helper + final SUMMARY line). Mirror its bash 3.2 style.
- `git` — required for the scope-guard's `git diff --name-only` invocation.
- The `tests/m029-acceptance/fixtures/status-headline-executing.fixture/` (or equivalent) — used by the readonly-invariant verifier's fixture-copy step.

## Constraints

- AD-19 single-script-file shape: every aggregator invocation is a single `bash <path>` call. The aggregator itself uses straight-line linear `bash` invocations + `emit_gate_result` accumulator updates — NO `for` loops over arrays, NO compound chains, NO eval. Mirror `tools/verify/m031-p00-phase-suite.sh`.
- Bash 3.2 compatibility: no associative arrays, no process substitution, no herestrings.
- The scope-guard MUST be conservative — paths matching neither allowlist nor denylist surface as `WARN:` advisories rather than silent passes. Any unexpected path during P01 work surfaces to the operator before merge.
- The readonly-invariant verifier's sentinel-file mechanism is a P01 PRECURSOR to the AD-9 / SC-14 production mechanism (full SC-14 lands in P02). The verifier's SUMMARY line includes a `note:` advisory clarifying this so future maintainers understand the precursor / production split.
- The phase-suite is BYTE-STABLE in its sub-gate ordering. Re-ordering sub-gates risks breaking the early-fail discipline (T01 design-contract failure should surface BEFORE T02 resolver failure surfaces, etc.).
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T06 modifies/creates ONLY the five new files listed in "Files Likely Touched" — no modification to M013/M019/M020/M027 surfaces, no new schema additions.

## Expected Output

After T06 completes:
- All five new artifacts exist on disk and are executable where applicable.
- `bash tools/verify/m029-p01-phase-suite.sh` exits 0 with `SUMMARY: m029-p01-phase-suite.sh pass=14 fail=0`.
- `bash tests/m029-acceptance/p01-acceptance-battery.sh` exits 0 with `BATTERY: p01-acceptance pass=4 fail=0`.
- A summary file at [`.orchestrator/milestones/M029/phases/P01/tasks/T06-acceptance-and-phase-suite-SUMMARY.md`](../../../../../milestones/M029/phases/P01/tasks/T06-acceptance-and-phase-suite-SUMMARY.md) documents the deliverables.
- The phase state derived by `bash scripts/state/derive-phase.sh .orchestrator/milestones/M029` transitions from `executing` to `summarizing` (every task plan has a corresponding summary).

## Notes

Expected phase-suite output: 14 `OK:` lines (one per sub-gate) interspersed with each sub-gate's own SUMMARY line, ending with the aggregate `SUMMARY: m029-p01-phase-suite.sh pass=14 fail=0`. Total stdout volume ≈ 50–80 lines depending on individual sub-gate verbosity.

The phase-suite's SUMMARY line is the canonical P01 close signal. `orchestrator:verify` (the framework verification command) consumes this SUMMARY when running mechanical verification of P01; the milestone-grain `validate-milestone.sh M029` (P03 deliverable) chains all three phase-suites (P01 + P02 + P03) plus the full SC-1..SC-14 acceptance battery.

Reporting note (per `commands/plan-phase.md` "Report deliverables accurately"): T06 SCHEDULES the authorship of these five close-gate artifacts; T06's executor authors them at execution time. The plan does not author them inline.

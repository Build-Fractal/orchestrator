---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M031"
name: "P01 phase-suite aggregator + SC-12 scope-guard verifier"
depends_on: ["T03"]
---

## Prerequisites

- T01 + T02 + T03 all complete with green verifiers:
  - T01: `m031-p01-build-context-profile-shape.sh`, `m031-p01-quick-no-skip-branch.sh`, `m031-p01-config-knobs-stable.sh`.
  - T02: `m031-p01-post-baseline-jsonl-population.sh`, `m031-p01-dispatch-md-reconciliation.sh`.
  - T03: `m031-p01-test-quick-injects-knowledge-shape.sh`, `m031-p01-test-build-context-profile-shape.sh`, `m031-p01-test-compression-applies-to-quick-shape.sh`, `m031-p01-test-quick-budget-median-shape.sh`.
- All nine prerequisite verifiers exist as files under `tools/verify/` and exit 0 individually.

## Description

T04 ships two final verifiers that close out P01:

1. `tools/verify/m031-p01-phase-suite.sh` — the phase-suite aggregator. Invokes all nine T01/T02/T03 verifiers in dependency order (straight-line, no array loops per AD-19 / P00 phase-suite convention), tallies pass/fail counts, emits a single envelope line `SUMMARY: m031-p01-phase-suite.sh pass=N fail=M`, and exits 0 iff `fail=0`. This is the milestone-grain integration gate for P01.

2. `tools/verify/m031-p01-scope-guard.sh` — the SC-12 scope-guard verifier. Asserts the P01 diff (against the milestone parent `M031` baseline) touches no path under `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`. Strict allow-list rather than block-list: only the files declared in the P01-PLAN.md "Files Likely Touched" list are permitted to differ from the M031 baseline.

T04 is the phase-close gate. Once T04's verifiers are green, P01 is ready for `orchestrator:verify` followed by `orchestrator:consolidate`.

## Steps

1. **Author `tools/verify/m031-p01-phase-suite.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Resolve `PROJECT_ROOT` from the script's own location (use `cd "$(dirname ...)/../.."` and `pwd`).
   - Initialize counters `pass=0` and `fail=0`.
   - Invoke each P01 sub-gate sequentially in this order (matches T01 → T02 → T03 dependency order); for each, capture the exit code; if 0 emit `OK: <gate-name>` on stdout and increment pass; else emit `FAIL: <gate-name> rc=<code>` on stdout and increment fail. Do NOT short-circuit — run all nine gates regardless of intermediate failures so the operator sees the complete report:
     1. `bash tools/verify/m031-p01-build-context-profile-shape.sh`
     2. `bash tools/verify/m031-p01-quick-no-skip-branch.sh`
     3. `bash tools/verify/m031-p01-config-knobs-stable.sh`
     4. `bash tools/verify/m031-p01-dispatch-md-reconciliation.sh`
     5. `bash tools/verify/m031-p01-post-baseline-jsonl-population.sh`
     6. `bash tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh`
     7. `bash tools/verify/m031-p01-test-build-context-profile-shape.sh`
     8. `bash tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh`
     9. `bash tools/verify/m031-p01-test-quick-budget-median-shape.sh`
   - Emit final stdout line: `SUMMARY: m031-p01-phase-suite.sh pass=N fail=M`.
   - Exit 0 iff `fail=0`; else exit 1.
   - **Straight-line discipline (AD-19)**: no array loops, no inline `for`/`while`/`if` blocks chaining the nine gates. Each gate is a separate sequential invocation with its own captured exit code. This mirrors the P00 phase-suite pattern from `tools/verify/p00-phase-suite.sh`.
   - File header: contains "SUMMARY:", "m031-p01-build-context-profile-shape", "m031-p01-quick-no-skip-branch", "m031-p01-dispatch-md-reconciliation", "m031-p01-phase-suite".

2. **Author `tools/verify/m031-p01-scope-guard.sh`.** Bash 3.2-compatible, executable. Behavior:
   - Use `git diff --name-only` against the milestone-parent baseline (the commit that immediately predates P01's first commit; the operator-supplied default is `--against <ref>` with a fallback to `HEAD~N` or to the most recent tag matching `[M030](../../../../../milestones/M030/index.md)*`). The simplest robust default: `git diff --name-only HEAD` reports all changes in the working tree + index; the verifier asserts only the P01-allowed paths appear.
   - Define the strict allow-list (matches `P01-PLAN.md` "Files Likely Touched"):
     ```
     scripts/dispatch/build-context.sh
     commands/dispatch.md
     tests/m031-acceptance/fixtures/empirical-baseline/post-m031-emitter.sh
     tests/m031-acceptance/fixtures/empirical-baseline/post-m031-baseline.jsonl
     tests/m031-acceptance/test-quick-injects-knowledge.sh
     tests/m031-acceptance/test-build-context-profile.sh
     tests/m031-acceptance/test-compression-applies-to-quick.sh
     tests/m031-acceptance/test-quick-budget-median.sh
     tools/verify/m031-p01-build-context-profile-shape.sh
     tools/verify/m031-p01-quick-no-skip-branch.sh
     tools/verify/m031-p01-config-knobs-stable.sh
     tools/verify/m031-p01-dispatch-md-reconciliation.sh
     tools/verify/m031-p01-post-baseline-jsonl-population.sh
     tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh
     tools/verify/m031-p01-test-build-context-profile-shape.sh
     tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh
     tools/verify/m031-p01-test-quick-budget-median-shape.sh
     tools/verify/m031-p01-phase-suite.sh
     tools/verify/m031-p01-scope-guard.sh
     [.orchestrator/milestones/M031/phases/P01/P01-PLAN.md](../../../../../milestones/M031/phases/P01/P01-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T01-build-context-profile-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T01-build-context-profile-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T02-ad14-capture-and-fr4-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T03-acceptance-tests-PLAN.md)
     [.orchestrator/milestones/M031/phases/P01/tasks/T04-phase-suite-and-scope-guard-PLAN.md](../../../../../milestones/M031/phases/P01/tasks/T04-phase-suite-and-scope-guard-PLAN.md)
     .orchestrator/milestones/M031/phases/P01/tasks/T01-SUMMARY.md
     .orchestrator/milestones/M031/phases/P01/tasks/T02-SUMMARY.md
     .orchestrator/milestones/M031/phases/P01/tasks/T03-SUMMARY.md
     [.orchestrator/milestones/M031/phases/P01/tasks/T04-SUMMARY.md](../../../../../milestones/M031/phases/P01/tasks/T04-SUMMARY.md)
     [.orchestrator/milestones/M031/phases/P01/P01-SUMMARY.md](../../../../../milestones/M031/phases/P01/P01-SUMMARY.md)
     ```
     plus a permissive prefix `.orchestrator/observability/` for JSONL emission records.
   - Define the strict block-list (SC-12 forbidden):
     - any path matching `knowledge/`
     - any path matching `scripts/cost/`
     - any path matching `scripts/dispatch/adapters/router/`
     - any path matching `scripts/auto/loop/`
   - For each changed path: assert it does NOT match the block-list. Emit `FAIL: scope-guard violation: <path> matches <block-pattern>` on any block-list match; emit `WARN: out-of-allow-list: <path>` on a path that matches neither allow nor block (informational, not a failure — the allow-list is comprehensive but the verifier keeps a soft warning channel for new files the planner did not anticipate).
   - Exit 0 iff zero block-list matches; exit 1 on any block-list match.
   - Emit final stdout line: `SUMMARY: m031-p01-scope-guard.sh pass=N fail=M block_list_violations=K`.
   - File header: contains "knowledge/", "scripts/cost", "scripts/dispatch/adapters/router", "scripts/auto/loop", "SC-12".
   - **Guard against well-intentioned future "fixes"**: the block-list is normative per CON-1 + DC-3 + Principle XV. Future maintainers tempted to relax it MUST first amend the spec's "Boundary write-sites M031 delegates" section. The verifier file's header comment names this contract.

3. **Run both new verifiers locally** to confirm exit 0:
   - `bash tools/verify/m031-p01-phase-suite.sh` — should report `SUMMARY: m031-p01-phase-suite.sh pass=9 fail=0`.
   - `bash tools/verify/m031-p01-scope-guard.sh` — should report `SUMMARY: m031-p01-scope-guard.sh pass=N fail=0 block_list_violations=0`.

## Must-Haves

This task addresses the following Must-Haves from `P01-PLAN.md`:
- "tools/verify/m031-p01-phase-suite.sh exists, is executable, and invokes every P01 gate in order" (Truth #10; Check via the suite itself)
- "The SC-12 scope-guard invariant holds for the P01 diff" (Truth #11; Check via `m031-p01-scope-guard.sh`)

## Verification

```bash
bash tools/verify/m031-p01-phase-suite.sh
```

```bash
bash tools/verify/m031-p01-scope-guard.sh
```

## Notes

- The phase-suite pattern is reused from P00 (`tools/verify/p00-phase-suite.sh`). Straight-line invocation, no array loops, no inline `for`/`while`/`if` chaining — AD-19 compliant.
- The scope-guard verifier is local-grain (T04 is the place SC-12 lives, since by definition you cannot verify the whole-phase scope until all phase tasks have committed). P04 will ship a milestone-grain `scope-guard.sh` under `tests/m031-acceptance/` that aggregates across all M031 phases (per the roadmap's P04 boundary).
- The expected pass count for the phase-suite is exactly 9 (one per sub-gate). If a future task introduces a new sub-gate, the suite MUST be amended additively and the expected count updated (the suite emits `pass=N` not `pass=9`, so the count is data, not a hard-coded literal — but the operator should review additions).
- D020 token hygiene (CON-7): authored prose in the verifiers MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code.

## Inputs

### From Previous Tasks

The phase-suite invokes nine pre-existing verifiers from T01/T02/T03. Each is a single-script invocation:

- From T01:
  - `tools/verify/m031-p01-build-context-profile-shape.sh` — asserts `--profile` + `--meta-out` flags + 5-key sidecar schema.
  - `tools/verify/m031-p01-quick-no-skip-branch.sh` — asserts no `# skip context` early-exit pattern in build-context.sh.
  - `tools/verify/m031-p01-config-knobs-stable.sh` — asserts the three P00 config knobs unchanged.
- From T02:
  - `tools/verify/m031-p01-post-baseline-jsonl-population.sh` — asserts 20 post-m031 JSONL records exist.
  - `tools/verify/m031-p01-dispatch-md-reconciliation.sh` — asserts FR-4 reconciliation in commands/dispatch.md.
- From T03:
  - `tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh` (SC-1)
  - `tools/verify/m031-p01-test-build-context-profile-shape.sh` (SC-2 / AD-13)
  - `tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh` (SC-3 / AD-17)
  - `tools/verify/m031-p01-test-quick-budget-median-shape.sh` (SC-15 / AD-18)

Each emits its own `SUMMARY: <script> pass=N fail=M` line and exits 0 iff `fail=0`. The phase-suite reads each exit code; it does NOT parse the SUMMARY lines (parsing would couple the suite to envelope formatting; exit codes are the load-bearing contract).

### From Disk (Pre-existing)

- `tools/verify/p00-phase-suite.sh` — P00's phase-suite aggregator. T04's phase-suite mirrors this structure verbatim (same straight-line invocation pattern, same `OK:`/`FAIL:` per-gate emission, same final `SUMMARY:` envelope).
- `git` (CLI) — required for the scope-guard's `git diff --name-only`. P01 already runs in a git repo; this is a hard requirement.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **AD-19 single-script-file shape**: every verifier invocation in the phase-suite MUST be a single `bash <script-path>` invocation. No compound `;`/`&&`/`||` chaining beyond the canonical `&&`/`||` pair. No inline subshells, no command substitution containing pipes.
- **Straight-line phase-suite**: no array loops, no `for`/`while` over an array of gates. Each gate is its own sequential invocation. (Mirrors P00.)
- **No edits to T01/T02/T03 deliverables** in T04 (T04 is purely additive — new verifiers under `tools/verify/`).
- **No edits to `templates/orchestrator-config-default.yml`**, `commands/dispatch.md`, `scripts/dispatch/build-context.sh`, or any other artifact owned by upstream tasks.
- **SC-12 scope-guard self-application**: the scope-guard verifier itself lives at `tools/verify/m031-p01-scope-guard.sh`, which is in the P01 allow-list. (The verifier does not flag itself.)
- **Verifier path discipline**: both new verifiers live under `tools/verify/m031-p01-*.sh`.

## Expected Output

After T04 completes:

1. `tools/verify/m031-p01-phase-suite.sh` exists, executable, invokes all nine P01 sub-gates straight-line, emits `SUMMARY: m031-p01-phase-suite.sh pass=9 fail=0`, exits 0.
2. `tools/verify/m031-p01-scope-guard.sh` exists, executable, asserts no block-list violations in the P01 diff, emits `SUMMARY: m031-p01-scope-guard.sh pass=N fail=0 block_list_violations=0`, exits 0.
3. Running `bash tools/verify/m031-p01-phase-suite.sh` is the single load-bearing P01 gate — green here means P01 is ready for `orchestrator:verify` and `orchestrator:consolidate`.

T04 closes P01. The next phase is P02 (Tier A+ middle flow, depends on P01 sidecar + profile flag).

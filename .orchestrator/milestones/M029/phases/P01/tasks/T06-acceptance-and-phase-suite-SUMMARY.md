---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P01"
milestone: "M029"
provides:
  - "P01 phase-close gate: SC-11 acceptance battery (SC-1..SC-4 slice) + 3 close-gate verifiers + 14-gate phase-suite aggregator"
requires:
  - "from:T01..T05 what:eleven upstream verifiers + four SC scripts; from:T01 what:references/status-headline-shape.md+references/status-json-schema.md design contracts"
affects:
  - "P02 (SC-14 production read-only mechanism inherits the sentinel-file precursor); P03 (full SC-1..SC-14 acceptance battery embeds the P01 slice)"
key_files:
  - "tests/m029-acceptance/p01-acceptance-battery.sh,tools/verify/m029-p01-acceptance-battery-shape.sh,tools/verify/m029-p01-readonly-invariant.sh,tools/verify/m029-p01-scope-guard.sh,tools/verify/m029-p01-phase-suite.sh"
key_decisions:
  - "AD-19 linear bash invocation pattern; sentinel-file find -newer as SC-14 precursor; conservative scope-guard (WARN advisory for unclassified paths, FAIL only on denylist hits); battery / phase-suite split (battery embeds in milestone validator, phase-suite is per-phase close gate)"
patterns_established:
  - "phase-suite aggregator structure mirrors m031-p00-phase-suite.sh (linear bash <path> + emit_gate_result + final SUMMARY); acceptance-battery wrapper aggregates SC scripts and emits BATTERY: line; scope-guard combines git status --porcelain=v1 with allowlist/denylist classification + WARN: advisory for unclassified"
drill_down_paths:
  - "tools/verify/m029-p01-phase-suite.sh,tests/m029-acceptance/p01-acceptance-battery.sh"
duration: "2h"
verification_result: "pass"
completed_at: "2026-05-05T23:23:25Z"
---

# T06 — P01 acceptance battery + phase-suite + read-only invariant + scope-guard

## What shipped

Five close-gate artifacts realize the P01 phase-close gate on the
M029/P01 plane:

1. `tests/m029-acceptance/p01-acceptance-battery.sh` — the SC-11 slice
   acceptance battery. Linear `_run_sc` invocations of the four P01 SC
   scripts (SC-1 resolver, SC-2 headline, SC-3 format=json, SC-4 context)
   in dependency order. Final form: `BATTERY: p01-acceptance pass=4 fail=0`.
   The full SC-11 battery covering all 14 success criteria lands in P03
   at `tests/m029-acceptance/run-acceptance-battery.sh`.

2. `tools/verify/m029-p01-acceptance-battery-shape.sh` — battery shape
   verifier. 10 assertions: file existence, executability, references
   to all four SC scripts, BATTERY: literal, end-to-end exit 0, and the
   final BATTERY line matches `pass=N fail=0`.

3. `tools/verify/m029-p01-readonly-invariant.sh` — CON-1 / FR-14 read-only
   invariant verifier. Copies the SC-2 fixture into a tmpdir as
   `<tmp>/orch-root/.orchestrator/`, stamps `.m029-p01-sentinel`, sleeps
   1s, runs each P01 surface (resolver, render-status-json, resolve-root,
   find-active-milestone, derive-phase, read-roadmap), and asserts
   `find -newer` returns no files under `.orchestrator/`. 12 assertions,
   all PASS. SUMMARY line includes `note: P01 precursor to AD-9 / SC-14;
   full mechanism lands in P02`.

4. `tools/verify/m029-p01-scope-guard.sh` — out-of-claim modification
   guard. Walks `git status --porcelain=v1` (or `git diff` against
   `M029_P01_SCOPE_BASE` if set), classifies each path against the P01
   allowlist (Files Likely Touched + tests/m029-acceptance/** +
   tools/verify/m029-p01-*.sh + .orchestrator/milestones/M029/** +
   specs/037-roadmap-visibility-cli-ux/**) and the denylist (P02/P03
   deliverables, M013/M019/M020/M027 surfaces). Denylist hits FAIL;
   unclassified paths surface as WARN: advisories without failing the
   gate. Conservative shape per plan.

5. `tools/verify/m029-p01-phase-suite.sh` — the canonical P01 close-gate
   aggregator. Linear `bash <path>` invocations of every P01 verifier
   (T01 contracts -> T02 resolver -> T03 headline -> T04 JSON renderer ->
   T05 context skill -> T06 close gates), 14 sub-gates plus the
   aggregate SUMMARY line. Final form: `SUMMARY:
   m029-p01-phase-suite.sh pass=14 fail=0`. Mirrors
   `tools/verify/m031-p00-phase-suite.sh` byte-for-byte at the
   structural level.

## Key design decisions

- Battery / phase-suite split. The battery aggregates the four
  user-facing SC acceptance scripts and is what a milestone-grain
  validator (`validate-milestone.sh M029`, P03 deliverable) embeds.
  The phase-suite aggregates the eleven T01..T05 verifiers + the
  three T06 close gates and is what a phase-close gate consumes.
  Both surfaces are needed: the SC battery proves user-facing
  acceptance; the phase-suite proves shape compliance.

- Sentinel-file readonly mechanism. T06's invariant verifier
  intentionally mirrors SC-4's sentinel/find-newer pattern (sleep 1s
  to avoid same-second mtime false negatives) and explicitly tags
  itself as the precursor to the production AD-9 / SC-14 mechanism
  landing in P02. The note: line in the SUMMARY tells future
  maintainers about the precursor / production split so they don't
  duplicate the mechanism.

- Conservative scope-guard. Paths that match neither allowlist nor
  denylist surface as `WARN:` advisories rather than silent passes —
  the operator sees every unexpected path before merge. The current
  WARN block (AGENTS.md / CLAUDE.md / KNOWLEDGE-INDEX.md / 31x
  knowledge/**/MEM*.md) reflects in-flight knowledge index updates
  triggered by the dispatch-payload assembler — these are M020-owned
  surfaces but maintained by infrastructure, not by P01 work.

- Linear invocation per AD-19. Every aggregator (battery + phase-suite)
  uses straight-line `bash <path>` invocations + accumulator updates,
  with NO `for` loops over arrays, NO compound chains, NO eval. Mirrors
  the m031-p00-phase-suite.sh proven pattern.

## Verification

- `bash tools/verify/m029-p01-phase-suite.sh` -> exit 0,
  `SUMMARY: m029-p01-phase-suite.sh pass=14 fail=0`.
- `bash tests/m029-acceptance/p01-acceptance-battery.sh` -> exit 0,
  `BATTERY: p01-acceptance pass=4 fail=0`.
- `bash tools/verify/m029-p01-acceptance-battery-shape.sh` -> exit 0,
  `SUMMARY: m029-p01-acceptance-battery-shape.sh pass=10 fail=0`.
- `bash tools/verify/m029-p01-readonly-invariant.sh` -> exit 0,
  `SUMMARY: m029-p01-readonly-invariant.sh pass=12 fail=0`.
- `bash tools/verify/m029-p01-scope-guard.sh` -> exit 0,
  `SUMMARY: m029-p01-scope-guard.sh pass=24 fail=0 warn=34`.

## Constraints honored

- AD-19 single-script-file shape: every aggregator invocation is a
  literal `bash <path>` call.
- Bash 3.2 compatibility: no associative arrays, no process
  substitution, no herestrings.
- Read-only / CON-1 / FR-14: the readonly-invariant verifier
  mechanically proves zero `.orchestrator/` mutation during P01
  surface invocation against the SC-2 fixture.
- CON-7 / AD-8 knowledge-layer boundary: T06 modifies / creates ONLY
  the five new files listed in "Files Likely Touched" — no
  modification to M013/M019/M020/M027 surfaces, no schema additions.
- Byte-stable phase-suite ordering: T01 contracts surface before
  T02 resolver before T03 headline ... so an upstream failure
  short-circuits diagnostics and the operator sees the root cause.

## Follow-ups

- Full SC-14 read-only mechanism lands in P02 alongside the where
  renderer + position summary surfaces; T06's verifier becomes the
  precursor that informs the production design.
- The full SC-1..SC-14 acceptance battery
  (`tests/m029-acceptance/run-acceptance-battery.sh`) lands in P03;
  the P01 slice in T06 covers SC-1..SC-4 only.
- After P02 ships, the phase-suite's denylist needs to drop
  `commands/where.md` + `scripts/diagnostics/render-position.sh` +
  `scripts/diagnostics/summarize-milestone.sh` (those become P02-owned
  allowlisted paths in their own scope-guard).

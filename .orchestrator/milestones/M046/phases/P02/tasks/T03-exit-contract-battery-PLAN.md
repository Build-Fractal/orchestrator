---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M046"
name: "SC-9 non-stubbed full-exit-set battery + CHILD_ABORT fixture"
depends_on: [T01, T02]
---

## Prerequisites

- T01 complete: `scripts/lifecycle/auto-loop.sh` writes the env-gated deterministic marker per the vocabulary table in `P02-PLAN.md`; `tests/fixtures/m046-p02/verifying-tree/MFIX/` exists.
- T02 complete: `scripts/lifecycle/self-continue-drive.sh` has the argv spawn, `CHILD_RC` capture, CHILD_ABORT truth table, and exports `ORCHESTRATOR_SELF_CONTINUE_MARKER=1` to the child.
- Verify both with `ls`: `tools/verify/m046-p02-marker-unit.sh` and `tools/verify/m046-p02-injection-reject.sh` must exist before starting.

## Description

SC-9 is milestone-blocking and NON-STUBBED: "the marker is correct for the COMPLETE `auto-loop.sh` exit set — including the exit-0 continuation substates and 1/12/13 errors — asserted against the real `auto-loop.sh`, not a golden of the happy codes; a killed child yields CHILD_ABORT." A seeded-marker stub does NOT satisfy it.

This task builds (a) fixture milestone trees that drive the REAL `auto-loop.sh` to every exit code in its contract, (b) `tools/verify/m046-p02-marker-exit-contract.sh` asserting, per case, BOTH the observed exit code AND the exact marker content, and (c) `tools/verify/m046-p02-child-abort.sh` running kill/crash/stall cases through the REAL driver with the real wrapper. The dual assertion (exit AND marker) is the anti-false-pass mechanism: a fixture that drifts to the wrong exit code fails loud instead of green-lighting a wrong mapping.

Precedent: M046 P01's cost-cadence probe drove the real `auto-loop.sh` at zero LLM spend using a fixture tree whose root doubles as `ORCHESTRATOR_ROOT` (`.orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/`). Reuse that pattern.

## Steps

1. **Probe pass first** (plan-time honesty: exits 2/3/13/14 depend on `budget-checker.sh` / `stuck-detector.sh` / `build-context.sh` / `context-monitor.sh` thresholds that were not pinned at plan time). For each uncertain case below, build the candidate tree in a scratch dir, run the real `bash scripts/lifecycle/auto-loop.sh <tree>` with the intended args/env, observe the exit code, and iterate on fixture content until the intended code is produced. Record what each fixture needed in a header comment inside the battery verifier. Config-driven cases set `ORCHESTRATOR_ROOT` to a fixture root containing `config.yml` (the P01 "fixture root doubles as ORCHESTRATOR_ROOT" pattern — read `scripts/state/resolve-root.sh` and `scripts/state/read-config.sh` to confirm the key names: `dispatch_budget`, `duration_budget`, `session_weight_limit`).

2. **Create the exit-code fixture trees** under `tests/fixtures/m046-p02/exit-trees/<case>/` (each containing an `MFIX/` milestone dir; add a fixture-root `config.yml` and/or `execution-log.jsonl` where the case needs one). Eleven cases:

   | case dir | tree state | invocation (real auto-loop.sh, gate on) | expected exit | expected marker |
   |----------|-----------|------------------------------------------|---------------|-----------------|
   | `planning-ok` | roadmap with unchecked P01, NO `phases/P01/P01-PLAN.md`, inputs sufficient for `build-context.sh ... PHASE_PLAN` to succeed | `<dir>` | 0 (`AUTO:PLANNING`) | `planning P01` |
   | `phase-complete` | copy of `verifying-tree/MFIX` (all task summaries, no phase summary) | `<dir>` | 0 | `phase_complete P01` |
   | `validating` | roadmap all `[x]`, all phase summaries present, no `MFIX-VALIDATED` marker | `<dir>` | 0 | `validating` |
   | `err-args` | copy of `verifying-tree/MFIX` | `<dir> --step=G` (no `--task`) | 1 | `error` |
   | `budget` | executing-state tree + `execution-log.jsonl` with dispatch records + fixture-root `config.yml` setting a low `dispatch_budget` | `<dir>` | 2 | `budget` |
   | `stuck` | executing-state tree + log with repeated failure records for the next task's unit id | `<dir>` | 3 | `stuck` |
   | `complete` | tree with `MFIX-VALIDATED` present | `<dir>` | 10 | `complete` |
   | `pause` | any valid tree + `pause-requested` file inside the milestone dir | `<dir>` | 11 | `pause` |
   | `drift` | roadmap `[x]` phase with NO phase summary | `<dir>` | 12 | `unexpected_state` |
   | `planning-failed` | planning-state tree where `build-context.sh` fails (e.g. `ORCHESTRATOR_ROOT` pointing at an empty root) | `<dir>` | 13 | `planning_failed` |
   | `rotate` | tree + heavy `execution-log.jsonl` + low `session_weight_limit` so `context-monitor.sh` reports `CONTEXT:ROTATE` | `<dir> --step=X` | 14 | first word `rotation`, second word `P01` |

   Notes: `planning-ok` vs `planning-failed` are the delicate pair — both derive state `planning`; the difference is whether `build-context.sh` succeeds. If `planning-ok` proves impossible to satisfy with a small self-contained tree (build-context needs spec/knowledge inputs), grow the fixture (add the minimal spec/CONTEXT files build-context reads) rather than stubbing build-context — the battery must run the real script end-to-end. If after a bounded effort (~5 iterations) `planning-ok` still cannot reach exit 0, STOP and report the blocker in the task summary — do NOT green the case with a stub; that specific case missing is a phase-gate FAIL, not a skip.

3. **Author `tools/verify/m046-p02-marker-exit-contract.sh`** (POSIX sh, executable, `set -eu`):
   - For each case in the table: copy the tree to `mktemp -d` scratch; `rm -f` any marker; run `ORCHESTRATOR_SELF_CONTINUE_MARKER=1 bash scripts/lifecycle/auto-loop.sh <scratch>/MFIX <case-args>` (plus per-case `ORCHESTRATOR_ROOT`/env from the probe pass), capturing the exit code without tripping `set -e` (`rc=0; bash ... >/dev/null 2>&1 || rc=$?`).
   - Assert `rc` equals the expected exit AND the marker file content equals the expected string exactly (`rotation` case: assert word 1 and word 2 separately).
   - One iteration-discipline note: implement the per-case logic as a function called once per case (a flat sequence of calls, not a data-driven loop, is fine and keeps the shape AD-19-safe inside the script).
   - Emit `PASS: case=<name> exit=<rc> marker=<content>` / `FAIL: ...` per case + a `SUMMARY: pass=N fail=M` line; exit non-zero if any fail.

4. **Author `tools/verify/m046-p02-child-abort.sh`** (POSIX sh, executable, `set -eu`) — through the REAL driver (`sh scripts/lifecycle/self-continue-drive.sh <mdir> --min-interval 0 --auto-cmd "sh <stub>"`), five cases:
   - `kill-self`: stub is `#!/usr/bin/env sh` + `kill -9 $$` (deterministic mid-flight SIGKILL, rc=137 — no race). Assert marker content `child_abort` and driver output contains `SELF_CONTINUE:CHILD_ABORT rc=137`.
   - `kill-after-marker`: stub writes `rotation P01` to the marker, then `kill -9 $$`. Assert the stale marker was OVERWRITTEN to `child_abort` (SC-9's "a killed child yields CHILD_ABORT") and the distinct terminal line fired.
   - `crash-no-marker`: stub exits 3 without writing. Assert marker `child_abort`, distinct terminal line with `rc=3`.
   - `error-exit-with-marker`: stub writes `budget`, exits 5. Assert marker STAYS `budget` and driver emits `SELF_CONTINUE:TERMINAL outcome=budget` (the 1..127-with-marker row — required so real auto-loop error exits keep their distinct terminals).
   - `clean-no-marker`: stub exits 0, writes nothing. Assert `SELF_CONTINUE:STALLED` (M045 parity; the driver must NOT fabricate child_abort for a clean unreporting child).
   - Emit `PASS:`/`FAIL:` per case + summary; non-zero exit on any failure.

5. Run the full set: both new verifiers plus `tools/verify/m046-p02-marker-unit.sh` and `tools/verify/m046-p02-legacy-parity.sh` (T01 regression under the new fixtures' presence — they share no state, this is a cheap sanity re-run).

## Must-Haves

- The marker is correct for the COMPLETE real `auto-loop.sh` exit set, asserted non-stubbed (SC-9)
  - Check: `bash tools/verify/m046-p02-marker-exit-contract.sh`
- A signal-killed child yields `child_abort` (overwriting stale markers), a crashed child yields `child_abort`, an error-exiting child with a marker keeps its marker, and a clean unreporting child still yields STALLED
  - Check: `bash tools/verify/m046-p02-child-abort.sh`

## Verification

```bash
bash tools/verify/m046-p02-marker-exit-contract.sh
bash tools/verify/m046-p02-child-abort.sh
bash tools/verify/m046-p02-marker-unit.sh
bash tools/verify/m046-p02-legacy-parity.sh
```

## Notes

Expected output: `m046-p02-marker-exit-contract.sh` ends with `SUMMARY: pass=11 fail=0`; `m046-p02-child-abort.sh` passes all 5 cases; the two T01 verifiers stay green.

Non-stubbed clarification (matches the P01 zero-LLM-spend standard): "non-stubbed" means the REAL `auto-loop.sh` and the REAL driver wrapper run end-to-end against real on-disk state; no `claude -p` spend is required — the child in the battery IS `auto-loop.sh` (via `--auto-cmd` in the child-abort verifier, direct invocation in the exit battery). Fixture stubs appear ONLY as kill/crash stand-ins in the child-abort verifier, where the surface under test is the driver's wrapper, not the loop.

auto-loop mutates trees (payload files, `pause-requested` deletion, drift logs) and `rebuild-index.sh` runs against the REPO root (`|| true`, output discarded) — always run against scratch copies; the repo-side index rebuild is idempotent and harmless (same as every P01 probe run).

## Inputs

### From Previous Tasks

- `scripts/lifecycle/auto-loop.sh` (T01) — marker gate `ORCHESTRATOR_SELF_CONTINUE_MARKER=1`; writes `<milestone-dir>/.self-continue-outcome` per the `P02-PLAN.md` vocabulary table; exit codes unchanged from the pre-T01 contract.
- `scripts/lifecycle/self-continue-drive.sh` (T02) — `run_child` argv spawn with `CHILD_RC` capture; CHILD_ABORT truth table; distinct `SELF_CONTINUE:CHILD_ABORT rc=<rc> continuations=<N> progress=<P>` terminal line; `--auto-cmd` is whitespace-split (simple `sh /abs/path/stub.sh` forms only).
- `tests/fixtures/m046-p02/verifying-tree/MFIX/` (T01) — base tree to copy for `phase-complete`, `err-args`, `pause` cases.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/` — proven executing-state fixture shape (roadmap + plans + summaries + execution-log) to copy for the `budget`/`stuck` cases.
- `scripts/state/derive-phase.sh` — state rules the trees drive (planning / executing / verifying / validating / completing).
- `scripts/state/read-config.sh`, `scripts/state/resolve-root.sh` — config keys and `ORCHESTRATOR_ROOT` resolution for the `budget`/`rotate`/`planning-failed` cases.
- `scripts/lifecycle/budget-checker.sh`, `scripts/lifecycle/stuck-detector.sh`, `scripts/lifecycle/context-monitor.sh`, `scripts/dispatch/build-context.sh` — threshold sources for the probe pass.

## Constraints

- NON-STUBBED (Principle II, milestone-blocking): every exit-battery case runs the real `auto-loop.sh`; no seeded markers, no mock loop. A case that cannot be realized honestly is reported as a blocker, never skipped silently.
- Do NOT modify `auto-loop.sh` (CON-2 — T01's single change is final) or the driver (T02 is final). If a fixture case exposes a mapping bug, fix the FIXTURE if the fixture is wrong; if the MECHANISM is wrong, route the fix through the owning task's file with an explicit note in the task summary (and re-run that task's verifiers).
- Fixture trees are checked in; verifiers always operate on scratch copies.
- Keep every fixture path within the `[A-Za-z0-9_./-]` charset (T02's allowlist applies to driver-driven cases).

## Expected Output

- `tests/fixtures/m046-p02/exit-trees/` — 11 case trees (some sharing content via copies of `verifying-tree`).
- `tools/verify/m046-p02-marker-exit-contract.sh` — 11/11 green.
- `tools/verify/m046-p02-child-abort.sh` — 5/5 green.

---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M046"
goal: "Marker full-exit contract + driver injection hardening — deterministic outcome markers keyed to the complete auto-loop.sh exit set, CHILD_ABORT for killed/crashed children, atomic temp+rename marker writes, argv-array child spawn with strict charset allowlist"
demo_sentence: "For every real auto-loop.sh exit — including the exit-0 continuation substates PLANNING/PHASE_COMPLETE/VALIDATING — the marker on disk names the correct outcome; a child killed mid-write leaves a whole old-or-new marker (atomic temp+rename), a killed/crashed child yields SELF_CONTINUE:CHILD_ABORT, and a metacharacter-bearing milestone name is rejected, not executed."
risk: "high"
depends_on: []
---

## Phase Context

M045 shipped the process-fresh self-continue driver (`scripts/lifecycle/self-continue-drive.sh`) reading a continuation decision from `<milestone-dir>/.self-continue-outcome`. Today that marker is written by the *agent* per `commands/auto.md` ("Outcome marker" section, ~line 561) — an LLM-execution-path write. Gap 3 (spec Problem Statement): `auto-loop.sh` exits `0` for its dominant continuation states (PLANNING / PHASE_COMPLETE / VALIDATING) and `1/12/13` for errors, so the common per-iteration exit writes no marker or a wrong one and the driver falls to a silent `unknown` → `STALLED`. Gap 4: the driver interpolates the milestone path into a shell string run by `sh -c` (`self-continue-drive.sh:57`).

This phase closes both gaps: FR-14 (marker keys the COMPLETE exit-code contract, writer division of labor), FR-15 (argv-array spawn + charset allowlist), atomic temp+rename for every marker write, FR-17 (attended legacy byte-parity when the marker gate is absent), SC-9 (non-stubbed fixture against the REAL `auto-loop.sh`), SC-10 (injection-rejection fixture).

## The auto-loop.sh Exit-Code Contract (authoritative, read from source 2026-07-13)

Header lines 45–54 plus the exit sites verified in the body:

| Exit | Meaning | Exit sites (line) | Substate line (via `_auto_output`) |
|------|---------|-------------------|-------------------------------------|
| 0 | success — substate on stdout | 245, 297, 406, 444, 519, 525, 529, 585, 640 | `AUTO:READY` / `AUTO:RECORDED` / `AUTO:VERIFY_PASS` / `CONTEXT:OK` / `AUTO:PLANNING` / `AUTO:PHASE_COMPLETE` / `AUTO:MILESTONE_VALIDATING` |
| 1 | error (args, missing scripts, VERIFY_FAIL, VERIFY_NO_CHECKS) | 81, 91, 99, 136, 181, 254, 269, 397, 403 | `AUTO:VERIFY_FAIL` / `AUTO:VERIFY_NO_CHECKS` / none |
| 2 | budget exceeded | 606 | none |
| 3 | stuck detected | 616 | none |
| 10 | milestone already complete | 532 | none |
| 11 | pause requested | 462 | none |
| 12 | unexpected state / roadmap drift / no active phase | 486, 542, 553 | `AUTO:ROADMAP_DRIFT` / none |
| 13 | planning payload assembly failed | 511 | `AUTO:PLANNING_FAILED` |
| 14 | context rotation recommended (`--step=X`) | 441 | `CONTEXT:ROTATE` |

Every exit-0 substate flows through the single output funnel `_auto_output()` (lines 146–153) — verified: lines 233, 296, 394, 402, 405, 418, 438, 482, 510, 518, 524, 528, 584, 638 all call it. This makes the funnel the one legitimate substate-capture point.

## Marker Vocabulary (single source of truth for this phase)

Marker file: `<milestone-dir>/.self-continue-outcome`, content `<word> [<phase>]` (word 2 drives the driver's forward-progress/thrash tracking, existing `awk '{print $2}'` at `self-continue-drive.sh:60`).

| Exit keyed | Marker word | Class |
|------------|-------------|-------|
| 0 + `AUTO:PLANNING phase=P##` | `planning P##` | continue |
| 0 + `AUTO:PHASE_COMPLETE phase=P##` | `phase_complete P##` | continue |
| 0 + `AUTO:MILESTONE_VALIDATING` | `validating` | continue |
| 0 + `AUTO:READY` / `AUTO:RECORDED` / `AUTO:VERIFY_PASS` / `CONTEXT:OK` | *(no write — mid-segment step; last-write-wins semantics preserved)* | — |
| 1 | `error` | terminal |
| 2 | `budget` | terminal (existing word) |
| 3 | `stuck` | terminal (existing word) |
| 10 | `complete` | terminal (existing word) |
| 11 | `pause` | terminal (existing word) |
| 12 | `unexpected_state` | terminal |
| 13 | `planning_failed` | terminal |
| 14 | `rotation P##` | continue (existing word; phase best-effort from `read-roadmap.sh active-phase`) |
| child killed/crashed (driver wrapper, not an auto-loop exit) | `child_abort` | terminal |

`blocked` remains in the vocabulary (entry-layer writer, no auto-loop exit code) — unchanged. Continue-class set consumed by the driver: `rotation | planning | phase_complete | validating`.

## CON-2 Accounting (why this is ONE additive change)

CON-2 authorizes AT MOST ONE additive, idempotent change to `auto-loop.sh`: the outcome-marker write keyed to its existing exit codes. The implementation is **one logical write mechanism** realized as two purely-additive textual insertions:

1. **Insertion A** — a self-contained block after line 100 (immediately after `MILESTONE_DIR` is validated, before the option-parse loop): two state variables (`_MARKER_SUBSTATE`, `_MARKER_PHASE`), one writer function (`_write_outcome_marker`), and one `trap _write_outcome_marker EXIT`. The trap is the single writer; it maps `$?` (+ captured substate for exit 0) to the vocabulary table above and writes atomically (temp + `mv -f`).
2. **Insertion B** — a substate-capture `case` added inside the existing `_auto_output()` body. All structured output flows through this one funnel (verified above), so a single capture point covers every exit-0 substate without touching any exit site.

Why this still counts as one change: single writer function, single trap, single capture hook in the one output funnel; **zero existing lines modified or removed**; no control-flow change; default-off behind `ORCHESTRATOR_SELF_CONTINUE_MARKER=1` (FR-17 byte-parity when absent); idempotent (the trap fires once per process; re-running the same invocation rewrites the same marker content via rename, no append). The roadmap's cross-cutting note ("P02 is the ONLY phase that touches `auto-loop.sh`, with exactly one additive marker write") is satisfied.

**Escalation rule for the executor**: if implementation reveals any exit path that bypasses `_auto_output` for a substate the contract needs, or forces any third insertion or any modification of an existing line, STOP and raise a Decision row in `.orchestrator/DECISIONS.md` per CON-2 — do not silently widen the change.

## Driver Wrapper Truth Table (FR-14 writer division of labor, deterministic)

The driver's child spawn is wrapped so the child's real exit status `rc` is captured (today it is discarded by `|| true`). After the child exits:

| Condition | Action |
|-----------|--------|
| `rc >= 128` (killed by signal) | atomically write `child_abort` (overwrite — a kill can land after a mid-segment marker write, so any present marker may be stale) |
| `1 <= rc <= 127` AND marker file absent | atomically write `child_abort` (crashed before reporting) |
| `1 <= rc <= 127` AND marker file present | keep the marker (auto-loop's deterministic exit-keyed report wins — required for fixtures that run the real `auto-loop.sh` as the child, whose error exits are 1/2/3/12/13) |
| `rc = 0` AND marker absent | no write → existing `unknown` → `SELF_CONTINUE:STALLED` path preserved (M045 parity; a clean child that never reported is a stall, not an abort) |
| `rc = 0` AND marker present | keep the marker |

On `child_abort` the driver emits a distinct terminal line `SELF_CONTINUE:CHILD_ABORT rc=<rc> continuations=<N> progress=<P>`, logs `{"type":"self_continue_child_abort",...}`, and exits 0 (parallel to `STOPPED`/`CAP_REACHED`). `self-continue-status.sh` needs no change: any non-`unconfirmed` last record already reports `SELF_CONTINUE:OK last=<type>`.

M045 regression safety (verified against the existing verifiers before planning): `m045-p03-driver-terminal.sh` (stubs exit 0 + terminal words → kept), `m045-p03-driver-cap.sh` (stubs exit 0 + `rotation P##` → continue), `m045-p04-stall.sh` (stub exits 0, no marker → STALLED preserved) all remain green under this table.

## Boundary Map

**Produces**
- `scripts/lifecycle/auto-loop.sh` — single CON-2-authorized additive outcome-marker mechanism, gated on `ORCHESTRATOR_SELF_CONTINUE_MARKER=1`, atomic temp+rename (T01)
- `scripts/lifecycle/self-continue-drive.sh` — hardened: strict charset allowlist on the milestone-dir argument, argv-array child spawn (no `sh -c`), deterministic wrapper owning the `child_abort` terminal, continue-class outcome mapping, atomic `child_abort` write, `ORCHESTRATOR_SELF_CONTINUE_MARKER=1` exported to the child (T02)
- `commands/auto.md` — Outcome-marker section amended: writer-of-record division, extended vocabulary, agent MUST NOT hand-write the marker under the gate (T04)
- SC-9 non-stubbed fixture battery against the real `auto-loop.sh` exit set + CHILD_ABORT cases (T03)
- SC-10 injection-rejection fixture (T02)
- FR-17 legacy byte-parity golden + verifier (T01)
- Verifiers: `tools/verify/m046-p02-{marker-unit,legacy-parity,injection-reject,driver-continue-class,marker-exit-contract,child-abort,atomic-write-discipline,phase-suite}.sh`

**Consumes**
- M045 driver trio (`self-continue-drive.sh`, `self-continue-branch.sh`, `self-continue-status.sh`) — `branch.sh` and `status.sh` are consumed UNCHANGED
- The real `auto-loop.sh` exit-code contract (table above)
- M046 P01 fixture pattern (`.orchestrator/milestones/M046/phases/P01/spike/cost/fixture/milestones/MFIX/` — fixture root doubles as `ORCHESTRATOR_ROOT`, real auto-loop.sh driven at zero LLM spend)
- M045 P03 verifier/golden pattern (`tools/verify/m045-p03-legacy-golden.sh`, `tests/fixtures/m045-rotation-exit-legacy.golden`)

**Out of scope (later phases)**: FR-13 fail-closed caps (the silent `MAX_CONT=20` default at `self-continue-drive.sh:21` stays — P04/P05 scope), FR-7 watchdog SIGKILL (P04, lands on this phase's atomic-marker discipline), FR-9 hook (P05), unified entry (P03).

## Must-Haves

### Truths

- With `ORCHESTRATOR_SELF_CONTINUE_MARKER=1`, `auto-loop.sh` deterministically writes the outcome marker keyed to its exit code (+ exit-0 substate), verified by direct invocations of the real script
  - Check: `bash tools/verify/m046-p02-marker-unit.sh`
- With the marker gate absent, `auto-loop.sh` stdout and exit code are byte-identical to the pinned legacy golden and NO marker file is written (FR-17); with the gate present, stdout stays byte-identical and only the marker side effect is added
  - Check: `bash tools/verify/m046-p02-legacy-parity.sh`
- The marker is correct for the COMPLETE real `auto-loop.sh` exit set — exit-0 substates PLANNING/PHASE_COMPLETE/VALIDATING plus 1/2/3/10/11/12/13/14 — asserted non-stubbed against fixture milestone trees (SC-9)
  - Check: `bash tools/verify/m046-p02-marker-exit-contract.sh`
- A signal-killed child yields `child_abort` (overwriting any stale marker); a crashed child with no marker yields `child_abort`; a clean rc=0 child with no marker still surfaces `SELF_CONTINUE:STALLED` (SC-9 kill leg + M045 parity)
  - Check: `bash tools/verify/m046-p02-child-abort.sh`
- A metacharacter-bearing milestone-dir name is rejected by the driver before reaching any command line, and no injected side effect executes (SC-10 / FR-15)
  - Check: `bash tools/verify/m046-p02-injection-reject.sh`
- Continue-class markers (`rotation`/`planning`/`phase_complete`/`validating`) re-spawn under the driver; error-class markers (`error`/`unexpected_state`/`planning_failed`/`child_abort`) terminate with no re-spawn
  - Check: `bash tools/verify/m046-p02-driver-continue-class.sh`
- Every marker write in both writers (`auto-loop.sh`, `self-continue-drive.sh`) goes through atomic temp+rename; no direct redirect to the final marker path exists; a live write leaves no temp residue
  - Check: `bash tools/verify/m046-p02-atomic-write-discipline.sh`
- All P02 verifiers plus the four M045 driver regression verifiers pass as one suite
  - Check: `bash tools/verify/m046-p02-phase-suite.sh`

### Artifacts

- scripts/lifecycle/auto-loop.sh (min 640 lines, contains "ORCHESTRATOR_SELF_CONTINUE_MARKER")
- scripts/lifecycle/self-continue-drive.sh (min 95 lines, contains "child_abort")
- commands/auto.md (min 600 lines, contains "child_abort")
- tools/verify/m046-p02-marker-unit.sh (min 30 lines, contains "auto-loop.sh")
- tools/verify/m046-p02-legacy-parity.sh (min 20 lines, contains "legacy-parity.golden")
- tools/verify/m046-p02-injection-reject.sh (min 20 lines, contains "SELF_CONTINUE:REJECT")
- tools/verify/m046-p02-driver-continue-class.sh (min 25 lines, contains "phase_complete")
- tools/verify/m046-p02-marker-exit-contract.sh (min 60 lines, contains "auto-loop.sh")
- tools/verify/m046-p02-child-abort.sh (min 30 lines, contains "child_abort")
- tools/verify/m046-p02-atomic-write-discipline.sh (min 20 lines, contains "self-continue-outcome")
- tools/verify/m046-p02-phase-suite.sh (min 15 lines, contains "m046-p02")
- tests/fixtures/m046-p02/legacy-parity.golden (min 1 lines, contains "AUTO:")

### Key Links

- tools/verify/m046-p02-marker-exit-contract.sh → scripts/lifecycle/auto-loop.sh (battery drives the real script)
- tools/verify/m046-p02-child-abort.sh → scripts/lifecycle/self-continue-drive.sh (kill cases run through the real driver)
- tools/verify/m046-p02-phase-suite.sh → tools/verify/m046-p02-marker-exit-contract.sh (aggregator runs the battery)
- commands/auto.md → scripts/lifecycle/self-continue-drive.sh (marker writer-of-record documentation names the driver)

## Tasks

### T01: auto-loop.sh outcome-marker mechanism + FR-17 legacy parity

The single CON-2-authorized additive change (Insertions A + B per the accounting above), env-gated, atomic. Co-authors `tools/verify/m046-p02-marker-unit.sh`, the legacy golden at `tests/fixtures/m046-p02/legacy-parity.golden`, `tools/verify/m046-p02-legacy-parity.sh`, and the shared fixture tree `tests/fixtures/m046-p02/verifying-tree/`. See `tasks/T01-marker-write-PLAN.md`.

### T02: driver injection hardening + deterministic CHILD_ABORT wrapper

FR-15: charset allowlist at entry, argv-array spawn replacing `sh -c` at `self-continue-drive.sh:57`, rc-capturing wrapper implementing the truth table, atomic `child_abort` write, continue-class mapping, env-gate export. Co-authors `tools/verify/m046-p02-injection-reject.sh` (SC-10) and `tools/verify/m046-p02-driver-continue-class.sh`; re-runs the four M045 driver verifiers. See `tasks/T02-driver-hardening-PLAN.md`.

### T03: SC-9 non-stubbed full-exit-set battery + CHILD_ABORT fixture

Fixture milestone trees under `tests/fixtures/m046-p02/exit-trees/` driving the REAL `auto-loop.sh` to every exit code; `tools/verify/m046-p02-marker-exit-contract.sh` asserts observed-exit AND marker-content per case; `tools/verify/m046-p02-child-abort.sh` runs kill/crash/stall cases through the real driver. See `tasks/T03-exit-contract-battery-PLAN.md`.

### T04: atomic-write discipline verifier + auto.md amendment + phase suite

`tools/verify/m046-p02-atomic-write-discipline.sh` (static shape + residue check), `commands/auto.md` Outcome-marker section rewrite (writer division, vocabulary, agent-must-not-hand-write under gate), `tools/verify/m046-p02-phase-suite.sh` aggregator (all P02 verifiers + 4 M045 regression verifiers). See `tasks/T04-atomicity-docs-suite-PLAN.md`.

## Task Dependencies

- T01 → T03 (battery asserts T01's marker map)
- T02 → T03 (child-abort cases run through T02's wrapper)
- T01 + T02 → T04 (static discipline checks read both writers; suite runs everything)
- T01 and T02 are independent of each other and may run in either order (T01 first is recommended: T02's continue-class verifier uses marker words T01's table defines, though only via stubs).

## Files Likely Touched

- scripts/lifecycle/auto-loop.sh (modify)
- scripts/lifecycle/self-continue-drive.sh (modify)
- commands/auto.md (modify)
- tools/verify/m046-p02-marker-unit.sh (create)
- tools/verify/m046-p02-legacy-parity.sh (create)
- tools/verify/m046-p02-injection-reject.sh (create)
- tools/verify/m046-p02-driver-continue-class.sh (create)
- tools/verify/m046-p02-marker-exit-contract.sh (create)
- tools/verify/m046-p02-child-abort.sh (create)
- tools/verify/m046-p02-atomic-write-discipline.sh (create)
- tools/verify/m046-p02-phase-suite.sh (create)
- tests/fixtures/m046-p02/legacy-parity.golden (create)
- tests/fixtures/m046-p02/verifying-tree/ (create, directory tree)
- tests/fixtures/m046-p02/exit-trees/ (create, directory tree)

## Plan-Time Discipline Evidence

- **Prerequisite existence** (rule 1): `scripts/lifecycle/auto-loop.sh`, `scripts/lifecycle/self-continue-drive.sh`, `scripts/lifecycle/self-continue-branch.sh`, `scripts/diagnostics/self-continue-status.sh`, `scripts/dispatch/detect-capabilities.sh`, `tests/fixtures/m045-rotation-exit-legacy.golden`, `tools/verify/m045-p03-{driver-terminal,driver-cap,legacy-golden}.sh`, `tools/verify/m045-p04-stall.sh`, `templates/phase-plan.md`, `templates/task-plan.md`, `scripts/util/classify-command.sh` — ALL verified present on disk 2026-07-13.
- **Verifier availability** (rule 2): every `## Verification` command resolves either to a script that exists today (M045 verifiers, `check-must-haves.sh`) or to a verifier co-authored inside the same task's `## Steps` (rule 2 clause (a)).
- **Classifier pre-validation** (rule 3): `bash scripts/util/classify-command.sh "bash tools/verify/m046-p02-marker-exit-contract.sh"` → `AUTO_SAFE`; `bash scripts/util/classify-command.sh "bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M046/phases/P02"` → `AUTO_SAFE` (run 2026-07-13). All Check/Verification commands use the same single-script-file shape.
- **run-probe scope** (rule 4): not used; all verifiers invoked directly.
- **Real-DB rule** (rule 5): no SQL in this phase.
- **Path collisions** (rule 6): `ls` run 2026-07-13 against every `create` path above — all absent (exit 1, "No such file or directory"). No collision with M045/M046-P01 verifiers (`m045-*`, `m046-p01-*` prefixes disjoint).
- **Corpus-exhaustion gate**: this plan embeds no operator/SME-destined open questions — gate not required.

## Risks

- **Fixture drivability of exits 2/3/13/14** (medium): budget/stuck/planning-failed/rotate depend on `budget-checker.sh` / `stuck-detector.sh` / `build-context.sh` / `context-monitor.sh` thresholds. T03 includes an explicit probe step; the battery asserts BOTH observed exit code AND marker content per case, so a mis-designed fixture fails loud (never a false pass). The P01 MFIX pattern (fixture root doubles as `ORCHESTRATOR_ROOT`) is the proven substrate.
- **Env-gate propagation through a real `claude -p`** (low): the SC-9 battery exercises driver → wrapper → real `auto-loop.sh` directly (non-stubbed per the gate's definition — real auto-loop, zero LLM spend, same standard P01 applied). Propagation of exported env through a live claude child follows the established `CONVERSUS_PROVIDER` / `ORCHESTRATOR_TIER2_LIVE` inheritance pattern; the live-e2e leg is discharged by the P04/P05 unattended gates that spawn real children.
- **Trap-under-`set -euo pipefail`** (low): the writer runs in an EXIT trap; it must capture `$?` first, guard all expansions with `${VAR:-}` (early exit-1 paths fire before `ROADMAP_FILE` is set), and internally `|| true` non-critical steps so the trap never alters the script's exit code. Specified verbatim in T01.
- **Deep-modules lens**: no new helper scripts beyond per-phase verifiers; the marker mechanism deliberately lives inside the two existing modules (auto-loop owns its own outcome report; the driver owns the child lifecycle) rather than a third shared lib — passing the deletion test (removing either leaves the other's seam intact).

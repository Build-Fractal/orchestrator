---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M046"
name: "Atomic-write discipline verifier + auto.md amendment + phase suite"
depends_on: [T01, T02, T03]
---

## Prerequisites

- T01–T03 complete. Confirm with `ls`: `tools/verify/m046-p02-marker-unit.sh`, `tools/verify/m046-p02-legacy-parity.sh`, `tools/verify/m046-p02-injection-reject.sh`, `tools/verify/m046-p02-driver-continue-class.sh`, `tools/verify/m046-p02-marker-exit-contract.sh`, `tools/verify/m046-p02-child-abort.sh` all exist and pass.
- `commands/auto.md` exists; its "Outcome marker" paragraph is at ~line 561 (`grep -n "Outcome marker" commands/auto.md` to locate).

## Description

Close the phase: (1) verify the atomic temp+rename discipline on BOTH marker writers, (2) amend `commands/auto.md` so the documented marker contract matches the FR-14 writer division of labor, (3) author the phase-suite aggregator that runs all P02 verifiers plus the four M045 driver regression verifiers.

## Steps

1. **Author `tools/verify/m046-p02-atomic-write-discipline.sh`** (POSIX sh, executable, `set -eu`). Two legs:
   - **Static shape leg** — assert by grep against the two writer files:
     - `scripts/lifecycle/auto-loop.sh`: the marker writer uses a temp path (a line matching `\.self-continue-outcome\.tmp`) followed by an `mv -f` onto the final path; AND there is NO direct redirect to the final marker path (zero occurrences of a `> ...` redirect whose target is the literal final `.self-continue-outcome` path — the only writes to the final basename must be `mv` renames). Implement as: count lines matching a write-redirect to the final name excluding `.tmp`, expect 0; count `mv -f` lines mentioning `.self-continue-outcome`, expect >= 1.
     - `scripts/lifecycle/self-continue-drive.sh`: same pair of assertions for the `child_abort` write (temp write + `mv -f "$_abort_tmp" "$OUTCOME_FILE"`; no direct redirect to `$OUTCOME_FILE`). Note line 56's `rm -f "$OUTCOME_FILE"` is a removal, not a write — the grep must not flag it.
   - **Behavioral residue leg** — copy `tests/fixtures/m046-p02/verifying-tree/MFIX` to scratch; run the gate-on pause case (`touch pause-requested`, run real auto-loop, expect exit 11); assert the marker content is exactly `pause` AND no `.self-continue-outcome.tmp.*` residue file exists in the scratch milestone dir.
   - `PASS:`/`FAIL:` lines; non-zero exit on any failure.

2. **Amend `commands/auto.md`** — replace the "Outcome marker" paragraph (currently: "at each exit path ... the loop additionally writes `<milestone-dir>/.self-continue-outcome` with one of `rotation <phase>` / `complete` / `blocked` / `budget` / `stuck` / `pause`. This marker is inert unless...") with the FR-14 contract. The replacement must state:
   - **Writer of record (driver-gated runs)**: when `ORCHESTRATOR_SELF_CONTINUE_MARKER=1` (exported by `self-continue-drive.sh`), `auto-loop.sh` itself writes the marker deterministically at every exit, keyed to its full exit-code contract — exit-0 substates `AUTO:PLANNING` → `planning <phase>`, `AUTO:PHASE_COMPLETE` → `phase_complete <phase>`, `AUTO:MILESTONE_VALIDATING` → `validating`; exit 14 → `rotation <phase>`; exits 1/2/3/10/11/12/13 → `error`/`budget`/`stuck`/`complete`/`pause`/`unexpected_state`/`planning_failed`. The agent MUST NOT hand-write `.self-continue-outcome` in gated runs — a hand-write would shadow the deterministic writer of record (`blocked` is the one entry-layer word the agent may still write, at BLOCK decision points outside `auto-loop.sh`).
   - **Driver-owned terminal**: a child killed by a signal or crashed before reporting yields `child_abort`, written by the driver's deterministic shell wrapper — never a silent stall for a killed child; the driver surfaces it as `SELF_CONTINUE:CHILD_ABORT rc=<rc>`.
   - **Continue-class vs terminal**: `rotation|planning|phase_complete|validating` re-spawn (still gated by arming + `headless_reentry` via `self-continue-branch.sh`); all other words are terminals.
   - **Atomicity**: every marker write is temp + `rename(2)` (`mv -f`), so a kill landing mid-write leaves the old or the new marker whole, never a torn one.
   - **Attended legacy parity (FR-17)**: without the env gate the marker mechanism is inert and attended behavior is byte-unchanged from M045; the attended manual marker convention remains as documented for non-driver runs.
   - Keep the amendment surgical — only this section changes; the surrounding `--self-continue` launch/driver documentation stays.

3. **Author `tools/verify/m046-p02-phase-suite.sh`** (POSIX sh, executable). Runs, in order, each with its own pass/fail capture (flat sequence, no loop-over-array cleverness needed):
   - `tools/verify/m046-p02-marker-unit.sh`
   - `tools/verify/m046-p02-legacy-parity.sh`
   - `tools/verify/m046-p02-injection-reject.sh`
   - `tools/verify/m046-p02-driver-continue-class.sh`
   - `tools/verify/m046-p02-marker-exit-contract.sh`
   - `tools/verify/m046-p02-child-abort.sh`
   - `tools/verify/m046-p02-atomic-write-discipline.sh`
   - M045 regression: `tools/verify/m045-p03-driver-terminal.sh`, `tools/verify/m045-p03-driver-cap.sh`, `tools/verify/m045-p03-legacy-golden.sh`, `tools/verify/m045-p04-stall.sh`
   - Emit one `SUITE: <name> PASS|FAIL` line per verifier and a final `SUMMARY: pass=N fail=M` (expect `pass=11 fail=0`); exit non-zero if any fail. Model on `tools/verify/m046-p01-phase-suite.sh`.

## Must-Haves

- Every marker write in both writers goes through atomic temp+rename; no direct redirect to the final marker path; a live write leaves no temp residue
  - Check: `bash tools/verify/m046-p02-atomic-write-discipline.sh`
- All P02 verifiers plus the four M045 driver regression verifiers pass as one suite
  - Check: `bash tools/verify/m046-p02-phase-suite.sh`

## Verification

```bash
bash tools/verify/m046-p02-atomic-write-discipline.sh
bash tools/verify/m046-p02-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M046/phases/P02
```

## Notes

Expected output: discipline verifier all-PASS; suite `SUMMARY: pass=11 fail=0`; `check-must-haves.sh` reports PASS for every Truth/Artifact/Key-Link in `P02-PLAN.md`.

Tier-3 residual (documented, accepted): the mid-write-kill guarantee ("old-or-new, never torn") is structural — it follows from `rename(2)` atomicity on a same-filesystem `mv`, which the static leg proves is the only write path. A deterministic behavioral race test would require killing between temp-write and rename, which cannot be forced without instrumenting the writers; the P04 SIGKILL watchdog work will exercise this surface live and inherits this discipline as a stated dependency (roadmap cross-cutting note: "P04's SIGKILL paths depend on it").

## Inputs

### From Previous Tasks

- `scripts/lifecycle/auto-loop.sh` (T01) — marker writer shape: temp `\.self-continue-outcome.tmp.$$` + `mv -f` inside `_write_outcome_marker()`.
- `scripts/lifecycle/self-continue-drive.sh` (T02) — `child_abort` writer shape: `_abort_tmp="$OUTCOME_FILE.tmp.$$"` + `mv -f`.
- All six T01–T03 verifiers (paths listed in Prerequisites) — the suite's members.
- `tests/fixtures/m046-p02/verifying-tree/MFIX/` (T01) — behavioral-leg fixture.

### From Disk (Pre-existing)

- `commands/auto.md` — amendment target ("Outcome marker" section, ~line 561).
- `tools/verify/m046-p01-phase-suite.sh` — aggregator shape to model.
- `tools/verify/m045-p03-driver-terminal.sh`, `m045-p03-driver-cap.sh`, `m045-p03-legacy-golden.sh`, `m045-p04-stall.sh` — regression members.

## Constraints

- Do NOT modify `auto-loop.sh` or `self-continue-drive.sh` in this task — if the discipline verifier finds a violation, the fix belongs to the owning task's change-set (report and route, per T03's constraint pattern).
- `commands/auto.md` is entry-layer documentation — CON-2 permits it; keep the edit confined to the Outcome-marker contract section.
- The suite must return non-zero on any member failure (it is the phase's single-command gate).

## Expected Output

- `tools/verify/m046-p02-atomic-write-discipline.sh` — green.
- `commands/auto.md` — Outcome-marker section rewritten per step 2 (contains `child_abort`, `phase_complete`, `ORCHESTRATOR_SELF_CONTINUE_MARKER`).
- `tools/verify/m046-p02-phase-suite.sh` — `SUMMARY: pass=11 fail=0`.

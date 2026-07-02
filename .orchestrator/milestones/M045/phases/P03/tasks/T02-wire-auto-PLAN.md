---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M045"
name: "Wire commands/auto.md to the driver + pin the legacy golden (SC-4)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/lifecycle/self-continue-drive.sh` exists.

## Description

Two small, additive changes: (1) document in `commands/auto.md` that `--self-continue` launches the driver, and add an **outcome marker** write at each rotation/terminal exit path so the driver can classify the segment; (2) pin the SC-4 legacy golden and a verifier. Neither changes the rotation-exit DECISION — legacy parity (FR-8) holds.

## Steps

1. In `commands/auto.md`, update the `## Self-Continue (M045 …)` section (added in P02): replace the P02 "Status: … wired in P03" note with the live launch contract:
   ```markdown
   **Launch**: `--self-continue` runs the milestone under the process-fresh
   driver `scripts/lifecycle/self-continue-drive.sh <milestone-dir>
   [--max-continuations N] [--min-interval S] [--stop-file <path>]`. The driver
   re-spawns a fresh `claude -p "orchestrator:auto <milestone-dir>"` (single-
   segment, no `--self-continue`) after each rotation-exit, until a terminal
   outcome, the cap, or the stop-file. Interrupt a run by creating the stop-file.
   ```
2. In `commands/auto.md`, in the `## Context Rotation Check` section step (c) (where it writes `continue.md`), add an additive step: also write `<milestone-dir>/.self-continue-outcome` containing `rotation <active-phase>`. And in the terminal exit paths (`## Completion` complete; phase-verification failure; budget/stuck/pause), write the matching word (`complete` / `blocked` / `budget` / `stuck` / `pause`). Frame these as: "Emit the self-continue outcome marker (inert unless running under `--self-continue`; consumed by `self-continue-drive.sh` to decide re-spawn vs stop)." Keep them additive — do NOT change the exit decision or the human-facing report.
3. Create the SC-4 golden `tests/fixtures/m045-rotation-exit-legacy.golden` containing exactly the byte-stable un-armed rotation directive:
   ```
   AUTO:ROTATE_EXIT reason=not-armed
   ```
4. Author `tools/verify/m045-p03-legacy-golden.sh`:
   ```sh
   #!/usr/bin/env sh
   # SC-4: un-armed rotation-exit output is byte-identical to the pinned golden.
   set -eu
   GOLD="tests/fixtures/m045-rotation-exit-legacy.golden"
   ACTUAL="$(bash scripts/lifecycle/self-continue-branch.sh --monitor-status 'CONTEXT:ROTATE weight=9 limit=3' --armed false --headless true)"
   EXPECT="$(cat "$GOLD")"
   [ "$ACTUAL" = "$EXPECT" ] || { echo "FAIL: un-armed output drifted from golden"; echo " expect: $EXPECT"; echo " actual: $ACTUAL"; exit 1; }
   echo "PASS: golden matches ($EXPECT)"
   ```
5. `chmod +x tools/verify/m045-p03-legacy-golden.sh` and run it.

## Must-Haves

- `commands/auto.md` documents the driver launch + the outcome-marker emission.
- Golden fixture exists; the un-armed branch output matches it byte-for-byte.

## Verification

`bash tools/verify/m045-p03-legacy-golden.sh`
`bash tools/verify/m045-p02-arming-surface.sh`

## Inputs

### From Previous Tasks
- `scripts/lifecycle/self-continue-drive.sh` (T01) — reads `<milestone-dir>/.self-continue-outcome` (`<outcome> [<phase>]`).
- `scripts/lifecycle/self-continue-branch.sh` (P02) — un-armed rotation → `AUTO:ROTATE_EXIT reason=not-armed` (the golden).

### From Disk (Pre-existing)
- `commands/auto.md` — `## Self-Continue` (P02) + `## Context Rotation Check` + `## Completion` sections.

## Constraints

- Additive only: the outcome-marker writes and the driver-launch doc must NOT alter the rotation-exit decision or the legacy human handoff (FR-8).
- `## Verification` block = check commands only (AD-19).

## Expected Output

`auto.md` documents the live driver + emits outcome markers; SC-4 golden pinned and matching.

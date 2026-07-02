---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M045"
goal: "Wire self-continue live: a process-fresh driver that re-spawns claude -p across rotation boundaries until a terminal state, with the full safety envelope (cap, terminal guards, min-interval, interruptibility) and legacy parity."
demo_sentence: "With --self-continue armed + headless_reentry, a run advances across rotation boundaries by re-spawning fresh claude -p processes and halts on every terminal state or at max-continuations; un-armed, the rotation path is byte-identical to the legacy golden capture."
risk: "high"
depends_on: ["P02"]
---

## Must-Haves

### Truths

- The driver re-spawns after a rotation-exit but STOPS on every terminal outcome (complete/blocker/budget/stuck/pause) — no re-spawn.
  - Check: `bash tools/verify/m045-p03-driver-terminal.sh`
- The driver halts at max-continuations with a `SELF_CONTINUE:CAP_REACHED` marker carrying a forward-progress field.
  - Check: `bash tools/verify/m045-p03-driver-cap.sh`
- The un-armed rotation-exit output is byte-identical to a version-pinned legacy golden capture.
  - Check: `bash tools/verify/m045-p03-legacy-golden.sh`

### Artifacts

- scripts/lifecycle/self-continue-drive.sh (min 40 lines, contains "SELF_CONTINUE:CAP_REACHED")
- tests/fixtures/m045-rotation-exit-legacy.golden (min 1 lines, contains "AUTO:ROTATE_EXIT")
- tools/verify/m045-p03-driver-terminal.sh (min 12 lines, contains "terminal")
- tools/verify/m045-p03-driver-cap.sh (min 12 lines, contains "CAP_REACHED")
- tools/verify/m045-p03-legacy-golden.sh (min 8 lines, contains "golden")

### Key Links

- scripts/lifecycle/self-continue-drive.sh → scripts/lifecycle/self-continue-branch.sh (driver consults the branch for the armed×capable decision)

## Tasks

### T01: Author the process-fresh driver scripts/lifecycle/self-continue-drive.sh

See `tasks/T01-driver-PLAN.md`.

### T02: Wire commands/auto.md to the driver + pin the legacy golden (SC-4)

See `tasks/T02-wire-auto-PLAN.md`.

### T03: Driver safety fixtures — SC-2 (terminal) + SC-3 (cap + progress)

See `tasks/T03-driver-fixtures-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03
```

## Files Likely Touched

- scripts/lifecycle/self-continue-drive.sh (create)
- commands/auto.md (modify — document driver launch + confirm rotation-exit marker; NO change to the exit decision itself)
- tests/fixtures/m045-rotation-exit-legacy.golden (create)
- tools/verify/m045-p03-driver-terminal.sh (create)
- tools/verify/m045-p03-driver-cap.sh (create)
- tools/verify/m045-p03-legacy-golden.sh (create)

## Notes

- **Driver-outer design (low-risk):** `auto.md`'s rotation branch already writes `continue.md` (reason: context_rotation) and exits. The new **outer driver** re-spawns a fresh `claude -p "/orchestrator-auto <milestone>"` after each rotation-exit — that is the process-fresh re-entry (D015). So `auto.md` barely changes (document the driver launch + ensure the rotation-exit marker is machine-readable); the live exit decision is untouched, preserving legacy parity (FR-8). This is materially lower-risk than an in-line rewrite of the rotation branch.
- **Hermetic tests:** the driver takes `--auto-cmd "<cmd>"` (default `claude -p ...`). Fixtures inject a STUB auto step (a shell script that simulates rotation-exit then terminal) so the driver's loop/cap/terminal/interrupt logic is verified WITHOUT real `claude -p` / LLM cost.
- **Safety envelope:** cap (FR-5) + forward-progress field, min-interval between spawns (FR-5a reframed — no scheduler floor under process-fresh, but bound busy-spawn), terminal-states-never-respawn (FR-4), interruptibility via a stop-file (FR-6). Basic continuity markers emitted here; the full FR-9/FR-10 observability + `SELF_CONTINUE:STALLED` is P04.
- **`claude -p` recursion guard:** the child `claude -p /orchestrator-auto` MUST run WITHOUT `--self-continue` (single-segment: run until rotation-exit or terminal, then exit) so the child does not itself spawn a nested driver. The driver is the sole outer loop.

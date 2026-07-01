---
schema_version: "1.0"
type: phase-summary
phase: "P02"
milestone: "M045"
outcome: complete
---

# P02 Summary — Decision core (branch + capability + arming)

## Delivered

- **`scripts/dispatch/detect-capabilities.sh`** — new `headless_reentry` capability (can spawn a fresh `claude -p`; the D015 process-fresh substrate), in text + JSON. (T01)
- **`scripts/lifecycle/self-continue-branch.sh`** — deterministic FR-3 directive: `AUTO:SELF_CONTINUE` / `AUTO:ROTATE_EXIT reason=...` / `AUTO:NO_ROTATION` per the armed × capable × rotation truth table. (T02)
- **`commands/auto.md`** — `## Self-Continue` section documenting the `--self-continue` opt-in (default OFF, CON-4), the gate, and the directives. Doc-only. (T03)
- **Verifiers**: `tools/verify/m045-p02-{headless-capability,branch-truth-table,arming-surface}.sh` — all PASS (SC-5 = the truth-table verifier).

## Key decisions honored

- **Non-breaking (legacy parity FR-8)**: the live rotation-exit behavior is untouched; P02 is decision-core + docs only. The spawn wiring is P03.
- **Substrate = process-fresh (D015)**: the branch gates on `headless_reentry`, not the rejected `schedule_wakeup`.
- **Policy in shell (Principle X)**: the self-continue decision is a deterministic script; the agent only acts on its directive.

## For P03

Wire `commands/auto.md`'s `## Context Rotation Check` branch to: run
`context-monitor` → feed status + armed + capability to
`self-continue-branch.sh` → on `AUTO:SELF_CONTINUE`, spawn a process-fresh
`claude -p` re-entry (productionize the P01 spike driver) with the terminal-state
guards (FR-4), max-continuations cap + progress field (FR-5), min-spawn-interval
(FR-5a reframed), interruptibility (FR-6); on `AUTO:ROTATE_EXIT`, the existing
legacy handoff. Then SC-2/SC-3/SC-4 fixtures + the golden legacy baseline.

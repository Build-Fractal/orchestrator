---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M045"
goal: "Build the substrate-agnostic decision core of self-continuing auto: a deterministic rotation-branch directive, headless-reentry capability detection, and the arming surface — WITHOUT yet changing the live rotation-exit behavior (that wiring is P03)."
demo_sentence: "Given CONTEXT:ROTATE plus armed/capable flags, scripts/lifecycle/self-continue-branch.sh prints exactly AUTO:SELF_CONTINUE or AUTO:ROTATE_EXIT per the truth table; detect-capabilities.sh reports headless_reentry; and commands/auto.md documents the --self-continue arming surface — all while today's rotation exit still behaves identically."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- `detect-capabilities.sh` reports a `headless_reentry` capability reflecting whether a fresh `claude -p` can be spawned.
  - Check: `bash tools/verify/m045-p02-headless-capability.sh`
- The deterministic branch prints exactly one correct directive for every row of the armed × capable × rotation truth table.
  - Check: `bash tools/verify/m045-p02-branch-truth-table.sh`
- `commands/auto.md` documents the `--self-continue` arming surface and that it defaults OFF (explicit opt-in, spec CON-4).
  - Check: `bash tools/verify/m045-p02-arming-surface.sh`

### Artifacts

- scripts/lifecycle/self-continue-branch.sh (min 30 lines, contains "AUTO:SELF_CONTINUE")
- tools/verify/m045-p02-branch-truth-table.sh (min 15 lines, contains "AUTO:ROTATE_EXIT")
- tools/verify/m045-p02-headless-capability.sh (min 8 lines, contains "headless_reentry")
- tools/verify/m045-p02-arming-surface.sh (min 8 lines, contains "self-continue")

### Key Links

- scripts/lifecycle/self-continue-branch.sh → scripts/dispatch/detect-capabilities.sh (branch consults the headless_reentry capability)

## Tasks

### T01: Add `headless_reentry` capability to detect-capabilities.sh

See `tasks/T01-headless-capability-PLAN.md`.

### T02: Author scripts/lifecycle/self-continue-branch.sh (deterministic directive) + SC-5 truth-table

See `tasks/T02-branch-directive-PLAN.md`.

### T03: Document the `--self-continue` arming surface in commands/auto.md

See `tasks/T03-arming-surface-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03
```

(T02 consumes T01's capability field; T03 documents the surface that T02's branch enforces.)

## Files Likely Touched

- scripts/dispatch/detect-capabilities.sh (modify)
- scripts/lifecycle/self-continue-branch.sh (create)
- commands/auto.md (modify — documentation only in P02; live rotation-branch rewrite is P03)
- tools/verify/m045-p02-headless-capability.sh (create)
- tools/verify/m045-p02-branch-truth-table.sh (create)
- tools/verify/m045-p02-arming-surface.sh (create)

## Notes

- **Non-breaking discipline**: P02 builds the decision core but does NOT rewrite `commands/auto.md`'s rotation-exit behavior — the live loop still writes `continue.md` + exits for a human. That rewrite (directive → spawn a fresh `claude -p` re-entry) is P03. P02's `auto.md` change is documentation of the arming surface only. This keeps the milestone shippable-at-every-phase and preserves legacy parity (spec FR-8) until P03 wires the swap under capability + arming gates.
- **Substrate = process-fresh (D015)**: `headless_reentry` (can we spawn `claude -p`?) is the capability the branch gates on, replacing the rejected `schedule_wakeup`. The branch itself is substrate-agnostic — it emits a directive; P03 decides the directive triggers a `claude -p` spawn.
- **Truth table (SC-5)**: `armed=true  & headless_reentry=true & rotation → AUTO:SELF_CONTINUE`; every other combination (un-armed, or not capable, or no rotation) → `AUTO:ROTATE_EXIT` (legacy). This is the FR-3/FR-7/FR-8 contract in one table.

---
schema_version: "1.0"
type: phase-summary
phase: "P03"
milestone: "M045"
outcome: complete
---

# P03 Summary — Live wiring + safety envelope (process-fresh driver)

## Delivered

- **`scripts/lifecycle/self-continue-drive.sh`** (T01) — the outer process-fresh loop (FR-2/4/5/5a/6, D015): re-spawns a fresh `claude -p` auto segment per rotation-exit until a terminal outcome, the `--max-continuations` cap, or a `--stop-file`. Emits `SELF_CONTINUE:SCHEDULED|TERMINAL|CAP_REACHED|STOPPED` with `continuations=` + a `progress=` field that increments only on phase change (thrash detection, conversus MIT-5).
- **`commands/auto.md`** (T02) — `## Self-Continue` section updated to the live launch contract (driver invocation + outcome-marker emission at each exit path). Additive; the rotation-exit decision + legacy human handoff are UNCHANGED (FR-8 legacy parity).
- **`tests/fixtures/m045-rotation-exit-legacy.golden`** (T02) — SC-4 pinned baseline (`AUTO:ROTATE_EXIT reason=not-armed`).
- **Verifiers** (all PASS): `m045-p03-driver-terminal.sh` (SC-2 — 5/5 terminal outcomes stop, 0 re-spawn), `m045-p03-driver-cap.sh` (SC-3 — cap halts; thrash progress=1 vs healthy progress=3), `m045-p03-legacy-golden.sh` (SC-4).

## Design win

The **driver-outer** model kept this low-risk: `auto.md` already exits on rotation, so the driver simply re-spawns — no in-line rotation-branch rewrite. `auto.md`'s live exit decision is untouched (regression suite unchanged at 33/35; the 2 fails are pre-existing). Each re-spawn is a genuinely fresh process (process-fresh context reset — the property P01 proved in-session re-entry lacks).

## Verification

Phase must-haves: 19 PASS / 0 FAIL. `test-s08-auto-safety.sh` 33/35 (2 pre-existing, stash-confirmed). All fixtures hermetic (stub `--auto-cmd`, no real `claude -p`).

## For P04

Wire the driver's `SELF_CONTINUE:*` events + the `.self-continue-outcome` markers into the execution log as FR-9 record types (`self_continue_scheduled`/`cap_reached`/`unavailable`) + the FR-10 `self_continue_unconfirmed` / `SELF_CONTINUE:STALLED` watchdog surfaced via `orchestrator:status` (M029), plus the flagship SC-1 continuity fixture and SC-7 stall fixture.

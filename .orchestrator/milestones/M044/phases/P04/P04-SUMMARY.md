---
schema_version: "1.0"
type: phase-summary
phase: "P04"
milestone: "M044"
status: complete
---

# M044/P04 Summary — Capture-by-Default at Quick + Decisions Digest

The capture→store→inject loop is now closed at the default (Quick) intensity: an
explicitly-captured decision is recorded regardless of intensity, and the Quick
inject carries a bounded Decisions digest. Three tasks, all verified; phase-suite
`BATTERY: pass=3 fail=0`.

## What shipped

- **T01 — FR-8/G-1 explicit-decision capture at Quick.** `intensity-knowledge.sh`
  ran only `write-summary.sh` at Quick (`:92`) — it never captured decisions (G-1).
  Added a repeatable `--decision-arg <value>` flag that accumulates
  `append-decision.sh`'s argv and runs the legacy primitive (DQ-7 — no net-new verb)
  at **any** intensity, including Quick, independent of the intensity-gated auto
  steps. A decision-only capture (explicit decision + no `--` forwarded args) skips
  the auto steps (which need args and would fail) — strictly additive: a
  no-explicit-decision run is unchanged (the m008 step-count tests stay green), and a
  full close-flow run still runs both the auto steps and the decision.
- **T02 — FR-6 bounded budget-bounded Decisions digest at Quick.** `build-context.sh`
  direct-mode omitted the Decisions section under the Quick profile (the
  `if [ "$PROFILE" != "quick" ]` guard) and emitted only a marker otherwise — a Quick
  project shipped an empty-forever Decisions slot (G-2). New sourceable lib
  `scripts/dispatch/lib/decisions-digest.sh::dd_decisions_digest` reads the
  system-of-record `DECISIONS.md`, ranks rows newest-first, and routes the
  read-into-payload through the M036a `reference_apply_budget` governor (CON-2 — no
  silent over-inject, at-least-one invariant). Deterministic: file order is the rank,
  no wall-clock (CON-3). The lib is extracted (mirroring P01's
  `knowledge-provenance.sh`) so it's unit-testable independently of build-context's
  hardcoded `PROJECT_ROOT`. `build-context.sh` always emits `## Decisions` at Quick;
  an empty corpus yields a visible `(no decisions on record)` sentinel, never a
  silent omission. **Ships in the same phase as T01** so a Quick project never carries
  an empty-forever Decisions slot.
- **T03 — Capture-by-default round-trip (SC-8/SC-9).** Capture an explicit decision at
  Quick → it lands in `DECISIONS.md` in consumer-order (composes P02) → survives
  `rebuild-index.sh` → is resolved by `dd_decisions_digest`, the same function
  `build-context.sh` injects with. Because `build-context.sh` hardcodes
  `PROJECT_ROOT` to its own repo location (no override), the round-trip composes
  through the digest function against the fixture `DECISIONS.md`; the live
  `## Decisions` emit over the real repo is covered by T02's live lane.

## Verification

- Phase suite: `bash tools/verify/m044-p04-phase-suite.sh` → `BATTERY: pass=3 fail=0`.
- Framework must-haves: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M044/phases/P04` → all truths/artifacts/key-links PASS.
- Regression: `m008-p03` knowledge-pipeline + integration-e2e + bash32-compat (auto
  pipeline step counts unchanged), `m031-acceptance/test-build-context-profile`,
  `p03-build-context-delegates`, `m018-p02` filter suites, and the M044 P01 suite all
  green.

## Carried forward (Non-Goals, forward-pointed)

- The discoverable `/orchestrator-capture` + `/orchestrator-promote` command UX, the
  FR-8 auto-graduate-at-phase-close half, and the graduation mechanism + SoR docs are
  M040-track (DQ-7/DQ-8). P0 shipped the write primitive + round-trip confirmation
  only.
- Live runtime-memory read is cut (DQ-8, M009). P0 ships only the enforcement warning
  (P01).

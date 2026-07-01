---
schema_version: "1.0"
type: roadmap
milestone: "M045"
feature_ref: "046-self-continuing-auto"
feature_spec: "specs/046-self-continuing-auto/spec.md"
vision: "The Tier C autonomous loop continues itself across context-rotation boundaries via process-fresh claude -p re-entry — kick it once and it runs to a terminal state without a human re-invoking at each rotation. (Substrate pivoted from in-session ScheduleWakeup to process-fresh per P01/D015, 2026-07-01.)"
tier: "C"
created_at: "2026-07-01"
updated_at: "2026-07-01"
---

## Phases

- [x] **P01**: Viability spike — does in-session re-entry relieve context? — **DONE 2026-07-01, VERDICT PARTIAL.** In-session `ScheduleWakeup` re-entry preserves correctness but NOT per-rotation context relief; substrate pivoted to process-fresh `claude -p` per decision D015 / CON-5. Evidence: `.orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md`.
  - Risk: high
  - Depends: none
  - **Decision gate (fired)**: resolved #Q-1 / SC-6. Outcome was not the expected PASS — the in-session premise failed on the axis rotation targets, routing the re-entry substrate to process-fresh per CON-5. P02–P04 proceed with the substrate swapped (mechanism otherwise ~unchanged). #Q-2 resolved: `ScheduleWakeup` is `/loop`-only; moot under process-fresh (arming becomes a driver flag).
  - Boundary Map:
    - Produces: `.orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md` (VERDICT + #Q-1/#Q-2 resolution); throwaway spike harness under `phases/P01/spike/`; verifiers `tools/verify/m045-p01-*.sh`
    - Consumes: `scripts/lifecycle/context-monitor.sh` (real rotation detector); the `ScheduleWakeup` primitive (tested, rejected as substrate)
- [x] **P02**: Deterministic branch + capability detection + arming surface — **DONE 2026-07-01.** `self-continue-branch.sh` (SC-5 truth table PASS), `headless_reentry` capability, `--self-continue` arming docs in `auto.md` (doc-only; non-breaking). — "Given CONTEXT:ROTATE plus armed/available flags, a deterministic script prints exactly one of AUTO:SELF_CONTINUE / AUTO:ROTATE_EXIT per the truth table, and capability-absent yields the legacy-exit directive."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/lifecycle/self-continue-branch.sh` (FR-3 deterministic directive); `scripts/dispatch/detect-capabilities.sh` extended with a `headless_reentry` field (can we spawn a fresh `claude -p`? — replaces the rejected `schedule_wakeup` capability, FR-7); the arming surface in `commands/auto.md` (FR-1, a driver/launch flag under the process-fresh model); SC-5 truth-table fixture
    - Consumes: P01 substrate decision (D015: process-fresh `claude -p`); the rotation-exit branch contract
- [ ] **P03**: Self-continue wiring + terminal-state guards + safety envelope — "A self-continuing run advances across a rotation boundary with no manual re-invoke and halts on every terminal state; the max-continuations cap halts a thrash; the un-armed path is byte-identical to legacy."
  - Risk: high
  - Depends: P02
  - Boundary Map:
    - Produces: `commands/auto.md` §Context Rotation Check edits wiring the directive → spawn a process-fresh `claude -p` re-entry that resumes from disk (FR-2); a small driver (e.g. `scripts/lifecycle/self-continue-drive.sh`, productionized from the P01 spike) that loops rotation→fresh-process→resume until terminal; terminal-states-never-self-continue guard (FR-4); `max-continuations` cap + forward-progress field (FR-5); interruptibility (FR-6); un-armed legacy parity (FR-8); `tests/fixtures/rotation-exit-legacy-<ver>.golden` (SC-4); SC-2 + SC-3 fixtures
    - Consumes: P02 branch script + capability detection + arming surface
- [ ] **P04**: Continuity observability + stall watchdog + flagship acceptance — "A completed multi-segment run is auditable as one continuous execution in the log, an unfired re-entry surfaces as SELF_CONTINUE:STALLED in orchestrator:status, and the P1 cross-rotation story passes end-to-end."
  - Risk: medium
  - Depends: P03
  - Boundary Map:
    - Produces: `.orchestrator/execution-log.jsonl` new record types (`self_continue_scheduled`, `self_continue_cap_reached`, `self_continue_unavailable`, `self_continue_unconfirmed`) (FR-9/FR-10); `SELF_CONTINUE:STALLED` surface folded into the M029 `orchestrator:status` headline block (`scripts/diagnostics/render-status-json.sh`); SC-1 flagship continuity fixture + SC-7 stall fixture
    - Consumes: P03 self-continue events + terminal/cap/unavailable signals

## Cross-Cutting Concerns

- **Surgical confinement (spec CON-3)** — P01, P02, P03, P04. The change set is confined to the rotation-exit branch + arming surface + observability records. No phase may edit dispatch, verify, budget, or stuck scripts. P02 establishes the boundary discipline; all later phases conform.
- **State-on-disk authoritative (spec CON-2 / Principle VI)** — P01, P03. The correctness of any re-entry rests on re-derivation from disk; P01 stresses this under real rotation, P03 must preserve it (continue-file informational only).
- **Capability-detected degradation (spec FR-7/FR-8)** — P02 establishes the `schedule_wakeup` capability + legacy fallback; P03 consumes it for byte-identical un-armed/unavailable parity; P04 records the `unavailable` event. This is the degradation template M009 reuses.
- **Contingency routing (spec CON-5)** — P01 is the decision point. Every downstream phase is contingent on P01's PASS; a negative P01 collapses P02–P04 and routes to M-auto-v2b rather than expanding scope.

## Dependency Graph

```
P01 → P02 → P03 → P04
(gate)
```

Strictly linear. P01 is a decision gate: a negative outcome prunes P02–P04 entirely (CON-5 route-out), so there is no value in starting them before P01 resolves.

## Execution Order

1. **P01** — foundation + decision gate, no dependencies. Run first and to a firm PASS/negative verdict before any other phase begins. Highest priority in the milestone.
2. **P02** — depends on P01 PASS. Core deterministic mechanism.
3. **P03** — depends on P02. Wiring + safety envelope.
4. **P04** — depends on P03. Observability + flagship acceptance (SC-1).

No phases execute concurrently — the linear gate-then-build shape is intentional given P01's contingency role.

## Validation

- **No conflicting producers**: PASS — each phase produces a disjoint set (P01 spike evidence/harness; P02 branch + capability + arming; P03 auto.md wiring + fixtures + golden; P04 log record types + status surface). No artifact is produced by two phases.
- **All consumed items have producers**: PASS — P02 consumes P01's decision; P03 consumes P02's branch/capability/arming; P04 consumes P03's self-continue events. P01 consumes only pre-existing (rotation machinery + harness primitive), correctly declared as external, not unresolved.
- **DAG is acyclic**: PASS — P01→P02→P03→P04 is a linear chain, no cycles.
- **Demo sentence coverage**: PASS — each phase has a concrete, observable demo tied to specific SCs (P01→SC-6, P02→SC-5, P03→SC-2/3/4, P04→SC-1/7).

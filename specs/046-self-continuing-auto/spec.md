---
schema_version: "1.0"
type: feature-spec
feature_slug: "046-self-continuing-auto"
created_at: "2026-07-01"
status: "Ready-for-discuss"
milestone: "M045"
---

# Feature Specification: 046-self-continuing-auto

**Feature Branch**: `046-self-continuing-auto`
**Created**: 2026-07-01
**Status**: Ready-for-discuss
**Last Revised**: 2026-07-01 (conversus spec-pressure-test PASS; 3 P0 + 4 P1/P2 mitigations from the red-blue deliberation applied — SC-6 viability gate, CON-5 contingency routing, Problem-Statement reword, FR-10 stall watchdog, FR-5 progress field, FR-5a delay floor, SC-4 golden baseline)
**Milestone**: M045 — Auto v2 Posture 1 / "M-auto-v2a" (see `.orchestrator/proposals/Mxx-auto-v2-claude-code-loop-integration.md`)
**Input**: User description: "Posture 1 self-continuing attended autonomous execution: layer onto the existing Tier C auto loop so it auto-resumes across context-rotation boundaries via ScheduleWakeup/self-paced loop instead of stopping for a human to re-invoke. Intercept auto-loop.sh exit 14 (context rotation), schedule a fresh-context re-entry that consumes the continue-file, and keep advancing until the milestone completes, blocks, or exhausts budget."

## P01 Outcome — Substrate Pivot (2026-07-01, decision D015)

**The P01 viability spike (SC-6 / #Q-1) returned VERDICT: PARTIAL and pivoted this milestone's re-entry substrate.** Evidence: `.orchestrator/milestones/M045/phases/P01/P01-VIABILITY-EVIDENCE.md`.

Finding: in-session `ScheduleWakeup` re-entry preserves correctness (disk-authoritative resume, CON-2) but does **not** deliver per-rotation context relief — it re-fires in the same session without a reset, deferring relief to non-rotation-aware harness compaction (the spike's weight analog compounded 4→11→18). On the exact axis rotation targets, in-session re-entry is *weaker* than today's fresh-session re-invoke.

**Resolution (operator-confirmed, spec CON-5 route):** M045 folds into the process-fresh substrate — on rotation, hand off to a fresh `claude -p` re-entry that starts a genuinely fresh context and resumes from disk. Throughout this spec, read the re-entry primitive as the **process-fresh `claude -p` driver**, not in-session `ScheduleWakeup`. The P02–P04 mechanism work (deterministic branch, capability detection, safety envelope, observability) carries over ~unchanged; only the re-entry primitive swaps. CON-1 and #Q-1 below are updated accordingly.

## Problem Statement

The orchestrator's Tier C autonomous loop already runs a milestone to completion — deriving state, dispatching each task to a fresh context, verifying, recording, and advancing — but it cannot cross its own context-rotation boundary unattended. When the orchestrating session's context grows deep, `auto-loop.sh --step=X` (via `context-monitor.sh`) returns exit 14 (`CONTEXT:ROTATE`), and today's `commands/auto.md` responds by writing a `continue.md` file, releasing the lock, printing a "Run `/orchestrator-auto` to continue" message, and **exiting cleanly for a human to re-invoke**. The loop is autonomous *within* a context window but not *across* context windows.

Three concrete pains follow from that gap. First, a multi-phase Tier C milestone that trips rotation two or three times requires an operator to babysit the run — noticing each clean exit and re-typing the command — which defeats the "set it running" promise of auto mode. Second, the gap penalizes exactly the large milestones auto mode exists for: the more phases, the more rotations, the more manual re-invocations. Third, the re-invoke is pure ceremony — because state is authoritative on disk (Principle VI), the human adds nothing at the boundary except the keystroke; the orchestrator already knows precisely where to resume.

The minimum surface that fixes all three is a single change to the rotation-exit path: when the operator has opted into self-continuation and the runtime exposes the scheduling primitive, the orchestrator schedules its own bounded, in-session re-entry (via the harness `ScheduleWakeup` / self-paced `/loop` mechanism — NOT a new OS process; see CON-1) instead of terminating for a human. The re-entry re-derives state from disk exactly as a manual re-invoke would, and the loop keeps advancing until it reaches a genuinely terminal state — milestone complete, blocker, budget exhaustion, stuck, or an explicit operator pause.

This feature explicitly does not attempt unattended/overnight execution, a stronger until-verified verification loop, a unified Tier A/B/C entry, or any change to task dispatch, verification, budget, or stuck detection. It touches only the handling of the rotation-exit path and the attended launch surface that arms it. Those broader ambitions are the deferred `M-auto-v2b` scope (proposal §Discussion Outcomes D1).

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The load-bearing slice is **US1 alone**: an operator launches a Tier C milestone in self-continuing mode once, and the loop advances through at least two phases separated by a context-rotation boundary without any manual re-invocation, halting on its own at the milestone's terminal state. US2 (safety envelope) and US3 (graceful degradation) defend correctness and portability on top of that slice but do not themselves close the dogfood loop.

### User Story 1 — Cross-rotation self-continuation (Priority: P1)

An operator runs `/orchestrator-auto` on a Tier C milestone in self-continuing mode and walks away. The loop dispatches and verifies tasks as it does today; when the orchestrating context grows deep enough to trip rotation between phases, the orchestrator schedules its own re-entry in a bounded-context continuation rather than exiting for a human. The operator returns to find the milestone completed (or cleanly halted at a blocker), with a continuous execution log across every rotation boundary, and never had to re-type the command.

**Why this priority**: This is the entire value of the milestone — removing the human-in-the-loop-per-rotation friction. Without it the feature does not exist; US2 and US3 only harden and port it.

**Independent Test**: A fixture milestone with a rotation threshold set low enough to trip after phase 1 (via `context-monitor.sh --limit`), driven through a stubbed self-continue harness, reaches `complete` across the boundary with zero manual re-invocations recorded in the execution log. Verified without invoking US2's cap or US3's degradation path.

**Acceptance Scenarios**:

1. **Given** a Tier C milestone launched in self-continuing mode with two incomplete phases and a rotation limit that trips after phase 1, **When** the loop finishes phase 1 and `auto-loop.sh --step=X` returns exit 14 `CONTEXT:ROTATE`, **Then** the orchestrator writes `continue.md`, releases the lock, and emits a self-continue directive that schedules re-entry (rather than a terminal "run `/orchestrator-auto`" handoff), and the subsequent re-entry re-derives state from disk and begins phase 2.
2. **Given** a self-continuing run that has just re-entered after a rotation, **When** `derive-phase.sh` reports the milestone is `complete` (or `auto-loop.sh` returns the milestone-complete terminal state), **Then** the orchestrator does NOT schedule a further re-entry, releases the lock, and reports final completion.
3. **Given** a self-continuing run across a rotation boundary, **When** the run completes, **Then** the execution log shows an unbroken sequence of dispatch/verify records spanning both phases with no `continue-consumed-by-human` marker between them.

### User Story 2 — Bounded, interruptible safety envelope (Priority: P2)

An operator wants confidence that self-continuation cannot run away. The loop only self-continues across *rotation* boundaries; every genuinely terminal condition — budget exceeded, stuck detected, phase-verification failure, explicit pause, unexpected state — still halts it exactly as today. A hard `max-continuations` cap bounds the number of self-scheduled re-entries as a backstop independent of the token/duration budgets, and the operator can cancel a self-continuing run.

**Why this priority**: Attended self-continuation is low-risk (a human is nominally present), but a runaway re-scheduling loop would erode trust in the whole feature. The cap and the "terminal states still terminate" invariant are the guardrails; they are P2 because US1 must exist first for them to guard anything.

**Independent Test**: Fixtures that force each terminal exit code (2 budget, 3 stuck, 11 pause, 12 unexpected, phase-verify fail) each confirm the self-continue directive is NOT emitted and the run halts. A separate fixture with a rotation that trips repeatedly confirms the run stops after `max-continuations` re-entries with a clear diagnostic.

**Acceptance Scenarios**:

1. **Given** a self-continuing run, **When** `auto-loop.sh` returns budget-exceeded (exit 2), stuck (exit 3), pause (exit 11), or unexpected-state (exit 12), **Then** no re-entry is scheduled and the run halts with the same continue-file + report + lock-release behavior as a non-self-continuing run.
2. **Given** a self-continuing run configured with `max-continuations=N`, **When** the run has already self-scheduled N re-entries, **Then** the (N+1)th rotation halts the run with a `SELF_CONTINUE:CAP_REACHED` diagnostic instead of scheduling another re-entry.
3. **Given** a self-continuing run in progress, **When** the operator cancels (interrupts the loop / removes the self-continue arming), **Then** no further re-entry is scheduled and the milestone is left in a clean on-disk state resumable by a normal `/orchestrator-auto`.

### User Story 3 — Graceful degradation to legacy behavior (Priority: P3)

On a runtime that does not expose the scheduling primitive (Codex CLI, Cursor), or when the operator has not armed self-continuation, the rotation-exit path behaves byte-identically to today: write `continue.md`, report, release lock, exit for manual re-invoke. Self-continuation is a capability-gated enhancement, never a hard dependency.

**Why this priority**: Preserves the launch-posture invariant that auto mode works everywhere it works today; the self-continue path is purely additive. P3 because it is a fallback, not the feature's reason to exist.

**Independent Test**: A capability-detection fixture reporting `schedule_wakeup: false` confirms the rotation path emits the legacy terminal handoff and exit, byte-identical to the pre-feature output. A second fixture with the capability present but self-continue un-armed confirms the same legacy path.

**Acceptance Scenarios**:

1. **Given** a runtime where capability detection reports the scheduling primitive is unavailable, **When** rotation trips during a self-continue-armed run, **Then** the orchestrator falls back to the legacy terminal handoff (continue-file + "run `/orchestrator-auto`" message + exit) and records `SELF_CONTINUE:UNAVAILABLE reason=no-schedule-primitive`.
2. **Given** a run that was NOT armed for self-continuation, **When** rotation trips, **Then** behavior is byte-identical to the current released rotation-exit path.

---

## Edge Cases

- **Rotation on the final phase**: rotation trips after the last phase's work but before validation. The re-entry must resume into the `validating`/`completing` states and terminate normally, not schedule an unbounded tail of empty re-entries.
- **Terminal state co-incident with rotation**: a phase completes, trips rotation, but the milestone is also now complete. Terminal completion wins — no re-entry is scheduled (US1 AS-2).
- **Lock still held at re-entry**: the prior segment released the lock before scheduling; the re-entry must acquire a fresh lock. If a stale lock is found (crash between release and re-entry), the re-entry follows the normal resume/stale-lock recovery path rather than self-continuing blindly.
- **Continue-file absent at re-entry**: state-on-disk is authoritative, so a missing `continue.md` is non-fatal — the re-entry re-derives position from `derive-phase.sh` and proceeds (matches today's "continue file is informational" note in `auto.md`).
- **Repeated immediate rotation** (threshold mis-set so every segment trips instantly): bounded by `max-continuations` (US2 AS-2); must not busy-loop below the scheduler's minimum delay.
- **Operator cancels mid-segment vs between segments**: cancellation between segments simply stops the next re-entry; mid-segment cancellation leaves the current task's fresh-context dispatch to resolve or be re-derived on next manual run.

---

## Functional Requirements

- **FR-1 (arm-self-continue)**: `orchestrator:auto` MUST accept an explicit opt-in to self-continuing mode (flag and/or a first-class `/loop`-dynamic launch recipe). The armed/un-armed state MUST be discoverable by the rotation-exit handler within the run. (US1, US3)
- **FR-2 (rotation-branch)**: On `auto-loop.sh --step=X` exit 14 (`CONTEXT:ROTATE`), when self-continue is armed AND the scheduling primitive is available, the orchestrator MUST schedule a fresh re-entry of `/orchestrator-auto` for the same milestone instead of terminating for manual re-invocation. The re-entry MUST re-derive state from disk. (US1)
- **FR-3 (deterministic directive)**: The decision to self-continue vs. legacy-exit MUST be produced by a deterministic script step (policy in shell, per Principle X), emitting a structured directive (e.g. `AUTO:SELF_CONTINUE delay=<s> milestone=<M###>` or `AUTO:ROTATE_EXIT reason=<...>`) that the agent turns into the actual `ScheduleWakeup` tool call. The agent MUST NOT infer the branch from prose. (US1, US3)
- **FR-4 (terminal states never self-continue)**: For every non-rotation terminal outcome — milestone complete, budget exceeded (exit 2), stuck (exit 3), pause (exit 11), unexpected state (exit 12), and phase-verification failure — the orchestrator MUST NOT schedule a re-entry and MUST halt with the existing continue-file/report/lock-release behavior. (US2)
- **FR-5 (continuation cap)**: A `max-continuations` cap MUST bound the number of self-scheduled re-entries per launched run, independent of `dispatch_budget`/`duration_budget`. On reaching the cap, the run MUST halt with a `SELF_CONTINUE:CAP_REACHED` diagnostic rather than scheduling another re-entry. The `CAP_REACHED` diagnostic MUST carry a forward-progress field (e.g. phase-boundaries-crossed or tasks-advanced per continuation) so a cap-halt is distinguishable, from the log alone, between a legitimately long milestone and a thrash where in-session re-entry gave no context relief (the CON-1 failure mode). (US2)
- **FR-5a (delay floor)**: The deterministic branch script MUST query — or, if the floor is not queryable, conservatively assume — the scheduling primitive's minimum re-entry delay, and MUST NOT request a delay below it. This prevents a busy re-entry loop under a mis-tuned rotation threshold before `max-continuations` halts the run. (US2)
- **FR-6 (interruptible)**: The operator MUST be able to cancel a self-continuing run such that no further re-entry is scheduled, leaving the milestone in a clean, normally-resumable on-disk state. (US2)
- **FR-7 (capability detection + degrade)**: The rotation branch MUST consult capability detection for the scheduling primitive. When absent, it MUST fall back to the legacy terminal handoff byte-for-byte and record `SELF_CONTINUE:UNAVAILABLE`. (US3)
- **FR-8 (legacy parity when un-armed)**: When self-continue is not armed, the rotation-exit path MUST be byte-identical to the current released behavior. (US3)
- **FR-9 (continuity observability)**: Self-continue events (scheduled re-entry, cap-reached, unavailable-degrade) MUST append structured records to `.orchestrator/execution-log.jsonl` so a completed multi-segment run is auditable as one continuous execution. (US1, US2)
- **FR-10 (unconfirmed-schedule watchdog)**: Because the deterministic branch emits a directive (FR-3) but the actual `ScheduleWakeup` call is made by the agent — which is already under the context pressure that tripped rotation — the branch script MUST write a `self_continue_unconfirmed` record synchronously *before* handing off to the agent, cleared only once the re-entry actually fires. A subsequent run's startup probe (or a lightweight check folded into the existing M029 `orchestrator:status` headline block) MUST surface an uncleared `self_continue_unconfirmed` record older than a configurable threshold as `SELF_CONTINUE:STALLED`, so a silently-failed re-entry is observable without operator foreknowledge rather than masquerading as a healthy in-flight continuation. (US1, US2)

## Success Criteria

- **SC-1**: A fixture Tier C milestone with a rotation limit that trips after phase 1, driven through the self-continue harness, reaches `complete` with the execution log showing dispatch/verify records for both phases and at least one `self_continue_scheduled` record and zero manual-re-invoke markers. Verified by an acceptance-battery script exiting 0. (US1)
- **SC-2**: A harness that forces exit codes 2/3/11/12 and a phase-verify failure asserts, for each, that no `self_continue_scheduled` record is emitted and the run halts — script exits 0 when all five cases hold. (US2, FR-4)
- **SC-3**: A fixture forcing repeated rotation halts after exactly `max-continuations` re-entries and emits `SELF_CONTINUE:CAP_REACHED` carrying a populated forward-progress field; the same fixture asserts consecutive `self_continue_scheduled` timestamps are never closer together than the scheduler's minimum delay floor; script exits 0. (US2, FR-5, FR-5a)
- **SC-4**: With capability detection stubbed to report the scheduling primitive absent, the rotation path output is byte-identical (`diff` exit 0) to a version-pinned golden capture of the un-armed legacy path (checked into `tests/fixtures/`, regenerated only via an explicit reviewed script), and records `SELF_CONTINUE:UNAVAILABLE`. (US3, FR-7, FR-8)
- **SC-5**: The deterministic branch script, given `CONTEXT:ROTATE` input plus armed/available flags, prints exactly one of the `AUTO:SELF_CONTINUE` / `AUTO:ROTATE_EXIT` directives per the truth table (armed×available → self-continue; otherwise exit), verified by a table-driven fixture test exiting 0. (FR-3)
- **SC-6 (viability closure gate — milestone-blocking)**: A real, NON-stubbed multi-rotation Tier C run under self-continue, crossing at least two rotation boundaries, MUST show bounded (non-compounding) orchestrating-context growth measured across those boundaries. This is a hard milestone-closure gate — the milestone MUST NOT close on stub evidence alone. Modeled on this repo's own M036a live-LLM-smoke precedent (env-gated live branch). A negative result triggers the CON-5 routing to `M-auto-v2b` rather than silent re-scoping. This SC exists because SC-1 verifies only a stub that structurally cannot measure the premise CON-1 rests on. (US1, CON-1, CON-5, #Q-1)
- **SC-7 (stall observability)**: A fixture that emits a `self_continue_unconfirmed` record and never fires the re-entry asserts that, after the configurable staleness threshold, `orchestrator:status` surfaces `SELF_CONTINUE:STALLED` without operator foreknowledge; script exits 0. (US1, FR-10)

## Non-Goals

- **Unattended / overnight execution** — the headless `claude -p` driver and cloud-routine substrates are `M-auto-v2b` Posture 2. This feature is attended: an operator launches it and can interrupt it.
- **Until-verified Stop-hook loop** — tighter per-unit verify→fix→re-verify is `M-auto-v2b` Posture 3.
- **Unified Tier A/B/C entry and `orchestrator:do` merge** — deferred to `M-auto-v2b` (proposal D1/D3). This feature operates only on the existing Tier C auto loop.
- **Changing task dispatch, verification, budget, or stuck detection** — all reused unchanged; this feature touches only the rotation-exit branch and the launch arming surface.
- **Guaranteeing a truly new OS process per re-entry** — see CON-1 and #Q-1; v2a accepts bounded in-session continuation, not process-fresh isolation.

## Constraints

- **CON-1 (process-fresh re-entry — REVISED per D015)**: ~~The `ScheduleWakeup` / self-paced `/loop` primitive re-fires within the same session…~~ **Superseded by the P01 outcome.** The re-entry substrate is a **process-fresh `claude -p` driver**: on rotation the loop hands off to a genuinely new process/context that resumes from disk (CON-2), giving a true per-rotation context reset — the property P01 proved in-session re-entry cannot provide. This is the substrate the FR/SC surface now assumes. (Historical note: the original in-session `ScheduleWakeup` design was tested and rejected in P01; see the P01 Outcome banner and `P01-VIABILITY-EVIDENCE.md`.)
- **CON-2 (state-on-disk authoritative)**: Correctness across any re-entry MUST derive entirely from on-disk state via `derive-phase.sh` and task scanning. The continue-file is informational only; a lossy or absent continuation MUST NOT corrupt progress. This is the invariant that makes CON-1 safe.
- **CON-3 (rotation-path-only surface)**: The change set MUST be confined to the rotation-exit branch (`commands/auto.md` §Context Rotation Check + a new deterministic branch script + capability detection) and the launch arming surface. No edits to dispatch, verify, budget, or stuck scripts.
- **CON-4 (explicit opt-in)**: Self-continuation MUST be armed explicitly per run and MUST NOT become the silent default via config alone. (Aligned with proposal D4's opt-in posture, applied at the lower-risk attended tier.)
- **CON-5 (FR/SC surface is contingent on the viability spike)**: The FR-1..FR-10 surface rests on CON-1's unverified premise that in-session re-entry relieves context pressure. That premise MUST be confirmed by SC-6 before this milestone closes. On a negative SC-6 outcome, the milestone halts at whatever slice of US1 is viable and routes the remaining scope to `M-auto-v2b`'s process-fresh headless-driver substrate (proposal §Discussion Outcomes D1/D2); scope MUST NOT expand to absorb a process-fresh re-entry mechanism *within* this milestone (preserves CON-3). This routing is stated here so a reader of this spec alone — without cross-referencing the proposal — knows what a negative viability outcome triggers.

### Knowledge-Layer Boundary (M-auto-v2a vs. M020 knowledge layer)

This milestone writes only to the **execution log** (`.orchestrator/execution-log.jsonl`, new `self_continue_*` record types) and reads on-disk lifecycle state via `derive-phase.sh`. It does NOT write to `KNOWLEDGE.md`, `DECISIONS.md`, MEM entries, the knowledge index, or any `knowledge/**` path — those remain owned by M020 and the per-phase consolidation flow. The self-continue records are observability events, not knowledge-graph nodes.

## Assumptions

- The existing context-rotation path (`auto-loop.sh --step=X`, `context-monitor.sh`, exit 14 handling in `auto.md`) is functioning as documented; this feature intercepts it rather than reworking it.
- The harness scheduling primitive (`ScheduleWakeup` / self-paced `/loop`) is available under Claude Code and re-fires a supplied `/orchestrator-auto` prompt on wakeup with a minimum delay floor.
- M028 hook-portability is in effect for consumer projects so the loop's dispatch path (and its shape-guard) behave identically across the re-entry boundary.
- Tier C milestones already exercise the rotation path in real runs (this repo, PBJ, LakeLedger), so the fixture thresholds model real behavior.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: The re-entry exists precisely to keep the orchestrating context bounded across a long milestone; the deterministic directive and minimal continue-file avoid carrying prose state across the boundary. CON-1 acknowledges the honest limit (in-session compaction, not process-fresh) rather than overclaiming.
- **Principle V (Fresh Context Per Unit)**: Per-task dispatch remains fully fresh-context and unchanged. The orchestrating loop's cross-rotation freshness is best-effort under CON-1; #Q-1 forces the plan phase to confirm whether in-session continuation gives enough relief or must escalate to a process-fresh re-entry.
- **Principle VI (State On Disk Is Truth)**: The feature's entire safety rests here — re-entry re-derives from disk (CON-2), so the scheduling primitive is a convenience, never a source of truth. This is what lets an attended self-continue be correct even under lossy compaction.
- **Principle X (Templating Over Inference)**: The self-continue-vs-exit decision is a deterministic shell branch emitting a structured directive (FR-3), not an LLM judgement call.
- **Principle XIV/XV (No Speculative Complexity / Surgical Precision)**: Scope is confined to the rotation-exit branch (CON-3); the broader Auto-v2 ambitions are explicitly deferred to v2b.

## Open Questions (defer to planning)

- **#Q-1 (fresh-context fidelity) — RESOLVED 2026-07-01 (P01, D015)**: Answer: in-session re-entry does NOT provide sufficient per-rotation relief; M045 uses the process-fresh `claude -p` driver. The original question text follows for history. Does `ScheduleWakeup` in-session re-entry plus harness context-management provide sufficient context relief for long Tier C milestones, or must v2a instead trigger a genuinely process-fresh re-entry (which would pull the v2b headless driver forward)? **Answered at plan-phase via a spike**: run a real multi-rotation Tier C milestone under self-continue and measure orchestrating-context growth across boundaries. This is the load-bearing risk of the whole milestone, and it is now enforced — not merely flagged — by **SC-6** (a milestone-blocking closure gate) and **CON-5** (in-spec routing to `M-auto-v2b` on a negative outcome). SC-1's stub evidence is explicitly insufficient to close this.
- **#Q-2 (arming surface)**: Should the arming surface be a `--self-continue` flag on `orchestrator:auto`, a dedicated `/loop /orchestrator-auto` recipe, or both? Which is the primary documented path? Owner: plan-phase, informed by the #Q-1 spike (a process-fresh answer favors the `/loop` recipe).
- **#Q-3 (cap default)**: What is the default `max-continuations` value, and does it live in config or as a launch flag only? Owner: plan-phase; must be conservative enough to backstop a mis-set rotation threshold.
- **#Q-4 (resume-skill reuse)**: Does the re-entry reuse the `orchestrator-resume` continue-file-consumption path, or a lighter self-continue-specific path? Owner: plan-phase; prefer reuse to avoid a second resume code path.

## Dependencies

- The existing rotation-exit machinery: `scripts/lifecycle/auto-loop.sh --step=X`, `scripts/lifecycle/context-monitor.sh`, and the `commands/auto.md` Context Rotation Check branch.
- `scripts/lifecycle/lock-manager.sh` (lock release before, fresh acquire at re-entry) and the `orchestrator-resume` / continue-file convention.
- The harness `ScheduleWakeup` / self-paced `/loop` primitive (Claude Code) and `scripts/dispatch/detect-capabilities.sh` (extended with a `schedule_wakeup` capability field).
- M028 hook portability (consumer-project dispatch parity across the re-entry boundary).

## Downstream Consumers (informational, not binding)

- **M-auto-v2b** consumes this as the proven attended-self-continue base before layering unattended (Posture 2) and until-verified (Posture 3), the unified A/B/C entry, and the `orchestrator:do` merge.
- **M009 (multi-runtime parity)** consumes FR-7's capability-detection + degrade pattern as the template for how CC-only loop primitives degrade on Codex/Cursor.

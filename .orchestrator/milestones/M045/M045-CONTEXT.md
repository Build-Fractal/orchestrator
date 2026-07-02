---
schema_version: "1.0"
type: context-draft
milestone: "M045"
status: finalized
created_at: "2026-07-01"
finalized_at: "2026-07-01"
---

## Architectural Decisions

Locked in the pre-spec discussion (proposal §Discussion Outcomes) and confirmed
by the conversus spec-pressure-test deliberation (`specs/046-self-continuing-auto/conversus/summary/final.md`):

- **AD-1 — Primitives drive `auto-loop.sh` unchanged.** The Claude-Code loop
  primitives are pluggable substrates over the existing on-disk state machine,
  never a replacement. The change set is confined to the context-rotation exit
  branch + the arming surface (spec CON-3). Dispatch/verify/budget/stuck are
  reused untouched.
- **AD-2 — Bounded in-session re-entry, not process-fresh (D1 / spec CON-1).**
  On `auto-loop.sh` exit 14, arm a `ScheduleWakeup`/self-paced-`/loop` re-entry.
  This re-fires in-session (harness compaction relieves context), NOT a new OS
  process. Correctness holds because state-on-disk is authoritative (spec CON-2);
  the truly process-fresh path is the deferred v2b headless driver.
- **AD-3 — Viability is gated, not assumed (spec SC-6 / CON-5).** Whether
  in-session re-entry actually relieves context (#Q-1) is the load-bearing risk.
  SC-6 makes it a milestone-blocking, non-stubbed viability spike; CON-5 routes a
  negative outcome out to `M-auto-v2b` per proposal D1/D2. The spike is the
  earliest, highest-priority plan-phase task.
- **AD-4 — Explicit per-run opt-in (D4 / spec CON-4).** Self-continuation is
  armed explicitly per run; no config knob makes it the silent default.
  (Attended tier of the broader D4 unattended-safety posture.)
- **AD-5 — Capability-detected graceful degradation (spec FR-7/FR-8).** On
  runtimes lacking the scheduling primitive (Codex/Cursor) or when un-armed, the
  rotation path is byte-identical to today's legacy human-handoff. This is the
  degradation template M009 will reuse.

## Scope Boundaries

**In scope (M045 = Auto v2 Posture 1 only):**
- Intercepting the `auto-loop.sh --step=X` exit-14 rotation branch to self-schedule a bounded in-session re-entry until the milestone reaches a terminal state.
- The arming surface (flag and/or `/loop`-dynamic recipe — exact form is #Q-2).
- Safety envelope: `max-continuations` cap, terminal-states-never-self-continue invariant, delay-floor respect, interruptibility, and the stall/thrash/unavailable observability surfaces (spec FR-4/FR-5/FR-5a/FR-6/FR-10).
- The SC-6 viability spike.

**Out of scope (deferred to M-auto-v2b / later):**
- Unattended/overnight execution (headless driver + cloud routines — Posture 2).
- Stop-hook until-verified loop (Posture 3).
- Unified Tier A/B/C entry + `orchestrator:do` deprecation/merge (D3).
- Any change to dispatch, verification, budget, or stuck detection.
- A guaranteed process-fresh re-entry mechanism (routes to v2b on a negative SC-6).

## Design Constraints

- **State-on-disk authoritative (Principle VI / spec CON-2)** — every re-entry
  re-derives from `derive-phase.sh`; continue-file is informational only.
- **CC-only primitive** — `ScheduleWakeup`/self-paced `/loop` are Claude Code
  native; degradation to legacy behavior is mandatory (FR-7/FR-8).
- **Hard dependency: M028 hook portability** — consumer-project dispatch +
  shape-guard parity must hold across the re-entry boundary.
- **Deterministic branch (Principle X / spec FR-3)** — the self-continue-vs-exit
  decision is a shell branch emitting a structured directive; the agent only
  translates the directive into the actual `ScheduleWakeup` tool call.
- **Verify `/goal` command + Monitor-tool behavior against official docs** before
  any design relies on them — the loop-primitive research sourced those two from
  third-party blogs, not Anthropic docs (the reliable primitives — `/loop`,
  `ScheduleWakeup`, routines, Stop hooks, headless — are doc-confirmed).

## Open Questions

All four are plan-phase-owned design decisions about the not-yet-built mechanism;
they passed the corpus-exhaustion gate at specify time (adjudicated genuinely
open, `specs/046-self-continuing-auto/conversus/corpus-exhaustion-specify.md`).
Carried forward verbatim as spec #Q-1..#Q-4:

- **#Q-1 (viability)** — does in-session re-entry relieve context, or must v2a
  escalate to process-fresh? Answered by the SC-6 spike (AD-3). *Earliest
  plan-phase task; gates the rest of the FR surface.*
- **#Q-2 (arming surface)** — `--self-continue` flag vs dedicated `/loop`
  recipe vs both; primary documented path. A process-fresh #Q-1 answer favors the
  `/loop` recipe.
- **#Q-3 (cap default)** — default `max-continuations` value; config vs
  launch-flag-only. Must backstop a mis-set rotation threshold.
- **#Q-4 (resume reuse)** — reuse `orchestrator-resume`'s continue-file path or a
  lighter self-continue-specific path (prefer reuse to avoid a second resume code
  path); resolves the self-triggered-vs-human-triggered marker taxonomy the SC-1
  fixture depends on.

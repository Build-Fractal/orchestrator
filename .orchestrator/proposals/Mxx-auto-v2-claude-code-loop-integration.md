# Proposal: Auto v2 — Claude-Code-Native Loop Integration (unified A/B/C autonomous execution)

**Captured**: 2026-06-30 from a planning conversation ("make auto mode a *truly* autonomous loop that works on Tier A, B, or C, sizes appropriately, and runs until verified using Claude Code's native loop functionality").
**Shape**: Milestone-shaped (est. 4–6 phases). Reworks the auto/do entry surface, adds a pluggable loop-substrate layer over the existing state machine, and touches dispatch, verify, hooks, and runtime-capability detection. **Does NOT rewrite `auto-loop.sh` or the on-disk state machine** — those stay the crown jewel.
**Slot**: Post-launch milestone candidate (provisional ID `Mxx` — assign at queue-entry; M045 is tentatively the knowledge-activation P0 hotfix). Sits in the same power-user band as M034 / M038 / M040.
**Predecessors** (all closed): M028 (autonomous-hardening v3 — hook portability to consumer projects; **load-bearing**, see Risks), M030 (adaptive model selection — per-iteration cost routing), M027 (cost+quality observability — the JSONL execution-log the loop reads for budget/stuck), M031 (right-sized entry — Quick/Standard/Full profiles + `orchestrator:do` universal entry that Auto v2 subsumes), M021/M016 (shape-guard hardening — the Stop-hook and headless-driver paths must survive it).
**Companions**: `orchestrator-exec-primitive.md` (output-side context discipline — a long unattended loop *needs* subprocess-output capture so test/build logs don't bloat the driving context), M040 (its contradiction gate is a natural loop-steering signal), M009 (multi-runtime — CC loop primitives don't exist in Codex/Cursor; the degradation story is M009's concern).

## Status

**RFC capture.** Directional scope confirmed in the 2026-06-30 conversation: operator wants **all three execution postures** (self-continuing attended, unattended/overnight, tighter until-verified) and the **Auto v2 unified-A/B/C-entry** ambition (not just flags on today's auto). This proposal is the input to `orchestrator:specify` when the arc enters the queue; it should first pass through `orchestrator:discuss` (Tier C) given the architectural surface.

## Discussion Outcomes — Locked Decisions (`orchestrator:discuss` substance, 2026-06-30)

Run as a pre-spec Tier C discussion (before a milestone scaffold exists — the formal discuss gate lives post-`evaluate`, so this captures the same substance and folds it back here for `specify` to inherit). Four forks resolved:

- **D1 — Sequencing: split into two milestones.** Ship **`M-auto-v2a` (Posture 1 only)** first as a standalone, tight slice; **`M-auto-v2b`** follows once v2a is proven in dogfood.
  - **`M-auto-v2a`** = self-continuing attended auto-resume across context-rotation, layered onto **today's existing Tier C auto** (no unified-entry refactor, no `do` change). Minimal surface: intercept `auto-loop.sh exit 14`, `ScheduleWakeup` a fresh-context re-entry that consumes the continue-file. This is the biggest "no babysitting" win at the lowest risk.
  - **`M-auto-v2b`** = the unified A/B/C entry + tier-sizing + `do` deprecation/merge (D3) + Posture 2 unattended (D2, D4) + Posture 3 unit-grain until-verified + runtime-degradation (M009 tie).
- **D2 — Unattended substrate: both, settle at spec.** Headless `claude -p` driver as primary; cloud routine (`/schedule`) as a gated stretch substrate. The v2b spec's goal-backward pass picks whether cloud ships in v2b or defers.
- **D3 — `orchestrator:do`: deprecate and merge** into unified `auto` (Tier A path). Deprecation notice on `do`, removed after one version. Breaking change for downstream — v2b must ship migration notes + `orchestrator:update` changelog surface. (Lands in v2b, not v2a.)
- **D4 — Unattended safety: explicit per-run opt-in only.** `--unattended` required on every invocation; **no config knob can make it the silent default.** Hard `--max-budget-usd` cap + `--max-iters` cap + BLOCK-on-ambiguity always on. Warrants a conversus red-team pass during v2b `specify`.

These supersede open questions #1 (substrate), #4 (which substrate), and the sequencing note below. Still open for v2b `specify`: Stop-hook grain enforcement mechanics (#3), `/goal`+Monitor doc verification (#5), M040 contradiction-gate composition (#6).

## The reframe (why this is not "add a loop")

**The orchestrator already has a loop.** Today's auto mode is a file-based, resumable state machine: an agent repeatedly calls `scripts/lifecycle/auto-loop.sh` (derive state → budget/stuck check → dispatch fresh subagent → verify → record → advance) until the milestone completes, blocks, or the session's context fills. State lives entirely on disk (Principle VI); each task runs in fresh context (Principle V). It already "runs until verified."

So the value of Claude Code's native loop primitives is **not** a new loop — it's closing three specific weaknesses of the *current* loop substrate:

1. **It needs babysitting.** Context accumulates → `auto-loop.sh` returns `exit 14 (context rotate)` → a human must re-run `/orchestrator-auto` in a fresh window. The loop cannot continue itself across a context boundary.
2. **It is attended-only.** No unattended / overnight / scheduled execution.
3. **Only Tier C gets the loop.** Tier A (`orchestrator:do`) and Tier B are episodic — invoke → run → stop. There is no tier-sized "loop shape."

**Design principle for the whole milestone: the loop primitives are *pluggable substrates that drive the same `auto-loop.sh` steps* — never a replacement for the state machine.** This keeps the work constitution-compliant (State On Disk Is Truth) and low-risk.

## Goal

One `orchestrator:auto` entry that:

1. **Classifies tier (A/B/C) and sizes the loop shape automatically** — subsuming today's split between `orchestrator:do` (Tier A) and `orchestrator:auto` (Tier C).
2. **Selects a loop substrate** based on an explicit `--posture` (attended-self-continuing | unattended | until-verified), with graceful degradation to today's manual re-invoke when the runtime lacks the primitive.
3. **Runs until verified / complete / blocked**, honoring the existing budget + stuck + context-rotation gates, now *without* a human re-kicking after each context boundary.

## The three postures (all in scope per operator)

### Posture 1 — Self-continuing attended (backbone: `ScheduleWakeup` / self-paced `/loop`)
Kick once; on `auto-loop.sh exit 14 (context rotate)`, instead of writing a continue-file and stopping for a human, the driver **schedules a fresh-context wakeup** that re-enters auto and consumes the continue-file automatically. The milestone runs to completion across arbitrarily many context boundaries with no babysitting. This is the **lowest-risk, highest-immediate-value** slice and should be P01.
- Fits Principle V/I cleanly: each wake is a *fresh* context that re-derives state from disk. No accumulation.
- Termination unchanged: budget-exceeded / stuck / blocker / milestone-complete all still stop it.

### Posture 2 — Unattended / overnight (backbone: cloud routine `/schedule` OR headless `claude -p` driver)
Two candidate substrates, pick one (or support both) at spec time:
- **Headless driver**: an external `while` loop (`scripts/lifecycle/auto-drive.sh`) calling `claude -p "run one orchestrator auto step for <M###>"` until `auto-loop.sh` reports complete. Naturally fresh-context per step; maps `--max-budget-usd` to our dispatch budget. Runs on the operator's machine, no cloud dependency. **Recommended primary** — least new surface, works offline, respects the existing budget gate directly.
- **Cloud routine**: fresh session per run, clones repo from default branch, runs unattended on Anthropic infra. Works *because* state is on-disk/in-git. Powerful "overnight" story but adds permissions + scheduling + blast-radius surface (≥1h min interval). Treat as a **stretch/second substrate**, gated behind explicit operator opt-in and a bounded task allowlist.
- **Blast radius is the headline risk here** — see Risks. Unattended auto must default to a hard budget cap, a max-iteration cap, and BLOCK-on-ambiguity rather than guess.

### Posture 3 — Tighter until-verified (backbone: Stop hook, scoped to the unit grain)
A `Stop` hook that returns `decision:"block"` while a **unit's** verification is failing, forcing a verify→fix→re-verify micro-loop before the unit can "complete." Replaces today's single-pass-with-one-retry task verify.
- **Must be scoped to the unit grain, NOT the milestone** — Stop-hook re-entry keeps the *same* context, which accumulates and fights Principle I/V. At milestone grain that's exactly the context-bloat problem Posture 1 solves the right way. The hook checks `stop_hook_active` to prevent infinite loops, and caps retries (reusing the existing stuck-detector threshold).

## Tier-sizing (the "sizes appropriately" requirement)

| Tier | Today | Auto v2 loop shape |
|---|---|---|
| **A** (single task, `paragraph-classify.sh` default) | `orchestrator:do` one-shot, no loop | Single dispatch + Posture-3 until-verified micro-loop. No state machine spun up. Quick profile inject. |
| **B** (single phase, 31–80 words, no structural markers) | Single-phase episodic | Phase-scoped loop over the phase's tasks; Posture-1 self-continue if it crosses a context boundary; Standard profile. |
| **C** (milestone, lexical/FR markers) | Full auto loop, attended | Today's full milestone loop + Posture-1 self-continue + optional Posture-2 unattended; Full profile / operator-set intensity. |

Tier (structural scope) and intensity (Quick/Standard/Full execution rigor) stay **orthogonal**, as today. Auto v2 picks a default intensity per tier but the operator can override.

## Primitive → gap map (from the 2026-06-30 research)

| Primitive | Confidence | Role in Auto v2 |
|---|---|---|
| Self-paced `/loop` + `ScheduleWakeup` | High (both available in-session) | Posture 1 backbone — auto-resume across context rotation |
| Headless `claude -p` + SDK `max_turns`/`max_budget_usd` | High | Posture 2 primary — external drive loop, budget cap |
| Cloud routines / `/schedule` | High | Posture 2 stretch — unattended overnight |
| Stop hook (`decision:"block"` + `stop_hook_active` guard) | High | Posture 3 — unit-grain until-verified |
| Subagents / Agent tool | High | Unchanged — the fresh-context dispatch target per unit |
| `/goal` command, Monitor-tool event model | **LOW — sourced from third-party blogs, not official docs** | **Do NOT design on these until verified against official docs during `specify`.** `/goal` looks like a declarative sibling of Posture 3; verify first. |

## Constitution constraints this must respect

- **V (Fresh Context Per Unit)** + **I (Context Minimization)**: every loop iteration re-derives state from disk and builds a *minimal* payload for that unit only — no accumulation between iterations. This is why Posture 1 (fresh wake) is preferred over milestone-grain Stop-hook (same context).
- **VI (State On Disk Is Truth)**: loop coordination stays file-state-derived. No in-memory loop state that a crash would lose. The substrates drive `auto-loop.sh`; they do not hold state.
- **VIII (No Dead Infrastructure)** / **XIV (No Speculative Complexity)**: each substrate must be reachable and demand-justified; if the cloud-routine substrate has no live consumer at ship time, defer it rather than ship it dark.

## Risks & open questions (for `discuss` → `specify`)

1. **CC-only lock-in.** `/loop`, routines, and Stop hooks don't exist in Codex/Cursor. Auto v2 deepens CC-exclusivity. **Required**: a capability-detection gate (`scripts/dispatch/detect-capabilities.sh` extension) that degrades to today's manual re-invoke when a substrate is absent. Coordinate with M009.
2. **Unattended blast radius.** Posture 2 running with nobody watching + the shape-guard's autonomous surface = the highest-stakes new capability we'd ship. Non-negotiable defaults: hard budget cap, max-iteration cap, BLOCK-on-ambiguity (never guess an underspecified task), and a bounded write scope. This likely needs its own conversus red-team pass.
3. **Stop-hook grain discipline.** Milestone-grain Stop-hook re-entry accumulates context and violates Principle I — spec must constrain it to unit grain and cap retries at the stuck-detector threshold.
4. **Which Posture-2 substrate?** Headless driver (offline, simple, recommended) vs cloud routine (powerful, more surface) vs both. Decide at spec time; #Q for the operator.
5. **Verify `/goal` and Monitor** against official docs before either enters the design.
6. **Interaction with M040's contradiction gate** — should an unattended loop hard-BLOCK on a FLAG/BLOCK verdict, or route to the human-gated queue and continue with other units? (Composition point, not a blocker.)

## Sequencing rationale

Post-launch, power-user band (same tier as M034/M038/M040 — this is workflow depth, not first-impression scope). **Hard dependency on M028 hook portability** being verified in *consumer* projects (the Stop-hook and headless paths must work where the shape-guard hook is installed via `~/.claude/orchestrator-hooks/`, not just in this repo). Benefits from M030 (per-iteration cost routing) and M031 (tier profiles) — both closed. Natural companion to `orchestrator-exec-primitive` (long unattended loops need output-side context discipline); consider co-sequencing or folding.

**Recommended smallest viable first cut (~1 phase): Posture 1 only.** Self-continuing attended auto — auto-resume across context rotation via `ScheduleWakeup` — delivers most of the "no babysitting" value at the lowest risk, and is a clean standalone slice if the full Auto-v2 milestone slips.

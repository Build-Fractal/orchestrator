# Proposal: M027 — Roadmap Visibility & CLI UX

**Captured**: 2026-04-27
**Shape**: Milestone (3 phases)
**Source**: Sweep of `~/Sites/conversus-oss` (`engine/cli/context.py`, `engine/cli/progress.py`, `engine/cli/render.py`, `docs/user-guide/`) for adoptable UX patterns

## Goal

Make the orchestrator's autonomous execution legible to humans (and to GitHub) at a glance. Ship `orchestrator:where` — a tree renderer that shows the work hierarchy from milestone → phase → task → current dispatch — together with the supporting infrastructure (invocation-context resolver, structured output discipline, M013 GitHub coupling) that lets the same data drive at-rest snapshots and live-tail updates during `orchestrator:auto`.

## Why

Today an `orchestrator:auto` run prints exit codes (`AUTO:READY`, `AUTO:PHASE_COMPLETE`) and JSONL append events; the developer must mentally reconstruct *what* phase/task is happening from `git log` + scroll-back + occasional `orchestrator:status` invocations. The information is on disk (M019 Tier 1 emitter, M013 sidecar) — what's missing is a single rendering that surfaces it.

Conversus solved the same orientation problem with a Rich-based progress handler, an invocation-context resolver, and a 4-part result render. Those patterns adapt cleanly to the orchestrator's bash/markdown world without pulling in Python/Rich.

Pre-launch (M009), the orchestrator wants to feel transparent and predictable. M027 is the polish that delivers that feeling.

## Strict non-goals

This milestone is *not* duplicating any conversus capability. Specifically excluded:
- Multi-agent deliberation, parallel agent waves, modes (cooperative / red-blue / etc.) — orchestrator delegates to conversus.
- Cross-review / disputes / synthesis / arbitration phases.
- Heterogeneous-provider deliberation.
- The `conversus.yml` config grammar — orchestrator's `.orchestrator/config.yml` has different concerns; do not unify.

The orchestrator pulls *patterns* from conversus, not *capabilities*.

## Findings (conversus sweep, condensed)

### F1. Event-emitter / handler split with stderr-only renderer

**Conversus**: `engine/events.py` defines `PhaseStarted`, `AgentDispatched`, `AgentCompleted`, `PhaseCompleted` events flowing through an `EventEmitter` protocol with `CallbackEmitter`, `NullEmitter`, and `AsyncQueueEmitter`. The TUI handler at `engine/cli/progress.py:30-69` renders to **stderr** (so stdout stays piped/clean) using Rich, with TTY auto-detection that strips ANSI when piped.

**Orchestrator gap**: `commands/auto.md:282-301` ships an inline stderr handler that prints `[PHASE_STARTED]` / `[AGENT_DISPATCHED]` markers — but the auto-loop driver (`scripts/lifecycle/auto-loop.sh`) doesn't have continuous progress rendering for the watching human. The JSONL execution log (`.orchestrator/milestones/M###/execution-log.jsonl`) is post-hoc, not live.

**Adoption**: a `scripts/diagnostics/progress-render.sh` that tails the JSONL stream and renders. Use `tput`/ANSI directly (no Rich dependency). Stdout/stderr discipline mirrors conversus: progress to stderr, artifact paths to stdout.

### F2. `InvocationContext` — single-resolve renderer + exit-code mode

**Conversus**: `engine/cli/context.py` has `detect_context()` which reads three signals (TTY, CI env vars, Claude Code env vars) and returns a frozen `InvocationContext` with three resolved fields: `default_provider`, `renderer ∈ {tui, json, plain}`, `exit_code_scheme ∈ {interactive, governance}`. Single resolve, every downstream call reads it; tests pass argv/env/isatty explicitly.

**Orchestrator gap**: capability detection happens at init (`scripts/dispatch/detect-capabilities.sh`) but there's no render-mode concept at runtime. Output discipline across `auto.md` / `status.md` / `dispatch.md` is ad-hoc. No `--format=json` for CI consumers.

**Adoption**: new `scripts/state/detect-invocation-context.sh` produces an env block consumed by command implementations. Add `--format=json` flag to `orchestrator:status` and `orchestrator:where`. This unblocks GitHub Actions integration for M013 without scraping.

### F3. Result render — headline + indicators table + drill-down

**Conversus**: `engine/cli/render.py::render_result()` emits headline panel → summary paragraph → quality-indicators table → full markdown body. Glanceable verdict + drill-down depth in one output.

**Orchestrator gap**: `orchestrator:status` (commands/status.md) renders progressively but as flat sections. No headline. No "Indicators" mini-table.

**Adoption**: prepend a 3-line headline block to status output ("Milestone M018 — phase 4 of 5, on-budget, 2 tasks ahead of est"). Existing flat sections drill down beneath. Single command, single render — no API change for callers reading the existing sections.

### F4. Pre-execution confirmation block (`/conversus converge`)

**Conversus**: `docs/user-guide/guided-workflow.md:73-83` — before running, the converge step shows config (mode, agents, iterations) + cost estimate (total LLM launches) + confirmation prompt.

**Orchestrator gap**: `orchestrator:auto` enters the loop and starts dispatching. The budget gate (`scripts/lifecycle/budget-checker.sh`) triggers on *exceedance*, not as an upfront confirmation. Tier C users have no "you are about to dispatch ~N tasks across M phases at est. $X" handshake.

**Adoption**: opt-in preflight summary at the top of `auto.md` for Standard/Full intensities (suppressed in Quick). Reads existing data — `read-roadmap.sh`, `aggregate-metrics.sh`. No new infrastructure; just composes existing emitters.

### F5. `conversus context` debug subcommand

**Conversus**: `docs/user-guide/cli.md:217-223` — prints detected invocation context (runtime, provider, model, env signals). Lightweight visibility, not heavy diagnostics.

**Orchestrator gap**: `orchestrator:doctor` is heavy; `scripts/diagnostics/check-providers.sh` and `check-permissions.sh` exist but aren't surfaced as a single command. No "what does the orchestrator think the world looks like right now?" probe.

**Adoption**: `orchestrator:context` skill — prints resolved root, runtime, capability profile, intensity defaults, active milestone, lock state. One screen, no I/O writes.

## Headline feature: `orchestrator:where`

A new lightweight skill that renders the work hierarchy from milestone → phase → task → current dispatch. Two modes: at-rest snapshot, and live-tail consuming `execution-log.jsonl` events during `orchestrator:auto`.

### Render shape (target output)

```
Feature: 030-context-compression-layer
└─ Milestone M018  Context Compression Layer    [▓▓▓▓▓▓░░░░] 60% (3/5 phases)
   ├─ ✓ P01  Compression grammar contract             reviewed
   ├─ ✓ P02  Knowledge-aware filter                    PASS
   ├─ ▶ P03  Tier-1 microcompact                       executing  ← here
   │   ├─ ✓ T01  tier1 paging
   │   ├─ ✓ T02  cache-prune
   │   └─ ▶ T03  verifiers and summary                 dispatched 2m 14s ago
   ├─ ◇ P04  Tier-2 emitter                            pending
   └─ ◇ P05  Wire-up                                   pending

State: executing | Lock: held by PID 42301 | Budget: 8/20 dispatches | Last verify: pass
GitHub: orchestrator-tracking#142 (Issue) | Project board: column "In progress"
```

Symbols: `▓░` (progress), `▶` (current), `◇` (pending), `✓` (done), `✗` (failed). Rendered via `tput` / ANSI escapes; auto-strip when not TTY (per F2's invocation-context resolver).

### Reused infrastructure (reads, no writes)

- `scripts/state/derive-phase.sh` — current state cursor
- `scripts/state/read-roadmap.sh` — phase list, active phase
- `.orchestrator/milestones/M###/execution-log.jsonl` — live event stream (M019 Tier 1)
- `scripts/lifecycle/lock-manager.sh status` — lock owner + operation
- `scripts/diagnostics/efficiency-footer.sh` — budget rollup
- `.orchestrator/integrations/github.json` (M013 sidecar) — issue + project mappings

### M013 GitHub coupling — what makes this earn its weight

The orchestrator already has `orchestrator-github-init`, `orchestrator-github-sync`, `orchestrator-github-status` skills that project local state onto Issues/Milestones/Projects v2. The renderer reads the M013 sidecar to fold GitHub state into the same screen *without an API call on every invocation*. When integration is absent, the GitHub line silently disappears. `--refresh-github` does an opt-in `gh` roundtrip and updates the sidecar.

This delivers a single mental model: the developer's terminal view matches what's on the GitHub project board.

## Phase shape

| Phase | Goal | Key artifact | Verifies |
|---|---|---|---|
| P01 | Foundation: invocation-context resolver + headline status | `scripts/state/detect-invocation-context.sh`. Headline block in `orchestrator:status`. `orchestrator:context` debug skill. `--format=json` on status. | TTY/non-TTY/CI all render correctly. JSON output validates against schema. |
| P02 | `orchestrator:where` at-rest renderer | New skill + `scripts/diagnostics/render-position.sh`. Reads roadmap + execution log + lock + telemetry. M013 sidecar fold-in (no API calls). | Tree renders correctly for milestones in all states (planning/executing/blocked/complete). |
| P03 | Live-tail mode + auto preflight + verifiers + summary | `orchestrator:where --live` tails JSONL. `orchestrator:auto` opt-in preflight summary. `--refresh-github` flag for sidecar refresh. Verifiers + summary. | Live tail updates within 1s of JSONL append. Preflight matches actual dispatch count ±1. |

## Dependencies & sequencing

**Requires**: M013 (GitHub integration — shipped) for sidecar fold-in. M019 Tier 1 (observability emitter — shipped) for JSONL stream.

**Optional dependency**: M019 Tier 2+3 (observability metrics extension) — if shipped before M027, the headline block can show richer telemetry (token usage, cost). If not, headline gracefully degrades.

**Independent of**: M026, M024, M014 ext, M020, M018, M023.

**Slot recommendation** (per `.orchestrator/proposals/README.md`): after M023 (design layer), before M009 (extended runtime-parity audit). It's launch polish that wants to ship *with* the launch experience, not before.

## Out of scope

- A "live dashboard" or web UI — terminal-only.
- A persistent watcher daemon — `orchestrator:where --live` runs in the foreground while user watches.
- Any change to the `orchestrator:auto` loop logic itself — M027 only *reads* what auto already emits.
- Replacing `orchestrator:status` — `where` is the tree view, `status` is the flat-section view. Both keep their roles.
- Implementing a Rich/TUI library binding — bash + ANSI is sufficient; pulling in a TUI dep adds runtime cost we don't need.

## Open questions for `orchestrator:specify`

1. **Skill name**: `orchestrator:where` vs `orchestrator:tree` vs `orchestrator:position`. "Where" matches user's mental model ("where am I?"); "tree" describes the rendering; "position" is most generic.
2. **Live-tail mechanism**: `inotify`/`fswatch` vs polling `tail -f` JSONL? Polling is portable to all 3 runtimes (Mac/Linux/Windows-via-WSL). `inotify` is Linux-only.
3. **GitHub refresh frequency**: should at-rest renders ever auto-refresh the sidecar, or only on explicit `--refresh-github`? Recommendation: never auto-refresh (avoid surprise API calls); always explicit.
4. **Roadmap grouping**: when a feature has multiple milestones (e.g., 030-context-compression-layer might span M018 + future M0XX), should `where` show the cross-milestone view or only the active one? Recommendation: active milestone only; full feature view is a separate render.
5. **Headline block content**: minimum useful set? Suggested fields: milestone ID + name, current phase index, percent complete, lock status, last-dispatch recency, last-verify result. Anything else feels like leakage from `status`.

## Source evidence (file paths)

- `~/Sites/conversus-oss/engine/cli/context.py` (F2 — invocation context resolver)
- `~/Sites/conversus-oss/engine/cli/progress.py:30-69` (F1 — TUI handler with stderr render)
- `~/Sites/conversus-oss/engine/cli/render.py` (F3 — 4-part result rendering)
- `~/Sites/conversus-oss/docs/user-guide/guided-workflow.md:73-83` (F4 — preflight pattern)
- `~/Sites/conversus-oss/docs/user-guide/cli.md:217-223` (F5 — context debug subcommand)
- `commands/auto.md:282-301` (orchestrator inline stderr handler — gap)
- `commands/status.md` (existing flat-section render — extend with headline)
- `scripts/lifecycle/auto-loop.sh` (the loop that emits JSONL — read-only consumer)
- `scripts/state/detect-invocation-context.sh` (NEW — to create)
- `scripts/diagnostics/render-position.sh` (NEW — to create)
- `.orchestrator/integrations/github.json` (M013 sidecar — read-only consumer)

# spec-kit-orchestrator

A [spec-kit](https://github.com/github/spec-kit) extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development workflow.

## What it does

Spec-kit excels at single-context-window development: constitution, specify, clarify, plan, tasks, implement. But projects larger than one context window hit a wall. This extension adds the orchestration layer.

**Three execution tiers** from the same entry point:

- **Tier A** (single context window) — routes to standard spec-kit, zero overhead
- **Tier B** (one SDD flow, multiple contexts) — adds structured handoff between steps
- **Tier C** (multiple SDD flows, full orchestration) — state machine dispatch, crash recovery, knowledge generation

**Core capabilities:**

- Milestone / Phase / Task work hierarchy with boundary maps
- File-based state machine (disk is truth, crash-recoverable)
- Fresh context per task dispatch with minimal payload construction
- Must-haves verification (Truths, Artifacts, Key Links)
- Append-only decisions register and cross-session knowledge file
- Knowledge consolidation and archival
- Graceful degradation (no subagents? sequential. no gh-aw? local only.)

## Status

**v0.1.0 — Implementation complete.** The extension is fully implemented and tested:

- **10 commands** — `speckit.orchestrator.evaluate` through `speckit.orchestrator.consolidate`
- **21 helper scripts** — state management, dispatch, verification, knowledge, lifecycle
- **13 templates** — roadmaps, phase plans, task plans, summaries, dispatch prompts, config defaults
- **4 reference docs** — state machine, verification ladder, tier definitions, file formats
- **7 test suites** — structural validation (S01), state machine (S02), design artifacts (S03), core commands (S04), autonomous mode (S05), knowledge lifecycle (S06), cross-slice integration (S07)

### Key references

- `specs/001-speckit-orchestrator/spec.md` — full feature specification (67 FRs, 20 SCs)
- `.specify/memory/constitution.md` — 7 governing principles
- `.planning/research/` — deep research reports on 5 source systems

## Installation

```bash
specify extension add speckit-orchestrator
```

Or via APM:

```bash
apm install speckit-orchestrator
```

## Commands

| Command | Purpose |
|---------|---------|
| `speckit.orchestrator.evaluate` | Classify scope as Tier A, B, or C |
| `speckit.orchestrator.discuss` | Capture architectural decisions before roadmap generation |
| `speckit.orchestrator.roadmap` | Decompose spec into phases with dependency graph and boundary maps |
| `speckit.orchestrator.plan-phase` | Plan one phase — task decomposition with must-haves |
| `speckit.orchestrator.dispatch` | Execute one task in a fresh context with constructed payload |
| `speckit.orchestrator.auto` | Autonomous dispatch loop until milestone completes |
| `speckit.orchestrator.verify` | Must-haves verification for a completed phase |
| `speckit.orchestrator.status` | Progress dashboard — completion, blockers, next action |
| `speckit.orchestrator.resume` | Crash/pause recovery using disk state |
| `speckit.orchestrator.consolidate` | Knowledge compression and artifact archival |

## License

MIT

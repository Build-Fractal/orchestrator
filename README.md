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

**Specification phase.** The spec is complete and under review. Implementation has not begun.

- `specs/001-speckit-orchestrator/spec.md` — full feature specification (67 FRs, 20 SCs)
- `.specify/memory/constitution.md` — 7 governing principles
- `.planning/research/` — deep research reports on 5 source systems

## Installation (future)

```bash
specify extension add speckit-orchestrator
```

Or via APM:

```bash
apm install speckit-orchestrator
```

## Commands (planned)

| Command | Purpose |
|---------|---------|
| `speckit.orchestrator.evaluate` | Scope triage (Tier A/B/C) |
| `speckit.orchestrator.discuss` | Pre-planning architectural decisions |
| `speckit.orchestrator.roadmap` | Decompose spec into phases |
| `speckit.orchestrator.plan-phase` | Plan one phase with must-haves |
| `speckit.orchestrator.dispatch` | Execute one task in fresh context |
| `speckit.orchestrator.auto` | Autonomous dispatch loop |
| `speckit.orchestrator.verify` | Must-haves verification |
| `speckit.orchestrator.status` | Progress dashboard |
| `speckit.orchestrator.resume` | Crash/pause recovery |
| `speckit.orchestrator.consolidate` | Knowledge compression and archival |

## License

MIT

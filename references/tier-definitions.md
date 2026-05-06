# Tier Definitions Reference

> Progressive disclosure reference for the speckit-orchestrator execution tiers.
> Self-contained — read this document to understand what each tier provides and when to use it.

## Overview

The orchestrator classifies every project into one of three execution tiers (A, B, or C) based on the number of complete spec-driven-development process flows (specify → clarify → plan → tasks → implement) the work requires. The tier determines which orchestrator features are active, which state machine states apply, and how much overhead is introduced.

Tier classification happens automatically during `/orchestrator-evaluate` but can be overridden by the developer at any time (FR-002).

---

## Tier A — Single Context

**When it applies**: The entire feature fits in approximately one context window. All SDD steps run inline with minimal context switching. The work is one task or a few very small tasks.

`.orchestrator/` (config, knowledge, integrations) is always present in any orchestrator-installed project; only `.orchestrator/milestones/M###/` scaffolding is conditional on Tier B/C. Tier A invocations read knowledge and reuse the project's compression layer — they just skip the milestone-tree ceremony.

### What's Included

- Single dispatch with knowledge + compression via the Quick profile (M031: `build-context.sh` always runs)
- The host runtime's native SDD workflow remains available (specify → clarify → plan → tasks → implement, invoked via the runtime's own commands) when the operator prefers
- Quick-profile knowledge injection (1-hop touched-file hits) and the M018 compression pipeline (filter + Tier 1/2 caveman-style compaction) — both unconditional per M031

### What's Excluded

- No state machine progression, no roadmap, no per-milestone summaries
- No `.orchestrator/milestones/M###/` directory created
- No autonomous loop, no consolidation, no boundary-map ceremony
- No execution log per milestone (the project-level `.orchestrator/observability/` records remain, but no milestone-grain `unit_close` series)
- No verification ladder beyond the dispatch's own Quick-profile gates

### State Machine

None. Tier A does not use the orchestrator state machine.

### Commands Available

None — direct host-runtime commands only. The orchestrator's `evaluate` command classifies as Tier A and then steps aside entirely.

### Typical Projects

- Bug fixes
- Small feature additions (< 100 lines changed)
- Configuration changes
- Documentation updates
- Single-file refactors

---

## Tier B — One SDD Flow, Multiple Contexts

**When it applies**: The work requires one complete SDD flow where each step (specify, clarify, plan, tasks, implement) fits in its own context window. Tasks dispatch to separate contexts, but it is a single pass through the process.

### What's Included

- A single-milestone roadmap with flat phases (no nested milestones)
- Task-level dispatch to separate contexts
- Per-task must-have verification
- Phase summaries with structured frontmatter
- Structured handoff between SDD steps
- DECISIONS.md and KNOWLEDGE.md (created if decisions or patterns emerge, but not required scaffolding)

### What's Excluded

- **Autonomous mode** — the developer drives step transitions manually
- **Crash recovery machinery** — no lock files; sessions are developer-initiated
- **Roadmap reassessment** after phases — plans execute as written
- **Boundary maps required** — optional for Tier B; phases are sequential by default
- **Knowledge consolidation** — no automatic compression of artifacts
- **`discussing` state** — no context draft discussion; planning starts immediately
- **`replanning` state** — no mid-execution plan revision
- **`validating` state** — no milestone-level validation gate
- **`completing` state** — no separate milestone summary generation step

### State Machine

Simplified 5-state subset:

```
pre-planning → planning → executing → summarizing → complete
```

### Commands Available

A subset of orchestrator commands — those that support the linear flow:

- `/orchestrator-evaluate` — Tier classification
- `/orchestrator-roadmap` — Generate roadmap
- `/orchestrator-plan-phase` — Generate phase plans
- `/orchestrator-dispatch` — Dispatch tasks
- `/orchestrator-verify` — Verify must-haves
- `/orchestrator-status` — Show progress

Not available in Tier B: `/orchestrator-auto`, `/orchestrator-resume`, `/orchestrator-consolidate`, `/orchestrator-discuss`

### Typical Projects

- Medium features requiring 2–5 phases
- Single API endpoint with tests and documentation
- Component library addition with multiple sub-components
- Migration tasks with well-defined steps

---

## Tier C — Multiple SDD Flows, Full Orchestration

**When it applies**: The work requires orchestrating two or more complete SDD flows — multiple milestones or phases, each needing its own full specify → implement cycle, with roadmap decomposition, autonomous dispatch, and cross-phase coordination.

### What's Included

Everything in the orchestrator:

- Full roadmap with dependency graphs and boundary maps
- Autonomous mode — tasks dispatch without human intervention
- Crash recovery via lock files, PID liveness checks, and recovery briefings
- Stuck detection — same unit dispatched twice without progress triggers a stop
- Roadmap reassessment after each phase completes
- Knowledge consolidation — verbose phase artifacts compressed into milestone summaries
- Context draft discussion before planning
- Boundary map verification at phase boundaries
- Milestone-level validation gate
- Full decisions register and knowledge file management
- Execution log with detailed verification entries

### What's Excluded

Nothing — Tier C has access to the complete orchestrator surface.

### State Machine

Full 9-state machine:

```
pre-planning → discussing → planning → [replanning] → executing →
  summarizing → [back to planning if more phases] →
  validating → completing → complete
```

### Commands Available

All orchestrator commands:

- `/orchestrator-evaluate` — Tier classification
- `/orchestrator-discuss` — Context draft discussion
- `/orchestrator-roadmap` — Generate roadmap
- `/orchestrator-plan-phase` — Generate phase plans
- `/orchestrator-dispatch` — Dispatch tasks
- `/orchestrator-verify` — Verify must-haves
- `/orchestrator-status` — Show progress
- `/orchestrator-auto` — Autonomous execution
- `/orchestrator-resume` — Resume after crash/pause
- `/orchestrator-consolidate` — Knowledge consolidation

### Typical Projects

- Major feature additions spanning multiple subsystems
- Architecture migrations (e.g., monolith to microservices)
- New product modules with cross-cutting concerns
- Multi-sprint epics decomposed into shippable milestones

---

## Tier Promotion

Tier promotion from B → C is supported at any time (FR-002):

- **All existing artifacts are preserved** — roadmaps, phase plans, task plans, summaries, decisions, and knowledge carry forward unchanged.
- **New capabilities activate immediately** — lock files, autonomous mode, crash recovery, and discussion become available.
- **State machine expands** — the 5-state subset expands to the full 9-state machine. The current state is re-derived from disk (file-presence derivation is tier-agnostic).
- **No data migration required** — the orchestrator reads the same files regardless of tier. Promotion is a configuration change, not a structural one.

Tier demotion (C → B or B → A) is not recommended. If the project truly needs less orchestration, start a new milestone at the lower tier.

---

## Decision Table

Use this table to determine which tier applies to a project:

| Characteristic | Tier A | Tier B | Tier C |
|----------------|--------|--------|--------|
| Context windows needed | 1 | 2–10 | 10+ |
| SDD flows | 0–1 (inline) | 1 (single pass) | 2+ (multiple cycles) |
| Phases | 0 | 1–5 | 4–10+ |
| Cross-phase dependencies | None | Sequential | Complex graph |
| Boundary maps needed | No | Optional | Required |
| Autonomous execution | No | No | Yes |
| Crash recovery needed | No | No | Yes |
| Knowledge consolidation | No | No | Yes |
| Developer drives transitions | N/A | Yes | Optional (auto mode) |
| Estimated effort | < 1 hour | 1–8 hours | 8+ hours |

**Rule of thumb**: If you're unsure between tiers, start lower. You can always promote (B → C) without losing work. Starting too high adds unnecessary ceremony.

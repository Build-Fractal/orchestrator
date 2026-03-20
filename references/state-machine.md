# State Machine Reference

> Progressive disclosure reference for the speckit-orchestrator state machine.
> Self-contained — read this document to understand milestone lifecycle states without cross-referencing the spec or data model.

## Overview

The orchestrator uses a **file-presence state machine** with 9 canonical states. State is never stored as a field — it is derived deterministically by examining which files exist on disk under `.specify/orchestrator/milestones/{M###}/`. This means state survives crashes, is always consistent with reality, and requires no migration when resuming interrupted sessions.

The derivation script (`scripts/state/derive-phase.sh`) evaluates conditions in priority order and returns the first matching state.

---

## The 9 States

### 1. `pre-planning`

**Condition**: Milestone directory does not exist, or exists but contains no roadmap or context draft.

**What it means for the developer**: The milestone has been identified but no work has started. The developer needs to either begin a discussion (Tier C) or jump straight to planning.

**What it means for the orchestrator**: No state files to read. The next action is either `speckit.orchestrator.discuss` (Tier C) or `speckit.orchestrator.roadmap` (Tier B/C).

**Tier availability**: All tiers (Tier B and C).

---

### 2. `discussing`

**Condition**: A context draft file (`M###-CONTEXT.md`) exists with `status: draft` in its frontmatter.

**What it means for the developer**: The team is resolving architectural decisions, scope boundaries, design constraints, and open questions before committing to a plan. The context draft captures this conversation.

**What it means for the orchestrator**: Planning is blocked until the context draft is finalized (`status: finalized`). The orchestrator presents discussion sections and accepts updates.

**Tier availability**: Tier C only. Tier B skips this state — projects go directly from `pre-planning` to `planning`.

---

### 3. `planning`

**Condition**: No roadmap file exists yet, OR the roadmap exists but the active phase has no plan file (`P##-PLAN.md`).

**What it means for the developer**: The roadmap needs to be generated from the spec, or the next phase needs its detailed plan (task decomposition, must-haves, boundary map).

**What it means for the orchestrator**: Generate the roadmap via `speckit.orchestrator.roadmap`, then generate phase plans via `speckit.orchestrator.plan-phase` for each phase before execution begins.

**Tier availability**: All tiers (Tier B and C).

---

### 4. `replanning`

**Condition**: Any phase in the roadmap is marked as stale (needs replanning due to new information or failure).

**What it means for the developer**: Something discovered during execution invalidated part of the plan. A phase needs to be revised before work can continue.

**What it means for the orchestrator**: The stale phase's plan must be regenerated. Downstream phases may also need reassessment. The orchestrator re-enters `planning` for the affected phase after replanning completes.

**Tier availability**: Tier C only. Tier B does not support replanning — plans are executed as-is.

---

### 5. `executing`

**Condition**: The active phase has incomplete tasks (task plan files exist without corresponding summary files).

**What it means for the developer**: Tasks are being dispatched and worked on. Each task is an atomic unit that fits in one context window.

**What it means for the orchestrator**: Dispatch the next incomplete task via `speckit.orchestrator.dispatch`, verify its must-haves on completion, and persist the task summary. In autonomous mode (Tier C), this loops automatically.

**Tier availability**: All tiers (Tier B and C).

---

### 6. `summarizing`

**Condition**: All tasks in the active phase have summaries, but no phase summary (`P##-SUMMARY.md`) exists yet.

**What it means for the developer**: All planned work for this phase is done and verified. The phase needs its rollup summary before moving to the next phase.

**What it means for the orchestrator**: Generate the phase summary by compressing all task summaries into a phase-level rollup. After summarization, check if more phases remain — if yes, return to `planning`/`executing` for the next phase.

**Tier availability**: All tiers (Tier B and C).

---

### 7. `validating`

**Condition**: All phases in the milestone are complete (all have summaries), but no milestone validation has been performed.

**What it means for the developer**: The entire milestone's work is done at the phase level. A final cross-cutting validation ensures everything integrates correctly before closing out.

**What it means for the orchestrator**: Run the milestone-level verification gate — spec compliance review across all phases, cross-phase integration checks, and any configured verification commands.

**Tier availability**: Tier C only. Tier B skips validation — it goes directly from the last phase summary to `complete`.

---

### 8. `completing`

**Condition**: Milestone validation passed, but no milestone summary (`M###-SUMMARY.md`) exists yet.

**What it means for the developer**: The milestone has been validated. The final step is generating the milestone-level summary and performing knowledge consolidation.

**What it means for the orchestrator**: Generate the milestone summary (compressed rollup of all phase summaries), consolidate knowledge, and archive raw artifacts if configured.

**Tier availability**: Tier C only. Tier B does not have a separate completing state.

---

### 9. `complete`

**Condition**: The milestone summary (`M###-SUMMARY.md`) exists on disk.

**What it means for the developer**: The milestone is done. All phases completed, verified, and summarized. The milestone summary contains everything needed to understand what was built.

**What it means for the orchestrator**: No further action. The milestone is terminal. Knowledge and decisions are persisted for future milestones.

**Tier availability**: All tiers (Tier B and C).

---

## State Derivation Rules

The derivation script evaluates these conditions in strict priority order. The **first matching rule wins** — no further rules are evaluated.

| Priority | Condition | Derived State | Example |
|----------|-----------|---------------|---------|
| 1 | Milestone directory does not exist | `pre-planning` | `milestones/M001/` is absent |
| 2 | Context draft exists with `status: draft` | `discussing` | `M001-CONTEXT.md` has `status: draft` in frontmatter |
| 3 | No roadmap file exists | `planning` | `M001-ROADMAP.md` is absent |
| 4 | Any phase marked stale in roadmap | `replanning` | A phase line contains a stale marker |
| 5 | Active phase has incomplete tasks | `executing` | `T02-PLAN.md` exists but `T02-SUMMARY.md` does not |
| 6 | Active phase: all tasks done, no phase summary | `summarizing` | All `T##-SUMMARY.md` exist but `P01-SUMMARY.md` does not |
| 7 | All phases done, no milestone validation | `validating` | All `P##-SUMMARY.md` exist, no validation marker |
| 8 | Milestone validated, no milestone summary | `completing` | Validation passed but `M001-SUMMARY.md` absent |
| 9 | Milestone summary exists | `complete` | `M001-SUMMARY.md` exists |

**"Active phase"** = the first incomplete phase in dependency order, with high-risk phases prioritized among those whose dependencies are satisfied (per FR-043).

---

## State Transition Diagram

```
                    ┌──────────────┐
                    │ pre-planning │ ◄── scaffold milestone
                    └──────┬───────┘
                           │ discuss (Tier C required, Tier B skips)
                    ┌──────▼───────┐
                    │  discussing  │ ◄── create/update context draft
                    └──────┬───────┘
                           │ finalize context (status: draft → finalized)
                    ┌──────▼───────┐
                    │   planning   │ ◄── generate roadmap + phase plans
                    └──────┬───────┘
                           │ plan complete, dispatch first task
              ┌────────────▼────────────┐
              │       executing         │ ◄── dispatch tasks, verify each
              └────────────┬────────────┘
                           │ all tasks in phase done
              ┌────────────▼────────────┐
              │      summarizing        │ ◄── generate phase summary
              └────────────┬────────────┘
                           │ summary written
                           │ ◄── if more phases: back to planning/executing
                           │
              ┌────────────▼────────────┐
              │      validating         │ ◄── all phases done, milestone gate
              └────────────┬────────────┘     (Tier C only)
                           │ validation passed
              ┌────────────▼────────────┐
              │      completing         │ ◄── generate milestone summary
              └────────────┬────────────┘     (Tier C only)
                           │
              ┌────────────▼────────────┐
              │        complete         │
              └─────────────────────────┘
```

### Side Transitions

- **Replanning**: From `executing` or `summarizing`, if new information invalidates the current plan, the orchestrator marks the affected phase as stale. The next derivation cycle returns `replanning` (priority 4 fires before priority 5/6). After replanning, execution resumes.

- **Crash Recovery**: From any state, if a lock file (`orchestrator.lock`) exists with a stale PID (process no longer running), the orchestrator detects an interrupted session. Recovery reads surviving disk artifacts to determine what completed, synthesizes a recovery briefing, and resumes from the derived state. The lock file's `runtime` field determines the liveness check strategy (`local` → `kill -0`, `ci-github` → workflow API).

---

## Tier-Conditional State Machine

### Tier B (Single SDD Flow)

Tier B uses a **5-state subset** of the full state machine:

```
pre-planning → planning → executing → summarizing → complete
```

**Excluded states**: `discussing`, `replanning`, `validating`, `completing`

- No context draft discussion — planning starts immediately
- No replanning — plans execute as written
- No milestone-level validation gate — the last phase summary marks completion
- No separate completing state — milestone summary is optional or automatic
- Phases are sequential by default; boundary maps are optional
- No autonomous mode — the developer drives step transitions manually
- No crash recovery machinery (no lock files)

### Tier C (Full Orchestration)

Tier C uses the **full 9-state machine** with all transitions:

```
pre-planning → discussing → planning → [replanning] → executing →
  summarizing → [back to planning if more phases] →
  validating → completing → complete
```

- Context draft discussion required before planning
- Replanning supported when new information emerges
- Full milestone validation gate after all phases
- Separate completing state for milestone summary and knowledge consolidation
- Autonomous mode available — tasks dispatch without human intervention
- Crash recovery via lock files and stuck detection
- Boundary maps required for cross-phase coordination

### Tier A

Tier A does **not use the orchestrator state machine**. It routes directly to standard spec-kit commands with zero overhead. No orchestrator state files are created.

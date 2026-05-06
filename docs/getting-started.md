# Getting Started

> User guide for installing and using the spec-kit-orchestrator.
> Follow this guide to run your first orchestrated milestone from scratch.

> Audience: users

## Overview

spec-kit-orchestrator is a standalone autonomous orchestrator that adds multi-phase coordination to coding-agent workflows. It decomposes large features into milestones, phases, and tasks, then dispatches each task to a fresh agent context with a purpose-built payload. All state lives on disk -- there is no database, no long-running process, and no in-memory state to lose.

The orchestrator is useful when a feature is too large to build in a single context window. It manages the lifecycle from scope classification through execution, verification, and knowledge consolidation. You write a feature spec; the orchestrator figures out how many phases you need, plans each one, dispatches tasks with just enough context, verifies the results, and records what it learned for future milestones.

**Who it is for**: developers using Claude Code, Codex CLI, or Cursor who need to build features that span multiple context windows. If your feature fits in one context, the orchestrator classifies it as Tier A and steps aside -- you use your host runtime's native single-context workflow with zero overhead.

---

## Prerequisites

Before installing the orchestrator, ensure you have:

| Requirement | Version | Notes |
|-------------|---------|-------|
| Host runtime | recent | Claude Code, Codex CLI, or Cursor. |
| Bash | >= 3.2 | All helper scripts target Bash 3.2+ (macOS default). |
| git | any recent | Version control. Used for worktree isolation (optional). |
| jq | any recent | Optional. Used for JSON parsing in some scripts. Not required for core functionality. |

---

## Installation

The orchestrator ships as a runtime-specific installer that runs from a clone of this repo. The installer registers skills/commands, wires hooks, and stages the orchestrator runtime (`scripts/`, `templates/`, `references/`) directly into your project.

### 1. Run the installer

From a clone of the spec-kit-orchestrator repo:

```bash
# Claude Code (primary runtime)
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project

# Codex CLI
bash packaging/install/install-codex.sh --project-dir /path/to/your-project

# Cursor (--project-dir required)
bash packaging/install/install-cursor.sh --project-dir /path/to/your-project
```

The installer registers `orchestrator:*` skills/commands into the active runtime and stages `scripts/`, `templates/`, `references/` into your project (every `commands/*.md` invokes helpers via project-relative paths, so they must live there). Files are recorded in `.orchestrator/installed-files.txt` for clean uninstall.

### 2. Initialize your project

In your project directory:

```
/orchestrator-init
```

`init` probes the project, detects host capabilities, generates `.orchestrator/config.yml` with sensible defaults, and writes a runtime-appropriate instruction file. Completes in ~1 second.

### 3. Create project configuration (optional)

`/orchestrator-init` writes a default config. To customize, edit `.orchestrator/config.yml` or start from the template:

```bash
cp templates/orchestrator-config-default.yml .orchestrator/config.yml
```

Common settings:

```yaml
# Verification commands run after each task and phase
verification_commands:
  - npm test
  - npm run lint

# Override automatic tier classification
default_tier: null    # A, B, C, or null (auto-detect)

# Context verbosity for dispatch payloads
context_verbosity: standard   # minimal | standard | full
```

See `references/file-formats.md` for the full config schema, or `templates/orchestrator-config-default.yml` for a commented reference file.

### 4. Create your feature spec

Before running the orchestrator commands, you need a feature spec:

```bash
mkdir -p specs/001-your-feature
# Write your spec at specs/001-your-feature/spec.md
```

The spec should contain user stories, acceptance criteria, and functional requirements. The orchestrator analyzes these to determine scope and plan phases. Specs are read via pluggable format adapters at `scripts/dispatch/adapters/format/`; the orchestrator runs standalone with no external tool dependency. (See [Migrating from spec-kit](migrating-from-speckit.md) if you have an existing spec-kit project to onboard.)

### 5. Verify the installation

Confirm the orchestrator scripts are in place:

```bash
test -f scripts/lifecycle/scaffold.sh && echo "OK: scaffold.sh found"
bash -n scripts/state/derive-phase.sh && echo "OK: derive-phase.sh valid"
bash scripts/state/read-config.sh default_tier && echo "OK: read-config.sh works"
```

For the full installation reference, see [Installation](../references/installation.md).

---

## Your First Orchestrated Project

The orchestrator commands follow a sequential workflow. Each step produces files on disk that drive the next step. Here is the typical flow from start to finish.

### Step 1: Evaluate

```
/orchestrator-evaluate
```

This is always the first orchestrator command. It reads your feature spec, counts user stories, acceptance scenarios, and functional requirements, then classifies your project into one of three tiers:

- **Tier A** -- Single context. The orchestrator steps aside entirely. Use your host runtime's native single-context workflow.
- **Tier B** -- One SDD flow, multiple contexts. Manual dispatch with simplified state machine (5 states).
- **Tier C** -- Multiple SDD flows. Full orchestration with autonomous dispatch, crash recovery, discussion gates, and milestone validation (10 states).

The evaluate command scaffolds the orchestrator directory structure at `.orchestrator/milestones/M001/` and writes an evaluation file (`M001-EVALUATION.md`) that records the tier, spec path, and scope metrics.

If the evaluation classifies your project as Tier A, you are done with the orchestrator. Proceed with your host runtime's native workflow.

### Step 2: Discuss (Tier C only)

```
/orchestrator-discuss
```

For Tier C projects, discussion is a required gate before roadmap generation. This command creates and manages a context draft (`M001-CONTEXT.md`) that captures architectural decisions, scope boundaries, design constraints, and open questions.

The workflow is iterative:

1. The command creates a context draft with `status: draft`.
2. You discuss architecture, constraints, and design choices. The draft is updated as decisions are made.
3. When all open questions are resolved, the context draft is finalized (`status: finalized`).
4. The roadmap command will not proceed until the context draft is finalized.

For Tier B projects, discussion is optional. You can skip directly to the roadmap step.

### Step 3: Roadmap

```
/orchestrator-roadmap
```

This command decomposes your feature spec into an ordered sequence of phases. It reads the spec (and the finalized context draft for Tier C) and produces a roadmap file (`M001-ROADMAP.md`) that defines:

- **Phases**: numbered units of work (P01, P02, ...), each with a title, goal, and risk level
- **Dependencies**: which phases depend on which (e.g., P03 depends on P01 and P02)
- **Boundary maps** (Tier C): what crosses between phases -- shared types, APIs, database schemas
- **Cross-cutting concerns**: requirements that span multiple phases

The roadmap drives all downstream orchestration. Phase ordering, dependency resolution, and boundary enforcement all derive from this file.

### Step 4: Plan Phase

```
/orchestrator-plan-phase
```

This command plans a single phase by generating a detailed phase plan (`P01-PLAN.md`) with:

- **Truths**: grep-verifiable assertions that must hold after the phase completes (e.g., "file X contains pattern Y")
- **Artifacts**: files that must exist with minimum line counts and required content
- **Key links**: cross-file references that must resolve
- **Task decomposition**: individual tasks (T01, T02, ...) that each fit in one context window
- **Task plans**: per-task payloads with context, instructions, and acceptance criteria

Each task plan is written as a standalone document (`T01-PLAN.md`, `T02-PLAN.md`, ...) that contains everything a fresh context needs to execute the task without prior knowledge of the project.

Run this command once for each phase. The orchestrator identifies the next phase that needs planning and generates its plan.

### Step 5: Dispatch

For Tier B, dispatch tasks one at a time:

```
/orchestrator-dispatch
```

This command picks the next incomplete task in the active phase, assembles a context payload from the task plan and relevant state files, dispatches execution, verifies the output against must-haves, and records the result in the execution log.

For Tier C, you can run tasks autonomously:

```
/orchestrator-auto
```

The auto command acquires a session lock, then loops through the full lifecycle: derive state, check budget and stuck detection, dispatch the next task, verify results, record outcomes, and advance to the next task or phase. It continues until:

- The milestone completes
- A blocker is encountered (verification failure, stuck task, budget exceeded)
- A pause is requested

Auto mode handles phase transitions automatically -- when all tasks in a phase pass verification, it generates the phase summary, plans the next phase, and continues dispatching.

---

## Understanding Engine Output

When the orchestrator runs, it emits structured output lines that report what is happening at each stage. These lines are machine-parseable and human-readable.

### Events

Event lines follow the format:

```
EVENT:<TYPE> key=value key=value ...
```

Key event types:

| Event | Meaning |
|-------|---------|
| `DISPATCH_START` | A task dispatch is beginning. Includes model, token estimate, payload size. |
| `TASK_COMPLETE` | A task finished. Includes outcome (pass/fail/skip/blocked). |
| `PHASE_COMPLETE` | All tasks in a phase completed and passed verification. |
| `BUDGET_CHECK` | Budget enforcement ran. Includes remaining budget and elapsed time. |
| `STUCK_DETECTED` | A task has failed repeatedly and is flagged as stuck. |

Events are also appended to the execution log (`execution-log.jsonl`) for post-run analysis.

### Results

Result lines report verification outcomes:

```
RESULT:<CHECK_TYPE> status=<pass|fail> detail="..."
```

Check types include:
- `TRUTH` -- a grep pattern was checked against the codebase
- `ARTIFACT` -- a file existence or content check ran
- `KEY_LINK` -- a cross-file reference was validated
- `COMMAND` -- a configured verification command executed

### Verification

Verification uses a 4-tier ladder:

| Tier | What it checks | When it runs |
|------|---------------|--------------|
| Tier 1 -- Static | File existence, line counts, content patterns (grep) | Always. Every task and phase. |
| Tier 2 -- Commands | Configured test suites, linters, type checkers | When `verification_commands` are set in config. |
| Tier 3 -- Behavioral | Spec compliance review, cross-phase integration | Per-phase, after Tiers 1-2 pass. |
| Tier 4 -- Human | Manual review and acceptance | When configured; typically milestone-level. |

A task or phase is marked `pass` only when all applicable tiers succeed. Any failure at a lower tier prevents higher tiers from running.

For the full verification protocol, see [Verification Ladder](../references/verification-ladder.md).

---

## File Structure

All orchestrator state lives under `.orchestrator/`. The orchestrator never stores state in memory -- everything is derived from file presence on disk. This means state survives crashes and is always consistent with reality.

```
.orchestrator/
├── config.yml                    # Project config (written by orchestrator:init)
├── KNOWLEDGE.md                  # Global knowledge entries (patterns, lessons)
├── DECISIONS.md                  # Architectural decision register
├── execution-log.jsonl           # Append-only dispatch log (JSON lines)
├── orchestrator.lock             # Session lock (present during auto mode)
├── memory/
│   └── constitution.md           # 7 governing principles (if configured)
└── milestones/
    └── M001/
        ├── M001-EVALUATION.md    # Tier classification and scope metrics
        ├── M001-CONTEXT.md       # Discussion context draft (Tier C)
        ├── M001-ROADMAP.md       # Phase decomposition and dependencies
        ├── M001-SUMMARY.md       # Milestone rollup (written at completion)
        ├── M001-VALIDATED         # Cross-phase validation marker (Tier C)
        ├── execution-log.jsonl   # Per-milestone dispatch log
        └── phases/
            └── P01/
                ├── P01-PLAN.md           # Phase plan (truths, artifacts, tasks)
                ├── P01-VERIFICATION.md   # Phase verification report
                ├── P01-SUMMARY.md        # Phase rollup summary
                └── tasks/
                    ├── T01-PLAN.md       # Task plan (standalone payload)
                    ├── T01-SUMMARY.md    # Task result summary
                    ├── T02-PLAN.md
                    └── T02-SUMMARY.md
```

### Key files explained

- **EVALUATION.md**: Written by `evaluate`. Contains the tier (A/B/C), spec path, user story count, requirement count, and estimated SDD flow count.
- **CONTEXT.md**: Written by `discuss` (Tier C). Contains architectural decisions, design constraints, and resolved questions. Must be finalized (`status: finalized`) before roadmap generation.
- **ROADMAP.md**: Written by `roadmap`. Defines phases, dependencies, boundary maps, and cross-cutting concerns. The source of truth for phase ordering.
- **PLAN.md** (phase): Written by `plan-phase`. Contains truths, artifacts, key links, and task decomposition for one phase.
- **PLAN.md** (task): Written by `plan-phase`. A standalone document with everything a fresh context needs to execute one task.
- **SUMMARY.md**: Written after task/phase/milestone completion. Compressed rollup of what was done, what was learned, and what changed.
- **execution-log.jsonl**: Append-only log of every dispatch. Each line is a JSON object with milestone, phase, task, outcome, verification result, model, and timestamps.

For complete file format specifications, see [File Formats](../references/file-formats.md).

---

## Crash Recovery and Resume

The orchestrator is designed to survive crashes at any point during execution. State is never held in memory -- it is always derived from files on disk.

### What happens on crash

When a session crashes (process killed, machine restart, network failure):

1. The session lock file (`orchestrator.lock`) is left behind with the dead process's PID.
2. Any task that was mid-execution has no summary file -- it will be detected as incomplete on resume.
3. Completed tasks already have their summary files on disk and are not re-executed.

### How to resume

```
/orchestrator-resume
```

The resume command detects the type of interruption:

- **Crash**: A stale lock file exists (the lock holder's PID is no longer running). The command breaks the lock, synthesizes a recovery briefing from disk state, and resumes from the last completed task.
- **Graceful pause**: A continue file (`continue.md`) exists. The command reads the handoff context from the continue file and resumes where the pause left off.

In both cases, the state machine derives the current state from file presence. No task is re-executed if its summary already exists. The orchestrator picks up exactly where it left off.

### Stuck detection

During autonomous execution, the orchestrator monitors for stuck tasks -- tasks that fail verification repeatedly. If a task fails more times than the configured retry limit, the auto loop pauses and reports the blocker rather than retrying indefinitely.

---

## Running Diagnostics

The orchestrator includes a diagnostics subsystem for detecting common problems.

### Status check

```
/orchestrator-status
```

This is a read-only command that reports:
- Current state (e.g., `executing`, `verifying`, `planning`)
- Milestone completion (X/Y phases complete)
- Active phase progress (X/Y tasks complete)
- Overall progress percentage
- Blockers (stale locks, failed verification, stuck tasks)
- Recommended next action

### Doctor

The doctor subsystem runs a suite of diagnostic checks:

```bash
bash scripts/diagnostics/run-doctor.sh .orchestrator
```

Checks include:

| Check | What it detects |
|-------|----------------|
| `check-orphaned.sh` | Artifacts with no parent reference (orphaned files) |
| `check-stale.sh` | Knowledge entries that have not been accessed recently |
| `check-scope.sh` | Scope mismatches between roadmap and phase plans |
| `check-cost-spikes.sh` | Unusual cost patterns in the execution log |
| `check-permissions.sh` | Drift between generated and actual permission settings |
| `check-plans.sh` | Task plans with forbidden bash shapes (would block auto mode) |
| `check-constitution.sh` | Constitution consistency across dependent templates |
| `check-events.sh` | Event registry drift and missing event types |
| `check-hashes.sh` | Content hash validation for tamper detection |
| `check-run-ids.sh` | Run ID consistency across execution log entries |

Each check emits a structured line: `DOCTOR:<CHECK> status=ok|warn|fail detail="..."`. Use these to diagnose issues before they block execution.

You can also run the doctor through the command interface:

```
/orchestrator-doctor
```

---

## Migrating from spec-kit

If you already have a spec-kit project and want to adopt the orchestrator, see [Migrating from spec-kit](migrating-from-speckit.md). The orchestrator preserves spec-kit as a migration *source* via `scripts/migrate/adapters/speckit.sh` and `scripts/dispatch/adapters/format/speckit.sh`, and is not a runtime dependency.

---

## Next Steps

Once you are comfortable with the basic workflow, explore these topics:

- [Architecture](../references/architecture.md) -- How the engine pipeline works, data flow, and subsystem relationships
- [Engine Reference](../references/engine.md) -- CLI arguments, lifecycle stages, checkpointing, crash recovery
- [Events Reference](../references/events.md) -- Complete registry of EVENT: line types and field schemas
- [State Machine](../references/state-machine.md) -- The 10-state lifecycle, transition rules, and tier-conditional behavior
- [Verification Ladder](../references/verification-ladder.md) -- The 4-tier verification protocol in detail
- [Tier Definitions](../references/tier-definitions.md) -- When each tier applies and what features it includes
- [File Formats](../references/file-formats.md) -- State file format contracts for all orchestrator artifacts
- [Installation](../references/installation.md) -- Full installation reference including autonomy configuration and updating
- [Recipe Authoring](recipe-authoring.md) -- Customize context recipes for dispatched tasks
- [Hook Development](hook-development.md) -- Write custom quality gates and automation hooks
- [Knowledge Management](knowledge-management.md) -- Create and manage knowledge entries across milestones

# File Formats Reference

> Progressive disclosure reference for all speckit-orchestrator state file formats.
> Self-contained — read this document to understand any file format without cross-referencing other docs.
> For the authoritative contract with parsing rules, see `contracts/state-files.md`.

## Overview

All orchestrator state is persisted to disk under `.specify/orchestrator/`. Files use two primary formats: **YAML frontmatter + markdown body** (for human-readable documents) and **structured data** (JSON, JSONL, YAML for machine-readable state).

Every file write is idempotent (FR-066): writing a file that already exists is a no-op unless explicit overwrite is requested.

---

## Directory Structure

```
.specify/orchestrator/
├── DECISIONS.md                    # Global decisions register
├── KNOWLEDGE.md                    # Global knowledge file
├── execution-log.jsonl             # Global dispatch history
├── orchestrator.lock               # Active session lock (ephemeral)
├── continue.md                     # Pause resume point (ephemeral)
└── milestones/
    └── M001/
        ├── M001-EVALUATION.md      # Tier classification + spec path
        ├── M001-ROADMAP.md         # Phase definitions + boundary maps
        ├── M001-CONTEXT.md         # Discussion context draft (Tier C)
        ├── M001-SUMMARY.md         # Milestone rollup summary
        └── phases/
            └── P01/
                ├── P01-PLAN.md          # Task decomposition + must-haves
                ├── P01-VERIFICATION.md  # Phase verification report
                ├── P01-SUMMARY.md       # Phase summary
                └── tasks/
                    ├── T01-PLAN.md
                    ├── T01-SUMMARY.md
                    └── T02-PLAN.md
```

---

## Roadmap (`M###-ROADMAP.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/M###-ROADMAP.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written at planning, updated at reassessment. Never modify completed phases.

### Frontmatter Fields

```yaml
---
milestone: M001                              # Milestone ID
feature_ref: "001-speckit-orchestrator"       # Originating feature branch
feature_spec: "specs/001-speckit-orchestrator/spec.md"  # Path to spec
vision: "Core orchestration engine..."        # One-sentence vision
tier: C                                      # A, B, or C
created_at: "2026-03-19T10:00:00Z"           # ISO 8601
updated_at: "2026-03-19T10:00:00Z"           # ISO 8601
---
```

### Body — Phase Block Format

Each phase is a markdown list item with specific formatting:

```markdown
## Phases

- [x] **P01**: Extension Foundation — "Developer can install the extension"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml (validated manifest)
    - Consumes: none

- [ ] **P02**: State Machine Core — "Developer can see state derivation working"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/*.sh
    - Consumes: P01/extension.yml
```

### Parsing Rules

- Phase status: `[x]` = complete, `[ ]` = incomplete
- Phase ID: `**P##**` bold text after checkbox
- Demo sentence: text in quotes after `—` on the phase line
- Risk / Depends / Boundary Map: indented under phase, key-value after colon
- Reassessment: update existing incomplete phases, append new phases, never modify completed phases

---

## Phase Plan (`P##-PLAN.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/phases/{P##}/P##-PLAN.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written at phase planning. Immutable once tasks begin executing.

### Frontmatter Fields

```yaml
---
phase: P02                                    # Phase ID
milestone: M001                               # Parent milestone
goal: "Implement file-based state machine"    # Phase goal
demo_sentence: "Developer can see state derivation working"
risk: high                                    # high | medium | low
depends_on: [P01]                             # Phase ID dependencies
---
```

### Body — Must-Haves Structure

```markdown
## Must-Haves

### Truths
- derive-phase.sh outputs correct state for all 9 states
- State derivation completes in <1s

### Artifacts
- scripts/state/derive-phase.sh (min 40 lines, handles all 9 states)
- scripts/state/read-roadmap.sh (min 20 lines)

### Key Links
- commands/auto.md → scripts/state/derive-phase.sh
- scripts/state/derive-phase.sh → read-roadmap.sh

## Tasks

### T01: derive-phase.sh — Core state derivation
[Full task plan...]

### T02: read-roadmap.sh — Roadmap parser
[Full task plan...]
```

---

## Task Plan (`T##-PLAN.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/phases/{P##}/tasks/T##-PLAN.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written at task planning. Immutable during execution.

### Frontmatter Fields

```yaml
---
task: T01                          # Task ID
phase: P02                        # Parent phase
milestone: M001                   # Parent milestone
---
```

### Body Sections

```markdown
# T01: Task Name

## Description
[What this task does and why]

## Steps
1. [Step-by-step instructions with exact paths and commands]

## Must-Haves
- [ ] [Verification criteria]

## Verification
- [Commands to verify, with expected output]

## Inputs
- [Files and artifacts this task reads]

## Expected Output
- [Files and artifacts this task produces]
```

---

## Phase Verification Report (`P##-VERIFICATION.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/phases/{P##}/P##-VERIFICATION.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written once at phase verification. Never edited after creation.

### Frontmatter Fields

```yaml
---
schema_version: "1.0"
type: verification-report
phase: P01
milestone: M001
overall_result: pass             # pass | fail
verified_at: "2026-03-20T15:00:00Z"
---
```

### Body Sections

```markdown
# P01 Verification Report

## Tier 1 — Static Checks
[Must-have verification results from check-must-haves.sh]

## Tier 2 — Command Execution
[Test/lint results from run-commands.sh]

## Tier 3 — Behavioral Review
[Agent-driven truth evaluation results]

## Tier 4 — Human/UAT Review
[Human review items and their status]

## Summary
[Overall assessment: pass/fail with specific failures listed]
```

### State Machine Role

The presence of `P##-VERIFICATION.md` is what transitions the state from `verifying` → `summarizing`. Without this file, `derive-phase.sh` returns `verifying` when all tasks have summaries.

---

## Summaries (`*-SUMMARY.md`)

**Location**: Same directory as the corresponding plan file
**Format**: YAML frontmatter + markdown body
**Mutability**: Written once at completion. Never edited after creation.

### 15-Field Frontmatter Schema

All summary types (task, phase, milestone) share this 15-field base schema (phase and milestone summaries add `observability_surfaces` for 16 fields):

```yaml
---
id: T01                      # Unit ID (T##, P##, or M###)
parent: P01                  # Parent ID (P## for tasks, M### for phases, null for milestones)
milestone: M001              # Owning milestone
provides:                    # What this unit built (~5 items)
  - "derive-phase.sh: 9-state file-presence derivation"
requires:                    # Upstream dependencies consumed
  - from: P01/T01
    what: "extension.yml with command registration"
affects: [P03, P04]          # Downstream phase IDs depending on this output
key_files:                   # Important file paths
  - scripts/state/derive-phase.sh
key_decisions:               # Decisions made with brief rationale
  - "D003: POSIX sh for portability"
patterns_established:        # Patterns introduced
  - "File-presence state derivation at scripts/state/"
drill_down_paths:            # Paths to related plan/detail files
  - .specify/orchestrator/milestones/M001/phases/P01/tasks/T01-PLAN.md
duration: "25m"              # Actual duration
verification_result: pass    # pass | fail | partial
completed_at: "2026-03-19T14:30:00Z"  # ISO 8601
---
```

### Body Sections

```markdown
[One-line summary of what happened]

## What Happened
[Narrative description of implementation]

## Deviations
[Differences from plan, or "None — implemented per plan."]

## Files Created/Modified
- `path/to/file` — New/Modified. Description.
```

### Phase and Milestone Summary Extensions

Phase and milestone summaries add one field to the frontmatter:

```yaml
observability_surfaces:      # How to inspect this unit's health
  - "bash tests/test-phase.sh — runs all phase checks"
  - "grep -c 'PASS' tests/test-phase.sh — count passing checks"
```

Phase summaries are compressed rollups of all task summaries. Milestone summaries are compressed rollups of all phase summaries. Each includes `drill_down_paths` to the next level of detail.

---

## Evaluation (`M###-EVALUATION.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/M###-EVALUATION.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written at evaluation. Updated only on re-evaluation with `--force`.

### Frontmatter Fields

```yaml
---
schema_version: "1.0"
type: evaluation
milestone: M001                              # Milestone ID
feature_ref: "001-galaga-clone"              # Feature reference from spec dir
feature_spec: "specs/001-galaga-clone/spec.md"  # Path to feature spec
tier: C                                      # A, B, or C
tier_source: auto                            # auto | config | override
created_at: "2026-03-22T10:00:00Z"          # ISO 8601
---
```

### Body Sections

```markdown
# M001 Evaluation

## Classification
- **Tier**: C
- **Source**: auto
- **Next command**: speckit.orchestrator.discuss

## Metrics
| Metric | Count |
|--------|-------|
| User stories | 8 |
| Acceptance scenarios | 24 |
| Functional requirements | 45 |
| Estimated SDD flows | 3 |

## Reasoning
[Narrative explanation of tier classification]

## Complexity Factors
[Key factors that influenced the classification]
```

### Role in the System

The evaluation file is the **authoritative source of tier classification** for all downstream commands. Commands like `discuss`, `roadmap`, and `plan-phase` read the `tier` and `feature_spec` fields from this file rather than re-deriving them. This ensures consistency — the tier used during planning matches the tier determined during evaluation, even if `default_tier` in config changes later.

---

## Context Draft (`M###-CONTEXT.md`)

**Location**: `.specify/orchestrator/milestones/{M###}/M###-CONTEXT.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written at discussion start, updated during discussion, finalized once.
**Tier**: Tier C required, Tier B optional.

### Frontmatter Fields

```yaml
---
milestone: M001
status: draft                     # draft | finalized
created_at: "2026-03-19T09:00:00Z"
finalized_at: null                # Set when status → finalized
---
```

### Body Sections

```markdown
## Architectural Decisions
[Preferences about patterns, libraries, approaches]

## Scope Boundaries
[What is explicitly in and out of scope]

## Design Constraints
[Non-negotiable requirements from stakeholders or existing systems]

## Open Questions
[Unresolved items to investigate during planning]
```

### Finalization Rules

- Setting `status: finalized` and `finalized_at` to a timestamp triggers the `discussing` → `planning` state transition.
- Once finalized, the context draft is read-only. Create a new context draft for scope changes during execution.

---

## Continue File (`continue.md`)

**Location**: `.specify/orchestrator/continue.md`
**Format**: YAML frontmatter + markdown body
**Mutability**: Written on pause, consumed on resume. Ephemeral — deleted after successful resume.

### Frontmatter Fields

```yaml
---
milestone: M001                    # Current milestone
phase: P01                        # Current phase
task: T03                         # Current or next task
step: 2                           # Step within current task
total_steps: 5                    # Total steps in task
saved_at: "2026-03-19T14:00:00Z"  # When pause occurred
---
```

### Body Sections

```markdown
## Completed Work
[What was finished before pause]

## Remaining Work
[What still needs to be done]

## Decisions Made
[Decisions recorded during this session]

## Context
[Any context needed to resume effectively]

## Next Action
[The specific next action to take on resume]
```

### Consumption Rules

- On resume, the orchestrator reads the continue file, reconstructs context, and resumes from the indicated step.
- After successful resume and re-entry into the execution loop, the continue file is deleted.
- If the continue file references a task that already has a summary, skip to the next incomplete task.

---

## Lock File (`orchestrator.lock`)

**Location**: `.specify/orchestrator/orchestrator.lock`
**Format**: JSON
**Mutability**: Created at session start, deleted at session end. Ephemeral.

### Schema

```json
{
  "pid": 12345,
  "runtime": "local",
  "startedAt": "2026-03-19T10:00:00Z",
  "unitType": "execute-task",
  "unitId": "M001/P01/T02",
  "unitStartedAt": "2026-03-19T10:15:00Z",
  "completedUnits": ["M001/P01/T01"],
  "featureBranch": "001-speckit-orchestrator"
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `pid` | number | Process ID of the orchestrator session |
| `runtime` | string | Runtime discriminator: `"local"`, `"ci-github"`, etc. |
| `startedAt` | ISO 8601 | When the session started |
| `unitType` | string | Current operation type |
| `unitId` | string | Current unit being processed |
| `unitStartedAt` | ISO 8601 | When the current unit started |
| `completedUnits` | string[] | Units completed in this session |
| `featureBranch` | string | Git branch being worked on |

For CI runtimes, add `"run_id": "12345678"` field.

### Staleness Check

The `runtime` field determines the liveness check strategy:

- `"local"` — read `pid`, attempt `kill -0 $pid`. Process gone → stale.
- `"ci-github"` — read `run_id`, call GitHub Actions API. Status not `in_progress` → stale. **Note:** CI runtime liveness checks (GitHub API `run_id` lookup) are deferred to US7 (GitHub Agentic Workflows). In v0.1.0, only local PID checking via `kill -0` is implemented.
- Unknown runtime → treat as stale (fail-open for crash recovery).

---

## Execution Log (`execution-log.jsonl`)

**Location**: `.specify/orchestrator/execution-log.jsonl`
**Format**: JSONL (one JSON object per line)
**Mutability**: Append-only. Never edit or delete existing entries.

### Entry Format (via `record-result.sh`)

```json
{
  "timestamp": "2026-03-19T10:15:00Z",
  "unitId": "M001/P01/T01",
  "milestone": "M001",
  "phase": "P01",
  "task": "T01",
  "tier": "C",
  "outcome": "success",
  "dispatch_method": "subagent",
  "attempt": 1,
  "verification_result": "pass",
  "duration_s": 300,
  "payload_bytes": 4096
}
```

Use `scripts/lifecycle/record-result.sh` to append entries with field validation. The script generates `timestamp` and `unitId` automatically from `milestone`, `phase`, and `task` fields.

### Required Fields

`timestamp`, `unitId`, `milestone`, `phase`, `task`, `tier`, `outcome`, `dispatch_method`, `attempt`

### Optional Fields

`verification_result`, `duration_s`, `payload_bytes`, `concerns`

### Outcome Values

`success`, `failure`, `retry`, `blocked`, `timeout`, `stuck`

### Verification Entry

Appended after phase verification with detailed per-tier results:

```json
{
  "timestamp": "2026-03-19T15:00:00Z",
  "unitId": "M001/P01",
  "unitType": "verify-phase",
  "tier": "C",
  "duration": "30s",
  "outcome": "success",
  "verification": {
    "tier1_static": {"status": "pass", "checks": 5, "failures": 0},
    "tier2_command": {"status": "pass", "checklist": "P01-must-haves"},
    "tier3_behavioral": {"status": "skipped"},
    "tier4_human": {"status": "skipped"}
  },
  "featureBranch": "001-speckit-orchestrator"
}
```

---

## Decisions Register (`DECISIONS.md`)

**Location**: `.specify/orchestrator/DECISIONS.md`
**Format**: Markdown table
**Mutability**: Append-only. Never edit or remove existing rows.

### Table Format

```markdown
| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/P01/T01 | arch | State derivation mechanism? | File-presence-based | Crash recovery derives from what exists | No |
```

### Columns

| Column | Description |
|--------|-------------|
| `#` | Sequential ID: D001, D002, ... |
| `When` | Unit scope where the decision was made (e.g., M001/P01/T01) |
| `Scope` | Category: `arch`, `pattern`, `library`, `data`, `api`, `scope`, `convention` |
| `Decision` | The question being decided |
| `Choice` | The answer chosen |
| `Rationale` | Why this choice was made |
| `Revisable?` | `No` or `Yes — [trigger condition]` |

### Append Rules

- New entries go at the bottom of the table
- Never edit existing rows
- Reversals are new rows referencing the original: `D005 | ... | Reverses D002: now targeting bash 4+ because...`
- Check if an exact entry already exists before appending (idempotency)

---

## Knowledge File (`KNOWLEDGE.md`)

**Location**: `.specify/orchestrator/KNOWLEDGE.md`
**Format**: Markdown list with scope tags
**Mutability**: Append-only. Never edit existing entries.

### Entry Format

```markdown
- **[scope]** [date] Description of the pattern, rule, or lesson learned.
```

### Scope Tags

| Scope | Applies to |
|-------|------------|
| `project` | Entire project, all milestones |
| `milestone:M001` | Specific milestone |
| `phase:M001/P02` | Specific phase |

### Append Rules

- New entries go at the bottom
- Never edit existing entries
- Check for duplicates before appending

---

## Configuration (`orchestrator-config.yml`)

**Location**: Project root (not inside `.specify/orchestrator/`)
**Format**: YAML
**Mutability**: Edited by the developer or team.

### 7 Configuration Keys

```yaml
default_tier: null              # Auto-detect. Override: A, B, or C
verification_commands:          # Run after each task
  - npm test
  - npm run lint
context_verbosity: standard     # minimal | standard | full
git_isolation: false            # Use git worktree per milestone
dispatch_budget: null           # Max dispatches per milestone (advisory)
duration_budget: null           # Max cumulative duration (e.g., "2h")
budget_enforcement: advisory    # advisory (warn only) | enforced (stop-after)
```

### Precedence Layers (highest to lowest)

1. **Environment variables**: `SPECKIT_ORCHESTRATOR_{KEY}` (e.g., `SPECKIT_ORCHESTRATOR_DEFAULT_TIER=B`)
2. **Local config**: `orchestrator-config.local.yml` (project root, gitignored)
3. **Project config**: `orchestrator-config.yml` (project root, team-shared)
4. **Extension defaults**: `extension.yml` defaults section (factory defaults)

Each key is resolved independently — a local config can override one key while falling through to project config for others.

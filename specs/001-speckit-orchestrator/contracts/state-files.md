# Contract: State File Formats

**Version**: 1.0 | **Date**: 2026-03-19
**Spec References**: FR-019, FR-020, File Format Specifications

## Overview

All orchestrator state is persisted to disk under `.specify/orchestrator/`. This contract defines the exact format of every state file. Scripts and commands that read or write these files MUST conform to these formats.

## File Index

| File | Format | Mutability | Scope |
|------|--------|-----------|-------|
| `orchestrator.lock` | JSON | Created/deleted per session | Global |
| `continue.md` | YAML frontmatter + markdown | Written on pause, consumed on resume | Global |
| `DECISIONS.md` | Markdown table | Append-only | Global |
| `KNOWLEDGE.md` | Markdown list | Append-only | Global |
| `execution-log.jsonl` | JSONL (one object per line) | Append-only | Global |
| `M###-ROADMAP.md` | YAML frontmatter + markdown | Written at planning, updated at reassessment | Per-milestone |
| `M###-CONTEXT.md` | YAML frontmatter + markdown | Written at discussion, finalized once | Per-milestone |
| `{M###}-TIER.md` | YAML frontmatter | Written at evaluation, updated on override | Per-milestone |
| `M###-SUMMARY.md` | YAML frontmatter + markdown | Written at completion, updated per phase | Per-milestone |
| `M###-VALIDATION.md` | YAML frontmatter + markdown | Written at validation, immutable after | Per-milestone |
| `P##-PLAN.md` | YAML frontmatter + markdown | Written at phase planning | Per-phase |
| `P##-SUMMARY.md` | YAML frontmatter + markdown | Written at phase summarization | Per-phase |
| `T##-PLAN.md` | YAML frontmatter + markdown | Written at task planning | Per-task |
| `T##-SUMMARY.md` | YAML frontmatter + markdown | Written at task completion | Per-task |

## Roadmap Format (`M###-ROADMAP.md`)

```yaml
---
schema_version: 1
milestone: M001
feature_ref: "001-speckit-orchestrator"
feature_spec: "specs/001-speckit-orchestrator/spec.md"
vision: "Core orchestration engine with state machine, dispatch, and verification"
tier: C
success_criteria:
  - "SC-001: Tier classification completes in <5 minutes"
  - "SC-003: 5-phase milestone completes autonomously without human intervention"
  - "SC-009: 100% of phase transitions include mechanical verification"
created_at: "2026-03-19T10:00:00Z"
updated_at: "2026-03-19T10:00:00Z"
---
```

**`success_criteria`**: List of measurable milestone-level success criteria. Sourced from the feature spec's Success Criteria section during roadmap generation. Used by `mark-complete.sh` to generate `M###-VALIDATION.md` with one checkbox per criterion. Required for Tier C milestones (populates the `validating` gate); optional for Tier B.

```markdown
## Phases

- [x] **P01**: Extension Foundation — "Developer can install the extension and see all 10 commands registered"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: extension.yml (validated manifest), commands/*.md (10 command stubs)
    - Consumes: none

- [ ] **P02**: State Machine Core — "Developer can scaffold a milestone and see state derivation working"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/*.sh (derive-phase, read-roadmap, check-lock, read-config)
    - Consumes: P01/extension.yml (command registration)

- [ ] **P03**: Dispatch Pipeline — "Developer can dispatch a single task to a fresh context and get results back"
  - Risk: high
  - Depends: P02
  - Boundary Map:
    - Produces: scripts/dispatch/*.sh, templates/dispatch-prompt.md, runtime adapters
    - Consumes: P02/derive-phase.sh (state), P02/read-roadmap.sh (phase info)
```

**Parsing Rules**:
- Phase status: `[x]` = complete, `[ ]` = incomplete
- Phase ID: `**P##**` bold text after checkbox
- Demo sentence: text after `—` on the phase line
- Risk/Depends/Boundary Map: indented under phase, key-value after colon
- Reassessment: update existing phases, append new phases, never modify completed phases

## Tier Metadata Format (`{M###}-TIER.md`)

```yaml
---
schema_version: 1
tier: C
feature_ref: "001-speckit-orchestrator"
feature_spec: "specs/001-speckit-orchestrator/spec.md"
classified_at: "2026-03-19T10:00:00Z"
override: false
---
```

Created by `evaluate` during scaffolding. Persists tier classification before roadmap exists, enabling `derive-phase.sh` to determine tier-conditional state transitions.

**Fields**:
- `tier`: B or C (Tier A produces no orchestrator state)
- `feature_ref`: Feature branch name
- `feature_spec`: Path to spec.md
- `classified_at`: When classification occurred
- `override`: Whether developer manually overrode the automatic classification

## Milestone Validation Format (`M###-VALIDATION.md`)

```yaml
---
schema_version: 1
milestone: M001
status: pass  # pass | fail
validated_at: "2026-03-19T16:00:00Z"
validator: auto  # auto | human
---
```

```markdown
## Success Criteria Checklist

- [x] SC-001: Description — **Evidence**: reference to test output or artifact
- [x] SC-002: Description — **Evidence**: reference
- [ ] SC-003: Description — **Evidence**: (pending or failing)
```

**Fields**:
- `schema_version`: Always `1` for v0.1.0
- `milestone`: Milestone ID (M001, M002...)
- `status`: `pass` (all criteria checked) or `fail` (any unchecked)
- `validated_at`: ISO 8601 timestamp when validation was performed
- `validator`: `auto` (mechanical validation via scripts) or `human` (manual review)

**Rules**:
- Created by `mark-complete.sh` for Tier C milestones only (Tier B skips validation)
- Immutable after `status: pass` — no updates allowed
- Body contains one checkbox per milestone success criterion with evidence reference
- `derive-phase.sh` rule #7: absence of this file triggers `validating` state; presence enables `completing`

## Phase Plan Format (`P##-PLAN.md`)

```yaml
---
schema_version: 1
phase: P02
milestone: M001
goal: "Implement file-based state machine with 9-state derivation"
demo_sentence: "Developer can scaffold a milestone and see state derivation working"
risk: high
depends_on: [P01]
---
```

```markdown
## Must-Haves

### Truths
- derive-phase.sh outputs correct state for all 9 states
- State derivation completes in <1s on a milestone with 10 phases

### Artifacts
- scripts/state/derive-phase.sh (min 40 lines, handles all 9 states)
- scripts/state/read-roadmap.sh (min 20 lines, parses checkbox + frontmatter)
- scripts/state/check-lock.sh (min 15 lines, PID liveness check)
- scripts/state/read-config.sh (min 25 lines, 4-layer resolution)

### Key Links
- commands/auto.md → scripts/state/derive-phase.sh (invokes for state)
- commands/status.md → scripts/state/read-roadmap.sh (displays progress)
- scripts/state/derive-phase.sh → read-roadmap.sh (reads phase completion)

## Tasks

### T01: derive-phase.sh — Core state derivation
[Full task plan with exact paths, code, commands, expected output...]

### T02: read-roadmap.sh — Roadmap parser
[Full task plan...]

### T03: check-lock.sh + read-config.sh — Support scripts
[Full task plan...]
```

## Summary Frontmatter (Task, Phase, Milestone)

All summaries share this base schema:

```yaml
---
schema_version: 1
id: T01              # or P01 or M001
parent: P01          # or M001 or null (for milestone)
milestone: M001
provides:            # What this unit built (~5 items)
  - "derive-phase.sh: 9-state file-presence derivation"
requires:            # Upstream dependencies consumed
  - from: P01/T01
    what: "extension.yml with command registration"
affects: [P03, P04]  # Downstream phase IDs depending on this output
key_files:           # Important file paths
  - scripts/state/derive-phase.sh
key_decisions:       # Decisions made with brief rationale
  - "D003: POSIX sh for portability"
patterns_established: # Patterns introduced
  - "File-presence state derivation at scripts/state/"
drill_down_paths:    # Paths to related plan files
  - .specify/orchestrator/milestones/M001/phases/P02/tasks/T01-PLAN.md
duration: "25m"
verification_result: pass  # pass | fail | partial
completed_at: "2026-03-19T14:30:00Z"
---
```

## Execution Log Entry Format

```json
{
  "schema_version": 1,
  "timestamp": "2026-03-19T10:15:00Z",
  "unitId": "M001/P01/T01",
  "unitType": "execute-task",
  "tier": "C",
  "duration": "5m",
  "outcome": "success",
  "model": "claude-opus-4-6",
  "featureBranch": "001-speckit-orchestrator"
}
```

**unitType values**: `evaluate`, `discuss`, `plan-phase`, `execute-task`, `verify-phase`, `summarize-phase`, `validate-milestone`, `complete-milestone`, `consolidate`

**outcome values**: `success`, `failure`, `blocked`, `concerns`, `timeout`, `stuck`

**Verification Entry** (appended after phase verification):
```json
{
  "schema_version": 1,
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

## Lock File Format

```json
{
  "schema_version": 1,
  "pid": 12345,
  "runtime": "local",
  "startedAt": "2026-03-19T10:00:00Z",
  "unitType": "execute-task",
  "unitId": "M001/P01/T02",
  "unitStartedAt": "2026-03-19T10:15:00Z",
  "completedUnits": ["M001/P01/T01"],
  "featureBranch": "001-speckit-orchestrator",
  "phase_start_tree": "abc1234"
}
```

**Staleness Check**: Read `runtime` field to determine liveness strategy:
- `"local"` — read `pid`, attempt `kill -0 $pid`. Process gone → stale.
- `"ci-github"` — read `run_id`, call `gh api /repos/{owner}/{repo}/actions/runs/{run_id}`. Status not `in_progress` → stale.
- Unknown runtime → treat as stale (fail-open for crash recovery).

The `runtime` discriminator makes the lock file self-describing — `derive-phase.sh` needs no adapter code to check liveness.

**`phase_start_tree`**: Git tree hash captured at phase start. Used by `check-external-mods.sh` (FR-064) to detect files changed outside the orchestrator at phase boundaries. Compared against current working tree to identify external modifications before the two-stage review.

## DECISIONS.md Table Format

```markdown
| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/P01/T01 | arch | ... | ... | ... | No |
```

**Scope values**: `arch`, `pattern`, `library`, `data`, `api`, `scope`, `convention`

**Append rule**: New entries go at the bottom. Never edit existing rows. Reversals are new rows: `D005 | ... | Reverses D002: ...`

## KNOWLEDGE.md Entry Format

```markdown
- **[scope]** [date] Description of the pattern, rule, or lesson learned.
```

**Scope values**: `project`, `milestone:M001`, `phase:M001/P02`

**Append rule**: New entries go at the bottom. Never edit existing entries.

## Idempotency Contract

All file writes MUST be idempotent (FR-066):
- Scaffolding an existing milestone → no-op
- Writing a summary that already exists → no-op (require explicit confirmation to overwrite)
- Appending to DECISIONS.md → check if exact entry already exists before appending
- Creating a lock when one exists → check PID liveness first
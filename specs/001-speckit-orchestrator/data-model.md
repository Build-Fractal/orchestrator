# Data Model: Speckit-Orchestrator Extension

**Date**: 2026-03-19
**Source**: spec.md (Key Entities, File Format Specifications), research.md, conversus final summary

## Entity Relationship Diagram

```
Milestone (M001, M002...)
 ├── has many → Phase (P01, P02... per milestone)
 │    ├── has many → Task (T01, T02... per phase)
 │    │    └── produces → Task Summary (T##-SUMMARY.md)
 │    ├── produces → Phase Summary (P##-SUMMARY.md)
 │    └── declares → Boundary Map (produces/consumes interfaces)
 ├── produces → Milestone Summary (M###-SUMMARY.md)
 ├── produces → Milestone Validation (M###-VALIDATION.md) [Tier C only]
 ├── owns → Context Draft (M###-CONTEXT.md) [Tier C required, Tier B optional]
 ├── owns → Tier Metadata (M###-TIER.md) [Tier B/C only, created at evaluation]
 └── references → Feature Spec (specs/{NNN}/spec.md)

Global State (project-wide, not per-milestone)
 ├── DECISIONS.md (append-only register)
 ├── KNOWLEDGE.md (append-only cross-session memory)
 ├── execution-log.jsonl (append-only dispatch history)
 ├── orchestrator.lock (ephemeral, per-session)
 └── continue.md (ephemeral, written on pause)

Configuration (outside .specify/orchestrator/, outside APM radius)
 ├── extension.yml defaults section (factory defaults)
 ├── orchestrator-config.yml (project root, team-shared)
 ├── orchestrator-config.local.yml (project root, gitignored)
 └── SPECKIT_ORCHESTRATOR_* env vars (per-run/CI)
```

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
        ├── M001-TIER.md            # Tier classification (B or C)
        ├── M001-ROADMAP.md         # Phase definitions + boundary maps + dependencies
        ├── M001-CONTEXT.md         # Discussion context draft (Tier C)
        ├── M001-SUMMARY.md         # Milestone rollup (updated per phase completion)
        ├── M001-VALIDATION.md      # Milestone validation gate (Tier C only)
        └── phases/
            └── P01/
                ├── P01-PLAN.md     # Task decomposition + must-haves
                ├── P01-SUMMARY.md  # Phase summary (14-field frontmatter)
                ├── archive/        # Prior summaries preserved on rollback (FR-058)
                └── tasks/
                    ├── T01-PLAN.md
                    ├── T01-SUMMARY.md
                    └── T02-PLAN.md
```

## Entity Definitions

### Milestone

| Field | Type | Description |
|-------|------|-------------|
| id | `M###` (M001, M002...) | Sequential, zero-padded to 3 digits |
| feature_ref | string | Originating feature branch + spec dir path |
| vision | string | One-sentence milestone vision |
| success_criteria | string[] | Measurable outcomes for milestone completion |
| phases | Phase[] | Ordered list of phases (4-10 per milestone) |
| status | derived | Derived from file presence (see State Machine) |

**Lifecycle**: pre-planning → discussing → planning → executing → summarizing → validating → completing → complete

**Constraints**:
- One spec-kit feature maps to one milestone by default (FR-055)
- Tier C may map one feature to multiple milestones
- `feature_ref` in roadmap frontmatter links back to originating feature
- `success_criteria` in roadmap frontmatter lists measurable outcomes; consumed by `mark-complete.sh` to generate M###-VALIDATION.md (Tier C validating gate)

### Phase

| Field | Type | Description |
|-------|------|-------------|
| id | `P##` (P01, P02...) | Sequential within milestone, zero-padded to 2 digits |
| parent | `M###` | Owning milestone |
| goal | string | Phase goal statement |
| demo_sentence | string | What user can see/do when phase completes (FR-006) |
| risk | enum | high / medium / low (drives execution order, FR-043) |
| depends_on | `P##`[] | Phase IDs this phase depends on |
| boundary_map | BoundaryMap | What this phase produces and consumes |
| must_haves | MustHaves | Verification criteria |
| tasks | Task[] | 1-7 tasks per phase |
| status | derived | Derived: no plan → unplanned; plan exists, tasks incomplete → executing; all tasks done, no summary → summarizing; summary exists → complete |

**Constraints**:
- Each phase 1-7 tasks (FR-004)
- High-risk phases execute before low-risk among satisfied dependencies (FR-043)
- Tier B: phases are sequential by default, boundary maps optional
- Tier C: boundary maps required, dependencies explicit

### Task

| Field | Type | Description |
|-------|------|-------------|
| id | `T##` (T01, T02...) | Sequential within phase, zero-padded to 2 digits |
| parent | `P##` | Owning phase |
| milestone | `M###` | Owning milestone |
| name | string | Descriptive task name |
| plan | markdown | Complete task plan (exact paths, code, commands, expected output) |
| must_haves | MustHaves | Per-task verification criteria |
| status | derived | Derived: no summary → incomplete; summary exists → complete |

**Constraints**:
- MUST fit in one context window (iron rule, FR-005)
- Plan assumes zero context (FR-011, Principle IV)
- Atomic dispatch unit for autonomous execution (FR-012)

### Boundary Map

| Field | Type | Description |
|-------|------|-------------|
| produces | Interface[] | Function signatures, types, endpoints, file paths this phase creates |
| consumes | Interface[] | Specific outputs from upstream phases this phase depends on |

**Structure**:
```yaml
boundary_map:
  produces:
    - type: script
      path: scripts/state/derive-phase.sh
      exports: [derive_phase]
    - type: template
      path: templates/dispatch-prompt.md
  consumes:
    - from: P01
      artifact: extension.yml
      field: provides.commands
```

### Must-Haves

| Field | Type | Description |
|-------|------|-------------|
| truths | string[] | Observable behaviors that must be true when done |
| artifacts | Artifact[] | Files that must exist with real content |
| key_links | Link[] | Critical wiring between artifacts that must be verified |

**Artifact**:
```yaml
- path: scripts/state/derive-phase.sh
  min_lines: 20
  contains: ["pre-planning", "executing", "complete"]  # optional content checks
```

**Link**:
```yaml
- from: commands/auto.md
  to: scripts/state/derive-phase.sh
  via: "references script path in command body"
```

### Task Summary (`T##-SUMMARY.md`)

**Frontmatter** (YAML):
```yaml
---
schema_version: 1
id: T01
parent: P01
milestone: M001
provides:
  - "derive-phase.sh: 9-state derivation from file presence"
  - "dispatch table pattern: first-match-wins rule evaluation"
requires:
  - from: P01/T01
    what: "extension.yml with command registration"
affects: [P02, P03]
key_files:
  - scripts/state/derive-phase.sh
  - scripts/state/read-roadmap.sh
key_decisions:
  - "D003: Use POSIX sh for portability over bash-specific features"
patterns_established:
  - "File-presence state derivation at scripts/state/"
drill_down_paths:
  - .specify/orchestrator/milestones/M001/phases/P01/tasks/T01-PLAN.md
duration: "25m"
verification_result: pass
completed_at: "2026-03-19T14:30:00Z"
---
```

**Body**:
```markdown
State derivation script that reads `.specify/orchestrator/` directory tree and outputs the current state machine phase.

## What Happened
Implemented the 9-state derivation logic following the dispatch table pattern from research.md (R-002). Used POSIX sh for cross-platform compatibility.

## Deviations
None — implemented per plan.

## Files Created/Modified
- `scripts/state/derive-phase.sh` — New. 45 lines. Core state derivation.
- `scripts/state/read-roadmap.sh` — New. 30 lines. Roadmap parsing helper.
```

### Phase Summary (`P##-SUMMARY.md`)

Same frontmatter schema as task summary (including `schema_version: 1`), but `id` is a phase ID, `parent` is a milestone ID. Body is a compressed rollup of all task summaries. Includes `drill_down_paths` to each task summary.

### Milestone Summary (`M###-SUMMARY.md`)

Same frontmatter schema (including `schema_version: 1`). Compressed rollup of all phase summaries. Updated incrementally as each phase completes.

### Decisions Register (`DECISIONS.md`)

**Format**: Markdown table, append-only.

```markdown
| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/P01/T01 | arch | State derivation mechanism? | File-presence-based, not stored field | Crash recovery derives state from what exists, not what was recorded | No |
| D002 | M001/P01/T02 | convention | Shell script portability target? | POSIX sh | Must work on macOS (zsh default) and Linux (bash default) | Yes — if we drop macOS support |
```

**Columns**: `#` (D001...), `When` (unit scope), `Scope` (arch|pattern|library|data|api|scope|convention), `Decision` (question), `Choice` (answer), `Rationale` (why), `Revisable?` (No | Yes — trigger condition).

Reversals are new rows referencing the original: `D005 | ... | Reverses D002: now targeting bash 4+ because...`

### Knowledge File (`KNOWLEDGE.md`)

**Format**: Append-only markdown list with scope tags.

```markdown
- **[project]** [2026-03-19] spec-kit hooks use `optional: true` — the LLM decides whether to execute. Conditions in hook definitions are NOT evaluated by the LLM. Use descriptive prompts instead.
- **[milestone:M001]** [2026-03-19] All state scripts must handle the case where `.specify/orchestrator/` doesn't exist yet (pre-scaffolding state).
- **[phase:M001/P01]** [2026-03-19] `jq` is optional — scripts must degrade to grep/sed when jq is unavailable.
```

### Lock File (`orchestrator.lock`)

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
  "phase_start_tree": "abc123def456"
}
```

The `phase_start_tree` field stores the git tree hash at phase start (via `git write-tree`). Used by `check-external-mods.sh` (FR-064) to detect files changed outside the orchestrator at phase boundaries.

**Runtime discriminator**: The `runtime` field determines the liveness check strategy:
- `"local"` — check PID existence via `kill -0 $pid`
- `"ci-github"` — check workflow run status via `gh api /repos/{owner}/{repo}/actions/runs/{run_id}`
- Extensible to `"ci-gitlab"`, `"ci-azure"`, etc.

For CI runtimes, add `"run_id": "12345678"` field. `derive-phase.sh` reads `runtime` to dispatch the correct liveness check without needing adapter code (self-describing schema).

### Continue File (`continue.md`)

**Frontmatter**:
```yaml
---
schema_version: 1
milestone: M001
phase: P01
task: T03
step: 2
total_steps: 5
saved_at: "2026-03-19T14:00:00Z"
---
```

**Body**: Completed Work, Remaining Work, Decisions Made, Context, Next Action.

### Context Draft (`M###-CONTEXT.md`)

**Frontmatter**:
```yaml
---
schema_version: 1
milestone: M001
status: draft  # or: finalized
created_at: "2026-03-19T09:00:00Z"
finalized_at: null  # set when finalized
---
```

**Body sections**: Architectural Decisions, Scope Boundaries, Design Constraints, Open Questions. Finalization sets `status: finalized` and triggers `discussing` → `planning` transition.

### Tier Metadata (`{M###}-TIER.md`)

**Frontmatter**:
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

Created by the `evaluate` command during scaffolding. Persists the tier classification to disk before the roadmap is generated — resolving the gap where `derive-phase.sh` needs to know the tier but the roadmap doesn't exist yet.

**Consumed by**:
- `derive-phase.sh` — to determine valid state machine transitions (Tier B skips `discussing`, `replanning`, `validating`, `completing`)
- `roadmap` command — copies tier into roadmap frontmatter
- `status` command — displays current tier

**Lifecycle**: Written once by `evaluate`, updated only if tier is overridden (FR-002). Never deleted.

### Milestone Validation (`M###-VALIDATION.md`)

**Frontmatter** (YAML):
```yaml
---
schema_version: 1
milestone: M001
status: pass  # pass | fail
validated_at: "2026-03-19T16:00:00Z"
validator: auto  # auto | human
---
```

**Body**:
```markdown
## Success Criteria Checklist

- [x] SC-001: Tier classification completes in <5 minutes — **Evidence**: test-scaffold.sh timing output
- [x] SC-002: Context payload <20% of total artifacts — **Evidence**: scope-filter.sh output log
- [ ] SC-003: 5-phase milestone completes autonomously — **Evidence**: (pending validation)
```

Each success criterion from the milestone's roadmap is listed with a checkbox and evidence reference. The `status` field is derived from the checklist: `pass` when all criteria are checked, `fail` otherwise.

**Lifecycle**: Created by `mark-complete.sh` when all phases in a Tier C milestone are done (triggers the `validating` state). Written once; immutable after validation passes. For Tier B, this file is not created — the state machine transitions directly from `summarizing` to `complete`.

**Consumed by**:
- `derive-phase.sh` — absence triggers `validating` state (rule #7); presence enables `completing` transition
- `consolidate-artifacts.sh` — includes validation results in compressed milestone summary

### Execution Log (`execution-log.jsonl`)

One JSON object per line:
```json
{"schema_version":1,"timestamp":"2026-03-19T10:15:00Z","unitId":"M001/P01/T01","unitType":"execute-task","tier":"C","duration":"5m","outcome":"success","model":"claude-opus-4-6","featureBranch":"001-speckit-orchestrator"}
```

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

### Configuration (`orchestrator-config.yml`)

```yaml
# Speckit-Orchestrator Project Configuration
# See extension.yml defaults for factory values

default_tier: null              # Auto-detect. Override: A, B, or C
verification_commands:          # Run after each task
  - npm test
  - npm run lint
context_verbosity: standard     # minimal | standard | full
git_isolation: false            # Use git worktree per milestone
dispatch_budget: null           # Max dispatches per milestone (advisory)
duration_budget: null           # Max cumulative duration (advisory, e.g., "2h")
budget_enforcement: advisory    # advisory (warn only) | enforced (CI: maps to stop-after)
```

## State Machine

### States and Transitions

```
                    ┌──────────────┐
                    │ pre-planning │ ◄── scaffold milestone
                    └──────┬───────┘
                           │ discuss (Tier C required, Tier B optional)
                    ┌──────▼───────┐
                    │  discussing  │ ◄── create/update context draft
                    └──────┬───────┘
                           │ finalize context
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

  Side transitions:
  - Any executing/summarizing → replanning (when new info invalidates plan)
  - Any state → crash recovery (lock file + stale PID detected)
```

### State Derivation Rules (derive-phase.sh)

| Priority | Condition | State |
|----------|-----------|-------|
| 1 | Milestone dir does not exist | `pre-planning` |
| 2 | Context draft exists with `status: draft` | `discussing` |
| 3 | No roadmap file | `planning` |
| 4 | Any phase marked stale in roadmap | `replanning` |
| 5 | Active phase has incomplete tasks | `executing` |
| 6 | Active phase: all tasks done, no P##-SUMMARY.md | `summarizing` |
| 7 | All phases done, no milestone validation file | `validating` |
| 8 | Milestone validated, no M###-SUMMARY.md | `completing` |
| 9 | M###-SUMMARY.md exists | `complete` |

"Active phase" = first incomplete phase in dependency order (high-risk first among satisfied deps).

**Tier-conditional derivation**: When `{M###}-TIER.md` indicates Tier B, `derive-phase.sh` skips states not in Tier B's subset. Specifically: if tier is B and a context draft exists with `status: draft`, the script treats it as if the draft doesn't exist (Tier B discussion is optional and doesn't gate planning). Similarly, the `replanning`, `validating`, and `completing` states are skipped for Tier B — after all phases are summarized, the state transitions directly to `complete`.
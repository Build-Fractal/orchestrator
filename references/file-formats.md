# File Formats Reference

> Progressive disclosure reference for all speckit-orchestrator state file formats.
> Self-contained — read this document to understand any file format without cross-referencing other docs.
> For the authoritative contract with parsing rules, see `contracts/state-files.md`.

## Overview

All orchestrator state is persisted to disk under `.orchestrator/`. Files use two primary formats: **YAML frontmatter + markdown body** (for human-readable documents) and **structured data** (JSON, JSONL, YAML for machine-readable state).

Every file write is idempotent (FR-066): writing a file that already exists is a no-op unless explicit overwrite is requested.

---

## Directory Structure

```
.orchestrator/
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

**Location**: `.orchestrator/milestones/{M###}/M###-ROADMAP.md`
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

- [x] **P01**: Config Foundation — "Developer can install the orchestrator"
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces: .orchestrator/config.yml (validated config)
    - Consumes: none

- [ ] **P02**: State Machine Core — "Developer can see state derivation working"
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: scripts/state/*.sh
    - Consumes: P01/config.yml
```

### Parsing Rules

- Phase status: `[x]` = complete, `[ ]` = incomplete
- Phase ID: `**P##**` bold text after checkbox
- Demo sentence: text in quotes after `—` on the phase line
- Risk / Depends / Boundary Map: indented under phase, key-value after colon
- Reassessment: update existing incomplete phases, append new phases, never modify completed phases

---

## Phase Plan (`P##-PLAN.md`)

**Location**: `.orchestrator/milestones/{M###}/phases/{P##}/P##-PLAN.md`
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

**Location**: `.orchestrator/milestones/{M###}/phases/{P##}/tasks/T##-PLAN.md`
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

**Location**: `.orchestrator/milestones/{M###}/phases/{P##}/P##-VERIFICATION.md`
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
    what: "config.yml with runtime defaults"
affects: [P03, P04]          # Downstream phase IDs depending on this output
key_files:                   # Important file paths
  - scripts/state/derive-phase.sh
key_decisions:               # Decisions made with brief rationale
  - "D003: POSIX sh for portability"
patterns_established:        # Patterns introduced
  - "File-presence state derivation at scripts/state/"
drill_down_paths:            # Paths to related plan/detail files
  - .orchestrator/milestones/M001/phases/P01/tasks/T01-PLAN.md
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

**Location**: `.orchestrator/milestones/{M###}/M###-EVALUATION.md`
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

**Location**: `.orchestrator/milestones/{M###}/M###-CONTEXT.md`
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

**Location**: `.orchestrator/continue.md`
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

**Location**: `.orchestrator/orchestrator.lock`
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

**Location**: `.orchestrator/execution-log.jsonl`
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

### Telemetry Entry Format (via `record-telemetry.sh`)

Appended to the same execution log as dispatch results. Distinguished by
`"type": "telemetry"`.

```json
{
  "timestamp": "2026-03-19T10:15:00Z",
  "type": "telemetry",
  "unitId": "M001/P01/T01",
  "model_used": "claude-sonnet-4-20250514",
  "tokens_input": 5000,
  "tokens_output": 1200,
  "tokens_cache_read": 3000,
  "cost_estimated": 0.12,
  "cost_source": "estimated",
  "cache_hit_rate": 0.6,
  "payload_bytes": 4096
}
```

Use `scripts/telemetry/record-telemetry.sh` to append entries.

#### Required Fields

`timestamp` (auto-generated), `type` (always `"telemetry"`), `unitId`

#### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `model_used` | string | Model identifier used for the dispatch |
| `tokens_input` | number | Input token count |
| `tokens_output` | number | Output token count |
| `tokens_cache_read` | number | Cache-read token count |
| `cost_estimated` | number | Cost in dollars. `null`/absent = unknown, `0` = actually free |
| `cost_source` | string | Cost provenance: `estimated`, `reported`, or `unknown` |
| `cache_hit_rate` | number | Cache hit rate (0.0-1.0) |
| `payload_bytes` | number | Payload size in bytes |

#### Cost Source Enum (AD-2)

| Value | Meaning |
|-------|---------|
| `estimated` | Cost computed from chars/4 heuristic |
| `reported` | Cost returned by provider API response |
| `unknown` | No cost data available |

**Null vs Zero Distinction**: A missing `cost_estimated` field means the
cost is unknown. A `cost_estimated` of `0` means the operation was
actually free (zero cost). These are semantically different: `null` =
"we don't know" vs `0` = "we know it was free." The `cost_source` field
provides additional provenance for downstream consumers.

**Legacy Entries**: Entries written before the `cost_source` field was
introduced lack the field entirely. Downstream consumers (e.g.,
`aggregate-metrics.sh`) classify these by the presence of cost data: if
`cost_estimated` is present, the entry is treated as `estimated`;
otherwise it is treated as `unknown`.

---

## Decisions Register (`DECISIONS.md`)

**Location**: `.orchestrator/DECISIONS.md`
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

**Location**: `.orchestrator/KNOWLEDGE.md`
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
| `source:<cite_id>` | Specific reference-corpus source (M036 — see `references/reference-frontmatter-contract.md`) |

### Append Rules

- New entries go at the bottom
- Never edit existing entries
- Check for duplicates before appending

---

## Configuration (`orchestrator-config.yml`)

**Location**: Project root (not inside `.orchestrator/`)
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
4. **Built-in defaults**: `templates/orchestrator-config-default.yml` (factory defaults shipped with the orchestrator)

Each key is resolved independently — a local config can override one key while falling through to project config for others.

---

## Routing Configuration (`routing.yaml`)

**Location**: `.orchestrator/routing.yaml` or `templates/routing.yaml` (default)
**Format**: YAML (max 2 levels nesting, parseable by grep/sed/awk)
**Mutability**: Edited by the developer. Optional -- if absent, built-in defaults are used.

### Schema

```yaml
models:
  heavy:
    id: "claude-opus-4-6"           # Model identifier for complex tasks
    context_budget: 200000           # Max context tokens for this tier
    fallback: "claude-sonnet-4-6,claude-haiku-4-5"  # Comma-separated fallback chain (or empty)
  standard:
    id: "claude-sonnet-4-6"         # Model identifier for typical tasks
    context_budget: 150000
    fallback: "claude-haiku-4-5"
  light:
    id: "claude-haiku-4-5"          # Model identifier for simple tasks
    context_budget: 80000
    fallback: ""

classification:
  heavy:
    patterns: "new subsystem,>5 files,architectural decision,first phase"
    confidence: 0.8
  standard:
    patterns: "feature implementation,2-5 files,follows established pattern"
    confidence: 0.6
  light:
    patterns: "config change,test addition,single-file edit,documentation"
    confidence: 0.4

fallback_config:
  recoverable_errors: "rate_limit,timeout,overloaded"
  max_retries: 2
  retry_delay_seconds: 5

history_weight: 0.3                  # Weight for historical data in routing (0.0-1.0)
budget_ceiling_usd: 50.00           # Maximum spend ceiling in USD
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `models.<tier>.id` | string | Model identifier for the tier |
| `models.<tier>.context_budget` | integer | Maximum context tokens for dispatches in this tier |
| `models.<tier>.fallback` | string | Comma-separated fallback model IDs for retry on recoverable error |
| `classification.<tier>.patterns` | string | Comma-separated keywords that signal this complexity tier |
| `classification.<tier>.confidence` | float | Minimum confidence threshold for tier assignment |
| `fallback_config.recoverable_errors` | string | Comma-separated error types that trigger fallback |
| `fallback_config.max_retries` | integer | Maximum retry attempts per dispatch |
| `fallback_config.retry_delay_seconds` | integer | Delay between retry attempts |
| `history_weight` | float | Weight (0.0-1.0) given to historical telemetry data in routing |
| `budget_ceiling_usd` | float | Maximum USD spend ceiling for the project |

### Parsing Rules

- Max 2 levels of YAML nesting. Parseable by `scripts/lib/recipe-parser.sh` using grep/sed/awk.
- `read_recipe_field routing.yaml "models.heavy.id"` returns the model ID.
- `parse_recipe_fallback routing.yaml "heavy"` returns the comma-separated fallback chain.
- When the routing config file is absent, `classify-complexity.sh` uses built-in keyword arrays and `select-model.sh` uses built-in model defaults.

### Resolution Order

When `select-model.sh` or `classify-complexity.sh` receive a `--routing-config` path:
1. If the file exists, read configuration from it.
2. If the file does not exist or the field is missing, fall back to built-in defaults.

The orchestrator looks for `routing.yaml` at `.orchestrator/routing.yaml`. If not found, `templates/routing.yaml` provides a copyable starting point.

---

## Doctor History (`doctor-history.jsonl`)

Append-only log of diagnostic results for trend tracking. Written by `scripts/diagnostics/run-doctor.sh` after each doctor run.

**Location**: `.orchestrator/doctor-history.jsonl`

**Format**: One JSON object per line (JSONL).

**Mutability**: Append-only. Never edit or delete existing entries.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | ISO 8601 UTC timestamp of the run (e.g., `2026-04-13T16:00:00Z`) |
| `checks_passed` | integer | Number of non-advisory checks that passed |
| `checks_total` | integer | Total number of non-advisory checks run |
| `advisory_warnings` | integer | Number of advisory-only checks that warned |
| `status` | string | `healthy` (all passed) or `needs_attention` (any failed) |

### Example

```json
{"timestamp":"2026-04-13T16:00:00Z","checks_passed":12,"checks_total":12,"advisory_warnings":0,"status":"healthy"}
{"timestamp":"2026-04-14T10:30:00Z","checks_passed":10,"checks_total":12,"advisory_warnings":1,"status":"needs_attention"}
```

### Append Rules

- New entries are appended by `run-doctor.sh` at the end of each diagnostic run.
- Never edit or remove existing entries.
- The file is created automatically on first run if it does not exist.

---

## Context Recipe (`context-recipe.yaml`)

**Location**: `templates/context-recipe.yaml` (default); overrideable at milestone, phase, or task level
**Format**: YAML (max 2 levels nesting, parseable by grep/sed/awk -- no jq required)
**Mutability**: Edited by the developer. The default template ships with the extension; project-level overrides placed alongside orchestrator state files.

### Resolution Order (FR-211)

When building a dispatch payload, `scripts/dispatch/build-context.sh` resolves the recipe file by specificity (most-specific wins):

1. **Task-level**: `.orchestrator/milestones/{M###}/phases/{P##}/tasks/context-recipe.yaml`
2. **Phase-level**: `.orchestrator/milestones/{M###}/phases/{P##}/context-recipe.yaml`
3. **Milestone-level**: `.orchestrator/milestones/{M###}/context-recipe.yaml`
4. **Default**: `templates/context-recipe.yaml`

Resolved by `resolve_recipe()` in `scripts/lib/recipe-parser.sh`.

### Sections Block

Each section declares what content to include in a dispatch payload. Fields:

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `source` | string | `computed`, file path, `phase_summaries`, `phase_plan`, `task_plan`, `template` | How to resolve the section content |
| `priority` | string | `required`, `compressible`, `optional` | Compression eligibility (required sections are never dropped) |
| `order` | integer | Any positive integer | Sort key for payload assembly (lower = earlier in payload) |
| `filter` | string | `none`, `scope`, `staleness`, `confidence` | Content filtering strategy |
| `cache_hint` | string | `static`, `semi-static`, `dynamic` | Guides prompt caching boundaries |

### Source Types

| Source | Meaning |
|--------|---------|
| `computed` | Content generated at assembly time (e.g., state context from `derive-phase.sh`) |
| File path (e.g., `KNOWLEDGE.md`) | Relative path from orchestrator root; file read directly |
| `phase_summaries` | Aggregated summaries from upstream phases (resolved via roadmap dependencies) |
| `phase_plan` | The current phase plan (`P##-PLAN.md`) |
| `task_plan` | The current task plan (`T##-PLAN.md`) |
| `template` | Content rendered from a dispatch prompt template with variable substitution |

### Default Sections

The default recipe defines 7 sections (listed by `order`):

```yaml
sections:
  knowledge:
    source: KNOWLEDGE.md
    priority: compressible
    order: 10
    filter: scope
    cache_hint: static

  decisions:
    source: DECISIONS.md
    priority: compressible
    order: 20
    filter: staleness
    cache_hint: static

  constraints:
    source: template
    priority: optional
    order: 30
    filter: none
    cache_hint: static

  scope:
    source: phase_plan
    priority: required
    order: 40
    filter: none
    cache_hint: semi-static

  upstream:
    source: phase_summaries
    priority: compressible
    order: 50
    filter: none
    cache_hint: dynamic

  state:
    source: computed
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic

  task_plan:
    source: task_plan
    priority: required
    order: 60
    filter: none
    cache_hint: dynamic
```

### Compression Block

Graduated compression steps applied in order until the payload fits within the model's token budget (from `routing.yaml` `context_budget`). Steps are tried sequentially; if a step reduces the payload enough, later steps are skipped.

| Step Type | Description | Additional Fields |
|-----------|-------------|-------------------|
| `drop_optional` | Remove sections with `priority: optional` | none |
| `summarize` | Truncate matching sections to a word limit | `target_sections`, `max_words` |
| `drop_lowest_confidence` | Remove knowledge entries below a confidence threshold | `target_sections`, `min_confidence` |

```yaml
compression:
  enabled: true
  steps:
    step_1:
      type: drop_optional
      description: Remove sections marked priority optional
    step_2:
      type: summarize
      target_sections: upstream
      max_words: 200
      description: Truncate upstream summaries to 200 words each
    step_3:
      type: drop_lowest_confidence
      target_sections: knowledge
      min_confidence: 0.5
      description: Drop knowledge entries below 0.5 confidence
  protected_sections: task_plan,scope,state
```

The `protected_sections` field is a comma-separated list of section names that are never removed by compression, regardless of their `priority` value.

### Manifest Block

Controls the manifest header prepended to every assembled payload.

```yaml
manifest:
  enabled: true
  include_token_count: true
  include_section_list: true
  include_compression_applied: true
```

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | boolean | Whether to include the manifest header at all |
| `include_token_count` | boolean | Include estimated token counts per section in manifest table |
| `include_section_list` | boolean | Include the section name/line-range/priority table |
| `include_compression_applied` | boolean | Note which compression steps were applied |

### Parsing Rules

- Parsed by `parse_recipe_sections()` in `scripts/lib/recipe-parser.sh`.
- Output format: `<name>|<source>|<priority>|<order>|<filter>|<cache_hint>` (one line per section, sorted by order ascending).
- Compression steps parsed by `parse_recipe_compression()` with output format: `<step_key>|<type>|<target_sections>|<max_words>|<min_confidence>|<description>`.
- All parsing uses grep/sed/awk only (NFR-202). No jq or external JSON tools.

---

## Hooks Configuration (`hooks.yaml`)

**Location**: `templates/hooks.yaml` (default); overrideable at milestone or phase level
**Format**: YAML (max 2 levels nesting, parseable by grep/sed/awk -- no jq required)
**Mutability**: Edited by the developer. Optional -- if absent, hooks are skipped with a `SAFETY_WARNING` event.

### Global Defaults

```yaml
hook_defaults:
  timeout: 30
  block_on_fail: true
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `timeout` | integer | `30` | Seconds before a hook process is killed (SIGTERM, then SIGKILL after 1s) |
| `block_on_fail` | boolean | `true` | Whether a non-zero exit from a hook blocks the pipeline |

The global defaults can be overridden per-hook by setting the same field on individual hook entries.

### Lifecycle Points

Hooks are organized under four lifecycle points, executed in pipeline order:

| Lifecycle Point | When It Runs | Use Cases |
|----------------|-------------|-----------|
| `PRE_DISPATCH` | After context assembly, before agent dispatch | Payload validation, budget pre-check, external gate |
| `POST_DISPATCH` | After agent returns output, before verification | Output validation, response quality gate |
| `POST_VERIFY` | After verification completes, before result recording | Phase completeness check, summary quality gate |
| `PRE_ADVANCE` | After result recording, before phase/task state advance | Final budget enforcement, knowledge consolidation trigger |

### Hook Entry Fields

Each hook is a named entry under a lifecycle point:

```yaml
PRE_DISPATCH:
  payload_sanity:
    name: Payload Sanity Check
    script: scripts/verify/guards/check-payload.sh
    enabled: true
    block_on_fail: true
    description: Block dispatch if payload is empty or under 100 chars
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable hook name |
| `script` | string | yes | Path to the hook script (relative to project root) |
| `enabled` | boolean | no (default: `true`) | Whether the hook runs; disabled hooks are skipped entirely |
| `block_on_fail` | boolean | no (inherits global default) | `true` = non-zero exit stops pipeline; `false` = non-zero exit emits warning only |
| `description` | string | no | Human-readable description of what the hook checks |

### Default Hooks

The default `templates/hooks.yaml` ships with 5 hooks across 4 lifecycle points:

| Lifecycle | Hook Key | Script | block_on_fail |
|-----------|----------|--------|---------------|
| `PRE_DISPATCH` | `payload_sanity` | `scripts/verify/guards/check-payload.sh` | `true` |
| `PRE_DISPATCH` | `budget_precheck` | `scripts/verify/guards/check-budget.sh` | `true` |
| `POST_DISPATCH` | `output_sanity` | `scripts/verify/guards/check-output.sh` | `true` |
| `POST_VERIFY` | `phase_completeness` | `scripts/verify/guards/check-phase-complete.sh` | `false` |
| `PRE_ADVANCE` | `budget_enforcement` | `scripts/verify/guards/check-budget-advance.sh` | `true` |
| `PRE_ADVANCE` | `knowledge_trigger` | `scripts/knowledge/trigger-consolidation.sh` | `false` (disabled) |

### Execution Behavior

Hooks are dispatched by `run_hooks()` in `scripts/lib/hooks.sh`:

1. **Frozen snapshot**: Each hook receives a read-only snapshot of engine state via `$ORCH_HOOK_SNAPSHOT` (chmod 444 temp file). Hooks MUST NOT modify engine state (Principle XII: Hook Isolation).
2. **Snapshot integrity check**: After each hook completes, the snapshot file's modification time and write permissions are verified. If the snapshot was modified, a `HOOK_VIOLATION` event is emitted unconditionally (never downgraded, even under `ORCH_FORCE`).
3. **Timeout enforcement**: Hooks are killed at `timeout` seconds (SIGTERM, then SIGKILL after 1 second).
4. **Verdict protocol**: Hooks may emit `VERDICT:` lines to stdout. Recognized verdicts: `PASS`, `WARN`, `NEEDS_REVIEW`, `BLOCK`. The most severe verdict across all `VERDICT:` lines determines the hook outcome. `BLOCK` verdicts stop the pipeline (unless `ORCH_FORCE` is set). `WARN` verdicts emit warnings but continue.
5. **Graceful degradation**: If `scripts/lib/recipe-parser.sh` is unavailable or the hooks YAML is missing, `run_hooks()` emits a `SAFETY_WARNING` and returns 0 (no-op).

### Parsing Rules

- Parsed by `parse_recipe_hooks()` in `scripts/lib/recipe-parser.sh`.
- Output format: `<hook_key>|<name>|<script>|<enabled>|<block_on_fail>|<description>` (one line per hook).
- All parsing uses grep/sed/awk only (NFR-202). No jq or external JSON tools.

---

## Engine Checkpoint (`engine-checkpoint.json`)

**Location**: `.orchestrator/milestones/{M###}/engine-checkpoint.json`
**Format**: JSON
**Mutability**: Written atomically on every task completion. Cleared on full phase success.

### Schema

```json
{
  "run_id": "a1b2c3d4",
  "milestone": "M001",
  "phase": "P02",
  "last_task": "T03",
  "outcome": "success",
  "timestamp": "2026-03-19T14:30:00Z"
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `run_id` | string | Run ID from `ORCH_RUN_ID` (set by `init_run_context()`). Value is `"unset"` if no run context was initialized. |
| `milestone` | string | Milestone ID (e.g., `M001`) |
| `phase` | string | Phase ID (e.g., `P02`) |
| `last_task` | string | Task ID of the last completed task (e.g., `T03`) |
| `outcome` | string | Outcome of the last task (e.g., `success`, `failure`, `retry`, `blocked`, `timeout`, `stuck`) |
| `timestamp` | string | ISO 8601 UTC timestamp from `orch_now()` (uses `ORCH_STARTED_AT` for reproducibility) |

### Atomic Write Pattern

Checkpoint writes use a temp-file-then-move strategy to prevent partial writes on crash:

1. Build JSON content in memory.
2. Write to `engine-checkpoint.json.tmp.$$` (PID-suffixed temp file in the same directory).
3. `mv` the temp file to the final path (atomic on POSIX filesystems).
4. If write or move fails, the temp file is removed and a `SAFETY_WARNING` event is emitted.

This ensures that any checkpoint file that exists on disk is always a complete, valid JSON object.

### Crash Recovery Role

The engine checkpoint is the handoff mechanism between crashed and resumed runs (Principle VI: State On Disk Is Truth):

- **Detection**: `checkpoint_detect()` returns 0 if a non-empty checkpoint file exists for the milestone.
- **Reading**: `checkpoint_read()` extracts individual fields (e.g., `checkpoint_read M001 last_task` returns `T03`). Parsing uses grep to find `"field":` and sed to extract the value.
- **Clearing**: `checkpoint_clear()` removes the checkpoint file after a phase completes successfully. This prevents stale checkpoints from triggering unnecessary recovery on the next run.
- **Resume flow**: On engine start, if a checkpoint is detected, the engine reads `phase` and `last_task` to determine where to resume. The caller emits a `CHECKPOINT_RESUME` event; this library only emits `CHECKPOINT_WRITE` events.

### Functions (in `scripts/engine/checkpoint.sh`)

| Function | Arguments | Description |
|----------|-----------|-------------|
| `checkpoint_path` | `<milestone>` | Returns the file path for the milestone's checkpoint |
| `checkpoint_write` | `<milestone> <phase> <task> <outcome>` | Atomically writes a checkpoint; emits `CHECKPOINT_WRITE` event |
| `checkpoint_read` | `<milestone> <field>` | Reads a single field from the checkpoint file |
| `checkpoint_detect` | `<milestone>` | Returns 0 if a non-empty checkpoint file exists |
| `checkpoint_clear` | `<milestone>` | Removes the checkpoint file (safe to call when none exists) |

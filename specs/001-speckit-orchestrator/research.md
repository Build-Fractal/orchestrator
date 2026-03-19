# Research: Speckit-Orchestrator Extension

**Date**: 2026-03-19
**Sources**: 6 research reports (`.planning/research/`), 15 conversus artifacts, constitution, spec

## Decision Log

### R-001: Extension Organization Model

**Decision**: Single-hierarchy command-centric layout. No parallel `skills/` directory tree.

**Rationale**: The conversus process surfaced this as the most contentious dispute across all 3 tool perspectives. spec-kit and gh-aw both resist a parallel hierarchy (spec-kit wants extension primacy; gh-aw wants no duplication). APM's need for SKILL.md metadata can be satisfied by deriving it from command frontmatter at install time — this is a packaging concern, not an organizational one.

**Alternatives Considered**:
- Parallel `skills/` tree with `SKILL.md` per skill (APM's position) — rejected: maintenance burden, metadata duplication, org model conflict
- Dual-entry-point: both `extension.yml` and `apm.yml` index same structure — rejected: added complexity without proportional value for initial delivery

**Layout**:
```
commands/evaluate.md       ← authoritative command definition
commands/evaluate/         ← resource directory (if command needs co-located assets)
  scripts/
  templates/
  references/
```

---

### R-002: State Machine Implementation

**Decision**: File-presence-based state derivation with a dispatch table pattern.

**Rationale**: Ported from GSD-2's architecture (`.planning/research/02-gsd.md`). State is never stored as a field — it is derived deterministically from which files exist on disk. This makes crash recovery trivial: restart, read disk, derive state, continue.

**Implementation Pattern**:
```bash
# derive-phase.sh pseudocode
if ! milestone_dir_exists; then echo "pre-planning"; exit; fi
if context_draft_exists && ! context_finalized; then echo "discussing"; exit; fi
if ! roadmap_exists; then echo "planning"; exit; fi
if needs_replan; then echo "replanning"; exit; fi
if active_task_incomplete; then echo "executing"; exit; fi
if all_tasks_done && ! phase_summary_exists; then echo "summarizing"; exit; fi
if all_phases_done && ! milestone_validation_exists; then echo "validating"; exit; fi
if milestone_validated && ! milestone_summary_exists; then echo "completing"; exit; fi
echo "complete"
```

**Dispatch Table** (first match wins):
| Phase | Condition | Action |
|-------|-----------|--------|
| pre-planning | No roadmap | Prompt: run `evaluate` or `roadmap` |
| discussing | Context draft not finalized | Prompt: run `discuss` to finalize |
| planning | Phase has no plan | Dispatch: `plan-phase` for next unplanned phase |
| replanning | Phase marked stale | Dispatch: `plan-phase` with invalidation context |
| executing | Task incomplete | Dispatch: `dispatch` for next incomplete task |
| summarizing | Phase done, no summary | Dispatch: generate phase summary |
| validating | All phases done, no validation | Dispatch: milestone validation gate |
| completing | Validated, no summary | Dispatch: milestone summary generation |
| complete | Summary exists | Stop: milestone complete |

---

### R-003: Runtime Adapter Interface Design

**Decision**: 5 core operations. No capability negotiation. Parallel fan-out is adapter-internal.

**Rationale**: All 3 conversus perspectives converged on needing an adapter layer but disagreed on richness. The post-conversus arbitration (orchestrator as arbiter) resolved this decisively: the orchestrator always dispatches tasks sequentially from its perspective. Parallel fan-out is the adapter's internal optimization, invisible to core. This eliminates conditional branches entirely (FR-068 satisfied automatically) and keeps the core dispatch loop maximally simple (Principle 1).

**Complete Interface** (5 operations, all adapters must implement):
```
dispatch-task(payload) → task_handle
await-completion(task_handle) → completion_status
collect-result(task_handle) → result_artifacts
signal-failure(task_handle, diagnostic) → void
inject-context(task_handle, context) → void
```

**Adapter-internal optimizations** (invisible to core):
- The gh-aw adapter MAY batch independent tasks (detected from roadmap dependency graph) into parallel CI jobs
- The local-subprocess adapter MAY use parallel Agent tool calls for independent tasks
- These optimizations are unconstrained — adapters implement the 5 operations however they want

**FR-069 rewrite**: "Adapters MAY implement internal optimizations (e.g., parallel fan-out, concurrency control) that are invisible to the orchestrator's core dispatch loop. The interface contract is the five core operations; adapter-internal behavior is unconstrained."

**Alternatives Considered**:
- 3 operations (APM) — rejected: too thin. `inject-context` needed for FR-052 decision injection; `signal-failure` needed for escalation ladder
- Capability negotiation (original plan) — rejected by arbitration: inevitably leads to `if adapter.supports('batch')` branches in core, violating FR-068
- gh-aw-shaped interface with batch dispatch as core op — rejected: forces orchestrator to understand parallelism, which is a runtime concern not an orchestration concern

---

### R-004: Configuration Architecture

**Decision**: spec-kit's multi-layer config system with 4 precedence levels.

**Rationale**: The conversus process unanimously agreed that config must route through spec-kit's system (not custom `config.json` per original playbook). This avoids the APM-overwrite problem (APM's always-overwrite deployment would destroy runtime config) and keeps config outside APM's deployment radius.

**Precedence** (highest → lowest):
1. `SPECKIT_ORCHESTRATOR_*` env vars — CI/per-run overrides
2. `orchestrator-config.local.yml` (gitignored) — developer preferences
3. `orchestrator-config.yml` (project root) — team-shared settings
4. `extension.yml` `defaults` section — factory defaults

**Schema** (validated by `config_schema` in extension.yml):
```yaml
default_tier: null          # enum: A, B, C, null (auto-detect)
verification_commands: []   # e.g., ["npm test", "npm run lint"]
context_verbosity: standard # enum: minimal, standard, full
git_isolation: false        # Use git worktree per milestone
dispatch_budget: null       # Max dispatches per milestone (advisory)
duration_budget: null       # Max cumulative duration (advisory, e.g., "2h")
```

**Key Constraint**: User-mutable config MUST NOT reside in APM-managed directories (FR-070).

---

### R-005: Dispatch Payload Construction

**Decision**: Scope-filtered context injection following GSD-2's pre-loading pattern adapted for markdown.

**Rationale**: GSD-2 achieves fresh context programmatically via Pi SDK. The orchestrator must achieve equivalent isolation through prompt construction — the dispatch payload IS the context. Over-injecting violates Principle I (Context Minimization); under-injecting causes task failures.

**Payload Structure** (per dispatch):
```markdown
# Task: {task_id} — {task_name}

## Task Plan
{full task plan text — pasted, not file-referenced}

## Phase Context
{phase plan excerpt — goal, demo sentence, must-haves}

## Upstream Dependencies
{scope-filtered summaries from completed upstream phases}

## Relevant Decisions
{DECISIONS.md entries scoped to: current milestone + current phase + upstream deps + arch-scoped}

## Relevant Knowledge
{KNOWLEDGE.md entries scoped to: project + current milestone + current phase}

## Constitution Principles
{applicable principles from constitution.md — always included}

## Verification Criteria
{must-haves for this specific task: truths, artifacts, key links}
```

**Context Verbosity Profiles**:
| Level | Includes | Approximate Budget |
|-------|----------|-------------------|
| minimal | Task plan + phase must-haves + constitution | ~2000 tokens |
| standard | + roadmap excerpt + decisions + dependency summaries | ~5000 tokens |
| full | + all knowledge entries + full roadmap + all summaries | ~10000 tokens |

---

### R-006: Verification Architecture

**Decision**: Four-tier verification ladder with per-task and per-phase boundaries.

**Rationale**: Ported from GSD-2's verification enforcement and Superpowers' "iron law" of evidence before claims. The orchestrator never trusts agent self-reports — all verification is independent.

**Per-Task Verification** (after each dispatch):
1. **Static checks**: Required artifacts exist on disk with real content (not stubs)
2. **Command checks**: Configured verification commands pass (test, lint, build)

**Per-Phase Verification** (after all tasks complete):
1. **Spec compliance review**: Phase achieves demo sentence; boundary map contracts satisfied; no scope creep
2. **Code quality review**: Naming consistency; error handling patterns; test coverage; no TODO/FIXME leftovers

**Must-Haves Format** (mechanically checkable):
```yaml
truths:       # Observable behaviors that must be true
  - "derive-phase.sh outputs 'executing' when active task exists"
artifacts:    # Files that must exist with real content
  - path: scripts/state/derive-phase.sh
    min_lines: 20
    exports: []  # or function names for libraries
key_links:    # Wiring between artifacts
  - from: commands/auto.md
    to: scripts/state/derive-phase.sh
    via: "bash script invocation"
```

---

### R-007: Crash Recovery Model

**Decision**: Lock file + disk forensics + recovery briefing synthesis.

**Rationale**: Ported from GSD-2's crash recovery. The lock file records what was being attempted; disk state reveals what completed. The gap between the two is the recovery context.

**Lock File** (`orchestrator.lock`):
```json
{
  "pid": 12345,
  "startedAt": "2026-03-19T10:00:00Z",
  "unitType": "execute-task",
  "unitId": "M001/P01/T02",
  "unitStartedAt": "2026-03-19T10:15:00Z",
  "completedUnits": ["M001/P01/T01"],
  "featureBranch": "001-speckit-orchestrator"
}
```

**Recovery Flow**:
1. On startup, `check-lock.sh` checks if lock exists
2. If lock + PID alive → another session is running (concurrent access safety)
3. If lock + PID dead → crashed session. Read lock to determine what was in progress
4. Examine disk: does the task have a summary? → it completed before crash
5. No summary → task was interrupted. Synthesize recovery briefing from:
   - Lock file (what was attempted)
   - Git diff (what changes were made)
   - Execution log (last entries before crash)
6. Dispatch recovery with briefing context

**Stuck Detection**: If same unit dispatched twice (tracked in execution log) without producing expected artifacts → stop and report the specific missing artifact. No infinite retry loops.

---

### R-008: Knowledge Scoping Strategy

**Decision**: Three-level scope tags with filtered injection.

**Rationale**: Unbounded knowledge injection violates Principle I. As KNOWLEDGE.md grows, injecting the entire file into every dispatch degrades context efficiency. Scope tags ensure each dispatch receives only relevant entries.

**Scope Tags**:
- `project` — applies to all future work (always injected)
- `milestone:{M###}` — applies within a specific milestone
- `phase:{M###/P##}` — applies to a specific phase and its direct dependents

**DECISIONS.md Scoping**:
- Inject: all decisions scoped to current milestone + current phase + upstream dependencies
- Also inject: any decision tagged `scope: arch` (architectural decisions are milestone-wide)
- Exclude: decisions from unrelated phases in the same milestone

**Implementation**: `scope-filter.sh` takes current context (milestone, phase) and filters entries before injection into dispatch payload.

---

### R-009: Tier Behavior Differentiation

**Decision**: Three distinct execution surfaces with progressive capability activation.

**Rationale**: The spec defines Tier A/B/C with different included capabilities. The implementation must cleanly separate what each tier activates to satisfy SC-008 (Tier A = zero overhead) and SC-017 (Tier B = fewer than half Tier C state files).

| Capability | Tier A | Tier B | Tier C |
|------------|--------|--------|--------|
| Scope triage | Yes | Yes | Yes |
| Standard spec-kit flow | Inline | Per-phase | Per-phase |
| Roadmap with phases | No | Single milestone, flat | Full hierarchy |
| Task dispatch to fresh context | No | Yes | Yes |
| Per-task must-have verification | No | Yes | Yes |
| Phase summaries | No | Yes | Yes |
| Structured handoff | No | Yes | Yes |
| Autonomous mode | No | No (developer drives) | Yes |
| Crash recovery (lock files) | No | No | Yes |
| Boundary maps | No | Optional | Required |
| Knowledge consolidation | No | No | Yes |
| `discussing` state | No | Optional, skippable | Required gate |
| DECISIONS.md / KNOWLEDGE.md | No | Optional (created if needed) | Required scaffolding |
| `replanning` / `validating` / `completing` states | No | No | Yes |

---

### R-010: Hook Integration Strategy

**Decision**: Hybrid — hooks at 4 available points + command composition for hookless steps.

**Rationale**: spec-kit provides 4 hook points (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`). The orchestrator needs to inject context at plan/specify/clarify steps too. Command composition (orchestrator commands wrapping spec-kit commands) fills the gap.

**Hook Usage**:
| Hook | Orchestrator Behavior |
|------|-----------------------|
| `before_tasks` | Check if orchestration active; if so, inject phase scope context |
| `after_tasks` | Offer to generate roadmap from tasks.md phases |
| `before_implement` | Inject phase scope enforcement; offer dispatch via orchestrator |
| `after_implement` | Trigger phase verification and summary generation |

**Command Composition** (for hookless steps):
- `speckit.orchestrator.plan-phase` wraps `/speckit.plan` with phase-scoped context injection
- Discussion wraps `/speckit.clarify` with constraint context
- Roadmap wraps `/speckit.specify` with milestone decomposition guidance

**Key Detail**: All hooks use `optional: true` — they prompt the user and no-op when orchestration is not active. No forced behavior on non-orchestrated projects.

---

### R-011: Lock File Runtime Discriminator

**Decision**: Lock file includes a `runtime` discriminator field and adapter-specific liveness data.

**Rationale**: Plan-level conversus convergence (all 3 tools). PID-based liveness is meaningless on ephemeral CI runners. `derive-phase.sh` (a shared bash script) runs as a precomputation step with no adapter code available, so the discriminator must be self-describing in the lock file itself.

**Schema Addition**:
```json
{
  "pid": 12345,
  "runtime": "local",
  "startedAt": "...",
  "unitType": "execute-task",
  "unitId": "M001/P01/T02",
  "unitStartedAt": "...",
  "completedUnits": ["M001/P01/T01"],
  "featureBranch": "001-speckit-orchestrator"
}
```

For CI: `"runtime": "ci-github"`, add `"run_id": "12345678"` field. `derive-phase.sh` reads `runtime` to choose: PID check for local, `gh api` for CI.

**Alternatives Considered**:
- Adapter method `check_liveness()` only — rejected: script must work without adapter code in precomputation
- Separate lock file per runtime — rejected: unnecessary complexity, polymorphic schema is cleaner

---

### R-012: Two-Channel Context Injection Model

**Decision**: Two explicit channels with a documented priority rule. Command-time context overrides ambient context on conflict.

**Rationale**: Plan-level conversus convergence. APM `.instructions.md` provides ambient, file-pattern-scoped guidance (static, never references runtime state). Spec-kit frontmatter provides command-time context (dynamic, command-specific). In CI, both channels collapse into a single dispatch payload — `build-context.sh` must define the merge order.

**Priority Rule**: Command-time context wins on conflict.

**CI Merge Semantics**: `build-context.sh` assembles: (1) APM ambient instructions (filtered by file patterns), (2) spec-kit command-time context (phase plan, must-haves, scope-filtered decisions/knowledge), (3) orchestrator dispatch payload. Command context overrides ambient on any conflict.

**Scope Constraint**: APM `.instructions.md` MUST NOT reference orchestrator runtime state, phase identity, or command arguments. Violating this recreates competing context injection channels.

---

### R-013: Verification Tier Integration

**Decision**: Four-tier verification model integrated into spec-kit's mechanisms, not a parallel system.

**Rationale**: Plan-level conversus identified verification architecture as the most contested area (appeared in 5 of 6 cross-reviews). Resolution: spec-kit checklists are the primary gate (tier 2). R-006 scripts implement checklist verification, not a separate verification system. APM hooks excluded entirely (APM withdrew).

**Tier Definitions**:
| Tier | Mechanism | Trigger | Failure |
|------|-----------|---------|---------|
| 1. Static | Deterministic scripts | Precomputation (CI) or `{SCRIPT}` (local) | Block |
| 2. Command | spec-kit checklists | Gate `/speckit.implement` | Block |
| 3. Behavioral | gh-aw staged mode | CI only, post-implementation | Escalate to human |
| 4. Human | Manual review | When mechanical insufficient | Human decides |

**Execution Order**: Sequential. Each tier must pass before the next runs.

**Result Schema** (addition to `execution-log.jsonl`):
```json
{
  "timestamp": "...",
  "unitId": "M001/P01",
  "unitType": "verify-phase",
  "verification": {
    "tier1_static": {"status": "pass", "checks": 5, "failures": 0},
    "tier2_command": {"status": "pass", "checklist": "P01-must-haves"},
    "tier3_behavioral": {"status": "skipped"},
    "tier4_human": {"status": "skipped"}
  }
}
```

---

### R-014: Hydrate-Execute-Persist Pattern for CI

**Decision**: CI adapter follows a mandatory three-phase sequence: hydrate → execute → persist.

**Rationale**: Plan-level conversus identified this as the most important convergence, resolving dangerous contradictions flagged in all 6 cross-reviews. Working tree is canonical during execution; repo-memory is a durability sync mechanism.

**Sequence**:
1. **Hydrate**: Pull `.specify/orchestrator/` from durable storage (repo-memory branch) into working tree
2. **Execute**: All reads/writes target working tree. AD-2 applies — disk state is truth
3. **Persist**: Commit working tree state back to durable storage, including post-hook state

**Local Adapter**: Hydrate and persist are no-ops (files persist naturally).

---

### R-015: CI Dispatch Mode (Step vs Continuous)

**Decision**: `auto` command supports dual mode. Local adapters run `continuous` (full state machine loop). CI adapter runs `step` (one unit per workflow run).

**Rationale**: CI runners have timeout caps (GitHub Actions: 6h default). A full milestone cannot complete in one run. The `step` mode advances one unit, persists state, and re-enters via `schedule` or `repository_dispatch`.

**Concurrency Requirement**: All gh-aw task dispatch workflows MUST include `concurrency: { job-discriminator: ${{ inputs.task_id }} }` to prevent fan-out cancellations (dispatching T02 would otherwise cancel T01).
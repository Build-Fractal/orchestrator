# GSD-2 Research Report

> **Purpose:** Deep-dive into GSD-2's architecture, workflow model, and operational patterns to inform the design of the speckit-orchestrator extension.
>
> **Source repository:** `./gsd-2/` (standalone TypeScript CLI built on the Pi SDK)
>
> **Key source files cited throughout:**
> - `src/resources/GSD-WORKFLOW.md` — manual bootstrap protocol (the canonical methodology doc)
> - `docs/architecture.md` — system structure, dispatch pipeline, module table
> - `docs/auto-mode.md` — state machine, fresh sessions, reliability features
> - `docs/commands.md` — all commands and headless mode
> - `docs/configuration.md` — preferences, models, hooks, verification
> - `docs/token-optimization.md` — profiles, compression, complexity routing
> - `docs/cost-management.md` — budgets, tracking, projections
> - `docs/git-strategy.md` — worktree isolation, branch modes, squash merge
> - `docs/parallel-orchestration.md` — multi-worker coordinator
> - `docs/skills.md` — skill discovery, lifecycle, health tracking
> - `docs/working-in-teams.md` — multi-user workflow
> - `docs/troubleshooting.md` — doctor, recovery procedures
> - `src/resources/extensions/gsd/auto-dispatch.ts` — declarative dispatch table
> - `src/resources/extensions/gsd/state.ts` — state derivation from disk
> - `src/resources/extensions/gsd/crash-recovery.ts` — lock file crash recovery

---

## 1. Work Hierarchy

### 1.1 Milestone -> Slice -> Task Model

GSD organizes all work into a three-level hierarchy (source: `GSD-WORKFLOW.md` lines 29-33):

```
Milestone  ->  a shippable version (4-10 slices)
  Slice    ->  one demoable vertical capability (1-7 tasks)
    Task   ->  one context-window-sized unit of work (fits in one session)
```

**Size guidance:**
- **Milestone:** 4-10 slices. Represents a shippable version. Ordered by risk (high-risk first to validate feasibility early).
- **Slice:** 1-7 tasks. Each slice is a "demoable vertical capability" with a demo sentence describing what the user can see/do when done.
- **Task:** Must fit in one context window. If it can't, it is two tasks. This is the **iron rule**.

**Risk and dependency tags** are inline metadata on slice entries in the roadmap: `risk:low|medium|high`, `depends:[S01, S02]`. Dependencies list slice IDs that must complete before the slice can start.

### 1.2 File Structure (.gsd/ Directory)

All artifacts live in `.gsd/` at the project root (source: `GSD-WORKFLOW.md` lines 41-64, `getting-started.md` lines 113-131):

```
.gsd/
  STATE.md                                  # Derived cache dashboard (runtime, gitignored)
  PROJECT.md                                # What the project is right now
  REQUIREMENTS.md                           # Requirement contract (active/validated/deferred)
  DECISIONS.md                              # Append-only decisions register
  KNOWLEDGE.md                              # Append-only cross-session memory
  preferences.md                            # Project-local preferences (YAML frontmatter)
  metrics.json                              # Token/cost tracking ledger
  routing-history.json                      # Adaptive model routing data
  auto.lock                                 # Crash recovery lock file
  completed-units.json                      # Completed unit tracking
  reports/                                  # Auto-generated HTML reports
  parallel/                                 # Coordinator <-> worker IPC files
    <MID>.status.json                       # Worker heartbeat + progress
    <MID>.signal.json                       # Coordinator -> worker signals
  worktrees/                                # Git worktrees (one per milestone)
    <MID>/                                  # Isolated checkout for milestone
  activity/                                 # JSONL session dumps for forensics
  milestones/
    M001/
      M001-ROADMAP.md                       # Milestone plan (checkboxes = state)
      M001-CONTEXT.md                       # Optional: user decisions from discuss phase
      M001-CONTEXT-DRAFT.md                 # Optional: draft seed from prior discussion
      M001-RESEARCH.md                      # Optional: codebase/tech research
      M001-SUMMARY.md                       # Milestone rollup (updated as slices complete)
      M001-VALIDATION.md                    # Milestone validation gate result
      slices/
        S01/
          S01-PLAN.md                       # Task decomposition for this slice
          S01-CONTEXT.md                    # Optional: slice-level user decisions
          S01-RESEARCH.md                   # Optional: slice-level research
          S01-SUMMARY.md                    # Slice summary (written on completion)
          S01-UAT.md                        # Non-blocking human test script
          continue.md                       # Ephemeral: resume point if interrupted
          tasks/
            T01-PLAN.md                     # Individual task plan
            T01-SUMMARY.md                  # Task summary with frontmatter
```

**Runtime/gitignored files:** `STATE.md`, `auto.lock`, `completed-units.json`, `metrics.json`, `activity/`, `runtime/`, `worktrees/`, `milestones/**/continue.md`.

**Shared/committed files:** `preferences.md`, `PROJECT.md`, `REQUIREMENTS.md`, `DECISIONS.md`, `milestones/` (roadmaps, plans, summaries, research).

### 1.3 State Derivation

`STATE.md` is a **derived cache**, NOT the source of truth (source: `GSD-WORKFLOW.md` lines 519-539, `state.ts`).

**Sources of truth:**
- `M###-ROADMAP.md` -> which slices exist and which are done (checkbox parsing: `- [x]` = done, `- [ ]` = not done)
- `S##-PLAN.md` -> which tasks exist within a slice (same checkbox parsing)
- `T##-SUMMARY.md` -> what happened during a task
- `S##-SUMMARY.md` and `M###-SUMMARY.md` -> compressed outcomes

**How `deriveState()` works** (source: `state.ts` lines 134-300):

1. Find all milestone IDs on disk (sorted by `milestoneIdSort`)
2. If `GSD_MILESTONE_LOCK` is set (parallel worker), filter to only that milestone
3. Optionally batch-parse all `.md` files via native Rust parser for performance
4. For each milestone: parse its roadmap, check `isMilestoneComplete()` (all slices done), check for summary file (fully completed)
5. Build a `MilestoneRegistryEntry[]` with status: `complete`, `active`, `pending`
6. For the active milestone: find the first incomplete slice, find the first incomplete task
7. Derive the `phase` field from the combination of: roadmap existence, context existence, research existence, plan existence, task completion state, summary existence, validation existence
8. Memoize result with 100ms TTL to avoid redundant disk reads within a dispatch cycle

**Phases derived from disk state:**
- `pre-planning` — milestone exists but no roadmap
- `needs-discussion` — has draft context but needs full discussion
- `planning` — roadmap exists, active slice has no plan yet
- `replanning-slice` — slice needs replanning
- `executing` — active task exists and isn't done
- `summarizing` — all tasks in slice done, no slice summary yet
- `validating-milestone` — all slices done, no validation file
- `completing-milestone` — validation passed, no milestone summary
- `complete` — milestone summary exists

**Reconciliation rules** (source: `GSD-WORKFLOW.md` lines 535-539):
- Roadmap says slice done but task summaries missing -> inconsistency
- Task marked done but no summary -> treat as incomplete
- Continue file exists for completed task -> delete continue file
- State points to nonexistent slice/task -> rebuild state from files

### 1.4 Roadmap Format

`M###-ROADMAP.md` exact format (source: `GSD-WORKFLOW.md` lines 70-126):

```markdown
# M001: Title of the Milestone

**Vision:** One paragraph describing what this milestone delivers.

**Success Criteria:**
- Observable outcome 1
- Observable outcome 2

---

## Slices

- [ ] **S01: Slice Title** `risk:low` `depends:[]`
  > After this: what the user can demo when this slice is done.

- [ ] **S02: Another Slice** `risk:medium` `depends:[S01]`
  > After this: demo sentence.

- [x] **S03: Completed Slice** `risk:low` `depends:[S01]`
  > After this: demo sentence.

## Boundary Map

### S01 -> S02
Produces:
  types.ts -> User, Session, AuthToken (interfaces)
  auth.ts  -> generateToken(), verifyToken(), refreshToken()

Consumes: nothing (leaf node)

### S02 -> S03
Produces:
  api/auth/login.ts  -> POST handler
  api/auth/signup.ts -> POST handler
  middleware.ts       -> authMiddleware()

Consumes from S01:
  auth.ts -> generateToken(), verifyToken()
```

**Parsing rules:**
- `- [x]` = done, `- [ ]` = not done
- `risk:` and `depends:[]` are inline metadata parsed from the line
- `depends:[]` lists slice IDs this slice requires

**Boundary Map** (required section):
- Shows what each slice produces (functions, types, interfaces, endpoints) and consumes from upstream slices
- Planning artifact, not runnable code
- Forces upfront interface thinking before implementation
- Enables deterministic verification that slices connect
- Updated during slice planning if new interfaces emerge

### 1.5 Plan Formats

**`S##-PLAN.md`** (source: `GSD-WORKFLOW.md` lines 127-150):

```markdown
# S01: Slice Title

**Goal:** What this slice achieves.
**Demo:** What the user can see/do when this is done.

## Must-Haves
- Observable outcome 1 (used for verification)
- Observable outcome 2

## Tasks

- [ ] **T01: Task Title**
  Description of what this task does.

- [ ] **T02: Another Task**
  Description.

## Files Likely Touched
- path/to/file.ts
- path/to/another.ts
```

**`T##-PLAN.md`** (source: `GSD-WORKFLOW.md` lines 152-188):

```markdown
# T01: Task Title

**Slice:** S01
**Milestone:** M001

## Goal
What this task accomplishes in one sentence.

## Must-Haves

### Truths
Observable behaviors that must be true when this task is done:
- "User can sign up with email and password"
- "Login returns a JWT token"

### Artifacts
Files that must exist with real implementation (not stubs):
- `src/lib/auth.ts` -- JWT helpers (min 30 lines, exports: generateToken, verifyToken)
- `src/app/api/auth/login/route.ts` -- Login endpoint (exports: POST)

### Key Links
Critical wiring between artifacts:
- `login/route.ts` -> `auth.ts` via import of `generateToken`
- `middleware.ts` -> `auth.ts` via import of `verifyToken`

## Steps
1. First thing to do
2. Second thing to do
3. Third thing to do

## Context
- Relevant prior decisions or patterns to follow
- Key files to read before starting
```

**Must-haves are what make verification mechanically checkable:**
- **Truths** are checked by running commands or reading output
- **Artifacts** are checked by confirming files exist with real content (not stubs)
- **Key Links** are checked by confirming imports/references actually connect the pieces

### 1.6 Summary Format

**`T##-SUMMARY.md` frontmatter fields** (source: `GSD-WORKFLOW.md` lines 407-448):

```yaml
---
id: T01
parent: S01
milestone: M001
provides:
  - What this task built (~5 items)
requires:
  - slice: S00
    provides: What that prior slice built that this task used
affects: [S02, S03]
key_files:
  - path/to/important/file.ts
key_decisions:
  - "Decision made: reasoning"
patterns_established:
  - "Pattern name and where it lives"
drill_down_paths:
  - .gsd/milestones/M001/slices/S01/tasks/T01-PLAN.md
duration: 15min
verification_result: pass
completed_at: 2026-03-07T16:00:00Z
---

# T01: Task Title

**Substantive one-liner -- NOT "task complete" but what actually shipped**

## What Happened
Concise prose narrative of what was built.

## Deviations
What differed from the plan and why (or "None").

## Files Created/Modified
- `path/to/file.ts` -- What it does
```

**Soft caps for summary content:**
- ~5 provides per summary
- ~10 key_files per summary
- ~5 key_decisions per summary
- ~3 patterns_established per summary

**Slice summary** (`S##-SUMMARY.md`): written when all tasks complete. Compresses all task summaries. Includes `drill_down_paths` to each task summary.

**Milestone summary** (`M###-SUMMARY.md`): updated each time a slice completes. Compresses all slice summaries. This is what gets injected into later slice planning.

---

## 2. Auto-Mode Dispatch Pipeline

### 2.1 The Full 13-Step Loop

From `docs/architecture.md` lines 106-123:

```
1.  Read disk state (STATE.md, roadmap, plans)
2.  Determine next unit type and ID
3.  Classify complexity -> select model tier
4.  Apply budget pressure adjustments
5.  Check routing history for adaptive adjustments
6.  Dynamic model routing (if enabled) -> select cheapest model for tier
7.  Resolve effective model (with fallbacks)
8.  Check pending captures -> triage if needed
9.  Build dispatch prompt (applying inline level compression)
10. Create fresh agent session
11. Inject prompt and let LLM execute
12. On completion: snapshot metrics, verify artifacts, persist state
13. Loop to step 1
```

Phase skipping (from token profile) gates steps 2-3: if a phase is skipped, the corresponding unit type is never dispatched.

The **per-slice loop** flows through these phases automatically (source: `auto-mode.md` lines 12-25):

```
Research -> Plan -> Execute (per task) -> Complete -> Reassess Roadmap -> Next Slice
                                                                          | (all slices done)
                                                                  Validate Milestone -> Complete Milestone
```

### 2.2 Context Pre-Loading

What gets inlined into each dispatch prompt (source: `auto-mode.md` lines 34-45):

| Inlined Artifact | Purpose |
|------------------|---------|
| Task plan | What to build |
| Slice plan | Where this task fits |
| Prior task summaries | What's already done |
| Dependency summaries | Cross-slice context |
| Roadmap excerpt | Overall direction |
| Decisions register | Architectural context |

The amount inlined is controlled by the token profile's **inline level** (see section 2.4).

**Summary injection rules** (source: `GSD-WORKFLOW.md` lines 614-631):
1. Check the current slice's `depends:[]` in the roadmap
2. Load summaries from those dependency slices
3. Start with the highest available level -- milestone summary first
4. Only drill down to slice/task summaries if specific detail is needed
5. Stay within ~2500 tokens of total injected summary context
6. If the dependency chain is too large, drop the oldest/least-relevant summaries first

### 2.3 Fresh Session Per Unit

Every dispatch creates a **new agent session** via the Pi SDK. The LLM starts with a clean context window containing only the pre-inlined artifacts it needs (source: `architecture.md` line 52, `auto-mode.md` lines 28-31).

This prevents:
- Quality degradation from context accumulation
- Stale reasoning from prior tasks leaking into current work
- Context window exhaustion across multi-task executions

The session file path is recorded in the lock file for crash recovery forensics.

### 2.4 Token Profiles and Context Compression

Three profiles (source: `token-optimization.md`):

**`budget` -- Maximum Savings (40-60% reduction):**

| Dimension | Setting |
|-----------|---------|
| Planning model | Sonnet |
| Execution model | Sonnet |
| Simple task model | Haiku |
| Completion model | Haiku |
| Subagent model | Haiku |
| Milestone research | **Skipped** |
| Slice research | **Skipped** |
| Roadmap reassessment | **Skipped** |
| Context inline level | **Minimal** -- drops decisions, requirements, extra templates |

**`balanced` -- Smart Defaults (default):**

| Dimension | Setting |
|-----------|---------|
| All models | User's default |
| Subagent model | Sonnet |
| Milestone research | Runs |
| Slice research | **Skipped** |
| Roadmap reassessment | Runs |
| Context inline level | **Standard** -- includes key context, drops low-signal extras |

**`quality` -- Full Context:**

| Dimension | Setting |
|-----------|---------|
| All models | User's configured defaults |
| All phases | Run |
| Context inline level | **Full** -- everything inlined |

**Inline level compression details:**

| Profile | Inline Level | What's Included |
|---------|-------------|-----------------|
| `budget` | `minimal` | Task plan, essential prior summaries (truncated). Drops decisions register, requirements, UAT template, secrets manifest. |
| `balanced` | `standard` | Task plan, prior summaries, slice plan, roadmap excerpt. Drops some supplementary templates. |
| `quality` | `full` | Everything -- all plans, summaries, decisions, requirements, templates, and root files. |

Specific compression behaviors at `minimal` level:
- `buildExecuteTaskPrompt` -- drops decisions template, truncates prior summaries to the most recent one
- `buildPlanMilestonePrompt` -- drops PROJECT.md, REQUIREMENTS.md, decisions, supplementary templates
- `buildCompleteSlicePrompt` -- drops requirements and UAT template inlining
- `buildCompleteMilestonePrompt` -- drops root GSD file inlining
- `buildReassessRoadmapPrompt` -- drops project, requirements, and decisions files

### 2.5 Complexity Classification and Model Routing

Tasks are classified by analyzing the task plan (source: `token-optimization.md` lines 110-124):

| Signal | Simple | Standard | Complex |
|--------|--------|----------|---------|
| Step count | <= 3 | 4-7 | >= 8 |
| File count | <= 3 | 4-7 | >= 8 |
| Description length | < 500 chars | 500-2000 | > 2000 chars |
| Code blocks | -- | -- | >= 5 |
| Signal words | None | Any present | -- |

**Signal words** that prevent simple classification: `research`, `investigate`, `refactor`, `migrate`, `integrate`, `complex`, `architect`, `redesign`, `security`, `performance`, `concurrent`, `parallel`, `distributed`, `backward compat`, `migration`, `architecture`, `concurrency`, `compatibility`.

**Non-task unit type defaults:**

| Unit Type | Default Tier |
|-----------|-------------|
| `complete-slice`, `run-uat` | Light |
| `research-*`, `plan-*`, `execute-task`, `complete-milestone` | Standard |
| `replan-slice`, `reassess-roadmap` | Heavy |
| `hook/*` | Light |

**Tier -> model mapping:**

| Tier | Model Phase Key | Typical Model |
|------|----------------|---------------|
| Light | `completion` | Haiku (budget) / user default |
| Standard | `execution` | Sonnet / user default |
| Heavy | `execution` | Opus / user default |

---

## 3. Orchestration

### 3.1 Sequential Execution (Single-Worker Auto Mode)

`/gsd auto` runs a state-machine loop that reads `.gsd/STATE.md`, determines the next unit of work, dispatches it, and loops (source: `auto-mode.md` lines 7-8).

The **dispatch table** (`auto-dispatch.ts`) is a declarative array of `DispatchRule` objects evaluated in order; the first match wins. Rules are named for debugging:

1. `rewrite-docs (override gate)` -- handle pending doc overrides (max 3 attempts with circuit breaker)
2. `summarizing -> complete-slice` -- when all tasks done, dispatch slice completion
3. `run-uat (post-completion)` -- run UAT if configured
4. `reassess-roadmap (post-completion)` -- reassess after slice completes (skippable via profile)
5. `needs-discussion -> stop` -- draft context needs discussion
6. `pre-planning (no context) -> stop` -- no context or roadmap, needs `/gsd` discuss
7. `pre-planning (no research) -> research-milestone` -- dispatch milestone research
8. `pre-planning (has research) -> plan-milestone` -- dispatch milestone planning
9. `planning (no research, not S01) -> research-slice` -- dispatch slice research
10. `planning -> plan-slice` -- dispatch slice planning
11. `replanning-slice -> replan-slice` -- dispatch replanning
12. `executing -> execute-task (recover missing task plan)` -- fallback to plan-slice
13. `executing -> execute-task` -- dispatch task execution
14. `validating-milestone -> validate-milestone` -- reconciliation gate
15. `completing-milestone -> complete-milestone` -- dispatch milestone completion

**DispatchAction types:**
- `{ action: "dispatch", unitType, unitId, prompt, pauseAfterDispatch? }` -- send to LLM
- `{ action: "stop", reason, level }` -- halt auto mode
- `{ action: "skip" }` -- skip this unit, re-derive state

### 3.2 Parallel Execution (Multi-Worker Coordinator)

Source: `parallel-orchestration.md`.

**Architecture:**
- A **coordinator** (your GSD session) spawns up to 4 **worker** processes
- Each worker is a separate `gsd` process with `GSD_MILESTONE_LOCK` env var scoping it to one milestone
- Workers are prevented from spawning nested parallel sessions via `GSD_PARALLEL_WORKER` env var

**Isolation per worker:**

| Resource | Isolation Method |
|----------|-----------------|
| Filesystem | Git worktree -- each worker has its own checkout |
| Git branch | `milestone/<MID>` -- one branch per milestone |
| State derivation | `GSD_MILESTONE_LOCK` -- `deriveState()` only sees the assigned milestone |
| Context window | Separate process -- each worker has its own agent sessions |
| Metrics | Each worktree has its own `.gsd/metrics.json` |
| Crash recovery | Each worktree has its own `.gsd/auto.lock` |

**Coordination via file-based IPC:**
- `.gsd/parallel/<MID>.status.json` -- workers write heartbeats, coordinator reads them
- `.gsd/parallel/<MID>.signal.json` -- coordinator writes signals (pause/resume/stop), workers consume them
- Atomic writes (write-to-temp + rename) prevent partial reads

**Eligibility rules:**
1. Not complete (finished milestones skipped)
2. Dependencies satisfied (all `dependsOn` entries must be `complete`)
3. File overlap check (warning, not blocker -- separate worktrees prevent interference)

**Merge reconciliation:**
- `.gsd/` state files auto-resolved (accept milestone branch version)
- Code conflicts stop and report for manual resolution
- Sequential merge order by default (M001 before M002)

### 3.3 Git Isolation

Three modes configured via `git.isolation` in preferences (source: `git-strategy.md`):

| Mode | Working Directory | Branch | Best For |
|------|-------------------|--------|----------|
| `worktree` (default) | `.gsd/worktrees/<MID>/` | `milestone/<MID>` | Full file isolation |
| `branch` | Project root | `milestone/<MID>` | Submodule-heavy repos |
| `none` | Project root | Current branch | Hot-reload workflows |

**Commit format:** Conventional commits with scope from task summary:
- Task: `{type}(S01/T02): <one-liner from summary>`
- Plan/docs: `docs(S01): add slice plan`
- Squash to main: `type(M001/S01): <slice title>`

**Squash merge message:**
```
feat(M001/S01): file I/O foundation

Agent can parse, format, load, and save all GSD file types with round-trip fidelity.

Tasks completed:
- T01: core types and interfaces
- T02: markdown parser for plan files
- T03: file writer with round-trip fidelity
```

### 3.4 Two-Terminal Workflow

Source: `getting-started.md` lines 79-97.

**Terminal 1 -- let it build:**
```bash
gsd
/gsd auto
```

**Terminal 2 -- steer while it works:**
```bash
gsd
/gsd discuss    # talk through architecture decisions
/gsd status     # check progress
/gsd queue      # queue the next milestone
/gsd steer      # hard-steer plan documents
/gsd capture    # fire-and-forget thought capture
```

Both terminals read and write the same `.gsd/` files. Decisions in terminal 2 are picked up at the next phase boundary automatically.

### 3.5 Headless Mode

`gsd headless` runs commands without a TUI -- designed for CI, cron, scripted automation (source: `commands.md` lines 101-183).

```bash
gsd headless              # Run auto mode (default)
gsd headless next         # Run a single unit
gsd headless query        # Instant JSON snapshot (~50ms, no LLM)
gsd headless --timeout 600000 auto   # With timeout for CI
gsd headless dispatch plan           # Force a specific phase
gsd headless new-milestone --context brief.md --auto  # Create + auto
```

**Exit codes:** `0` = complete, `1` = error or timeout, `2` = blocked.

**`gsd headless query` output schema:**

```json
{
  "state": {
    "phase": "executing",
    "activeMilestone": { "id": "M001", "title": "..." },
    "activeSlice": { "id": "S01", "title": "..." },
    "activeTask": { "id": "T01", "title": "..." },
    "registry": [{ "id": "M001", "status": "active" }],
    "progress": { "milestones": { "done": 0, "total": 2 }, "slices": { "done": 1, "total": 3 } },
    "blockers": []
  },
  "next": {
    "action": "dispatch",
    "unitType": "execute-task",
    "unitId": "M001/S01/T01"
  },
  "cost": {
    "workers": [{ "milestoneId": "M001", "cost": 1.50, "state": "running" }],
    "total": 1.50
  }
}
```

---

## 4. Reliability

### 4.1 Crash Recovery

Source: `crash-recovery.ts`, `auto-mode.md` lines 62-65, `troubleshooting.md`.

**Lock file mechanism:**
- `auto.lock` is written on auto-start, updated on each unit dispatch, deleted on clean stop
- Contains: `pid`, `startedAt`, `unitType`, `unitId`, `unitStartedAt`, `completedUnits`, `sessionFile`
- If the lock file exists on next startup, the previous session crashed
- Stale lock detection: checks if the PID is still alive via `process.kill(pid, 0)`

**Session forensics:**
- The lock records the Pi session file path (`sessionFile`)
- Pi appends JSONL entries incrementally via `appendFileSync`, so the file on disk reflects every tool call up to the crash point
- On crash recovery, the system reads the surviving session file and synthesizes a recovery briefing from every tool call that made it to disk

**Headless auto-restart (v2.26):**
- `gsd headless auto` triggers automatic restart on crash
- Exponential backoff: 5s -> 10s -> 30s cap
- Default 3 attempts, configurable with `--max-restarts N`
- SIGINT/SIGTERM bypasses restart (intentional shutdown)
- Combined with crash recovery, enables true overnight "run until done" execution

**Recovery procedures:**
```bash
rm .gsd/auto.lock                 # Reset lock file
rm .gsd/completed-units.json      # Reset completed unit tracking
/gsd doctor                       # Full state rebuild and integrity check
```

### 4.2 Stuck Detection

Source: `auto-mode.md` lines 92-96.

**Dispatch-twice rule:**
- If the same unit dispatches twice (the LLM didn't produce the expected artifact), GSD retries once with a **deep diagnostic prompt**
- If it fails again, auto mode stops with the exact file it expected, so the user can intervene
- Error message: "Loop detected"

**Post-mortem:** `/gsd forensics` provides structured root-cause analysis -- inspects activity logs, crash locks, and session state.

### 4.3 Timeout Supervision

Three timeout tiers (source: `auto-mode.md` lines 99-116):

| Timeout | Default | Behavior |
|---------|---------|----------|
| Soft | 20 min | Warns the LLM to wrap up |
| Idle | 10 min | Detects stalls, intervenes |
| Hard | 30 min | Pauses auto mode |

Configuration:
```yaml
auto_supervisor:
  soft_timeout_minutes: 20
  idle_timeout_minutes: 10
  hard_timeout_minutes: 30
```

Recovery steering nudges the LLM to finish durable output (commit, write summaries) before timing out.

### 4.4 Provider Error Recovery

Source: `auto-mode.md` lines 68-77.

GSD classifies provider errors and auto-resumes when safe:

| Error Type | Examples | Action |
|-----------|----------|--------|
| Rate limit | 429, "too many requests" | Auto-resume after `retry-after` header or 60s |
| Server error | 500, 502, 503, "overloaded", "api_error" | Auto-resume after 30s |
| Permanent | "unauthorized", "invalid key", "billing" | Pause indefinitely (requires manual resume) |

**Fallback models:** When a model fails, GSD tries the next model in the `fallbacks` list:
```yaml
models:
  execution:
    model: claude-sonnet-4-6
    fallbacks:
      - openrouter/minimax/minimax-m2.5
```

### 4.5 Verification Enforcement

Source: `auto-mode.md` lines 128-138, `configuration.md` lines 186-203.

```yaml
verification_commands:
  - npm run lint
  - npm run test
verification_auto_fix: true       # auto-retry on failure (default: true)
verification_max_retries: 2       # max retry attempts (default: 2)
```

- Shell commands run automatically **after every task execution**
- Failures trigger auto-fix retries -- the agent sees the verification output and attempts to fix the issues before advancing
- Ensures code quality gates are enforced **mechanically**, not by LLM compliance

**Verification ladder** (from `GSD-WORKFLOW.md` lines 364-370):
1. **Static:** Files exist, exports present, wiring connected, not stubs
2. **Command:** Tests pass, build succeeds, lint clean
3. **Behavioral:** Browser flows work, API responses correct
4. **Human:** Ask the user only when you genuinely can't verify yourself

**Verification report format** includes tables for:
- Observable Truths (status + evidence)
- Artifacts (expected vs actual, SUBSTANTIVE/STUB classification)
- Key Links (wiring status)
- Anti-Patterns Found (file, line, pattern, severity)

### 4.6 Context Pressure Monitor

Source: `auto-mode.md` lines 83-85.

When context usage reaches **70%**, GSD sends a **wrap-up signal** to the agent, nudging it to finish durable output (commit, write summaries) before the context window fills.

From the manual protocol (`GSD-WORKFLOW.md` lines 660-667):
- **If mid-task:** Write `continue.md` with exact resume state
- **If between tasks:** Update STATE.md with next action (no continue file needed)
- **Don't fight it.** A fresh session with the right files loaded is better than a stale session with degraded reasoning.

---

## 5. Adaptive Intelligence

### 5.1 Roadmap Reassessment After Each Slice

Source: `auto-mode.md` lines 125-126.

After each slice completes, the roadmap is reassessed. If the work revealed new information that changes the plan, slices are reordered, added, or removed before continuing.

This is implemented as the `reassess-roadmap` dispatch rule (rule #4 in the dispatch table), which checks `checkNeedsReassessment()` and dispatches `buildReassessRoadmapPrompt()`.

Can be skipped with `balanced` or `budget` token profiles (or explicitly via `phases.skip_reassess: true`).

### 5.2 KNOWLEDGE.md -- Cross-Session Memory

Source: `auto-mode.md` lines 79-81.

`KNOWLEDGE.md` is an **append-only register** of project-specific rules, patterns, and lessons learned.

- The agent **reads** it at the start of every unit
- The agent **appends** to it when discovering recurring issues, non-obvious patterns, or rules that future sessions should follow
- Gives auto-mode cross-session memory that survives context window boundaries
- Can be manually added via `/gsd knowledge rule|pattern|lesson <description>`
- Distinct from `custom_instructions` in preferences -- KNOWLEDGE.md is project-specific and injected into every agent prompt automatically

### 5.3 DECISIONS.md -- Append-Only Register

Source: `GSD-WORKFLOW.md` lines 233-258.

Format:
```markdown
# Decisions Register

<!-- Append-only. Never edit or remove existing rows.
     To reverse a decision, add a new row that supersedes it.
     Read this file at the start of any planning or research phase. -->

| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/S01 | library | Validation library | Zod | Type inference, already in deps | No |
| D002 | M001/S01 | arch | Session storage | HTTP-only cookies | Security, SSR compat | Yes -- if mobile added |
```

**Field definitions:**
- **#** -- Sequential ID (`D001`, `D002`, ...), never reused
- **When** -- Where the decision was made: `M001`, `M001/S01`, or `M001/S01/T02`
- **Scope** -- Category tag: `arch`, `pattern`, `library`, `data`, `api`, `scope`, `convention`
- **Decision** -- What was decided (the question)
- **Choice** -- What was chosen (the answer)
- **Rationale** -- Why
- **Revisable?** -- `No`, or `Yes -- trigger condition`

**Rules:**
- **Append-only** -- rows are never edited or removed. To reverse, add a new row referencing the old ID.
- **When to read:** At the start of any planning or research phase
- **When to write:** During discussion, during planning, during task execution (if an architectural choice was made), and during slice completion (catch-all)

### 5.4 Continue-Here Protocol

Source: `GSD-WORKFLOW.md` lines 472-513.

**When to write `continue.md`:**
- About to lose context (compaction, session end, Ctrl+C)
- Current task isn't done yet
- Want to pause and come back later

**Format:**
```markdown
---
milestone: M001
slice: S01
task: T02
step: 3
total_steps: 7
saved_at: 2026-03-07T15:30:00Z
---

## Completed Work
- What's already done in this task and prior tasks in the slice.

## Remaining Work
- What steps remain, with enough detail to resume.

## Decisions Made
- Key decisions and WHY (so next session doesn't re-debate).

## Context
The "vibe" -- what you were thinking, what's tricky, what to watch out for.

## Next Action
The EXACT first thing to do when resuming. Not vague. Specific.
```

**How to resume:**
1. Read `continue.md`
2. Delete `continue.md` (it's consumed, not permanent)
3. Pick up from "Next Action"

### 5.5 Capture System

Source: `auto-mode.md` lines 198-204, `architecture.md` line 137-138.

**Fire-and-forget thought capture:**
```
/gsd capture "add rate limiting to API endpoints"
```

- Captures are stored and triaged automatically between tasks
- Works during auto mode without interrupting execution
- Triage classification determines resolution: inject into current work, defer to future slice, trigger replanning, or create a quick-task

**Key modules:**
- `captures.ts` -- fire-and-forget thought capture and triage classification
- `triage-resolution.ts` -- capture resolution (inject, defer, replan, quick-task)

---

## 6. Principles to Port to Spec-Kit Extension

### 6.1 The "Iron Rule" -- Task Must Fit One Context Window

The single most important design principle in GSD. If a unit of work cannot fit in one context window, it must be decomposed further. This ensures:
- Each dispatch gets a clean context with full reasoning capacity
- No degraded quality from accumulated garbage
- Predictable resource consumption per unit
- Clean crash recovery boundaries (each unit is atomic)

### 6.2 State Machine Driven by Files on Disk

`.gsd/` is the **sole source of truth**. No in-memory state survives across sessions. The phase is derived from what files exist on disk (roadmap? plan? summaries? validation?). This enables:
- Crash recovery (just re-read disk state)
- Multi-terminal steering (both terminals read/write same files)
- Session resumption (fresh session reads STATE.md and picks up)
- External tooling integration (headless query reads the same files)

### 6.3 Fresh Context Per Unit with Pre-Loaded Artifacts

Every dispatch creates a new agent session. The dispatch prompt is carefully constructed with everything needed -- task plans, prior summaries, dependency context, decisions register -- so the LLM starts oriented instead of spending tool calls reading files.

The context pre-loading is controlled by inline levels (minimal/standard/full) that trade cost for completeness.

### 6.4 Crash Recovery via Lock + Forensics

The `auto.lock` file with PID, session file path, and unit tracking enables:
- Detection of interrupted sessions
- Session forensics from surviving JSONL
- Stale lock cleanup
- Headless auto-restart with exponential backoff

### 6.5 Adaptive Replanning as First-Class Phase

After each slice completes, the system asks: "Does the roadmap still make sense?" This is not an afterthought -- it's a named phase (`reassess-roadmap`) in the dispatch table with its own prompt builder. Real work changes the plan.

### 6.6 Cost Tracking and Budget Enforcement

Every unit's tokens, cost, duration, and tool calls are captured in `metrics.json`. Budget ceilings can pause or halt auto mode. Budget pressure automatically downgrades model tiers:
- < 50% used: no adjustment
- 50-75% used: standard -> light
- 75-90% used: same, more aggressive
- > 90% used: everything except heavy -> light; heavy -> standard

### 6.7 Verification as Mechanical Gate

Must-haves in task plans (Truths, Artifacts, Key Links) make verification mechanically checkable, not dependent on LLM self-assessment. Combined with `verification_commands` (lint, test), this creates a hard quality gate that the agent cannot skip.

The verification ladder (static -> command -> behavioral -> human) provides a hierarchy of verification strength.

### 6.8 Boundary Maps for Deterministic Cross-Slice Verification

The boundary map in `M###-ROADMAP.md` specifies what each slice produces and consumes. This enables:
- Upfront interface thinking before implementation
- Concrete targets for downstream slices
- Deterministic verification that slices actually connect
- Must-haves that reference boundary map contracts (e.g., "exports `generateToken()` as specified in boundary map S01->S02")

### 6.9 Two-Stage Workflow (Auto + Steer)

The recommended workflow is auto mode in one terminal and steering from another. This separation means:
- The execution engine runs uninterrupted
- Human decisions are captured asynchronously and picked up at phase boundaries
- Status monitoring doesn't interrupt execution
- Captures and discussions are fire-and-forget from the human's perspective

---

## Appendix A: Bundled Extensions

Source: `src/resources/extensions/` directory listing and `architecture.md` lines 56-77.

| Extension | What It Provides |
|-----------|-----------------|
| `gsd` | Core workflow engine -- auto mode, state machine, commands, dashboard |
| `browser-tools` | Playwright-based browser automation |
| `search-the-web` | Brave Search, Tavily, or Jina page extraction |
| `google-search` | Gemini-powered web search |
| `context7` | Up-to-date library/framework documentation |
| `bg-shell` | Long-running process management with readiness detection |
| `subagent` | Delegated tasks with isolated context windows |
| `mac-tools` | macOS native app automation via Accessibility APIs |
| `mcporter` | Lazy on-demand MCP server integration |
| `voice` | Real-time speech-to-text |
| `slash-commands` | Custom command creation |
| `ask-user-questions` | Structured user input (single/multi-select) |
| `get-secrets-from-user` | Masked secret collection |
| `async-jobs` | Background command execution (`async_bash`, `await_job`, `cancel_job`) |
| `remote-questions` | Discord, Slack, Telegram integration for headless question routing |
| `ttsr` | Tool-triggered system rules -- conditional context injection |
| `universal-config` | Discovery of existing AI tool configurations |
| `shared` | Shared utilities across extensions |

Additional extensions listed in `src/resources/extensions/` but not in docs: `shared/`.

## Appendix B: Bundled Agents

Source: `src/resources/agents/` directory listing and agent `.md` files.

| Agent | Role | Tools |
|-------|------|-------|
| `scout` | Fast codebase recon -- compressed context for handoff | read, grep, find, ls, bash |
| `researcher` | Web research -- finds and synthesizes current information | web_search, bash |
| `worker` | General-purpose execution in isolated context window | all (restricted from spawning subagents) |
| `javascript-pro` | Modern JS specialist (ES2023+, Node.js 20+) | all |
| `typescript-pro` | TypeScript specialist (TS 5.0+, type-level programming) | all |

## Appendix C: Bundled Skills

Source: `src/resources/skills/` directory listing and `docs/skills.md`.

Skills in `src/resources/skills/`: `accessibility`, `agent-browser`, `best-practices`, `code-optimizer`, `core-web-vitals`, `debug-like-expert`, `frontend-design`, `github-workflows`, `lint`, `make-interfaces-feel-better`, `react-best-practices`, `review`, `swiftui`, `test`, `userinterface-wiki`, `web-design-guidelines`, `web-quality-audit`.

Additional skills documented in `docs/skills.md`: `rust-core`, `axum-web-framework`, `axum-tests`, `tauri`, `tauri-ipc-developer`, `tauri-devtools`, `security-audit`, `security-review`, `security-docker`.

## Appendix D: Key Module Table (v2.24)

Source: `architecture.md` lines 126-149.

| Module | Purpose |
|--------|---------|
| `auto.ts` | Auto-mode state machine and orchestration |
| `auto-dispatch.ts` | Declarative dispatch table (phase -> unit mapping) |
| `auto-prompts.ts` | Prompt builders with inline level compression |
| `auto-worktree.ts` | Worktree lifecycle (create, enter, merge, teardown) |
| `complexity-classifier.ts` | Unit complexity classification (light/standard/heavy) |
| `model-router.ts` | Dynamic model routing with cost-aware selection |
| `model-cost-table.ts` | Built-in per-model cost data |
| `routing-history.ts` | Adaptive learning from routing outcomes |
| `captures.ts` | Fire-and-forget thought capture and triage |
| `triage-resolution.ts` | Capture resolution (inject, defer, replan, quick-task) |
| `metrics.ts` | Token and cost tracking ledger |
| `state.ts` | State derivation from disk |
| `preferences.ts` | Preference loading, merging, validation |
| `git-service.ts` | Git operations -- commit, merge, worktree sync |
| `memory-extractor.ts` | Extract reusable knowledge from session transcripts |
| `memory-store.ts` | Persistent memory store for cross-session knowledge |
| `crash-recovery.ts` | Lock file crash recovery |
| `queue-order.ts` | Milestone queue ordering |

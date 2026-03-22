# spec-kit-orchestrator

A [spec-kit](https://github.com/github/spec-kit) extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development (SDD) workflow.

> **Current version**: 0.2.0 — 10 commands, 27 scripts, 14 templates, 5 reference docs, 334 test assertions

## The Problem

Spec-kit excels at single-context-window development: specify, clarify, plan, tasks, implement. But projects larger than one context window hit a wall — there's no coordination layer for multi-phase work spanning multiple agent sessions. Context degrades, state is lost between sessions, and knowledge doesn't compound.

## The Solution

spec-kit-orchestrator adds a file-based orchestration layer that:

1. **Decomposes** large projects into context-window-sized phases
2. **Dispatches** each phase to a fresh agent session with only the context it needs
3. **Verifies** results mechanically (no self-assessment)
4. **Compounds knowledge** — phase N+1 is cheaper than phase N

## Quick Start

### 1. Install the extension

```bash
# Copy extension files into your spec-kit project
cp -r /path/to/spec-kit-orchestrator/{commands,scripts,templates,references,extension.yml} ./

# Make scripts executable
chmod +x scripts/**/*.sh
```

### 2. Write your spec

Use spec-kit as usual to create your feature spec:

```
/speckit.specify
/speckit.clarify
```

### 3. Evaluate scope

```
/speckit.orchestrator.evaluate
```

This classifies your project into one of three tiers:

| Tier | Scope | What Happens |
|------|-------|-------------|
| **A** | Single context window | Routes to standard spec-kit — zero overhead |
| **B** | One SDD flow, multiple contexts | Adds structured handoff between steps |
| **C** | Multiple SDD flows | Full orchestration: state machine, autonomous dispatch, crash recovery, knowledge generation |

### 4. Plan and execute (Tier C)

```
/speckit.orchestrator.discuss       # Capture architectural decisions
/speckit.orchestrator.roadmap       # Decompose spec into phases
/speckit.orchestrator.plan-phase    # Plan one phase with must-haves
/speckit.orchestrator.auto          # Run autonomous dispatch — start it and walk away
```

### 5. Monitor and wrap up

```
/speckit.orchestrator.status        # Check progress anytime (read-only, always safe)
/speckit.orchestrator.consolidate   # Compress knowledge at milestone end
```

That's it. For Tier A/B projects, the orchestrator stays out of the way. For Tier C, it handles the full lifecycle.

## Workflow

```
/evaluate ──▶ /discuss ──▶ /roadmap ──▶ /plan-phase
 (scope)      (Tier C)    (phases)     (tasks)
                                          │
                                          ▼
/consolidate ◀── /status ◀── /verify ◀── /auto
 (archive)       (check)    (checks)    (execute)
```

The state machine advances automatically during `/auto`. Use `/status` at any point to see where things stand.

## All Commands

| Command | When to Use |
|---------|-------------|
| `speckit.orchestrator.evaluate` | Starting a new project — classifies scope as Tier A, B, or C |
| `speckit.orchestrator.discuss` | Before roadmap — captures architectural decisions and constraints |
| `speckit.orchestrator.roadmap` | After discussion — decomposes spec into phases with dependency graph |
| `speckit.orchestrator.plan-phase` | Before execution — plans one phase with task decomposition and must-haves |
| `speckit.orchestrator.dispatch` | Manual execution — runs one task in a fresh context with constructed payload |
| `speckit.orchestrator.auto` | Autonomous execution — loops dispatch/verify until milestone completes |
| `speckit.orchestrator.verify` | After a phase — checks must-haves mechanically (automatic in auto mode) |
| `speckit.orchestrator.status` | Anytime — shows progress, blockers, and next action (read-only) |
| `speckit.orchestrator.resume` | After a crash or pause — recovers from disk state |
| `speckit.orchestrator.consolidate` | At milestone end — compresses knowledge and archives artifacts |

## Core Capabilities

- **Scope triage** — Classify projects as Tier A/B/C based on complexity, with manual override and tier promotion
- **Phase decomposition** — Roadmap generation with dependency graphs, boundary maps, and risk-ordered scheduling
- **State machine** — 9-state lifecycle derived entirely from file presence on disk (never in-memory)
- **Autonomous dispatch** — Derive state → budget check → stuck detection → context assembly → dispatch → verify → record → advance
- **Mechanical verification** — 4-tier ladder: static checks → command execution → behavioral validation → human review
- **Crash recovery** — Lock-based detection, recovery briefing from surviving artifacts, graceful pause/resume
- **Knowledge generation** — Structured summaries, append-only decisions/knowledge registers, scope-filtered context injection
- **Consolidation** — Artifact compression (87% reduction achieved) and archival at milestone boundaries
- **Graceful degradation** — No subagents? Sequential execution. No GitHub Agentic Workflows? Local only. No jq? Fallback parsing.

## Architecture

```
extension.yml                ← manifest: 10 commands, 5 hooks, 27 scripts
│
├── commands/                ← agent instruction documents (what to do)
│   └── references scripts/ and templates/ by path
│
├── scripts/                 ← executable helpers (how to do it)
│   ├── state/               ← derive-phase, read-config, read-roadmap (3)
│   ├── dispatch/            ← build-context, scope-filter, detect-capabilities (3)
│   ├── verify/              ← check-must-haves, check-boundary-map, check-scope,
│   │                          check-external-mods, run-commands (5)
│   ├── knowledge/           ← write-summary, append-decision, append-knowledge,
│   │                          consolidate-artifacts (4)
│   ├── lifecycle/           ← scaffold, lock-manager, stuck-detector, recovery-briefing,
│   │                          budget-checker, rollback-phase, mark-complete, record-result,
│   │                          sync-roadmap, auto-loop, phase-transition (11)
│   └── util/                ← json-field (1)
│
├── templates/               ← 14 output templates + 1 config default
│
├── references/              ← 5 progressive disclosure docs
│
└── tests/                   ← 7 test suites, 334 assertions
```

All orchestrator state lives at `.specify/orchestrator/` — separate from spec-kit's own state. State is derived from file presence on disk, making every session crash-recoverable.

### State Flow

```
pre-planning → discussing → planning → executing → summarizing → validating → completing → complete
                                          ↓ (failure)
                                      replanning
```

### Config Resolution

Four layers, highest precedence first:

```
Environment vars > .local config > project config > extension defaults
```

## Installation

### Option 1: Copy from repo

```bash
# From your project root
cp -r /path/to/spec-kit-orchestrator/commands/ ./commands/
cp -r /path/to/spec-kit-orchestrator/scripts/ ./scripts/
cp -r /path/to/spec-kit-orchestrator/templates/ ./templates/
cp -r /path/to/spec-kit-orchestrator/references/ ./references/
cp /path/to/spec-kit-orchestrator/extension.yml ./extension.yml

# Make scripts executable
chmod +x scripts/**/*.sh

# Verify installation
bash scripts/state/derive-phase.sh .specify/orchestrator
# Expected: "pre-planning" (no orchestrator state yet)
```

### Option 2: spec-kit CLI (when available)

```bash
specify extension add speckit-orchestrator
```

### What NOT to copy

`specs/`, `.specify/`, `tests/`, `CLAUDE.md`, `CHANGELOG.md`, `.git/` — these are the extension's own development artifacts. See [`references/installation.md`](references/installation.md) for full details.

### Requirements

- **spec-kit >= 0.1.0** — the extension host
- **Bash 3.2+** — scripts use associative-array-free patterns for macOS default bash compatibility
- **git** — version control, optional worktree isolation
- **jq** — optional, for JSON parsing in scripts (fallback parsing available)

## Hooks

The extension registers at 5 spec-kit lifecycle points:

| Hook | Trigger | Effect |
|------|---------|--------|
| `before_tasks` | Before task generation | Injects phase-level context if orchestrator is active |
| `after_tasks` | After task generation | Triggers roadmap generation from task phases |
| `before_implement` | Before implementation | Injects phase scope enforcement |
| `after_implement` | After implementation | Triggers phase summary and state advancement |
| `before_commit` | Before git commit | Runs tier-1 static verification to block commits with unmet must-haves |

All hooks are optional — the extension adds zero overhead when not actively orchestrating.

## Agent Compatibility

Designed and validated with **Claude Code**. The architecture avoids agent-specific code paths — all instructions are agent-neutral markdown, all scripts are POSIX-compatible — so compatibility with other agents is expected but not yet validated.

## Testing

7 test suites with 334 assertions:

```bash
bash tests/test-s01-structure.sh         # Structural validation (20 assertions)
bash tests/test-s02-state-machine.sh     # State machine derivation (28 assertions)
bash tests/test-s03-design-artifacts.sh  # Design artifacts (60 assertions)
bash tests/test-s04-core-commands.sh     # Core commands (70 assertions)
bash tests/test-s05-autonomous-mode.sh   # Autonomous mode (71 assertions)
bash tests/test-s06-knowledge-lifecycle.sh  # Knowledge lifecycle (57 assertions)
bash tests/test-s07-integration.sh       # Cross-slice integration (28 assertions)
```

## Governing Principles

1. **Context Minimization** — Every decision optimizes for minimizing context each task consumes
2. **Evidence Before Claims** — No task is complete without fresh verification evidence
3. **Design Before Code** — Every piece of work goes through an explicit design step
4. **Plans Assume Zero Context** — Plans are written for an agent with zero codebase knowledge
5. **Fresh Context Per Unit** — Each unit of work executes in a fresh context receiving only what it needs
6. **State On Disk Is Truth** — All state is recoverable from files on disk, no exceptions
7. **Knowledge Compounds** — Every phase produces structured documentation that makes the next phase cheaper

## Extending

### Adding a new command
1. Create `commands/<name>.md` following the standard structure
2. Register in `extension.yml` under `provides.commands`
3. Add test assertions in the appropriate test file
4. Register any helper scripts in `provides.scripts`

### Adding a new state
1. Add derivation rule in `scripts/state/derive-phase.sh` (priority-ordered)
2. Add fixture directory in `tests/fixtures/state-<name>/`
3. Update `references/state-machine.md`
4. Add test assertion in `test-s02-state-machine.sh`

### Adding a new template
1. Create in `templates/` with YAML frontmatter (`schema_version`, `type`)
2. Use `{{placeholder}}` syntax for all dynamic values
3. Add assertions in `test-s03-design-artifacts.sh`

## License

MIT

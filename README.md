# spec-kit-orchestrator

A standalone autonomous multi-phase orchestrator for long-horizon software development. Runs on Claude Code, Codex CLI, or Cursor. Originally built as an extension to [spec-kit](https://github.com/github/spec-kit); standalone as of v0.9.0 (M015).

> **Current version**: 0.9.0 — standalone-cutover complete. 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 5 user guides.

## The Problem

Coding agents excel at single-context-window development: specify, clarify, plan, tasks, implement. But projects larger than one context window hit a wall — there's no coordination layer for multi-phase work spanning multiple agent sessions. Context degrades, state is lost between sessions, and knowledge doesn't compound.

## The Solution

spec-kit-orchestrator adds a file-based orchestration layer that:

1. **Decomposes** large projects into context-window-sized phases
2. **Dispatches** each phase to a fresh agent session with only the context it needs
3. **Verifies** results mechanically (no self-assessment)
4. **Compounds knowledge** — phase N+1 is cheaper than phase N

## Quick Start

### 1. Install

From a clone of the orchestrator repo (or a prebuilt skill bundle), run the installer that matches your runtime:

```bash
# Claude Code
bash packaging/install/install-claude-code.sh

# Codex CLI
bash packaging/install/install-codex.sh

# Cursor
bash packaging/install/install-cursor.sh
```

The installer registers the orchestrator skills into the active runtime and drops the script/template/reference tree into place. No files to copy by hand.

### 2. Initialize your project

```
orchestrator:init
```

`init` probes the project, detects capabilities, generates a config + a runtime-appropriate instruction file, and registers skills. Completes in ~1 second.

### 3. Evaluate scope

```
orchestrator:evaluate
```

This classifies your project into one of three tiers:

| Tier | Scope | What Happens |
|------|-------|-------------|
| **A** | Single context window | Routes to the host runtime's native single-context workflow — zero overhead |
| **B** | One SDD flow, multiple contexts | Adds structured handoff between steps |
| **C** | Multiple SDD flows | Full orchestration: state machine, autonomous dispatch, crash recovery, knowledge generation |

### 4. Plan and execute (Tier C)

```
orchestrator:discuss        # Capture architectural decisions
orchestrator:roadmap        # Decompose spec into phases
orchestrator:plan-phase     # Plan one phase with must-haves
orchestrator:auto           # Run autonomous dispatch — start it and walk away
```

### 5. Monitor and wrap up

```
orchestrator:status         # Check progress anytime (read-only, always safe)
orchestrator:consolidate    # Compress knowledge at milestone end
```

That's it. For Tier A/B projects, the orchestrator stays out of the way. For Tier C, it handles the full lifecycle.

## Workflow

```
evaluate ──▶ discuss ──▶ roadmap ──▶ plan-phase
 (scope)     (Tier C)    (phases)    (tasks)
                                        │
                                        ▼
consolidate ◀── status ◀── verify ◀── auto
 (archive)      (check)   (checks)   (execute)
```

The state machine advances automatically during `orchestrator:auto`. Use `orchestrator:status` at any point to see where things stand.

## All Commands

| Command | When to Use |
|---------|-------------|
| `orchestrator:init` | First-run setup — detects project, probes capabilities, registers skills |
| `orchestrator:evaluate` | Starting a new project — classifies scope as Tier A, B, or C |
| `orchestrator:discuss` | Before roadmap — captures architectural decisions and constraints |
| `orchestrator:roadmap` | After discussion — decomposes spec into phases with dependency graph |
| `orchestrator:plan-phase` | Before execution — plans one phase with task decomposition and must-haves |
| `orchestrator:dispatch` | Manual execution — runs one task in a fresh context with constructed payload |
| `orchestrator:auto` | Autonomous execution — loops dispatch/verify until milestone completes |
| `orchestrator:verify` | After a phase — checks must-haves mechanically (automatic in auto mode) |
| `orchestrator:status` | Anytime — shows progress, blockers, and next action (read-only) |
| `orchestrator:resume` | After a crash or pause — recovers from disk state |
| `orchestrator:consolidate` | At milestone end — compresses knowledge and archives artifacts |
| `orchestrator:doctor` | Health diagnostics — orphaned artifacts, stale knowledge, cost spikes |
| `orchestrator:migrate` | Import prior state from another workflow (GSD, spec-kit) |

## Core Capabilities

- **Scope triage** — Classify projects as Tier A/B/C based on complexity, with manual override and tier promotion
- **Phase decomposition** — Roadmap generation with dependency graphs, boundary maps, and risk-ordered scheduling
- **State machine** — 10-state lifecycle derived entirely from file presence on disk (never in-memory)
- **Autonomous dispatch** — Derive state → budget check → stuck detection → context assembly → dispatch → verify → record → advance
- **Adaptive intensity** — Quick / Standard / Full pipeline scaling auto-calibrated per task and host capability profile
- **Backend-agnostic dispatch** — Uniform interface with filename-routed adapters (Claude Code / Codex CLI / Cursor)
- **Mechanical verification** — 4-tier ladder: static checks → command execution → behavioral validation → human review
- **Crash recovery** — Lock-based detection, recovery briefing from surviving artifacts, graceful pause/resume
- **Knowledge generation** — Structured summaries, append-only decisions/knowledge registers, scope-filtered context injection
- **Consolidation** — Artifact compression (87% reduction achieved) and archival at milestone boundaries

## Architecture

```
spec-kit-orchestrator/
│
├── packaging/
│   ├── bundle/              ← installable unit (skill + scripts + templates)
│   └── install/             ← per-runtime installers (claude-code, codex, cursor)
│
├── commands/                ← agent instruction documents (13 commands)
│
├── scripts/                 ← executable helpers organized by concern
│   ├── state/               ←   derive-phase, resolve-root, read-roadmap, ...
│   ├── dispatch/            ←   build-context, dispatch-interface, adapters/, ...
│   ├── engine/              ←   run.sh pipeline, intensity-analyze, checkpoint
│   ├── verify/              ←   check-must-haves, run-commands, ...
│   ├── knowledge/           ←   write-summary, append-decision, ...
│   ├── lifecycle/           ←   scaffold, init-project, lock-manager, auto-loop, ...
│   ├── migrate/             ←   source-format adapters (GSD, spec-kit, ...)
│   └── diagnostics/         ←   run-doctor + 12 checks
│
├── templates/               ← 24+ output templates + config defaults
│
├── references/              ← 15 progressive-disclosure reference docs
│
├── docs/                    ← user guides (getting-started, recipe-authoring, ...)
│
└── tests/                   ← 7 test suites, 334+ assertions
```

All orchestrator runtime state lives at `.orchestrator/` in the active project. State is derived from file presence on disk, making every session crash-recoverable.

### State Flow

```
pre-planning → discussing → planning → executing → summarizing → validating → completing → complete
                                          ↓ (failure)
                                      replanning
```

### Config Resolution

Four layers, highest precedence first:

```
Environment vars > orchestrator-config.local > project config > defaults
```

## Installation

The canonical install flow is a single runtime-specific installer script. Each installer is idempotent and safe to re-run after an update.

```bash
bash packaging/install/install-claude-code.sh   # Claude Code
bash packaging/install/install-codex.sh         # Codex CLI
bash packaging/install/install-cursor.sh        # Cursor
```

After install, run `orchestrator:init` once per project. See [`references/installation.md`](references/installation.md) for the full reference, autonomy configuration, and update flow.

### Requirements

- **Bash 3.2+** — scripts use associative-array-free patterns for macOS default bash compatibility
- **git** — version control, optional worktree isolation
- **jq** — optional, for JSON parsing in scripts (fallback parsing available)

### Migrating from spec-kit

If you already have a spec-kit project and want to adopt the orchestrator, see [`docs/migrating-from-speckit.md`](docs/migrating-from-speckit.md). The orchestrator preserves spec-kit as a migration *source* (via `scripts/migrate/` and `scripts/dispatch/adapters/format/speckit.sh`) but is not dependent on spec-kit at runtime.

## Agent Compatibility

The orchestrator formally supports three runtimes via the `packaging/install/install-*.sh` installers:

- **Claude Code** — primary runtime; most thoroughly exercised.
- **Codex CLI** — supported via the Codex adapter + installer.
- **Cursor** — supported via the Cursor adapter + installer.

All agent instructions are runtime-neutral markdown; all scripts are POSIX-compatible Bash 3.2+.

## Testing

7 test suites with 334+ assertions:

```bash
bash tests/test-s01-structure.sh            # Structural validation
bash tests/test-s02-state-machine.sh        # State machine derivation
bash tests/test-s03-design-artifacts.sh     # Design artifacts
bash tests/test-s04-core-commands.sh        # Core commands
bash tests/test-s05-autonomous-mode.sh      # Autonomous mode
bash tests/test-s06-knowledge-lifecycle.sh  # Knowledge lifecycle
bash tests/test-s07-integration.sh          # Cross-slice integration
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
2. Ensure the command file is discovered by `packaging/install/install-<runtime>.sh` during next install, or add it to the runtime adapter's command registry
3. Add test assertions in the appropriate test file
4. Register any helper scripts under `scripts/`

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

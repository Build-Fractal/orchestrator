# spec-kit-orchestrator

A [spec-kit](https://github.com/github/spec-kit) extension that adds autonomous multi-phase orchestration to spec-kit's spec-driven development (SDD) workflow.

## The Problem

Spec-kit excels at single-context-window development: specify, clarify, plan, tasks, implement. But projects larger than one context window hit a wall — there's no coordination layer for multi-phase work spanning multiple agent sessions. Context degrades, state is lost between sessions, and knowledge doesn't compound.

## The Solution

spec-kit-orchestrator adds a file-based orchestration layer that decomposes large projects into context-window-sized units, dispatches each to a fresh agent session with only the context it needs, verifies results mechanically, and compounds knowledge across phases.

**Three execution tiers** from the same entry point:

| Tier | Scope | What Happens |
|------|-------|-------------|
| **A** | Single context window | Routes to standard spec-kit — zero overhead |
| **B** | One SDD flow, multiple contexts | Adds structured handoff between steps |
| **C** | Multiple SDD flows | Full state machine: autonomous dispatch, crash recovery, knowledge generation |

## Core Capabilities

- **Scope triage** — Classify projects as Tier A/B/C based on complexity, with manual override and tier promotion
- **Phase decomposition** — Roadmap generation with dependency graphs, boundary maps, and risk-ordered scheduling
- **State machine** — 9-state lifecycle (`pre-planning` → `discussing` → `planning` → `executing` → `summarizing` → `validating` → `completing` → `complete`, with `replanning` on failure) derived entirely from disk file presence
- **Autonomous dispatch** — Derive state → budget check → stuck detection → context assembly → dispatch → verify → record → advance. Start it and walk away.
- **Mechanical verification** — 4-tier ladder: static checks → command execution → behavioral validation → human review. No self-assessment — verification is based on file existence, content checks, and command output.
- **Crash recovery** — Lock-based detection, recovery briefing synthesized from surviving artifacts, graceful pause/resume with structured continue files
- **Knowledge generation** — Structured summaries, append-only decisions/knowledge registers, scope-filtered context injection. Phase N+1 is cheaper than phase N.
- **Consolidation** — Artifact compression (87% reduction achieved) and archival at milestone boundaries
- **Graceful degradation** — No subagents? Sequential execution. No GitHub Agentic Workflows? Local only. No APM? Manual installation.

## Architecture

```
extension.yml              ← manifest: 10 commands, 5 hooks, 23 scripts
│
├── commands/*.md          ← agent instruction documents (what to do)
│   └── references scripts/ and templates/ by path
│
├── scripts/               ← executable helpers (how to do it)
│   ├── state/             ← derive-phase, read-config, read-roadmap
│   ├── dispatch/          ← build-context, scope-filter, detect-capabilities
│   ├── verify/            ← check-must-haves, check-boundary-map, check-scope, run-commands
│   ├── knowledge/         ← write-summary, append-decision, append-knowledge, consolidate-artifacts
│   └── lifecycle/         ← scaffold, lock-manager, stuck-detector, recovery-briefing,
│                            budget-checker, rollback-phase, mark-complete
│
├── templates/*.md         ← 13 output templates with {{placeholder}} syntax
│
├── references/*.md        ← 4 progressive disclosure docs
│
│   ├── util/              ← json-field (shared JSON parsing utility)
│
└── tests/                 ← 7 test suites, 307 assertions
```

All orchestrator state lives at `.specify/orchestrator/` — separate from spec-kit's own state. State is derived from file presence on disk (never in-memory), making every session crash-recoverable.

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

## Quickstart

```
evaluate → discuss (Tier C) → roadmap → plan-phase → auto/dispatch → verify → status → consolidate
```

1. **Evaluate** — `speckit.orchestrator.evaluate` classifies your project as Tier A/B/C
2. **Discuss** (Tier C) — `speckit.orchestrator.discuss` captures architectural decisions
3. **Roadmap** — `speckit.orchestrator.roadmap` decomposes spec into phases
4. **Plan** — `speckit.orchestrator.plan-phase` plans one phase with must-haves
5. **Execute** — `speckit.orchestrator.auto` runs autonomous dispatch (or use `dispatch` for manual)
6. **Verify** — `speckit.orchestrator.verify` checks must-haves after each phase
7. **Status** — `speckit.orchestrator.status` shows progress at any point
8. **Consolidate** — `speckit.orchestrator.consolidate` compresses knowledge at milestone end

## Commands

| Command | Purpose |
|---------|---------|
| `speckit.orchestrator.evaluate` | Classify scope as Tier A, B, or C |
| `speckit.orchestrator.discuss` | Capture architectural decisions before roadmap generation |
| `speckit.orchestrator.roadmap` | Decompose spec into phases with dependency graph and boundary maps |
| `speckit.orchestrator.plan-phase` | Plan one phase — task decomposition with must-haves |
| `speckit.orchestrator.dispatch` | Execute one task in a fresh context with constructed payload |
| `speckit.orchestrator.auto` | Autonomous dispatch loop until milestone completes |
| `speckit.orchestrator.verify` | Must-haves verification for a completed phase |
| `speckit.orchestrator.status` | Progress dashboard — completion, blockers, next action |
| `speckit.orchestrator.resume` | Crash/pause recovery using disk state |
| `speckit.orchestrator.consolidate` | Knowledge compression and artifact archival |

## Installation

```bash
specify extension add speckit-orchestrator
```

Or via APM (when available):

```bash
apm install speckit-orchestrator
```

## Requirements

- spec-kit >= 0.1.0
- Bash 4+ (scripts use associative-array-free patterns for bash 3.2 compatibility)
- git (version control, worktree isolation)
- jq (optional, for JSON parsing in scripts)

## Agent Compatibility

Works with all spec-kit-supported agents:
- Claude Code
- GitHub Copilot
- Cursor
- Gemini CLI

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

## Governing Principles

The extension is built on 7 constitutional principles:

1. **Context Minimization** — Every decision optimizes for minimizing context each task consumes
2. **Evidence Before Claims** — No task is complete without fresh verification evidence
3. **Design Before Code** — Every piece of work goes through an explicit design step
4. **Plans Assume Zero Context** — Plans are written for an agent with zero codebase knowledge
5. **Fresh Context Per Unit** — Each unit of work executes in a fresh context receiving only what it needs
6. **State On Disk Is Truth** — All state is recoverable from files on disk, no exceptions
7. **Knowledge Compounds** — Every phase produces structured documentation that makes the next phase cheaper

See [`.specify/memory/constitution.md`](.specify/memory/constitution.md) for full definitions.

## Testing

7 test suites with 307 assertions:

```bash
# Run all tests
bash tests/test-s01-structure.sh      # Structural validation (20 assertions)
bash tests/test-s02-state-machine.sh  # State machine derivation (26 assertions)
bash tests/test-s03-design-artifacts.sh  # Design artifacts (60 assertions)
bash tests/test-s04-core-commands.sh  # Core commands (57 assertions)
bash tests/test-s05-autonomous-mode.sh   # Autonomous mode (65 assertions)
bash tests/test-s06-knowledge-lifecycle.sh  # Knowledge lifecycle (57 assertions)
bash tests/test-s07-integration.sh    # Cross-slice integration (22 assertions)
```

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

## Roadmap

- **M002 candidates**: GitHub Agentic Workflows integration (US7), APM packaging and distribution (US8), user-facing documentation (`docs/getting-started.md`, `docs/configuration.md`)

## License

MIT

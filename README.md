# spec-kit-orchestrator

**A coordination layer for software work that's too big for a single agent session.**

Coding agents are excellent inside one context window. They struggle when work spans many — context degrades, state gets lost between sessions, and yesterday's reasoning has to be re-derived from scratch. spec-kit-orchestrator is the layer underneath that handles the part you don't want to: phase decomposition, fresh-context dispatch, mechanical verification, knowledge that compounds milestone over milestone.

Runs on Claude Code today. Codex CLI and Cursor adapters exist but are demand-driven — we'll land formal multi-runtime parity (M009) when the first non-Claude-Code user arrives.

> **v0.9.3** (2026-05-01) — Closed milestones M011–M016, M018–M021, M024–M033, M036a. Live in production against this repo's own development; see [CHANGELOG.md](./CHANGELOG.md) for full history.

## When you'd reach for this

- The feature is too large for one agent session and you've felt the pain of paste-the-summary-into-the-next-conversation handoffs.
- You want autonomous execution you can actually walk away from — not a chat loop that needs your attention.
- You care about verification that doesn't rely on the agent grading its own homework.
- The project will outlive any single conversation and the knowledge needs to accrete.

## When you wouldn't

- The work fits in one context window. The orchestrator detects this (Tier A) and steps aside automatically — no overhead, no friction. Just keep using your runtime's native flow.
- You want a chat companion. The orchestrator is a coordination layer, not a conversational partner. It does the boring scaffolding so the conversational parts get more signal.

## How it works

1. **Decompose** large projects into context-window-sized phases with explicit dependencies.
2. **Dispatch** each phase to a fresh agent session carrying only the context it needs — no scrollback to pollute.
3. **Verify** results mechanically (4-tier ladder: file checks → command execution → behavioral review → human review). No self-assessment.
4. **Compound knowledge** — every phase produces structured summaries that make the next phase cheaper.

All state lives on disk under `.orchestrator/`. There is no database, no long-running process, nothing to lose if your machine reboots mid-session.

## Quick Start

### 1. Install

From a clone of the orchestrator repo (or a prebuilt skill bundle), pick the installer for your runtime:

```bash
bash packaging/install/install-claude-code.sh   # Claude Code (primary)
bash packaging/install/install-codex.sh         # Codex CLI
bash packaging/install/install-cursor.sh        # Cursor
```

The installer registers the orchestrator skills with your runtime and stages the script tree into your project. Idempotent and safe to re-run.

> Coming in M035 (the launch milestone): `npm`, `brew`, and `curl | bash` install paths.

### 2. Start your project

```
/orchestrator-start
```

`start` is the warm front door. It auto-detects which of four shapes you're in and routes you to the right onboarding flow:

| You have… | `start` routes to… | What happens |
|---|---|---|
| Empty directory | **Ideation** | A 7-question grilling protocol that captures vision, scope, users, constraints |
| Materials (briefs, PDFs, decision logs) | **Materials intake** | Reconciles your inputs across 4 SSOT blocks; surfaces drift; asks only to resolve conflicts |
| An existing codebase | **Codebase ingestion** | Deterministic structural extraction → 5–15 seed knowledge entries. No 50-question interrogation. |
| spec-kit / GSD state | **Migration** | Lifts your existing artifacts in, then ingests the codebase |

All four paths converge on constitution authoring (3 stack starters: web-saas / cli-tool / library) and a CLAUDE.md custom block.

### 3. Build something

For most work, `/orchestrator-do "your task here"` is enough — it classifies the request and routes to the right depth automatically. For larger features:

```
/orchestrator-evaluate       # Classify scope as Tier A, B, or C
/orchestrator-discuss        # (Tier C) Capture architectural decisions
/orchestrator-roadmap        # (Tier C) Decompose spec into phases
/orchestrator-plan-phase     # Plan one phase with must-haves
/orchestrator-auto           # Run autonomous dispatch — start it and walk away
```

### 4. Check in or recover

```
/orchestrator-status         # Read-only progress check, always safe
/orchestrator-where          # Tree view of milestone → phase → task hierarchy
/orchestrator-resume         # After a crash or pause — picks up exactly where it left off
/orchestrator-consolidate    # Compress knowledge at milestone end
```

That's the loop. For Tier A/B projects, the orchestrator stays out of the way. For Tier C, it handles the full lifecycle without you needing to babysit it.

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
| `orchestrator:start` | Recommended first command — warm front door that auto-detects project shape and routes onboarding |
| `orchestrator:do` | One-shot tasks — classifies the request and routes to the right depth automatically |
| `orchestrator:init` | Lower-level scaffold — registers skills and writes config; called by `start` under the hood |
| `orchestrator:evaluate` | Starting a new project manually — classifies scope as Tier A, B, or C |
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

What the orchestrator gives you, in concrete terms:

- **Right-sized work**, automatically. Tier A projects (single context) get out of your way. Tier B/C projects get progressively more scaffolding without you having to choose.
- **Autonomous execution.** `orchestrator:auto` acquires a session lock and loops through dispatch → verify → record → advance until a milestone completes, a real blocker is hit, or you ask it to pause.
- **Mechanical verification, not vibes.** Every task and phase passes through a 4-tier ladder: file checks (truths and artifacts), configured commands (your tests, your linters), behavioral review, and optional human gates. Failures stop the loop honestly rather than getting hand-waved.
- **State that survives anything.** All state derives from files on disk. Crash mid-task and `orchestrator:resume` picks up exactly where it left off — no in-memory state to lose.
- **Knowledge that accumulates.** Every phase emits structured summaries, every decision goes into an append-only register, and the next phase's context is filtered to just what's relevant. Phase N+1 is genuinely cheaper than phase N.
- **Adaptive intensity.** Quick / Standard / Full pipelines auto-calibrate per task and host capability — small work doesn't pay big-work overhead.
- **Runtime-flexible.** Backend-agnostic dispatch with filename-routed adapters; Claude Code is the primary runtime, Codex CLI and Cursor adapters exist for when demand arrives.

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

After install, run `/orchestrator-start` from inside your project — that's the recommended entry. It calls `orchestrator:init` for you and routes you through the right onboarding flow. See [`references/installation.md`](references/installation.md) for the full reference, autonomy configuration, and update flow.

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

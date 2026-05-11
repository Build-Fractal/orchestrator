# orchestrator

**Every coding task — small or large — runs against a project-aware knowledge base, fresh-context dispatch, and mechanical verification.**

Most coding agents start each task from zero: no memory of yesterday's decisions, no map of your conventions, no thread to last week's architecture call. orchestrator changes that. Once your project is onboarded — about a minute for any existing codebase — every task you run, from a one-line typo fix to a multi-month rewrite, executes against a knowledge graph of your decisions, patterns, and prior work.

> **v0.9.3** — production. Live in development against this repo's own work; see [CHANGELOG.md](./CHANGELOG.md) for milestone history. Built on Claude Code (primary). Codex CLI and Cursor adapters exist; formal multi-runtime parity (M009) lands when the first non-Claude-Code user arrives.

---

## Why use it

- **Small tasks get sharper.** `/orchestrator-do "rename X to Y across the auth flow"` injects the relevant memories — decisions, conventions, prior context — before dispatch. The agent already knows your patterns.
- **Large projects get tractable.** Multi-week features decompose into context-window-sized phases with explicit dependencies. Autonomous execution loops `dispatch → verify → record → advance` until done. You walk away.
- **Verification is mechanical, not vibes.** Every task and phase passes a 4-tier ladder: file checks → command execution → behavioral review → human review. No self-graded pass/fail.
- **State survives anything.** Everything lives on disk under `.orchestrator/`. Crash mid-execution, kill the terminal, reboot — `/orchestrator-resume` picks up exactly where it left off.
- **Knowledge compounds.** Every phase emits structured summaries; every decision goes into an append-only register. Phase N+1 is genuinely cheaper than phase N.

---

## Install

**Once the launch tag publishes** (any of these one-liners, run from your project directory):

```bash
# npm
cd /path/to/your-project && npm install -g @build-fractal/orchestrator

# Homebrew
brew install build-fractal/tap/orchestrator

# curl
curl -fsSL https://orchestrator.build-fractal.dev/install.sh | bash
```

Each path auto-detects your project, registers the `orchestrator:*` skills with your runtime, and stages the runtime tree (`scripts/`, `templates/`, `references/`) into your project. Idempotent — re-run any time to update.

**Today (pre-launch — clone path):**

```bash
git clone git@github.com:Build-Fractal/orchestrator.git
cd orchestrator
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project
```

> Other runtimes: `install-codex.sh` and `install-cursor.sh` exist with the same flag shape.

**Requirements:** Bash 3.2+ (macOS default), git, jq (optional — JSON parsing fallback exists).

---

## Quick start

```bash
cd /path/to/your-project

# 1. Onboard your project (one-time, ~30 seconds for empty / ~1–5 minutes for existing codebase)
/orchestrator-start

# 2. Use it for any task
/orchestrator-do "fix the broken redirect after sign-up"
/orchestrator-do "add OAuth via Clerk and migrate existing sessions"
```

That's the whole loop for most tasks. `start` auto-detects which of four shapes your project is in and routes onboarding accordingly:

| You have… | `start` routes to… | What happens |
|---|---|---|
| Empty directory | **Ideation** | A 7-question grilling protocol captures vision, scope, users, constraints |
| Materials (briefs, PDFs, decision logs) | **Materials intake** | Reconciles inputs across 4 SSOT blocks; surfaces drift; asks only to resolve conflicts |
| Existing codebase | **Codebase ingestion** | Deterministic structural extraction → 5–15 seed knowledge entries. No 50-question interrogation. |
| spec-kit / GSD state | **Migration** | Lifts existing artifacts in, then ingests the codebase |

`/orchestrator-do` then classifies any task you give it and routes to the right depth — fast-path knowledge-injected dispatch for small tasks, the full plan-and-execute chain for larger features.

---

## What you can do

| If you have… | Type… | What happens |
|---|---|---|
| A one-line tweak | `/orchestrator-do "..."` | Knowledge-injected dispatch in seconds |
| A medium feature on an existing codebase | `/orchestrator-do "..."` | Auto-routed through plan → build chain with knowledge inject |
| A new feature spec | `/orchestrator-evaluate` | Classifies scope, writes evaluation, suggests next step |
| A multi-month project | `/orchestrator-start` then `/orchestrator-auto` | Full lifecycle: phases, dispatch, verify, summarize, advance — autonomous |
| Migration from spec-kit / GSD | `/orchestrator-start` | Auto-detects, lifts existing artifacts, then ingests the codebase |

---

## Commands

| Command | When to use |
|---|---|
| `/orchestrator-start` | First time in any project — warm front door, auto-routes onboarding |
| `/orchestrator-do "..."` | Any task — auto-classifies scope and dispatches with knowledge inject |
| `/orchestrator-status` | Anytime — read-only progress check |
| `/orchestrator-where` | Visual tree — milestone → phase → task hierarchy |
| `/orchestrator-resume` | After crash or pause — picks up exactly where it left off |
| `/orchestrator-evaluate` | Manual scope classification (Tier A/B/C) |
| `/orchestrator-discuss` | Capture architectural decisions before roadmap (Tier C) |
| `/orchestrator-roadmap` | Decompose spec into phases with dependency graph |
| `/orchestrator-plan-phase` | Generate detailed task plan for one phase |
| `/orchestrator-dispatch` | Manual dispatch of a single task |
| `/orchestrator-auto` | Autonomous loop — dispatch → verify → record → advance |
| `/orchestrator-verify` | Re-run mechanical verification on a phase |
| `/orchestrator-consolidate` | Compress knowledge at milestone end |
| `/orchestrator-doctor` | Health check — orphans, drift, cost spikes |
| `/orchestrator-migrate` | Import prior state from GSD / spec-kit |
| `/orchestrator-ingest-codebase` | Re-seed knowledge from current code state |

For larger features, the explicit chain is `evaluate → discuss → roadmap → plan-phase → auto → verify → consolidate`. `/orchestrator-do` runs the appropriate subset automatically based on task scope.

---

## How it works

1. **Onboard once.** `/orchestrator-start` detects your project shape and seeds the knowledge graph (5–15 MEMs from existing code; ideation flow for greenfield).
2. **Knowledge inject on every task.** `/orchestrator-do` and `/orchestrator-dispatch` pull relevant MEMs — decisions, conventions, related summaries — into the dispatched context. The agent isn't starting from zero.
3. **Fresh context per dispatch.** Each task runs in a clean session carrying only what it needs. No scrollback to pollute the next decision.
4. **Mechanical verification.** A 4-tier ladder runs after every task and phase: file checks → configured commands → behavioral review → optional human gates. Failures stop the loop honestly.
5. **State on disk.** Everything under `.orchestrator/` — no in-memory state, no database, no daemon. Survives crashes, machine reboots, context resets.

```
your-project/
├── .orchestrator/                 ← all state lives here
│   ├── config.yml
│   ├── KNOWLEDGE.md              ← knowledge graph index
│   ├── DECISIONS.md              ← append-only decision register
│   ├── execution-log.jsonl
│   └── milestones/               ← per-milestone artifacts
│
├── commands/  scripts/  templates/  references/   ← orchestrator runtime, staged into your project
└── (your code, unchanged)
```

---

## Documentation

- **[Getting Started](docs/getting-started.md)** — your first 30 minutes, end-to-end
- [Knowledge Management](docs/knowledge-management.md) — how the knowledge graph compounds
- [Migrating from spec-kit](docs/migrating-from-speckit.md) — onboard an existing spec-kit project
- [Recipe Authoring](docs/recipe-authoring.md) — customize context-injection per dispatch
- [Hook Development](docs/hook-development.md) — wire custom quality gates
- [Architecture](references/architecture.md) · [Engine](references/engine.md) · [State Machine](references/state-machine.md) · [Verification Ladder](references/verification-ladder.md) · [File Formats](references/file-formats.md) · [Installation](references/installation.md)

---

## Principles

The orchestrator is governed by 7 principles in `.orchestrator/memory/constitution.md`:

1. **Context Minimization** — every decision optimizes for tokens-per-task
2. **Evidence Before Claims** — no completion without fresh verification
3. **Design Before Code** — explicit design step before implementation
4. **Plans Assume Zero Context** — written for an agent with zero prior knowledge
5. **Fresh Context Per Unit** — each dispatch gets a clean session
6. **State On Disk Is Truth** — all state recoverable from files
7. **Knowledge Compounds** — every phase emits structured docs that make the next phase cheaper

---

## Status

Closed milestones (selected highlights): M011 spec management · M013 GitHub native integration · M020 knowledge layer maturation · M024 universal intake & routing · M030 adaptive model selection · M031 right-sized entry · M032 wiki distribution · M033 project onboarding experience · M035 packaging & distribution · M036a reference-corpus ingest · M037 wiki team-feedback-ready.

Full milestone history in [`.orchestrator/milestone-summary.md`](./.orchestrator/milestone-summary.md). Engineering changelog in [`CHANGELOG.md`](./CHANGELOG.md).

## License

MIT

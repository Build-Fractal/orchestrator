# Orchestrator

**Every coding task — small or large — runs against a project-aware knowledge base, fresh-context dispatch, and mechanical verification.**

Most coding agents start each task from zero: no memory of yesterday's decisions, no map of your conventions, no thread to last week's architecture call. Orchestrator changes that. Once your project is onboarded — about a minute for any existing codebase — every task you run, from a one-line typo fix to a multi-month rewrite, executes against a knowledge graph of your decisions, patterns, and prior work.

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

The five commands you'll use most:

| Command | When to use |
|---|---|
| `/orchestrator-start` | First time in any project — warm front door, auto-routes onboarding |
| `/orchestrator-do "..."` | Any task — auto-classifies scope and dispatches with knowledge inject |
| `/orchestrator-auto` | Autonomous loop — dispatch → verify → record → advance |
| `/orchestrator-status` | Anytime — read-only progress check |
| `/orchestrator-resume` | After crash or pause — picks up exactly where it left off |

For larger features, the explicit chain is `evaluate → discuss → roadmap → plan-phase → auto → verify → consolidate`. `/orchestrator-do` runs the appropriate subset automatically based on task scope.

### Full command reference

**Onboarding & entry** — `start` (front door) · `init` (lower-level scaffold) · `do "..."` (universal task entry) · `evaluate` (manual scope classification)

**Project intake** (called by `start`; available standalone) — `ideation` (greenfield grilling) · `materials-intake` (reconcile briefs / PDFs / decision logs) · `ingest-codebase` (seed knowledge from existing code) · `migrate` (import from GSD / spec-kit) · `constitution` (author project constitution)

**Planning** — `specify` (author feature spec) · `discuss` (capture architectural decisions) · `roadmap` (decompose spec into phases) · `plan-phase` (task decomposition with must-haves)

**Execution** — `dispatch` (manual single task) · `auto` (autonomous loop) · `verify` (re-run mechanical 4-tier verification)

**Knowledge layer** — `extract` (PDF / DOCX / XLSX / Markdown → reference corpus) · `ingest` (chunk a spec into knowledge entries) · `ingest-reference` (reference corpus → knowledge graph) · `consolidate` (compress and archive at milestone end) · `zoom-out` (one-layer-up code map)

**Wiki** — `wiki-init` (mkdocs scaffold + optional GitHub Pages deploy + Giscus comments)

**GitHub integration** — `github-init` (project state → Issues / Milestones / Projects v2) · `github-sync` (reconcile state with GitHub) · `github-status` (sidecar state report) · `comments` (GitHub comments → workflow classifier with human-gated apply)

**Operations** — `status` · `where` (visual milestone → phase → task tree) · `context` (runtime profile) · `resume` (crash recovery) · `doctor` (health diagnostics) · `cost` (predictive + retrospective cost) · `diagnose` (systematic debugging loop) · `update` (refresh runtime)

**Advanced** — `conversus-gate` (multi-agent adversarial deliberation gate) · `customblock-draft` (CLAUDE.md custom block authoring)

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
├── commands/  scripts/  templates/  references/   ← Orchestrator runtime, staged into your project
└── (your code, unchanged)
```

---

## Built-in capabilities

Beyond the core dispatch-and-verify loop, Orchestrator ships with a set of capabilities that turn it into more than just a task runner:

- **Wiki publishing** — `/orchestrator-wiki-init` scaffolds an mkdocs-based wiki that surfaces your project's milestones, phases, decisions, and knowledge entries as a browsable, team-shareable site. Optional one-flag GitHub Pages deploy (`--deploy`) and Giscus comments (`--with-giscus`). Recently polished in M037 for non-author readers — the wiki is the team-facing view of the knowledge graph.
- **GitHub native integration** — `/orchestrator-github-init` projects orchestrator state onto GitHub Issues, Milestones, and Projects v2 with marker-bearing bodies. `/orchestrator-comments` classifies inbound issue/PR comments into workflow actions (spec amendments, scope changes, etc.) with a human-gated apply step. Opt-in and reversible — delete `.orchestrator/integrations/github.json` to return to GitHub-free behavior.
- **Reference corpus ingest** — `/orchestrator-extract` and `/orchestrator-ingest-reference` turn PDFs, Word docs, Excel sheets, and Markdown reference materials (regulatory specs, training docs, glossaries) into queryable knowledge-graph chunks. Three-tier extraction: deterministic shell adapters (fast, free) for plain text, LLM-driven structured Markdown (high-fidelity, conversus fidelity-gated) for complex layouts.
- **Cost observability** — `/orchestrator-cost` gives both predictive per-tier estimates (Quick / Standard / Full) before you dispatch and retrospective rollups from the JSONL execution log after. Bash-only, zero LLM tokens — the cost view itself is free.
- **Adaptive model routing** — Orchestrator auto-routes between Quick / Standard / Full pipelines per task and host capability. Small work doesn't pay big-work overhead; large work doesn't get under-resourced. Shadow-mode default with a programmatic flip-gate when the shadow corpus reaches the configured confidence threshold.
- **Multi-agent deliberation** (Conversus integration) — `/orchestrator-conversus-gate` runs adversarial review of high-stakes artifacts in cooperative, winner-take-all, red-blue, or prisoner's-dilemma modes. Used internally for spec fidelity gates; available for any artifact you want pressure-tested before committing to it.
- **Diagnostic doctor** — `/orchestrator-doctor` runs 12+ checks: orphaned artifacts, stale knowledge, scope drift, cost spikes, permissions drift, plan-shape audits, constitution consistency. Each check emits structured `DOCTOR:<NAME> status=ok|warn|fail` lines for both human and machine consumers.
- **Crash recovery built-in** — Every state derives from disk; nothing in memory. Kill the process, reboot, lose your terminal — `/orchestrator-resume` reads disk state and picks up at the exact next undone step.

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

Orchestrator is governed by 7 principles in `.orchestrator/memory/constitution.md`:

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

# Orchestrator

**Every coding task — small or large — runs against a project-aware knowledge base, fresh-context dispatch, and mechanical verification.**

Most coding agents start each task from zero: no memory of yesterday's decisions, no map of your conventions, no thread to last week's architecture call. Orchestrator changes that. Once your project is onboarded — about a minute for any existing codebase — every task you run, from a one-line typo fix to a multi-month rewrite, executes against a knowledge graph of your decisions, patterns, and prior work.

> **v0.9.3** — in production use, dogfooded daily on its own development. Built on Claude Code (primary); Codex CLI and Cursor adapters exist (formal multi-runtime parity is a post-launch fast-follow). See [CHANGELOG.md](./CHANGELOG.md) for version history.

---

## Why use it

- **Small tasks get sharper.** `/orchestrator-do "rename X to Y across the auth flow"` injects the relevant memories — decisions, conventions, prior context — before dispatch. The agent already knows your patterns.
- **Large projects get tractable.** Multi-week features decompose into context-window-sized phases with explicit dependencies. Autonomous execution loops `dispatch → verify → record → advance` until done. You walk away.
- **Verification is mechanical, not vibes.** Every task and phase passes a 4-tier ladder: file checks → command execution → behavioral review → human review. No self-graded pass/fail.
- **State survives anything.** Everything lives on disk under `.orchestrator/`. Crash mid-execution, kill the terminal, reboot — `/orchestrator-resume` picks up exactly where it left off.
- **Knowledge compounds.** Every phase emits structured summaries; every decision goes into an append-only register. The next phase is genuinely cheaper than the last.

---

## When this isn't a fit

The orchestrator earns its overhead when work has structure to capture and continuity to preserve. Some shapes it's the wrong tool for:

- **Exploratory spike work where the product shape isn't known yet.** The orchestrator wants you to author a spec (or have one inferred); that's friction when you're still figuring out what you're building. **Reach for** your runtime's native flow first — `claude` / `cursor` / `codex` directly — and come back once the shape is clear.
- **Single-session work that fits in your head.** If a task is going to live in one context window and never resurface, the on-disk state-of-truth discipline is overhead without payoff. **Reach for** a one-shot dispatch in your runtime; bring the orchestrator in when the work crosses sessions or hands off between people.
- **Sandboxed or ephemeral environments.** The orchestrator's *State on Disk is Truth* invariant assumes a persistent project tree with `.orchestrator/`. Notebooks, CI-only runs, web-IDE scratchpads — anywhere files don't persist — break the model. **Reach for** an in-context flow until you have a real working tree.
- **Pure greenfield ideation without users.** `/orchestrator-ideation` helps structure thinking, but it isn't a substitute for talking to people who'd use what you're building. **Reach for** real user conversation first; bring the orchestrator in when the problem is sharp enough to spec.

These aren't permanent disqualifiers — they're "wrong-time, not wrong-tool" cases. When the work crosses into "multi-session continuity matters" or "I'd lose context if I closed this terminal," the orchestrator becomes the right fit.

---

## Pick your path

Find the row that matches what you brought. Each path assumes you've [installed](#install) and are sitting in your project directory.

| You have… | Run this | Time | What you get |
|---|---|---|---|
| **A one-line task** on any project | `/orchestrator-do "fix the broken redirect after sign-up"` | seconds | Knowledge-injected dispatch; no ceremony |
| **An existing codebase** (any size) | `/orchestrator-start` → routes to **codebase ingestion** | 1–5 min | 5–15 seed knowledge entries from deterministic structural extraction |
| **A greenfield project, nothing written yet** | `/orchestrator-start` → routes to **ideation** | 5–10 min | 7-question grilling protocol → vision, scope, users, constraints |
| **A greenfield project + materials** (briefs, PDFs, decision logs) | `/orchestrator-start` → routes to **materials intake** | 5–15 min | Reconciled SSOT across 4 blocks; only asked about real conflicts |
| **An existing spec-kit or GSD project** | `/orchestrator-start` → routes to **migration** | 2–5 min | Existing artifacts lifted in, codebase ingested |
| **A multi-month feature** to ship autonomously | `/orchestrator-start` then `/orchestrator-auto` | hours–days | Full lifecycle: roadmap → phases → dispatch → verify → advance, untouched |
| **Reference docs to add** (regs, glossaries, training PDFs) | `/orchestrator-extract` then `/orchestrator-ingest-reference` | varies | Tier-0/1/2 extraction into the knowledge graph; dispatched tasks cite the chunks |
| **A team that needs visibility** | `/orchestrator-wiki-init` (optionally `--deploy --with-giscus`) | 2 min | mkdocs site of milestones, phases, decisions, knowledge — GitHub Pages + commentable |
| **GitHub Issues / Projects as your tracker** | `/orchestrator-github-init` | 2 min | Orchestrator state projected to Issues / Milestones / Projects v2; opt-in, reversible |

Paths compose. A typical large-project setup: install → `/orchestrator-start` (codebase ingestion) → `/orchestrator-ingest-reference` (regulatory corpus) → `/orchestrator-wiki-init --deploy` (team view) → `/orchestrator-do` and `/orchestrator-auto` from then on.

---

## Install

**Today (clone path):**

```bash
git clone git@github.com:Build-Fractal/orchestrator.git
cd orchestrator
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project
```

> Other runtimes: `install-codex.sh` and `install-cursor.sh` exist with the same flag shape.

**Requirements:** Bash 3.2+ (macOS default), git, jq (optional — JSON parsing fallback exists).

The installer registers `orchestrator:*` skills with your runtime and stages the runtime tree (`scripts/`, `templates/`, `references/`) into your project. Idempotent — re-run any time to update.

> **Coming with M035 (launch):** one-liner install via npm, Homebrew, or `curl | bash`. Tracking in [`CHANGELOG.md`](./CHANGELOG.md).

---

## Your first command

```bash
cd /path/to/your-project

# 1. Onboard (one-time)
/orchestrator-start

# 2. Use it for any task
/orchestrator-do "fix the broken redirect after sign-up"
```

That's the whole loop. `start` runs the right onboarding flow for your project shape ([see Pick your path](#pick-your-path)). `do` then classifies any task you give it and routes to the right depth — fast-path knowledge-injected dispatch for small tasks, the full plan-and-execute chain for larger features.

### What a small task looks like

```
$ /orchestrator-do "fix the broken redirect after sign-up"

[classifier] tier=A scope=bugfix confidence=0.91
[knowledge-inject] 3 MEMs (auth/sign-up-flow, auth/redirects, conv/error-handling)
[dispatch] tier-A degenerate path · ~280 tokens of context
[execute] edits: src/app/(auth)/sign-up/page.tsx · tests: passing
[verify] tier-1 file checks ✓  tier-2 commands (npm test, npm run lint) ✓
[record] execution-log.jsonl appended · 1 task closed
```

The agent receives only what it needs — three relevant knowledge entries, not the whole codebase summary. Verification runs mechanically before the task counts as done.

---

## Verify your install

After `/orchestrator-start` completes, confirm the runtime is wired correctly:

```bash
/orchestrator-status   # one-screen progress + next-action report
/orchestrator-context  # runtime profile (resolved root, capabilities, active milestone)
/orchestrator-doctor   # 12+ health checks (orphans, drift, cost spikes, consistency)
```

All three are read-only and always safe to run. If any of them flag an issue, the output names the exact file to inspect.

---

## Five-command cheat sheet

| Command | When to use |
|---|---|
| `/orchestrator-start` | First time in any project — warm front door, auto-routes onboarding |
| `/orchestrator-do "..."` | Any task — auto-classifies scope and dispatches with knowledge inject |
| `/orchestrator-auto` | Autonomous loop — dispatch → verify → record → advance |
| `/orchestrator-status` | Anytime — read-only progress check |
| `/orchestrator-resume` | After crash or pause — picks up exactly where it left off |

For larger features the explicit chain is `evaluate → discuss → roadmap → plan-phase → auto → verify → consolidate`. `/orchestrator-do` runs the appropriate subset automatically based on task scope.

---

## How it works

> For the origin story — how the orchestrator went from a spec-kit extension to a standalone project, and what prior failures the constitution codifies — see [Why this exists](docs/why-this-exists.md).

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

Each of these maps to a journey row in [Pick your path](#pick-your-path) — they aren't optional add-ons, they're first-class surfaces.

- **Wiki publishing** — `/orchestrator-wiki-init` scaffolds an mkdocs wiki that surfaces milestones, phases, decisions, and knowledge entries as a team-shareable site. One-flag GitHub Pages deploy (`--deploy`) and Giscus comments (`--with-giscus`). Polished in M037 for non-author readers.
- **GitHub native integration** — `/orchestrator-github-init` projects orchestrator state onto GitHub Issues, Milestones, and Projects v2 with marker-bearing bodies. `/orchestrator-comments` classifies inbound comments into workflow actions with a human-gated apply step. Opt-in and reversible — delete `.orchestrator/integrations/github.json` to return to GitHub-free behavior.
- **Reference corpus ingest** — `/orchestrator-extract` and `/orchestrator-ingest-reference` turn PDFs, Word docs, Excel sheets, and Markdown reference materials (regulatory specs, training docs, glossaries) into queryable knowledge-graph chunks. Three-tier extraction: Tier 0 manifest + binary preservation, Tier 1 deterministic shell adapters (fast, free), Tier 2 LLM-driven structured Markdown under a conversus fidelity gate.
- **Materials intake** — `/orchestrator-materials-intake` reconciles heterogeneous inputs (Product Brief, Decision Register, MVP Plan, Handoff JSON) into a single pre-spec, surfacing drift and asking only about real conflicts.
- **Cost observability** — `/orchestrator-cost` gives both predictive per-tier estimates (Quick / Standard / Full) before dispatch and retrospective rollups from the JSONL execution log after. Bash-only, zero LLM tokens — the cost view itself is free.
- **Adaptive model routing** — Orchestrator auto-routes between Quick / Standard / Full pipelines per task and host capability. Small work doesn't pay big-work overhead; large work doesn't get under-resourced. Shadow-mode default with a programmatic flip-gate when the shadow corpus reaches the configured confidence threshold.
- **Multi-agent deliberation** (Conversus integration) — `/orchestrator-conversus-gate` runs adversarial review of high-stakes artifacts in cooperative, winner-take-all, red-blue, or prisoner's-dilemma modes. Used internally for spec fidelity gates; available for any artifact you want pressure-tested.
- **Diagnostic doctor** — `/orchestrator-doctor` runs 12+ checks: orphaned artifacts, stale knowledge, scope drift, cost spikes, permissions drift, plan-shape audits, constitution consistency. Emits structured `DOCTOR:<NAME> status=ok|warn|fail` lines for human and machine consumers.
- **Crash recovery built-in** — Every state derives from disk; nothing in memory. Kill the process, reboot, lose your terminal — `/orchestrator-resume` reads disk state and picks up at the exact next undone step.

---

## Full command reference

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

## Documentation

**Start here**
- **[Getting Started](docs/getting-started.md)** — your first 30 minutes, end-to-end
- [Migrating from spec-kit](docs/migrating-from-speckit.md) — onboard an existing spec-kit project

**Concepts**
- [Knowledge Management](docs/knowledge-management.md) — how the knowledge graph compounds
- [Recipe Authoring](docs/recipe-authoring.md) — customize context-injection per dispatch
- [Hook Development](docs/hook-development.md) — wire custom quality gates

**Reference**
- [Architecture](references/architecture.md) · [Engine](references/engine.md) · [State Machine](references/state-machine.md)
- [Verification Ladder](references/verification-ladder.md) · [File Formats](references/file-formats.md) · [Installation](references/installation.md)

---

## Principles

Orchestrator is governed by 7 principles in [`.orchestrator/memory/constitution.md`](./.orchestrator/memory/constitution.md):

1. **Context Minimization** — every decision optimizes for tokens-per-task
2. **Evidence Before Claims** — no completion without fresh verification
3. **Design Before Code** — explicit design step before implementation
4. **Plans Assume Zero Context** — written for an agent with zero prior knowledge
5. **Fresh Context Per Unit** — each dispatch gets a clean session
6. **State On Disk Is Truth** — all state recoverable from files
7. **Knowledge Compounds** — every phase emits structured docs that make the next phase cheaper

---

## Status

In production use against this repo's own development. 30+ closed milestones spanning spec management, GitHub integration, knowledge layer, autonomous hardening, adaptive model routing, reference-corpus ingest, wiki distribution, and onboarding experience. Full milestone history in [`.orchestrator/milestone-summary.md`](./.orchestrator/milestone-summary.md). Engineering changelog in [`CHANGELOG.md`](./CHANGELOG.md).

## License

MIT

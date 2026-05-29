# Getting Started

**From `git clone` to your first verified task in about 10 minutes.** Install the orchestrator into your project, onboard with one warm conversational command, then dispatch a real task that runs against your project's accumulated knowledge.

## TL;DR

```bash
# 1. Get the orchestrator
git clone git@github.com:Build-Fractal/orchestrator.git && cd orchestrator

# 2. Install into your project (Claude Code)
bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project

# 3. In your project, onboard with the warm front door
/orchestrator-start

# 4. Run your first task
/orchestrator-do "your task here"
```

Steps 1–2 run from the orchestrator clone; steps 3–4 run inside your own project from Claude Code. Each step is expanded below.

> **Is this for you?** The orchestrator makes every coding task — a one-line tweak or a multi-month rewrite — execute against a project-aware knowledge base, so dispatched agents never start from zero. If you only need single-context work, plain Claude Code is the right tool first; reach for the orchestrator when tasks span multiple contexts or you want accumulated project knowledge injected automatically. See [why-this-exists](why-this-exists.md) if you want the motivation before installing.

---

## Prerequisites

| Dependency | Required? | Check command |
|------------|-----------|---------------|
| Claude Code | Yes (primary runtime) | `claude --version` |
| git | Yes | `git --version` |
| Bash >= 3.2 | Yes (macOS default) | `bash --version` |
| jq | Optional (JSON parsing in some scripts) | `jq --version` |

Codex CLI and Cursor are post-launch fast-follows (tracked under M009); Claude Code is the supported runtime at launch.

---

## Step 0: Get the orchestrator

The installer runs from a clone of the orchestrator repo. Clone it first:

```bash
git clone git@github.com:Build-Fractal/orchestrator.git
cd orchestrator
```

Everything in Step 1 runs from inside this clone. (`scripts/`, `templates/`, and `references/` are staged from here into your own project.)

---

## Step 1: Install into your project

Pick the installer for your runtime. All three share the same flags. Replace `/path/to/your-project` with your project's absolute path.

| Runtime | Command |
|---------|---------|
| Claude Code (primary) | `bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project` |
| Codex CLI | `bash packaging/install/install-codex.sh --project-dir /path/to/your-project` |
| Cursor | `bash packaging/install/install-cursor.sh --project-dir /path/to/your-project` |

Shared flags:

| Flag | Effect |
|------|--------|
| `--project-dir PATH` | Target project root (defaults to `$PWD`). |
| `--dry-run` | Print `would_write=<path>` lines, write nothing. Run this first to preview. |
| `--mode copy\|symlink` | `copy` stages a real copy of the runtime tree (default); `symlink` links it for fast dogfooding. |
| `--force` | Overwrite existing hook config and orchestrator config. |

The installer registers the `orchestrator:*` skills/commands into your runtime and stages the runtime tree into your project (commands invoke helpers via project-relative paths, so the tree must live there). Installed files are recorded in `.orchestrator/installed-files.txt` for a clean uninstall.

> A curl-pipe-bash installer is also available at `packaging/install/install.sh`. For the full reference (autonomy configuration, updating), see [Installation](../references/installation.md).

---

## Step 2: Onboard with `/orchestrator-start`

Switch to your project directory and open Claude Code. `/orchestrator-start` is the warm conversational front door: it auto-detects which of four shapes your project is in, calls `/orchestrator-init` under the hood, and routes you into the right onboarding sub-flow.

```
/orchestrator-start
```

Find your project in the table to know which flow you'll land in and what to expect on screen:

| Your project shape | Detected flow | What it does | On screen / time |
|--------------------|---------------|--------------|------------------|
| Empty dir, no code, no docs | `greenfield-empty` | 7-question grilling protocol capturing vision, scope, constraints | A short Q&A; produces a structured pre-spec (a few minutes, paced by you) |
| Has briefs/plans/specs, no code | `greenfield-with-materials` | Materials intake reconciles your docs into one spec | Summarizes what it read, asks to fill gaps (a few minutes) |
| Existing source code | `existing-codebase` | Deterministic structural extraction — no interrogation | ~1 minute; produces 5–15 seed knowledge entries |
| Carries `.gsd/`, `.gsd2/`, or spec-kit artifacts | `migrating` | Migrates sibling-tool data into orchestrator format | See [Migrating from spec-kit](migrating-from-speckit.md) |

Detection is best-effort; `start` shows you the detected shape and lets you override before proceeding, so it is never a black box. If `migrating` and `existing-codebase` both apply, `migrating` wins. See [`commands/start.md`](../commands/start.md) for the full branch-detection rules.

> Prefer the lower-level primitive? `/orchestrator-init` alone probes the project, writes `.orchestrator/config.yml` with sensible defaults plus a runtime instruction file, and finishes in ~1 second — but skips onboarding. `/orchestrator-start` is recommended for new users.

---

## Checkpoint: confirm onboarding worked

Before dispatching work, confirm the orchestrator is healthy. Run both read-only commands from your project:

```
/orchestrator-doctor
/orchestrator-status
```

A healthy result looks like:

- **`/orchestrator-doctor`** — every check line reads `DOCTOR:<CHECK> status=ok`. `warn` lines are advisory (e.g. stale knowledge); a `fail` line names the specific problem to fix before proceeding.
- **`/orchestrator-status`** — a one-screen report showing current state, milestone/phase progress, no blockers, and a recommended next action. For a freshly onboarded project it will point you at your first task.

If `.orchestrator/config.yml` exists and doctor is clean, onboarding worked. To customize verification or tiering later, edit `.orchestrator/config.yml` (full schema: [File Formats](../references/file-formats.md)). Common keys:

```yaml
verification_commands:     # run after each task and phase
  - npm test
  - npm run lint
default_tier: null         # A, B, C, or null (auto-detect)
context_verbosity: standard   # minimal | standard | full
```

---

## Step 3: Your first task

`/orchestrator-do "..."` is the universal one-shot entry point. It classifies your request and routes it to the right depth automatically — you never have to choose a tier yourself.

```
/orchestrator-do "fix the typo in the README footer"
```

A small task fast-paths immediately, emitting one line like:

```
doing: fix the typo in the README footer — knowledge: 7 MEMs / 1840 tokens
```

That line means the orchestrator assembled a Quick-profile context payload, injected the **7 relevant MEMs** (knowledge entries — decisions, conventions, prior context) totalling ~1840 tokens, and handed the dispatch to the agent. No scaffolding, no state machine.

How `/orchestrator-do` routes (you don't pick — the classifier does):

| Task size | Tier | What happens |
|-----------|------|--------------|
| Small one-shot (a tweak, a fix) | **Tier A** | Knowledge-injected single dispatch; runs in seconds. |
| Middle-sized (a self-contained feature) | **Tier A+** | Research → plan → build chain (one approval prompt). |
| Large / multi-context (full feature, spec-shaped) | **Tier B/C** | Defers to `/orchestrator-specify`; you run that in your next turn. |

This is the zero-commitment way to prove the concept: one `/orchestrator-do` line on a real task, no project-wide commitment required.

---

## Understanding what just happened

The one-shot task you just ran was almost certainly classified **Tier A** (degenerate), which doesn't pass through the orchestrator's verification ladder — it gets a lighter, standard host-runtime check. The ladder below is what larger **phase-based** work (Tier B/C) goes through. For that work the orchestrator is opinionated about verification: nothing counts as done until it passes a **mechanical 4-tier verification ladder**, and self-graded "I think that worked" never makes it past Tier 1.

| Tier | What it checks | Failure mode |
|------|----------------|--------------|
| 1 — Static | File existence, line counts, content patterns (grep) | Missing file or pattern → task blocked, higher tiers don't run |
| 2 — Commands | Your configured `verification_commands` (tests, lint, type-check) | Non-zero exit → task fails; fix code and re-run |
| 3 — Behavioral | Spec-compliance review, cross-phase integration | Output doesn't match the spec → returned for rework |
| 4 — Human | Manual review / UAT (when configured, typically milestone-level) | Reviewer rejects → not accepted |

A task or phase is marked `pass` only when all applicable tiers succeed; a lower-tier failure prevents higher tiers from running. To watch this happen during a longer run, `/orchestrator-status` and `/orchestrator-where` are read-only and always safe to call mid-execution. Full protocol: [Verification Ladder](../references/verification-ladder.md).

---

## Crash recovery

All runtime state lives on disk under `.orchestrator/` — nothing is held in memory. A realistic failure: you kick off a long autonomous run, then your terminal is killed (laptop sleeps, SSH drops, machine reboots). The session lock is left behind and the in-flight task has no summary file.

To recover, just run:

```
/orchestrator-resume
```

It reads `.orchestrator/` state, distinguishes a crash (stale lock — breaks it and synthesizes a recovery briefing) from a graceful pause (a `continue.md` handoff file), and continues from the last completed task. Completed tasks already have summary files and are never re-executed. The orchestrator picks up exactly where it stopped.

---

## Going bigger

For work too large for `/orchestrator-do`, the full per-feature command chain is `evaluate → discuss → roadmap → plan-phase → auto → verify → consolidate`. `/orchestrator-do` already runs the appropriate subset for you based on scope; you only walk the chain by hand when you want manual control of each gate. `/orchestrator-auto` runs the autonomous loop (dispatch → verify → record → advance) until the milestone completes or a blocker surfaces.

For the mechanics behind each stage, see [Architecture](../references/architecture.md), [State Machine](../references/state-machine.md), and [Tier Definitions](../references/tier-definitions.md). For the on-disk artifact contracts (`EVALUATION.md`, `ROADMAP.md`, phase/task plans, `execution-log.jsonl`), see [File Formats](../references/file-formats.md).

---

## Next

- **New here?** Read [why-this-exists](why-this-exists.md) for the motivation and where the orchestrator fits versus plain Claude Code.
- **Coming from spec-kit?** [Migrating from spec-kit](migrating-from-speckit.md) — spec-kit is a migration *source*, never a runtime dependency.
- **Want depth on knowledge inject and MEMs?** [Knowledge Management](knowledge-management.md).

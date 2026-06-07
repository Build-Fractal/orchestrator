# Getting Started

**From install to your first verified task in about 10 minutes.** Install the orchestrator, onboard your project with one warm conversational command, then dispatch a real task that runs against your project's accumulated knowledge.

## TL;DR

```bash
# 1. Install the orchestrator (pick one channel)
npm install -g @build-fractal/orchestrator
#   or:  brew install build-fractal/orchestrator/orchestrator
#   or:  curl -fsSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash

# 2. In your project, open Claude Code and onboard with the warm front door
/orchestrator-start

# 3. Run your first task
/orchestrator-do "your task here"
```

Step 1 installs the tool and registers the `/orchestrator-*` skills into Claude Code (globally, in `~/.claude`); steps 2–3 run inside your own project from Claude Code. Each step is expanded below — including the from-source path if you'd rather clone.

> **On Cursor?** One different install command (it's project-scoped), then **steps 2–3 are identical**. → [On Cursor](#on-cursor)

> **Is this for you?** The orchestrator makes every coding task — a one-line tweak or a multi-month rewrite — execute against a project-aware knowledge base, so dispatched agents never start from zero. If you only need single-context work, plain Claude Code is the right tool first; reach for the orchestrator when tasks span multiple contexts or you want accumulated project knowledge injected automatically. See [why-this-exists](why-this-exists.md) if you want the motivation before installing.

---

## Prerequisites

| Dependency | Required? | Check command |
|------------|-----------|---------------|
| **Claude Code** _or_ **Cursor** | Yes — one runtime | `claude --version` / `cursor-agent --version` |
| git | Yes | `git --version` |
| Bash >= 3.2 | Yes (macOS default) | `bash --version` |
| Node.js >= 14 | Only for the npm install channel | `node --version` |
| `cursor-agent` CLI + `CURSOR_API_KEY` | Only for autonomous dispatch on Cursor | `cursor-agent --version` |
| jq | Optional (JSON parsing in some scripts) | `jq --version` |

**Two runtimes, same workflow.** **Claude Code** and **Cursor** are both first-class — identical `/orchestrator-*` commands, knowledge inject, verification, and review gates. They differ only in **how you install** (Step 1): Claude Code installs globally via a package manager; Cursor installs per-project ([jump to the Cursor setup](#on-cursor)). Steps 2–3 are identical on either. A Codex CLI installer exists too.

---

## Step 1: Install

**Pick your runtime — the install differs, then Steps 2–3 are identical:**

- **Claude Code** → install globally via a package manager (below).
- **Cursor** → install per-project with one command ([jump to On Cursor](#on-cursor)).

### Claude Code

Pick a channel. Each one puts the `orchestrator` binary on your PATH and registers the `/orchestrator-*` skills into Claude Code (globally, in `~/.claude/`).

| Channel | Command | Notes |
|---------|---------|-------|
| **npm** (recommended) | `npm install -g @build-fractal/orchestrator` | Runs the Claude Code installer for you. Install **from inside your project directory** to wire that project automatically. |
| **Homebrew** | `brew install build-fractal/orchestrator/orchestrator` | Taps `build-fractal/orchestrator` + installs. |
| **curl \| bash** | `curl -fsSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh \| bash` | No npm required; downloads the signed release tarball (verify with cosign — see [Installation](../references/installation.md#verifying-integrity)). |
| **From source** | `git clone https://github.com/Build-Fractal/orchestrator.git`<br>`cd orchestrator && bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project` | Development / latest unreleased. The Codex and Cursor installers (`install-codex.sh`, `install-cursor.sh`) share the same flags. |

The orchestrator binary itself is intentionally minimal — `orchestrator --version` / `--help` only. **The real command surface is the Claude Code skills** (`/orchestrator-*`), which is why onboarding (Step 2) happens inside Claude Code, not from the shell.

**Wiring a project.** Installing registers skills globally; the per-project runtime tree (`scripts/`, `templates/`, `references/`) is staged into each project you onboard (commands invoke helpers via project-relative paths, so the tree must live there). The npm channel stages it automatically when you install from inside the project; otherwise `/orchestrator-start` / `/orchestrator-init` (Step 2) stages it, or you re-run `install-claude-code.sh --project-dir <path>` directly. Installed files are recorded in `.orchestrator/installed-files.txt` for a clean uninstall. Installer flags (`--dry-run`, `--mode copy|symlink`, `--force`) and the full autonomy/update reference live in [Installation](../references/installation.md).

> **Updating later:** `npm update -g @build-fractal/orchestrator`, `brew upgrade orchestrator`, or `/orchestrator-update` from inside a project (it auto-detects your install channel). See [Releasing](../references/RELEASING.md) for how releases are cut.

### On Cursor

Cursor gets the **same `/orchestrator-*` commands and the same workflow** as Claude Code. It installs **per-project** (Cursor keeps everything under `<project>/.cursor/`), so there's no npm/Homebrew step — clone the repo once and point the installer at your project:

```bash
# Needs only bash + git — no API key.
git clone https://github.com/Build-Fractal/orchestrator.git
cd orchestrator
bash packaging/install/install-cursor.sh --project-dir /absolute/path/to/your-project
```

That single command stages, into your project:

| What you get | Where |
|---|---|
| Native `/orchestrator-*` slash commands | `.cursor/commands/orchestrator-*.md` |
| Always-on operating rule | `.cursor/rules/orchestrator.md` |
| Safety shape-guard (blocks unsafe shell before it runs) | `.cursor/hooks.json` → `beforeShellExecution` |
| Interactive review-gate renderer (MCP elicitation) | `.cursor/mcp.json` |
| git pre-commit gate (clobber-safe; skips in non-git dirs) | project git hooks |
| Framework runtime (`scripts/` `templates/` `references/`) + default `.orchestrator/config.yml` | project root |

**Then open your project in Cursor and run `/orchestrator-start`** — exactly like Claude Code. Steps 2 and 3 below are identical. (Prefer detected config over the default? Use `bash scripts/lifecycle/init-project.sh --project-dir <path> --runtime cursor` instead — same install plus capability detection and a graph rebuild.)

**Two things to know on Cursor:**

1. **Autonomous runs need `cursor-agent` + an API key.** The in-IDE slash commands work with just the install above. For `/orchestrator-auto` / headless dispatch, the orchestrator shells out to the `cursor-agent` CLI:
   ```bash
   cursor-agent --version          # the CLI must be on your PATH
   export CURSOR_API_KEY=...        # Cursor always round-trips to its backend
   export CURSOR_AGENT=1            # opt the dispatcher into the cursor-agent backend
   ```
2. **Per-run cost figures aren't wired for Cursor yet** — `cursor-agent` reports token usage but no USD cost, so cost surfaces report *not-available* (never a wrong number). Everything else — onboarding, knowledge inject, dispatch, verification, and review gates — works the same as Claude Code.

Hit a rough edge? → [Reporting issues](#reporting-issues-please-do).

---

## Joining a project that already uses orchestrator (git clone)

Cloning a repo a teammate already set up? You **inherit its entire memory** — milestones, decisions, and accumulated knowledge all live in the committed `.orchestrator/`, so you do **not** re-onboard or re-ideate. But two artifacts don't travel in a clone, so do these three things after pulling:

1. **Install orchestrator** (Step 1 above) so the `/orchestrator-*` commands are registered in your runtime.
2. **Run `/orchestrator-init` once** in the cloned project. It re-stages the framework runtime tree (`scripts/`/`templates/`/`references/`) if your repo gitignores it, **and rebuilds the knowledge graph** — `knowledge.db` is a generated, gitignored artifact, so it's absent on a fresh clone. One command and the graph is live.
3. **Run `/orchestrator-doctor`** to confirm. A clean run means you're ready; otherwise it names exactly what's missing (e.g. a `stale-graph-db` symptom prints the precise `rebuild-index.sh` command).

> **Why `init` and not `doctor`?** `doctor` is **read-only by design** — it *diagnoses* (and prints the fix) but never mutates your project. `init` is the command that *wires* things, so it's the one that rebuilds the graph. To rebuild the graph by hand any time, it's just `bash scripts/knowledge/rebuild-index.sh`.

| Layer | What | Travels in the clone? |
|-------|------|-----------------------|
| Project memory | `.orchestrator/` (config, `KNOWLEDGE.md`, `DECISIONS.md`, milestones, `KNOWLEDGE-INDEX.md`), `CLAUDE.md` | ✅ Committed |
| Framework runtime | `scripts/` `templates/` `references/` (staged by the installer) | ⚠️ Your repo's `.gitignore` decides — `init` re-stages it if absent |
| Generated graph | `knowledge.db` (the SQLite graph) | ❌ Always gitignored — `init` rebuilds it |

> **Repo-owner tip:** pick a convention and note it in your project README. **Always commit `.orchestrator/`** (the project's brain). For the runtime tree, either commit it (teammates then only need install → `init`) or gitignore it (teammates run `init` to re-stage). Either way `knowledge.db` is regenerated on clone — `init` handles it.

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

## Reviewing load-bearing decisions (interactive review gates)

For phase-based work, the orchestrator can put a **first-class review step between artifact authoring and sign-off** — so contract-defining decisions get deliberated, not reverse-engineered from a finished file. It's opt-in and built on two plan-frontmatter declarations:

- A task declaring `decision_packet: true` emits a structured `*-DECISIONS.md` alongside its artifact — one typed entry per load-bearing decision (picked value, rationale, alternatives, concrete impact, severity). `/orchestrator-status` and `/orchestrator-doctor` then report **unreviewed decisions** for the phase.
- A phase declaring `review_gates: [...]` runs the `interactive_review` stage at sign-off: each decision is surfaced one at a time — **accept**, **override** (supply a replacement, recorded verbatim), or **push back** — through whichever question primitive your runtime has:

  | Runtime | How decisions are surfaced |
  |---------|----------------------------|
  | Claude Code (interactive) | native `AskUserQuestion` prompt |
  | Cursor (interactive) | native MCP `elicitation/create` form (registered in `.cursor/mcp.json` at install) |
  | Headless / autonomous | a `QUESTIONS.md` hand-off you answer out-of-band, then `/orchestrator-resume` |

Responses land in an append-only `REVIEW.md` that populates `SIGNOFF.md`. Because a gate **must never deadlock an autonomous run**, each gate declares an auto-mode policy — **`defer`** (default: write a continue-file and pause, resumable via `/orchestrator-resume`), `accept-with-audit` (auto-accept with a per-decision audit record), or `refuse-entry` (halt at the phase boundary). The decision artifact is always written regardless of policy; only the operator touch is gated.

Optionally, a gate can declare `producer: conversus` to fold a [conversus](why-this-exists.md) deliberation's verdict and surviving disputes into the packet, so you adjudicate its findings at the gate rather than re-deriving them.

Gates are entirely opt-in — `decision_packet` and `review_gates` are never global defaults. See [`commands/plan-phase.md`](../commands/plan-phase.md) for declaring them and [`references/interactive-review-renderer.md`](../references/interactive-review-renderer.md) for the walkthrough mechanics.

---

## Reporting issues (please do!)

The fastest way to improve the orchestrator — on **Claude Code or Cursor** — is to tell us when something snags. It takes about 30 seconds and there's no wrong report.

| What | Where |
|---|---|
| 🐞 Something's broken | **[Bug report](https://github.com/Build-Fractal/orchestrator/issues/new?template=bug_report.yml)** |
| 💡 Want a feature | [Feature request](https://github.com/Build-Fractal/orchestrator/issues/new?template=feature_request.yml) |
| ❓ How-to / "is this normal?" | [GitHub Discussions](https://github.com/Build-Fractal/orchestrator/discussions) (not the issue tracker) |
| 🔒 Security issue | [Private advisory](https://github.com/Build-Fractal/orchestrator/security/advisories/new) — never a public issue |

**Make it instantly actionable** — the bug template asks for exactly this:

1. **Your runtime** — Claude Code or Cursor — and install channel.
2. **`/orchestrator-doctor` output** — run it (read-only, always safe) and paste what it prints. It surfaces the most common onboarding problems on its own.
3. A one-line *"I ran X, expected Y, got Z."*

That's a great report. You don't need a minimal reproduction — the doctor output plus your runtime usually points straight at the cause.

---

## Next

- **New here?** Read [why-this-exists](why-this-exists.md) for the motivation and where the orchestrator fits versus plain Claude Code.
- **Coming from spec-kit?** [Migrating from spec-kit](migrating-from-speckit.md) — spec-kit is a migration *source*, never a runtime dependency.
- **Want depth on knowledge inject and MEMs?** [Knowledge Management](knowledge-management.md).

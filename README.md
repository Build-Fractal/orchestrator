# Orchestrator

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-v0.10.2-green.svg)](./CHANGELOG.md)
[![Runtime](https://img.shields.io/badge/runtime-Claude%20Code%20%2B%20Cursor-orange.svg)](#try-it-with-zero-commitment)
[![Spec-driven](https://img.shields.io/badge/spec--driven-development-purple.svg)](./docs/why-this-exists.md)

**Agents dispatch with only the context they need — your decisions, conventions, and related code — never from zero; and every task passes mechanical verification before it counts as done.**

No context-rebuilding overhead at the start of each task. No self-graded "looks good to me" at the end. The mechanism: a per-project knowledge graph injected into each fresh-context dispatch, plus a 4-tier verification ladder ([definition](references/verification-ladder.md)) that runs before a task closes.

---

## See it in 10 seconds

A one-line task dispatch — the relevant knowledge (MEMs: memory entries in the knowledge graph — decisions, conventions, or summaries) is *shown* being injected, not asserted:

```
$ /orchestrator-do "fix the broken redirect after sign-up"

[knowledge-inject] 3 MEMs (auth/sign-up-flow, auth/redirects, conv/error-handling)
[verify] tier-1 file checks ✓  tier-2 commands (npm test, npm run lint) ✓
[record] execution-log.jsonl appended · 1 task closed
```

> **MEM** = a memory entry in the knowledge graph (a decision, convention, or summary). The agent received three relevant MEMs — not the whole codebase. Verification ran mechanically before the task counted as done.

---

## Is this for you?

Three questions. **Two or more "yes" → the overhead pays off:**

1. Will the work span **more than one context window**?
2. Will you **hand it off or resume it later** (another person, another session, after a crash)?
3. Do you need **mechanical per-task verification** instead of trusting the agent's self-report?

**Otherwise, reach for plain Claude Code first** — for single-context work that fits in one session and never resurfaces, the on-disk discipline is overhead without payoff. See [When this isn't a fit](docs/why-this-exists.md) for the full candor.

---

## What it does

| What you get | Evidence / example |
|---|---|
| **Small tasks get sharper** | `/orchestrator-do "rename X to Y across the auth flow"` injects the relevant MEMs before dispatch — see the 10-second block above. *(Concrete — try it now.)* |
| **Verification is mechanical, not vibes** | Every task passes a 4-tier ladder: file checks → command execution → behavioral review → human review. *(Concrete — shown in the dispatch block.)* See [verification-ladder.md](references/verification-ladder.md). |
| **Load-bearing decisions get reviewed, not rubber-stamped** | Declare `review_gates:` on a phase and each load-bearing decision is surfaced one-by-one at sign-off (accept / override / push back) through your runtime's native prompt — Claude Code `AskUserQuestion`, Cursor MCP elicitation, or a headless `QUESTIONS.md` hand-off — captured to an append-only `REVIEW.md` that populates `SIGNOFF.md`. Opt-in; never deadlocks an autonomous run (declared `defer` / `accept-with-audit` / `refuse-entry` policy). `status`/`doctor` surface unreviewed decisions. *(M034.)* |
| **Large projects get tractable** | Multi-week features decompose into context-window-sized phases; `/orchestrator-auto` loops `dispatch → verify → record → advance` until done. Dogfooded across **41 closed milestones** — audit trail in [`.orchestrator/milestone-summary.md`](./.orchestrator/milestone-summary.md). |
| **State survives anything** | All state lives on disk under `.orchestrator/` — crash, terminal kill, or reboot, then `/orchestrator-resume` continues exactly where it stopped. Recovery primitives shipped and dogfooded daily; see [state-machine.md](references/state-machine.md). |
| **Knowledge compounds** | Every phase emits structured summaries; decisions go to an append-only register; the next phase is cheaper than the last. Three-temperature (hot/warm/cold) graph indexed at [`.orchestrator/KNOWLEDGE.md`](./.orchestrator/KNOWLEDGE.md); see [knowledge-management.md](docs/knowledge-management.md). |

---

## Try it with zero commitment

Already installed and sitting in a project? One line, no onboarding required:

```bash
/orchestrator-do "fix the broken redirect after sign-up"
```

It works without setup, and works *sharper* after `/orchestrator-start` seeds the knowledge graph (about a minute for an existing codebase → 5–15 seed MEMs).

**Not installed yet?** → [Getting Started](docs/getting-started.md) owns the full walkthrough. Pick a channel:

```bash
# npm (recommended) — installs globally, runs the Claude Code installer for you
npm install -g @build-fractal/orchestrator

# curl | bash — no npm required; downloads the signed release tarball
curl -fsSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash

# Homebrew
brew install build-fractal/orchestrator/orchestrator

# From source (development / latest unreleased)
git clone https://github.com/Build-Fractal/orchestrator.git
cd orchestrator && bash packaging/install/install-claude-code.sh --project-dir /path/to/your-project
```

Installing registers the `/orchestrator-*` skills globally in Claude Code. Then, **in your project, open Claude Code and run `/orchestrator-start`** — the warm onboarding front door (or `/orchestrator-init` for the bare scaffold). The `orchestrator` binary itself is just `--version` / `--help`; the real surface is the Claude Code skills.

> ### 🟣 On Cursor? Two commands.
>
> Cursor gets the **same `/orchestrator-*` commands and the same core loop** — knowledge inject, dispatch, verification, and native interactive review gates (via Cursor's MCP elicitation). It installs **per-project** (Cursor keeps everything under `<project>/.cursor/`), so there's no npm step — just clone the repo and point the installer at your project:
>
> ```bash
> git clone https://github.com/Build-Fractal/orchestrator.git
> cd orchestrator
> bash packaging/install/install-cursor.sh --project-dir /path/to/your-project
> ```
>
> Then **open your project in Cursor and run `/orchestrator-start`** — the exact same first step as Claude Code. That single install lays down the slash commands (`.cursor/commands/`), an always-on rule (`.cursor/rules/`), the safety shape-guard (`.cursor/hooks.json`), and the review-gate server (`.cursor/mcp.json`).
>
> **Good to know:** the install needs only `bash` + `git` — *not* an API key. The `cursor-agent` CLI + `CURSOR_API_KEY` are only needed for **autonomous** runs (`/orchestrator-auto`); the in-IDE commands work without them. Per-run **cost figures aren't wired for Cursor yet** (they report as not-available, never wrong). → [Full Cursor walkthrough](docs/getting-started.md#on-cursor)

**Updating** is one line, and `orchestrator:update` auto-detects how you installed:

```bash
npm update -g @build-fractal/orchestrator   # npm / curl installs
brew upgrade orchestrator                    # Homebrew installs
/orchestrator-update                         # from inside any project (dispatches to the right channel)
```

(Requires Bash 3.2+, git, and optionally jq. macOS + Linux; Windows is fail-closed by design. **Claude Code** and **Cursor** are both supported — see the Cursor callout above. A Codex CLI installer exists with the same flags.)

---

## Pick your path

Each command below assumes you've [installed](docs/getting-started.md) and are in your project directory.

| Your intent | Command | Time | What you get |
|---|---|---|---|
| One-shot task, any project | `/orchestrator-do "fix the broken redirect after sign-up"` | seconds | Knowledge-injected dispatch; no ceremony |
| **Join a repo a teammate already set up** (git clone) | install, then `/orchestrator-init` | seconds | Re-stages the runtime + **rebuilds the gitignored knowledge graph**; `/orchestrator-doctor` to confirm. [Details](docs/getting-started.md#joining-a-project-that-already-uses-orchestrator-git-clone) |
| Onboard an existing codebase | `/orchestrator-start` → codebase ingestion | ~1 min | 5–15 seed MEMs via deterministic structural extraction |
| Start greenfield, nothing written | `/orchestrator-start` → ideation | 5–10 min | 7-question grilling protocol → vision, scope, users, constraints |
| Greenfield + materials (briefs, PDFs) | `/orchestrator-start` → materials intake | 5–15 min | Reconciled pre-spec; asked only about real conflicts |
| Ship a multi-month feature autonomously | `/orchestrator-start` then `/orchestrator-auto` | hours–days | Roadmap → phases → dispatch → verify → advance, untouched |
| Run it hands-off across context rotations | `/orchestrator-auto --self-continue` | hours–days | Self-continues over rotation boundaries via fresh-process re-entry; halts on completion / blocker / budget / cap. [Details](docs/getting-started.md#self-continuing-autonomous-runs---self-continue) |
| Add reference docs (regs, glossaries) | `/orchestrator-extract` then `/orchestrator-ingest-reference` | varies | Tiered extraction into the knowledge graph |
| Give a team visibility | `/orchestrator-wiki-init` (`--deploy --with-giscus`) | ~2 min | mkdocs site of milestones, phases, decisions — GitHub Pages + commentable |
| Use GitHub Issues / Projects as tracker | `/orchestrator-github-init` | ~2 min | State projected to Issues / Milestones / Projects v2; opt-in, reversible |

> **Coming from spec-kit?** spec-kit is a **migration source, not a dependency** — the orchestrator runs standalone with zero runtime dependency on it. `/orchestrator-start` → migration lifts your existing artifacts in. Expect a real (small) learning curve; the workflow and file layout differ. → [Migrating from spec-kit](docs/migrating-from-speckit.md).

---

## Mental models in one line each

| It's not… | The boundary |
|---|---|
| **plain Claude Code** | Use plain Claude Code first for single-context work. Orchestrator adds knowledge injection + verification for *multi-session, hand-off* work. See [Is this for you?](#is-this-for-you) |
| **spec-kit** | A migration source, not a dependency or runtime. The orchestrator runs standalone. → [migrating-from-speckit](docs/migrating-from-speckit.md) |
| **conversus** | An *optional* sister tool (multi-agent adversarial review), released separately and **not required**. The orchestrator works standalone without it; the `/orchestrator-conversus-gate` adapter degrades gracefully — deliberation gates are skipped — when it isn't installed. |

---

## Command cheat sheet

**Start with these 5 entry points** — they cover most of what you'll do day to day:

| Entry point | When to use |
|---|---|
| `/orchestrator-start` | First time in any project — warm front door, auto-routes onboarding (greenfield-empty / greenfield-with-materials / existing-codebase / migrating) |
| `/orchestrator-do "..."` | Any task — classifies scope, routes to Tier A quick-path, Tier A+ middle flow, or defers larger work to `/orchestrator-specify` |
| `/orchestrator-auto` | Autonomous loop — `dispatch → verify → record → advance` until milestone completes or a blocker surfaces. Add **`--self-continue`** to keep it running across context-rotation boundaries *without re-invoking by hand* — it re-spawns a fresh process each time and stops on completion, a blocker, budget, or a cap (opt-in, default off) |
| `/orchestrator-status` | Anytime — read-only one-screen progress + next-action report |
| `/orchestrator-resume` | After crash or pause — reads `.orchestrator/` state and continues exactly where it stopped |

> **Tier A / A+ / B / C** = task-scope classes, smallest to largest. `/orchestrator-do` picks one automatically; you rarely name them yourself.

**Beyond the entry points**, the orchestrator ships **37 user-facing commands** — planning (`specify`, `roadmap`, `plan-phase`), knowledge (`extract`, `ingest-reference`, `consolidate`), GitHub (`github-init`, `github-sync`, `comments`), diagnostics (`doctor`, `diagnose`, `detective`, `where`, `cost`), wiki, and more. Each lives at [`commands/<name>.md`](./commands/); the full per-feature chain is `evaluate → discuss → roadmap → plan-phase → auto → verify → consolidate`.

---

## Status & credibility

**v0.10.2** — published across npm / Homebrew / curl, in production use and **dogfooded daily on its own development**. Dozens of milestones closed (latest: M044 knowledge-activation reliability, 2026-06-07; M034 interactive review gates, 2026-06-06; M043 Cloudflare Pages + Access wiki-deploy target, 2026-06-05; M042 `/orchestrator-corpus-gate`, 2026-05-30; M041 `/orchestrator-detective`, 2026-05-25); the packaging & distribution launch event shipped 2026-05-09. **Cursor is a supported runtime (M009 + M034, 2026-06-06)** — native commands, dispatch backend, hooks, and interactive review gates. Next up is a demand-driven post-launch fast-follow queue (Cursor cost accounting; M023 design layer; the M038+M040 paired slot).

Full audit trail: [`.orchestrator/milestone-summary.md`](./.orchestrator/milestone-summary.md) · engineering changelog: [`CHANGELOG.md`](./CHANGELOG.md).

Governed by 15 constitutional principles ([`.orchestrator/memory/constitution.md`](./.orchestrator/memory/constitution.md)) — e.g. *Evidence Before Claims* (no task closes without fresh verification) and *Knowledge Compounds* (every phase emits docs that make the next cheaper). The full rationale and the prior failures these codify live in [why-this-exists](docs/why-this-exists.md).

---

## Hit a snag? Tell us

Reporting takes about 30 seconds, and it genuinely shapes what ships next — on **Claude Code or Cursor**:

| What | Where |
|---|---|
| 🐞 Something's broken | **[Open a bug report →](https://github.com/Build-Fractal/orchestrator/issues/new?template=bug_report.yml)** |
| 💡 Want a feature | [Open a feature request →](https://github.com/Build-Fractal/orchestrator/issues/new?template=feature_request.yml) |
| ❓ How-to / "is this normal?" | [GitHub Discussions →](https://github.com/Build-Fractal/orchestrator/discussions) (not the issue tracker) |
| 🔒 Security issue | [Private advisory →](https://github.com/Build-Fractal/orchestrator/security/advisories/new) — please don't open a public issue |

Two things make any report instantly actionable — the bug template asks for both:

1. **Your runtime** — Claude Code or Cursor (+ install channel).
2. **The output of `/orchestrator-doctor`** — it's read-only and safe to run anytime; paste what it prints.

That's it. No reproduction wizardry required — a one-paragraph "I ran X, expected Y, got Z" plus those two lines is a great report.

---

## Next step

| You are… | Go here |
|---|---|
| **Skeptical** — want the "why" before you commit | → [Why this exists](docs/why-this-exists.md) |
| **Ready to install** (Claude Code or Cursor) | → [Getting Started](docs/getting-started.md) |
| **On Cursor** and want the full setup | → [Getting Started → Cursor](docs/getting-started.md#on-cursor) |
| **Coming from spec-kit** with existing artifacts | → [Migrating from spec-kit](docs/migrating-from-speckit.md) |

**Want to contribute?** → [CONTRIBUTING.md](CONTRIBUTING.md) (dev setup, tests, conventions). Maintainers cutting a release → [Releasing](references/RELEASING.md).

**See also:** [Knowledge Management](docs/knowledge-management.md) · [Recipe Authoring](docs/recipe-authoring.md) · [Hook Development](docs/hook-development.md) · [Architecture](references/architecture.md) · [Verification Ladder](references/verification-ladder.md) · [State Machine](references/state-machine.md)

## License

MIT

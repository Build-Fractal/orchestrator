# Why this exists

**A knowledge graph that travels with the work plus mechanical verification beats markdown hand-off documents that quietly drift from reality.** That sentence is the whole pitch; the rest of this page is the evidence behind it.

> **This is the "should I care?" doc** for a skeptical evaluator deciding whether the orchestrator is worth their time — the motivation and origin story, not the install steps. If you've already decided and want hands-on, skip straight to [Getting Started](getting-started.md). If you're routing yourself, the [README](../README.md#documentation) is the hub.

## Is this for you?

| You are... | Read this if... |
|---|---|
| A skeptic | You've watched hand-off docs collapse and want to know why a knowledge graph is different |
| Evaluating fit | Your work is multi-week / multi-session and no longer fits one context window |
| Comparing tools | You want the boundary vs. plain Claude Code, spec-kit, and conversus stated plainly |

If your task fits in a single afternoon and a single context window, **use plain Claude Code first** — the orchestrator earns its keep only when work outgrows one session. [Honest limits](#honest-limits) covers exactly when.

## The problem

You're six weeks into a feature. The plan branched into a dozen interdependent phases, the conversation log holds a million tokens of decisions, and the session that picks up tomorrow starts cold. So you write a hand-off document. It works on the third session and collapses by the tenth: the summary grows longer than the code, the "everything important" payload blows past the context window it was meant to fit inside, and there's no mechanical proof that a "done" task is actually done — just a confident summary that diverged from reality two commits ago.

## Why our predecessors failed

The orchestrator's constitution is not aspirational — every principle is the scar tissue from a specific failure. Two homegrown predecessors, GSD-1 and GSD-2 ("Get Stuff Done"), taught the load-bearing lessons. Their adapters survive only as migration sources (`scripts/migrate/adapters/gsd1.sh` and the SQLite-backed GSD-2 path).

| Predecessor | Approach | What broke | Lesson encoded |
|---|---|---|---|
| **GSD-1** | Flat markdown in `.planning/` (`KNOWLEDGE.md`, `DECISIONS.md`, per-milestone dirs) | No strict on-disk shape → every project drifted into a bespoke layout the agent had to re-derive each session | Structure an agent must re-derive every session is structure that does not exist |
| **GSD-2** | State in SQLite + JSON schema layer | Humans could no longer read project state without tooling; crashes left half-written transactions; the DB had to be packaged, migrated, version-locked | State humans can't read on a Sunday with `cat` and `grep` is state that erodes trust |

Both lessons collapse into one principle — **State On Disk Is Truth**: every piece of state is a markdown file or a JSONL line at a known path, fully auditable with `cat` and `grep`, with no privileged accessor. (The orchestrator also outgrew GitHub's [spec-kit](https://github.com/github/spec-kit), which it started as an extension of. Spec-kit was excellent for single-feature work but stopped at the single-task boundary; the standalone cutover is covered in [Migrating from spec-kit](migrating-from-speckit.md).)

## What we built instead

Seven constitutional principles govern every decision (full text: [`.orchestrator/memory/constitution.md`](../.orchestrator/memory/constitution.md)). Each is the codified reaction to a failure mode:

| Principle | The failure that taught it |
|---|---|
| **Context Minimization** — optimize each task for the relevant-instructions / total-inherited ratio | The wall: multi-week features don't fit one context window, and hand-off docs grow past the window they're meant to fit in |
| **Evidence Before Claims** — no task is "done" without fresh verification evidence; "should work" is not evidence | Silent failures where the agent reported success and the human found the regression a week later |
| **Design Before Code** — every unit gets an explicit design step, however "simple" | Bug fixes that turned into architectural rewrites three commits in |
| **Plans Assume Zero Context** — task plans must be readable by an agent with zero prior project knowledge | Hand-off docs that only made sense to whoever wrote them |
| **Fresh Context Per Unit** — each dispatch starts in a clean session | Sessions polluting each other, producing decisions nobody could trace |
| **State On Disk Is Truth** — all state recoverable from files; no in-memory cache, no database | GSD-1's drift and GSD-2's opacity (above) |
| **Knowledge Compounds** — every phase emits structured summaries so the next phase is genuinely cheaper than the last | Projects that ran twenty milestones and ended up no smarter than they started |

Two things make this more than a values statement:

- **A knowledge graph, not a hand-off file.** A three-temperature model (hot / warm / cold) over individual detail files, an append-only decisions register, and a scoped graph, indexed at `.orchestrator/KNOWLEDGE.md`. The agent dispatched to fix the auth flow receives the few entries relevant to auth — *knowledge injection* — not the project's entire history. See [Knowledge Management](knowledge-management.md).
- **Mechanical verification, not vibes.** A 4-tier ladder every task must clear before it counts as done: (1) static file/content checks → (2) command execution (tests/lint) → (3) behavioral / spec-compliance review → (4) human review (UAT). Enforcement is mechanical: verification scripts check the principles by number rather than trusting a summary.

## Proof it works

The orchestrator's last release is **v0.9.2** (2026-04-28), in production use and **dogfooded daily on its own development** — it uses its own `/orchestrator-*` workflow to build itself.

| Claim | Evidence |
|---|---|
| Closed milestones, dogfooded end-to-end | Dozens of milestones closed across the project's history; the per-milestone audit trail lives in [`.orchestrator/milestone-summary.md`](../.orchestrator/milestone-summary.md) |
| Most recent close | M041 (`orchestrator:detective`) closed 2026-05-25 |
| Shipped to users | Launch event shipped 2026-05-09 (M035, packaging & distribution) |
| Surface area | A full command set under `commands/`, output templates under `templates/`, and reference docs under `references/` — each browsable on disk |

These are on-disk facts you can verify yourself, not marketing — every closed milestone leaves its own directory under `.orchestrator/milestones/`, and the narrative roll-up lives in `.orchestrator/milestone-summary.md`.

## Honest limits

The theory is clean; the candor is that not every project needs it.

- **Small, single-context work?** Use plain Claude Code directly. The orchestrator's structure is overhead until work outgrows one session — that's the boundary, and it's deliberate.
- **spec-kit is a migration source, not a dependency.** The orchestrator is standalone with zero runtime dependency on spec-kit. If you have a spec-kit project, see [Migrating from spec-kit](migrating-from-speckit.md).
- **conversus is optional.** It's a sister multi-agent deliberation engine invoked through a graceful-degradation adapter for adversarial review; the orchestrator works fully standalone when it isn't installed.
- **Runtime breadth is still narrowing.** Claude Code is the primary, production runtime; Codex CLI and Cursor are post-launch fast-follows tracked under M009.

**Cheapest way to disprove the skepticism:** onboard once and run a single one-shot task. `/orchestrator-do "your task"` classifies and dispatches in one move — zero commitment, and you'll see the knowledge-injected dispatch block for yourself.

## Ready to try it?

**Next: [Getting Started](getting-started.md)** — install in ~30 seconds, onboard your project with `/orchestrator-start`, and run your first task end-to-end.

See also:
- [README](../README.md#documentation) — the routing hub for every reader intent
- [Migrating from spec-kit](migrating-from-speckit.md) — if you're coming from a spec-kit project
- [`.orchestrator/milestone-summary.md`](../.orchestrator/milestone-summary.md) — the full audit trail behind the proof claims

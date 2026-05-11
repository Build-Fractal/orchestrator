# Proposal: M040 — Ambient Feedback Loop (the vault talks back)

**Captured**: 2026-05-10
**Shape**: Post-launch milestone, demand-driven. Three cohesive surfaces in one milestone; bundling justified by shared primitives (scheduled output, inbox surface, knowledge-graph read passes).
**Predecessors**: M020 (knowledge layer — MEM index, edge schema), M027 (cost+quality observability — JSONL execution-log emitter M040 reads from), M030 (adaptive model selection — for the synthesis pass routing), M011/P07 (conversus adapter — for contradiction-gate two-agent passes), M032 (wiki distribution — optional output surface for briefs), M036a (reference-corpus ingest — MEM-density baseline for the gap detector)
**Source**: 2026-05-10 README audit + adoption-pattern article on personal-knowledge systems ("vault that adds to you, not vault you add to"). The article's diagnosis — *"a knowledge system without a return path is a graveyard with good folders"* — applies directly to orchestrator. Today's knowledge graph is richer than what the article describes (typed MEMs, edges, dispatch injection, supersede chains), but most of that intelligence only fires *during a dispatch*. Between dispatches the vault is silent — same failure mode.

## Status

**RFC capture only.** Implementation deferred post-launch. The brief below covers three surfaces that share primitives and ship as one milestone when demand-signal lands. When the arc enters the queue, this proposal becomes the input to `orchestrator:specify M040` and grows into a full brief.

## TL;DR

Orchestrator runs are *episodic*: a user invokes `/orchestrator-do` or `/orchestrator-auto`, knowledge inject fires, work happens, state lands on disk. Between runs the project is silent. For multi-month projects this silence costs three things the framework can already detect but doesn't surface:

1. **Connections across recent work** that no single dispatch is positioned to notice (Phase 7 of Milestone N quietly relates to a decision shipped in Milestone N-2).
2. **Drift between accreting decisions** — later decisions silently invalidate earlier ones; nobody notices until a verifier fails or a downstream consumer (PBJ, LakeLedger) hits the contradiction live.
3. **Half-formed thoughts** that arrive between dispatches and have no low-friction landing surface — they get lost or become heavyweight to capture, so the user stops capturing them.

M040 builds the **ambient feedback loop**: an automatic daily/weekly brief that surfaces emerging patterns, a contradiction detector that runs on every decision write, and a friction-free inbox for thoughts that aren't yet ready to act on. The vault talks back without being asked.

## Why post-launch (not pre-launch)

Same reasoning as M034 / M038: this is **power-user workflow scope**, not first-impression scope. Pre-launch onboarding (M033) and early dispatches don't generate enough accreted state to make the feedback loop interesting. The brief becomes load-bearing once a project has 3+ closed milestones, 50+ MEMs, and a decision register that's outgrown one screen of grep. PBJ-central, LakeLedger, and this repo all currently meet that bar; the average new user does not.

Demand signal to watch for:
- Operators (us, PBJ, LakeLedger) hand-rolling "what did I work on this week / what's drifting" passes via ad-hoc bash + grep.
- A second downstream consumer signals "I lost track of what we decided about X" — exactly the failure mode the contradiction detector retires.
- Repeated `/orchestrator-do "remember when we decided…"` queries that resolve to MEMs the user should have been surfaced unbidden.

## Goal

After M040 ships, every orchestrator-managed project carries three ambient feedback surfaces:

1. **Daily/weekly project brief** — scheduled output that says "here's what your project is actually working on this week."
2. **Decision contradiction gate** — on every `DECISIONS.md` write, surface any contradiction with prior decisions.
3. **Frictionless capture inbox** — a 30-second landing surface for thoughts that aren't yet ready to be tasks.

All three compose: inbox items feed the brief; the brief flags contradictions; contradictions feed the human-gated apply queue (`commands/comments.md` CON-5/SC-5 convention).

## Strict scope

This is **the ambient-feedback layer**. It is **not**:

- A replacement for `/orchestrator-do` — capture inbox is *non-acting* by design; promotion to a task is a separate explicit step.
- A replacement for `/orchestrator-status` — status answers "where am I right now"; the brief answers "what is the project quietly working on."
- A replacement for `commands/comments.md` review queue — contradictions feed *into* the same queue, don't replace it.
- An auto-applier — every contradiction routes to human review; nothing auto-resolves.
- A net-new knowledge-graph storage layer — reads existing MEM / DECISIONS / execution-log; emits to `.orchestrator/briefs/` and `.orchestrator/inbox/`.

## Three surfaces

### Surface 1: Project brief — `/orchestrator-brief`

**Command shape:** `/orchestrator-brief [--window=daily|weekly] [--out=<path>]`

**Manual invocation:** runs immediately, emits brief to `.orchestrator/briefs/<date>-<window>.md`.

**Scheduled invocation:** wired through the existing `schedule` skill (M035 cron primitives). Default cadence at queue-entry decision: daily at 6am for active milestones, weekly Monday at 8am for cross-milestone synthesis.

**Read sources** (zero net-new storage):
- `.orchestrator/execution-log.jsonl` — last 24h (daily) / 7d (weekly)
- `.orchestrator/KNOWLEDGE.md` + recent MEM writes
- `.orchestrator/DECISIONS.md` — last 14d
- Active phase plans (current milestone)
- `.orchestrator/inbox/` — anything captured since last brief

**Output shape** (template-driven, deterministic structure):

```markdown
# Project Brief — <date> (<window>)

## Connections
<3 cross-MEM / cross-phase links the dispatcher would otherwise miss, with quoted passages>

## Drift signal
<phases shipping vs. roadmap intent; reuses `validate-milestone.sh` mechanics>

## One question
<derived from open decisions, blocked tasks, unresolved `discuss` outputs, or inbox items aging > 7d>
```

**Routing:** uses M030 model-selection — Quick tier for daily brief (cheap, fast), Standard tier for weekly synthesis (deeper read, named pattern detection).

### Surface 2: Decision contradiction gate

**Trigger:** any write to `.orchestrator/DECISIONS.md` (hook on PostToolUse Edit/Write).

**Mechanism:** two-agent conversus pass (new decision vs. all prior decisions on adjacent topics, filtered by the existing MEM edge graph — `decision/cites`, `decision/relates-to`). Reuses the M011/P07 conversus adapter; same shape as the existing spec-fidelity gate.

**Verdict shapes:** PASS (no contradiction), FLAG (advisory — surface in next brief, don't block), BLOCK (active contradiction — write to `.orchestrator/contradictions/<date>.md`, route to human-gated apply queue via `commands/comments.md` convention).

**Cost discipline:** runs only on decision writes, not on every MEM. M027 efficiency footer reports the cost. Operator can disable via config (`feedback_loop.contradiction_gate: off`) if cost outweighs value on a given project.

### Surface 3: Frictionless capture inbox — `/orchestrator-capture`

**Command shape:** `/orchestrator-capture "<thought>"` — no classification, no dispatch, no acting. Lands raw.

**Storage:** `.orchestrator/inbox/<YYYY-MM-DD>-<slug>.md` with frontmatter:

```yaml
---
captured_at: 2026-05-10T14:32:11Z
git_sha: abc1234
active_milestone: M040
active_phase: P01
captured_via: cli  # or telegram, web, hook
---
```

**Promotion:** inbox items surface in the daily brief and in `/orchestrator-status`. Three explicit promotion paths:
- `/orchestrator-promote <inbox-file> --to=mem` — becomes a MEM
- `/orchestrator-promote <inbox-file> --to=decision` — appended to `DECISIONS.md`
- `/orchestrator-promote <inbox-file> --to=task` — feeds `/orchestrator-do`

**Aging policy:** items aging > 14d without promotion appear in the weekly brief's "One question" slot ("you captured this two weeks ago and haven't acted — still relevant, or close it?").

**Optional adapters (post-v1):** lightweight `inbox-from-telegram.sh` / `inbox-from-email.sh` shell adapters following the same pattern as `scripts/dispatch/adapters/format/`. Not load-bearing; the CLI form is the v1 surface.

## Knowledge graph integration

M040 reads existing schema; minor additive extensions:

- **New node type:** `feedback/brief` (one per brief output, references the MEMs/decisions/phases it synthesizes from)
- **New node type:** `feedback/inbox-item` (lifecycle: `captured` → `promoted:<type>:<target>` or `closed:stale`)
- **New edge type:** `decision --contradicts--> decision` (emitted by the contradiction gate; informs the next brief's "drift signal")

All additive to M020's schema. No breaking changes.

## Lifecycle commands

```
orchestrator:brief [--window=daily|weekly] [--out=<path>]
orchestrator:capture "<thought>"
orchestrator:promote <inbox-file> --to=mem|decision|task
orchestrator:inbox [list|review|close <file>]
orchestrator:contradictions [list|review|resolve <file>]
```

## Relationship to M038 / M034

- **M034 (interactive review gates):** M040's contradiction gate emits exactly the decision-packet shape M034 consumes. M040 produces the artifacts; M034 provides the human walkthrough. Strong composition; no overlap.
- **M038 (living documents):** the daily/weekly *brief itself* is a living document — sections evolve, history matters, prior briefs are queryable. If M038 ships first, briefs register as living-docs and inherit section-binding for free. If M040 ships first, M038's queue-entry pass should add `feedback/brief` as a built-in living-doc type. Coordinated; not blocking either direction.
- **M039 (theme-leveraged process primitives):** M040's brief outputs render naturally as wiki pages via the mkdocs-macros pattern. M039 absorbs the wiki-projection surface; M040 owns the generator. Sibling milestones.

## Open Questions (for queue-entry plan-phase to resolve)

- **#Q-1 (brief cadence default):** Daily 6am + weekly Monday 8am, or operator-configured at init time? Brief leans operator-config with sensible defaults.
- **#Q-2 (contradiction-gate trust boundary):** Does the gate run on *every* decision write, or only decisions tagged with high-stakes markers (architectural, scope-amending)? Cost-vs-coverage tradeoff. Brief leans gate-on-every with config opt-out.
- **#Q-3 (inbox aging policy):** Stale at 14d, 30d, or operator-configured? Brief leans 14d default with operator-config override.
- **#Q-4 (promotion auto-vs-explicit):** Should the daily brief offer one-click promotion suggestions ("inbox item X looks like a MEM — promote?"), or stay read-only? Brief leans read-only v1 (no auto-mutating surfaces from the brief itself; promotion is always operator-driven).
- **#Q-5 (telegram/email adapter scope):** Land in M040 P0X or defer to a fast-follow once CLI capture is proven? Brief leans defer.

## Trigger condition

M040 fires when **at least two** of the following land:

1. Operator (us, PBJ, LakeLedger) ad-hoc invokes a "what did I work on this week" pass via custom bash + grep at least 3 times.
2. A second downstream consumer (beyond PBJ + LakeLedger) signals "I lost track of what we decided" friction.
3. M034 or M038 enters the queue — bundling decision is easier when at least one neighbor is moving.
4. ≥ 5 inbox-shaped friction reports (operator captures a thought, has nowhere to put it, loses it).

Without two of these, M040 is over-eager — the ambient feedback loop is only valuable once there's enough state for "ambient" to mean anything.

## Blast radius

- **Read-only over existing state** — M040 reads execution-log, KNOWLEDGE.md, DECISIONS.md, phase plans. No mutations to those surfaces.
- **New write surfaces** — `.orchestrator/briefs/`, `.orchestrator/inbox/`, `.orchestrator/contradictions/`. All under the existing state root; no new top-level directories outside `.orchestrator/`.
- **Hook addition** — one PostToolUse hook on `DECISIONS.md` writes (contradiction gate). Routes through M021 hook-shape guard; expected shape is a single shell call.
- **Cost surface** — bounded by config (`feedback_loop.daily_budget_usd`, `feedback_loop.contradiction_gate: on|off`). Defaults set so a typical project pays < $0.20/day for daily + weekly brief + contradiction gate on a normal-volume decision register.
- **Backward compat** — every command is net-new. Existing dispatch / verify / status flows unchanged. Disabling M040 via config returns the project to today's behavior exactly.

## Notes for queue-entry

- **Sequencing:** M040 cannot precede M027 (efficiency footer reports M040 costs) or M030 (adaptive routing for the synthesis pass). Both closed. M040 also benefits from M035 cron primitives being live for scheduled execution; verify M035 P02–P06 ship the cron surface before M040 queue-entry.
- **Spec authoring:** single spec covers all three surfaces. Tier C complexity. Conversus gate recommended (three coupled FRs + scheduling + cost-discipline + hook addition).
- **Roadmap:** 3 phases — P01 brief generator + scheduling + cost-discipline; P02 capture inbox + promote + status surface; P03 contradiction gate + conversus integration + human-gated apply queue routing.
- **Rough budget:** Tier C, 3 phases at Standard intensity, predicted ~$60-90 LLM cost + 1.5-2 weeks engineering effort.

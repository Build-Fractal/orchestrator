# EOS Patterns for the Orchestrator

**Status**: Vision draft (not a milestone proposal yet)
**Author**: Brett Kellgren
**Date**: 2026-05-04
**Inputs**: research survey on EOS / Ninety.io / Strety; current orchestrator surfaces (`commands/`, `.orchestrator/`, `KNOWLEDGE-INDEX.md`); constitution principles I–VII (`.orchestrator/memory/constitution.md`).
**Purpose**: Map what's load-bearing in EOS — and in the two SaaS implementations of it (Ninety, Strety) — onto the orchestrator's existing substrate. Answer the user's question: *what's worth adopting to integrate product, engineering, and go-to-market into one running system?*

---

## TL;DR

EOS is a **fixed set of artifacts and cadences** that force a leadership team to confront reality every week. Its integration trick is not workflow software — it's **artifact co-location**: one V/TO, one Scorecard, one Accountability Chart, one Issues List, all visible to all functions on a single page or single meeting agenda. Ninety and Strety are SaaS expressions of the same canon; they differ in positioning (Ninety = orthodox, Strety = collapse-the-stack with deep Slack/Teams integration), but neither has shipped serious AI yet.

The orchestrator already has analogous substrates — `M*-ROADMAP.md`, `KNOWLEDGE-INDEX.md`, `proposals/`, `metrics-rollup`, the skill registry — but they aren't fused into V/TO-shaped views, and we lack EOS's hard caps (5–15, 3–7, 6–10) and the cadenced sweep (L10's 5/5/5/5/5/60/5 minute shape).

**Adopt, in order of leverage:**

1. **A V/TO-shaped single-page render** (`orchestrator:where` extended) — vision, 90-day priorities, top issues, on one rendered page.
2. **One Scorecard per project, one owner per row, leading indicators only** — built on the existing `metrics-rollup` substrate.
3. **Accountability Chart for agent seats** — define seats with five named accountabilities + GWC-shaped fitness, then assign skills/models.
4. **A consolidate-as-L10 cadence** with the 5/5/5/5/5/60/5 shape and an explicit IDS step over `proposals/`.
5. **Hard caps as constitution-level invariants** — 3–7 Rocks per milestone, 5–15 Scorecard rows, 6–10 documented core processes.

**Extend the constitution by one principle:** **VIII. Co-Location Over Cross-Reference** — when two artifacts must be reasoned about together, render them on one page. (This sharpens, rather than replaces, Principle VI.)

---

## 1. What EOS is, in operational terms

EOS (Gino Wickman, *Traction*, 2007) is built around six components, each with a named artifact and a hard cadence:

| Component | Primary artifact | Cadence | Hard cap |
|---|---|---|---|
| **Vision** | V/TO (Vision/Traction Organizer) — 2 pages, 10-yr → 90-day on facing pages | Annual refresh, quarterly review | 1 doc, 3–7 core values, 3–7 1-yr priorities |
| **People** | Accountability Chart (seats, not org chart) + GWC + People Analyzer | Quarterly review | 5 accountabilities per seat |
| **Data** | Scorecard — leading indicators, one-owner-per-row | **Weekly** review (5 min) | 5–15 measurables |
| **Issues** | Issues List + IDS (Identify–Discuss–Solve) | Weekly during L10 | Two lists: short-term, long-term |
| **Process** | "The [Company] Way" — documented + Followed By All | Quarterly audit | 6–10 core processes (the 20% that drives 80%) |
| **Traction** | Rocks + Meeting Pulse (Level 10) | 90-day Rocks; **weekly L10**; quarterly + annual offsites | 3–7 Rocks per company + per leader |

The integration mechanism is not a workflow engine — it's **co-location**:

- One V/TO. Sales and engineering do not have separate visions.
- One Scorecard at the leadership level. The sales pipeline metric and the ops uptime metric live on the same 5–15-row table reviewed at the same Monday meeting.
- One Accountability Chart. Cross-function handoffs land at named seats, not at "the team."
- One Issues List during the L10. A marketing-pipeline issue and an engineering-hiring issue are ranked against each other — leadership cannot optimize per silo.

The **Level 10 Meeting** is the cadence that makes the artifacts load-bearing. 90 minutes weekly, fixed agenda: Segue (5) → Scorecard (5) → Rock review (5) → Headlines (5) → To-Dos (5) → **IDS the Issues List (60)** → Conclude+rate (5). The 60-minute IDS allocation is the point: most of the meeting is *issue work*, not status. Status fits in 10 minutes because the Scorecard already tells the truth.

---

## 2. Ninety vs Strety — what the SaaS adds

Both products implement the EOS canon (V/TO, Accountability Chart, Rocks, Scorecards, L10, Issues, To-Dos, Process, 1-on-1s). They differentiate on positioning:

| Axis | Ninety.io | Strety |
|---|---|---|
| Posture | EOS-orthodox; deep certified-Implementer partner network | "EOS+"; collapses adjacent SaaS (PM, perf reviews, surveys, SOPs) |
| Slack/Teams | Adjunct integrations | **Native** — capture Issues/To-Dos from chat three-dot menu; L10 inside Teams |
| Adjacent features | Knowledge Portal, Mastery (learning), Surveys, Directory | Project Management (Kanban tied to Rocks), Perf Reviews, HR Center |
| AI | **Notably thin** — public AI page disclaims being an AI assistant | AI Suggestions for Rocks/Scorecards; also thin |
| Best fit | Company implementing with a certified Implementer | Team that wants to delete Asana + Lattice + the EOS tool and live in chat |

**The signal for us**: neither tool has shipped a serious AI-coaching layer. Both still treat the artifacts as forms-to-fill. There's a market gap between the EOS-tool category and what users now expect after a year of agentic products. An orchestrator-native version that *operates the cadence* rather than presenting forms is a wedge — but that's a downstream observation, not the point of this document.

---

## 3. The vocabulary mapping — EOS → orchestrator

The orchestrator already has the substrate. The mapping is mostly a renaming exercise plus a fusion render. **None of these should be net-new files** — they should be views over what's already on disk.

| EOS concept | Orchestrator surface today | Gap |
|---|---|---|
| **V/TO (Vision)** | `CLAUDE.md` "Project Status" + "Forward Roadmap" sections; `proposals/` briefs | No single page renders the 10-yr/3-yr/1-yr/quarter on one surface. Vision is implicit in milestone summaries. |
| **Core Values** | `.orchestrator/memory/constitution.md` (7 principles) | Already canonical. Strong fit. |
| **10-Year Target / Niche** | Scattered across CLAUDE.md, milestone-summary.md, proposal briefs | No declared, atomic statement of the long-horizon target. |
| **Accountability Chart** | Skill registry (`commands/*.md`), agent definitions in `.claude/agents/` | Skills are titled but not "seated" — no five-accountabilities-per-seat discipline, no GWC analog. |
| **Rocks (90-day priorities)** | Milestones (M*) | Already 90-day-shaped in spirit. **No hard 3–7 cap.** |
| **Scorecard** | `scripts/observability/metrics-rollup.sh`, [M027](../milestones/M027/index.md) efficiency-footer, [M019](../milestones/M019/index.md) Tier 1 JSONL | Exists, but not framed as a one-owner-per-row weekly leading-indicator board. |
| **Issues List** | `.orchestrator/proposals/` (long-term), blockers in execution log (short-term) | Two lists exist but aren't unified or worked through an explicit IDS shape. |
| **To-Do List** | Phase task plans (`tasks/T*-*.md`) | Already present. |
| **Core Processes (Followed By All)** | `commands/*.md`, `references/*.md`, `KNOWLEDGE.md` patterns | We have many; we have not declared which 6–10 are the **core** core. |
| **Level 10 cadence** | `orchestrator:consolidate`, `orchestrator:status`, `orchestrator:doctor` | Exist as separate commands. No single sweep applies the L10 shape. |
| **People Analyzer / GWC** | (Implicit in [M030](../milestones/M030/index.md) model selection) | No explicit fitness check per seat × skill/model pairing. |
| **Customer/Employee Headlines** | Recent commits, M027 cost dashboard | Not surfaced as headlines in any sweep. |

---

## 4. Constitution alignment — where EOS already fits

Going through the 7 principles in order:

1. **Context Minimization** — EOS's cross-cutting *less is more* principle (5–15 measurables, 3–7 Rocks, 6–10 processes, 90-min meeting) is the same constraint expressed at the org level. Adopting EOS hard caps strengthens, not strains, this principle.
2. **Evidence Before Claims** — the Scorecard's leading-indicator + binary off-track rule is a direct expression. A Rock is on-track or off-track, not "kind of progressing." The People Analyzer turns intuition into a scored grid. Strong fit.
3. **Design Before Code** — V/TO before Rocks before tasks is the macro-scale version of design before code. The Accountability Chart is *seat design before person assignment* — the org-level analog.
4. **Plans Assume Zero Context** — V/TO is explicitly a hand-off document. Each Issue is resolved with enough specificity that Solve "forever" is plausible. Strong fit.
5. **Fresh Context Per Unit** — the L10's 90-minute box and IDS's "solve forever" rule are fresh-context discipline at the meeting scale.
6. **State On Disk Is Truth** — the entire EOS premise. The V/TO is a physical document. The Scorecard is a real spreadsheet. The Accountability Chart is on the wall. Reality lives in artifacts, not in heads. Strongest fit of all.
7. **Knowledge Compounds** — the Process component is exactly this: capture the 20% that drives 80%, audit it as Followed By All, refine it. The Issues List, worked through IDS, is the org-level analog of the orchestrator's `lessons/` MEM nodes.

**EOS does not contradict any principle.** It *extends* them with hard caps and an explicit cadence — the things our constitution implies but does not enforce.

---

## 5. What to adopt, in order of leverage

Ranked by how much each unlocks for the orchestrator's "integrate product / engineering / GTM" vision. Each item maps to existing substrate; none requires net-new infrastructure.

### Adopt 1 — A V/TO-shaped single-page render (`orchestrator:where`)

The single most load-bearing EOS pattern is **one document, all functions, two pages, 10-year on the left, 90-day on the right**. The orchestrator already has the components scattered across `CLAUDE.md`, `milestone-summary.md`, and per-milestone files. Extend the queued [M029](../milestones/M029/index.md) `orchestrator:where` to render a V/TO-shaped page:

```
┌─────────────────────────────────────────────────────────┐
│ VISION                       │ TRACTION                 │
│  • Core values (constitution)│  • 1-Year Plan           │
│  • 10-Year Target            │  • Quarterly Rocks (≤7)  │
│  • Niche / Three Uniques     │  • Issues List (top 10)  │
│  • 3-Year Picture            │                          │
└──────────────────────────────┴──────────────────────────┘
```

**Reuses**: `KNOWLEDGE-INDEX.md`, milestone roadmaps, proposals/, constitution. **New**: a single rendered view + a `vision.md` file capturing the long-horizon items that don't fit anywhere today (10-yr target, niche, 3-yr picture).

**Why first**: this is the "integrate product / engineering / GTM" deliverable in its purest form. One page, no silos.

### Adopt 2 — One Scorecard, one owner per row, leading indicators only

The orchestrator already emits a metrics rollup (M019/M027). Reframe it as a **Scorecard** with EOS discipline:

- 5–15 rows, hard cap.
- One owner per row (a skill, a script, a person).
- Leading indicators only — token-cost-per-task, verification-pass-rate-on-first-attempt, plan-time-to-execution-time ratio, proposal-aging — not lagging milestone-completion counts.
- Red/green thresholds. Red three intervals running auto-files an Issue.

**Reuses**: M019 JSONL stream, `scripts/observability/`, M027 efficiency-footer. **New**: the discipline of *retiring* metrics that fail Raise/Add/Kill review. The orchestrator's biggest risk here is metric sprawl — the 5–15 cap is the load-bearing rule, not the metrics themselves.

### Adopt 3 — Accountability Chart for agent seats (seats before people)

Current state: skills are titled (`orchestrator:dispatch`, `orchestrator:verify`) but their *accountabilities* are implicit. EOS's discipline:

- Define the **seat** before assigning a person (read: model + skill).
- Each seat owns exactly **five named accountabilities**, no overlap.
- Test fit with **GWC**: Get it (understands the work), Want it (the seat is sized appropriately), Capacity (the model can actually do it within budget).

For the orchestrator this becomes: each command/skill has a seat description, and M030's adaptive model selection is exactly the GWC test ("does this model have capacity for this seat at this tier"). Wired together:

- A new `seats/` index alongside `commands/` (or frontmatter on each command file) declaring the five accountabilities.
- M030's tier router consults the seat description as input.
- A periodic seat audit asks: is any seat owned by a skill whose capacity score is below threshold for three consecutive runs? File an Issue.

**Why this matters for cross-functional integration**: when the orchestrator eventually owns sales/GTM workflows (proposal generation, pipeline tracking), each new function should land on **one named seat**, not "the GTM agent fleet." This prevents the matrix-org failure mode at the agent level.

### Adopt 4 — `orchestrator:consolidate` as a Level 10 sweep

Today `orchestrator:consolidate` archives verbose artifacts at milestone boundaries. EOS's L10 shape gives us a richer cadence for *project-level* consolidation, applicable mid-milestone:

| Phase | Time budget | Orchestrator analog |
|---|---|---|
| Segue | 5% | "Best result this week" — one win surfaced from the JSONL stream |
| Scorecard review | 5% | Red rows from the leading-indicator dashboard |
| Rock review | 5% | Phase status: on-track / off-track binary |
| Headlines | 5% | New patterns/lessons added to KNOWLEDGE-INDEX |
| To-Do review | 5% | Last-week task completion rate |
| **IDS** | **60%** | **Walk the proposals/ + execution-log blockers in priority order; resolve, defer, or kill** |
| Conclude / rate | 5% | Self-rated meeting score → meta-metric on the Scorecard |

The 60% IDS allocation is the point. Today's consolidate is closer to "fire and forget"; the L10-shaped sweep allocates most of the budget to **issue work**, which is where compounding happens. This becomes the orchestrator's own version of Principle VII (Knowledge Compounds) — operationalized.

### Adopt 5 — Hard caps as constitution-level invariants

EOS's caps are the discipline that keeps the framework working:

- **3–7 Rocks** per milestone (currently unbounded).
- **5–15 Scorecard rows** per project (currently unbounded).
- **6–10 documented core processes** (currently we have many; the *core* core isn't declared).
- **Five accountabilities per seat** (currently implicit).
- **90-minute L10 box** (currently consolidate has no time budget).

These belong in the constitution (or a new "operational invariants" doc) as hard, enforceable limits. The orchestrator already has hooks (M021/[M028](../milestones/M028/index.md) shape-guards) — these are a natural place for cap enforcement.

---

## 6. What to adapt, not adopt straight

- **Quarterly cadence** doesn't map cleanly. EOS's quarterly Rock-setting offsite assumes a 13-week season. The orchestrator's milestones are already roughly quarterly-shaped but variable; adopt the *discipline* (re-set Rocks at milestone close, not arbitrarily) without inventing a calendar.
- **People Analyzer for humans** doesn't apply. Adapt as **Seat Analyzer for skills** — score each skill on (a) does it satisfy its five accountabilities, (b) is the seat sized right, (c) can the assigned model carry it within budget. M030's adaptive routing already does (c); we'd add (a) and (b).
- **Annual V/TO refresh** maps to the project-genesis flow we already have (`orchestrator:start` → `ideation` → `specify`). The "annual" cadence becomes "every milestone-set boundary" — naturally event-driven.
- **L10 *meeting*** doesn't apply to autonomous runs — adopt the *agenda shape* as the consolidation pass structure, not a literal meeting.

---

## 7. What to reject

- **The certification economy.** EOS's revenue model depends on certified Implementers gating the orthodoxy. The orchestrator should ship the patterns directly in the bundle — no certifying authority, no orthodoxy enforcement, no upsell. This aligns with the launch-posture choice (CC-only, OSS-primary per `project_m026_oss_posture.md`).
- **Rigidity.** EOS's "do all six components or it doesn't work" stance is a known failure mode for creative/research-shaped orgs. Orchestrator-side: every adopted pattern should be **opt-in and reversible**, the same posture we took for [M013](../milestones/M013/index.md) GitHub integration (FR-11).
- **Meeting overload.** EOS's daily/weekly/quarterly/annual cadences add up. We adopt one cadence (L10-shaped consolidate) at one boundary; resist adding more layers until demand-driven.
- **Per-seat 1-on-1s.** EOS's 1-on-1 cadence is a human-management pattern. The orchestrator's analog (per-skill review) is the Seat Analyzer above; don't import the meeting form.

---

## 8. Proposed constitution extension — Principle VIII

The current 7 principles cover *individual* artifact discipline (zero-context plans, evidence before claims, fresh context per unit). EOS adds a load-bearing *organizational* discipline that's currently implicit:

> **VIII. Co-Location Over Cross-Reference.** When two artifacts must be reasoned about together, render them on one page. Cross-function alignment fails by default — the V/TO trick (10-year and 90-day on facing pages) is the cure. The orchestrator's substrate is on disk (Principle VI), but humans and agents both make worse decisions when forced to navigate between files. A single rendered view, even if synthesized, beats a directory of cross-references.

This sharpens Principle VI rather than replacing it. State on disk is still truth; the rendered view is a *projection*, not a new source.

If you don't want to extend the constitution, the equivalent is a `references/CO-LOCATION.md` doctrine doc — but the principle is load-bearing enough to deserve constitutional rank.

---

## 9. Sequencing — what would actually ship first

Ordered by effort × leverage, fitting the existing roadmap:

1. **Now** (no milestone needed): write `vision.md` capturing 10-yr target / niche / 3-yr picture in V/TO shape. Pure documentation, ~half a day. Forces us to articulate the long-horizon target we currently leave implicit.
2. **Folds into M029** (`orchestrator:where`): render the V/TO-shaped single page. The brief already exists; this is a scope clarification, not a new milestone.
3. **Folds into M027 follow-up**: reframe the metrics rollup as a 5–15-row Scorecard with one-owner-per-row + Raise/Add/Kill discipline. Small, mechanical.
4. **New milestone candidate, post-launch**: **Seat Analyzer + Accountability Chart** — declare the five accountabilities per skill, wire into M030 tier routing. Touches enough surfaces to deserve its own brief.
5. **New milestone candidate, post-launch**: **L10-shaped consolidate** — agenda-shaped consolidation pass over proposals + blockers. Could fold into the existing `orchestrator:consolidate` rather than ship separately.
6. **Constitution amendment** (independent PR, any time): Principle VIII + the hard caps as operational invariants. Bundles with the standalone constitution amendment already queued ([`.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`](../proposals/constitution-amendment-inclusion-criteria.md)).

The launch sequence ([M032](../milestones/M032/index.md)+[M033](../milestones/M033/index.md) paired → M029 → [M035](../milestones/M035/index.md) P02–P06) is not disturbed — items 2 and 3 fold into existing milestones; items 4 and 5 are post-launch fast-follows; the constitution amendment is independent.

---

## 10. The honest assessment

EOS gets adopted and dies in two ways: (a) the leadership team treats it as forms to fill rather than reality to confront, or (b) the certification orthodoxy crowds out judgment. Both are *implementation* failures, not framework failures. An orchestrator-native version sheds both — the agents don't have an ego to protect from a red Scorecard row, and we have no certifying authority to please.

The asymmetric upside is real: **we already have the substrate** (state on disk, milestones, proposals, metrics rollup, skill registry). EOS is essentially a naming and framing layer on top of it, plus three hard disciplines we don't enforce yet (caps, co-location, cadenced sweep). Adopting the framing makes the system *legible to humans who think in those terms* — which is most operators of mid-stage SaaS — without changing what's underneath.

The cross-functional integration vision the user asked about — product, engineering, GTM in one running system — falls out almost for free once the V/TO render exists. That's the one to ship first.

---

## References

Research survey conducted 2026-05-04 against:
- EOS Worldwide official content (V/TO, L10, Accountability Chart, Core Processes, Scorecard method)
- Ninety.io (features, AI page, roadmap, G2 reviews)
- Strety (features, integrations, Slack/Teams positioning)
- Critical perspectives (ScaleupExec, The Metiss Group, C-Suite Integrators, Fractional Partners)
- Comparison sources (MonsterOps, vendor counter-comparisons)

Full source list available on request — primary takeaways above are paraphrased from the survey, not quoted from any single source.

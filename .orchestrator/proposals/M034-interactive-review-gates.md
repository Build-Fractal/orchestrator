# Proposal: M034 — Interactive Review Gates

**Captured**: 2026-04-28 during lakeledger M066/P01 dogfooding session
**Shape**: Milestone (2 phases — schema first, gate second; P01 ships value standalone)
**Predecessors**: M014 (review-queue convention — `commands/comments.md` CON-5/SC-5 human-gated apply pattern), M016/M021/M028 (autonomous-run shape guards), M027 (cost+quality observability — informs walkthrough cost), M030 (adaptive model selection — routes the walkthrough agent), M033 P04 (materials-intake interactive reconciliation — UX precedent)
**Source**: 2026-04-28 operator session on lakeledger (a downstream Tier C project) M066/P01. Catalog-defining task T02 produced `M066-CATALOG.md` (197 lines), `M066-CATALOG-SUMMARY.txt` (49 lines), and `SIGNOFF.md` with `approved_by: null`. Phase plan halted by design and asked the operator to "review the artifact and populate SIGNOFF.md to approve." Operator declined the static-file-read flow, asked Claude-the-agent to walk through the load-bearing decisions conversationally instead. The walkthrough was materially better — each decision arrived with concrete impact tables ("at threshold 0.35, here are which lakes pass / fail"), tradeoffs framed as choices, and the option to push back. Of the catalog's 8 load-bearing decisions, the static read would have surfaced 2–3 as "hmm, do I agree?" The walkthrough surfaced 5–6 more because each came with concrete impact framing the artifact itself didn't carry. The walkthrough was Claude-the-agent improvising on top of the orchestrator, **not** an orchestrator stage — meaning the next operator who hits a contract-defining gate gets the same "go read the file" UX unless they happen to ask for a walkthrough.

## Goal

A first-class **interactive review gate** stage between artifact authoring and SIGNOFF.md population, that:

1. Reads a structured **decision packet** the artifact-writing agent emits (one entry per load-bearing decision: picked value, rationale, alternatives considered, concrete impact of each).
2. Walks the operator through them conversationally (`AskUserQuestion`-style in interactive runtimes; QUESTIONS.md hand-off in CI / `auto` mode).
3. Captures answers in `REVIEW.md` (append-only audit trail) and populates `SIGNOFF.md` from that.
4. **Opt-in per phase/task** via plan frontmatter — never a default.

The existing `SIGNOFF.md` primitive is **consumed**, not replaced. The existing `.orchestrator/comments/review-queue/` convention from M014 is the canonical shape — same architectural pattern (agent classifies → write structured artifact → human-gated apply), different domain (phase-execution decisions vs PR-comment spec-amendments).

## Why M034 (not extending M031 / M033 / comments queue)

**M031** scopes *small-task entry* — the universal `orchestrator <task>` invocation. Bundling phase-execution review gates into M031 dilutes its right-sized-entry framing and grows it materially.

**M033** scopes *first-time-user bootstrap* — the warm conversational front door. M033's interactive flows (constitution authoring, materials intake, ideation) are project-bootstrap-time, not phase-execution-time. The UX shape rhymes (M033 P04 prescribes "≤5 conflicts → terminal interactive, >5 → markdown hand-off" — exactly the shape M034 wants), but the scope is disjoint.

**`commands/comments.md` review queue** is the canonical sibling — same architectural pattern, different domain. M034 reuses the *convention* (queue dir + apply/reject scripts + JSONL audit + CON-5/SC-5 "never auto-applied" invariant), not the code (different domain, different artifact shape, different lifecycle).

**`orchestrator:verify`** runs *after* SIGNOFF; M034 sits *before* SIGNOFF. They compose — verify checks the artifact passed the gate, M034 ensures the gate had operator buy-in on load-bearing decisions.

Naming as a new milestone keeps M031's small-task contract clean, keeps M033's bootstrap UX focused, and gives M034 its own success criteria around decision provenance.

## Why post-launch (not pre-launch)

The pre-launch queue (M028→M030→M031→M032→M033→M029) targets **first-time users on small projects**. M034's scenario — a contract-defining gate inside an active Tier C run with 8 load-bearing decisions — is a **power-user workflow**. Important, but landing it pre-launch dilutes the launch milestones without sharpening the first-impression.

Two secondary reasons:

1. **Blast radius is real.** "Decision packet" is a new artifact type that touches every artifact-authoring task across `dispatch`, `auto`, and `verify`. That's a milestone, not a phase.
2. **M034 composes with milestones that are already shipping.** It consumes M027 (cost+quality observability for walkthrough-cost surfacing) and M030 (adaptive model routing for the walkthrough agent). Both already shipped or pre-launch — M034 reaps their outputs instead of co-developing.

Slot: post-launch fast-follow alongside M009 (multi-runtime parity, deferred), M010 (Managed Agents, deferred), M023 (design layer, deferred). Demand-driven prioritization within that bucket — M034 ships when a second downstream consumer hits the same friction lakeledger M066 surfaced.

If a strict pre-launch slot is needed (operator preference), the only defensible host is **a phase inside M031** — M031's Tier A+ middle flow (research → plan → build, no auto/roadmap/consolidate) is exactly the intensity tier where contract-defining gates live. But that grows M031's scope materially; recommend against bundling.

## Strict scope

This is the **decision-packet schema + interactive walkthrough + REVIEW.md audit trail**. It is **not**:

- A replacement for `SIGNOFF.md` — populates it.
- A replacement for `orchestrator:verify` — sits before it in the lifecycle.
- A new dispatch mode — the gate is opt-in metadata on existing tasks/phases.
- A general AskUserQuestion harness — M033 owns interactive UX patterns; M034 invokes them.
- A spec-amendment review surface — M014 owns that (review-queue) and M034 reuses its conventions only.
- A blocking default — opt-in per plan, never global.

M034 asks: *can the operator participate in load-bearing decisions at the moment they're being made, with concrete impact framing, instead of reverse-engineering them from a static artifact post-hoc?*

## Findings (root-cause analysis)

### Finding A: SIGNOFF.md is approve-or-don't, not deliberate-then-approve

**Evidence**: `SIGNOFF.md` template asks `approved_by: null` to be flipped to a name. No structure for *what* was reviewed, *which* decisions were load-bearing, or *what alternatives* were on the table. Operator must re-derive that scaffolding by reading the artifact line-by-line — which works for short artifacts and small decision counts, fails at scale (lakeledger M066/P01: 197-line catalog, 8 load-bearing decisions, ~25-40% of decision-impact visible from prose alone).

**Root cause**: SIGNOFF.md was designed as a **gate**, not a **review surface**. The gate part is correct — the review-surface part is missing.

**Fix shape**: a sibling artifact `DECISIONS.md` (decision packet) emitted by the artifact-writing task, structured as an array of `{id, summary, picked_value, rationale, alternatives_considered, concrete_impact_*}` entries. Schema versioned via frontmatter (mirroring `templates/compression-tier3-prompt.md` pattern from M018). Lives at the same directory level as the primary artifact (e.g., `M066-CATALOG.md` ↔ `M066-CATALOG-DECISIONS.md`).

**Impact**: P01 of M034. Ships value standalone — even without the walkthrough stage, a structured decisions packet gives `doctor` / `status` something to surface ("phase has N unreviewed load-bearing decisions"), gives M027 efficiency-footer a "decisions-per-task" axis, and gives operators reading the markdown a clearer surfacing of load-bearing items vs prose.

### Finding B: No interactive review stage between artifact-write and SIGNOFF

**Evidence**: `commands/auto.md` and `commands/dispatch.md` lifecycle: artifact-write task completes → next task dispatched (or phase enters summarizing). There's no stage that reads the artifact, surfaces load-bearing decisions, walks the operator through them, captures responses, and writes back into SIGNOFF.

**Root cause**: scope, correctly. The orchestrator's autonomous posture treats operator-interrupt as a CON-5/SC-5-class boundary (review-queue convention), but the only existing instance is M014's spec-amendment queue. No general-purpose interactive review primitive.

**Fix shape**: a new lifecycle stage `interactive_review` invoked by phase plans declaring `review_gates: [...]` in frontmatter. Stage reads `*-DECISIONS.md`, surfaces entries via `AskUserQuestion` (CC) / runtime-equivalent (Codex CLI / Cursor — falls back to QUESTIONS.md hand-off file), captures responses to `REVIEW.md` (append-only), populates `SIGNOFF.md` from REVIEW.md's terminal entry.

**Impact**: P02 of M034. Lands the full UX value. Without P01's packet, P02 has nothing to walk through; without P02, P01 is ~25-40% of the value (per the operator's lakeledger evidence).

### Finding C: `auto` mode parity is the hardest design question

**Evidence**: `commands/specify.md:38` documents `--yes` as auto-accepting clarify-loops under `auto` mode. `commands/auto.md` runs unattended; an interactive review gate that blocks indefinitely would deadlock every Tier C autonomous run that touches a review-gated phase.

**Root cause**: review gates by definition want a human; `auto` mode by definition doesn't have one in the loop.

**Fix shape**: review-gate metadata declares one of three `auto_mode` policies:
- `defer` — `auto` mode pauses at the gate, emits `pending-review` JSONL event, writes a continue-file, and exits cleanly. Operator runs `orchestrator:resume` after walkthrough. **Default** for declared review gates.
- `accept-with-audit` — `auto` mode auto-accepts all decisions, emits one `auto-accepted` JSONL event per decision for retroactive audit. Mirrors `--yes` semantics for clarify-loops. Available but not default.
- `block` — `auto` mode refuses to enter the phase; only interactive runs proceed. Strictest. Available for compliance-bound projects.

Policy choice declared in plan frontmatter; `orchestrator:auto` reads it before entering the phase and dispatches accordingly. CON-5/SC-5 invariant inherited: regardless of policy, the **decision artifact is always written** — only the operator-touch is gated.

**Impact**: blocks the entire feature without resolution. Must be settled in P01's design pass before P02's interactive stage lands.

### Finding D: Multi-runtime UX divergence

**Evidence**: M018/P07 already proved zero-LLM-tier byte-equality across CC / Codex CLI / Cursor (`scripts/diagnostics/m018-runtime-parity.sh`). But M034's interactive walkthrough wants a runtime-native question primitive — `AskUserQuestion` exists on CC, Codex CLI has its own equivalent, Cursor has another. Direct calls would fragment.

**Root cause**: no existing abstraction over runtime question primitives.

**Fix shape**: route the walkthrough through `dispatch-interface.sh` so the runtime adapter (`scripts/dispatch/adapters/backend/*.sh`) handles AskUserQuestion vs file-based fallback uniformly. Pattern follows M018/P07 — declare the contract in `references/RUNTIME-ASSUMPTIONS.md`, prove parity per fixture. Codex CLI / Cursor fallback: write `QUESTIONS.md`, exit cleanly, operator answers in editor and re-invokes — same shape as M033 P04's >5-conflicts hand-off.

**Impact**: not load-bearing for launch (CC-only at launch), but cleanest landing if M009 (multi-runtime parity audit) ships post-M034. If M034 ships before M009, M034's runtime-assumption rows are *the* runtime-parity entries until M009 broadens the audit.

## Phase outline (preliminary — refined by `orchestrator:specify` + roadmap)

| Phase | Goal | Touch list (preliminary) | Standalone? |
|---|---|---|---|
| **P00** (recommended) | Empirical baseline | Replay lakeledger M066/P01 walkthrough as fixture; capture the 8-decision packet structure + walkthrough transcript. Decision: schema field-set, `auto_mode` default, REVIEW.md format. | Yes — produces a captured-artifact-fixture used by P01 + P02 |
| **P01** | Decision-packet schema + writer integration | New template `templates/decisions-packet.md` (versioned frontmatter). New helper `scripts/knowledge/write-decisions.sh` (mirrors `write-summary.sh` shape, single-file, bash 3.2). Dispatcher emits packet alongside primary artifact when plan declares `decision_packet: true`. `doctor` + `status` surfaces "N unreviewed decisions." | Yes — packet is independently useful for audit + observability |
| **P02** | Interactive walkthrough stage + REVIEW.md + SIGNOFF integration | New lifecycle stage `scripts/lifecycle/interactive-review.sh`. New template `templates/review.md`. Runtime-routed AskUserQuestion via `dispatch-interface.sh`. SIGNOFF.md populated from REVIEW.md terminal entry. `auto`-mode `defer` / `accept-with-audit` / `block` policies. | No — depends on P01 packet |

P00 baseline runs against lakeledger M066/P01 as the canonical empirical fixture (operator already has the artifact + transcript — same model as M032's pbj-central P00 baseline).

## Sequencing & dependencies

- **Slots after launch.** Post-launch fast-follow bucket alongside M009 / M010 / M023.
- **Demand signal**: a second downstream consumer hitting the same friction. Until that signal, the dogfood evidence (lakeledger M066/P01) is *one* data point — strong but n=1.
- **No pre-launch dependency.** Nothing on the M028→M030→M031→M032→M033→M029 queue requires M034 to ship.
- **Composes with** M027 (cost surfacing for walkthrough cost), M030 (routes walkthrough agent to Sonnet/Haiku — surgical task character).
- **Reuses (do not duplicate)**:
  - `.orchestrator/comments/review-queue/` convention + CON-5/SC-5 invariant from `commands/comments.md`
  - `dispatch-interface.sh` runtime-routing pattern from M025
  - Versioned-frontmatter template shape from `templates/compression-tier3-prompt.md` (M018)
  - M033 P04's "≤N interactive, >N hand-off" UX threshold pattern

## Open questions (for `orchestrator:specify` to resolve)

1. **`DECISIONS.md` vs frontmatter-on-primary-artifact** — separate file (cleaner schema, dual-write cost) vs embedded YAML in the primary artifact (single source of truth, larger blast radius on schema change). Recommendation: separate file for v1; revisit if dual-write friction surfaces.
2. **`auto_mode` default** — `defer` (safest, but interrupts every autonomous run touching a review gate) vs `accept-with-audit` (preserves autonomy, defers operator-touch to retro-audit) vs require-explicit-declaration (no default; plan must opt-in to a policy). Recommendation: `defer` as default, with `accept-with-audit` as the declared override for projects that explicitly accept retro-audit.
3. **REVIEW.md placement** — task-level (`tasks/T##/REVIEW.md`) vs phase-level (`P##-REVIEW.md`) vs decisions-co-located (`*-REVIEW.md` next to `*-DECISIONS.md`). Recommendation: decisions-co-located mirrors SUMMARY/PLAN convention.
4. **AskUserQuestion vs richer prompts** — single-question-per-decision (simpler, more friction) vs grouped (denser, harder to capture nuance). Recommendation: single-question-per-decision for v1; revisit if walkthrough fatigue surfaces.
5. **Decision-packet emission triggering** — every artifact-writing task by default, with opt-out (`decision_packet: false`)? Or opt-in only, planner declares per task? Recommendation: opt-in only — minimizes churn on tasks that don't have load-bearing decisions, preserves the gate's "load-bearing" framing.
6. **Cost surfacing** — does M027 efficiency-footer get a `decisions:` axis (mirroring `compression:` from M018)? Recommendation: yes, but as part of P02's success criteria, not P01's.

## Constraints / antipattern compliance

- **AD-19 single-script-file shape** — every new script is a single file, no nested helpers in subdirs except via existing `scripts/<concern>/` sharding. `write-decisions.sh` and `interactive-review.sh` follow `write-summary.sh` and `auto-loop.sh` shape respectively.
- **Bash 3.2 + POSIX sh** — no associative arrays in helpers, no `${var,,}`, no process substitution in the hot path. Compliance verified per `references/file-formats.md`.
- **AP-009 (compound-chain-gt2)** — interactive walkthrough script invokes ≤2 commands per chain; longer flows route through `scripts/util/run-probe.sh`.
- **CON-5 / SC-5 (never auto-applied)** — inherited verbatim from `commands/comments.md`. Decision artifact always written; operator-touch gated; `auto` mode policies (`defer` / `accept-with-audit` / `block`) all preserve this.
- **Principle I (Context Minimization)** — packet schema stays tight; impact tables regenerated on demand by the walkthrough agent rather than embedded in the packet. Walkthrough payload bounded.
- **Principle II (Evidence Before Claims)** — directly *operationalized* by M034. Concrete impact tables (which lakes pass / fail at threshold X) are exactly what Principle II says decision-authoring should produce. Frame the proposal as *enforcing Principle II at sign-off boundaries*, not as new policy.
- **Principle III (Design Before Code)** — sign-off-gated artifact authoring is explicit Principle III territory. M034 makes the gate substantively reviewable.
- **Principle IV (Plans Assume Zero Context)** — packet entries are self-contained: each carries enough rationale + alternatives + impact for an operator with no surrounding context to make the call. Same standard as plan task-units.
- **Principle XVI (Distribution Surface Integrity)** — once `decisions-packet.md` template + `write-decisions.sh` ship, they go through M032's `--with-<feature>`-managed asset distribution if any project-local artifact is needed. (Likely none; templates live in the orchestrator bundle, packet artifacts live in project's `.orchestrator/milestones/`.)
- **`--yes` parity contract** — Finding C is the formal resolution. Inherits from `commands/specify.md:38` semantics.

## Cross-references

- **M014 review queue convention**: `commands/comments.md`, `scripts/comments/{comments,apply,reject}.sh` — canonical CON-5/SC-5 pattern. Reuse the convention, not the code.
- **M033 P04 reconciliation UX**: `.orchestrator/proposals/M033-onboarding-experience.md` Q6 ("≤5 → terminal interactive, >5 → markdown") — same UX threshold pattern; M034 inherits.
- **M027 efficiency footer + cost-rollup**: `scripts/diagnostics/efficiency-footer.sh`, `scripts/diagnostics/metrics-rollup.sh` — surfacing target for "decisions-per-task" axis.
- **M030 task-character classifier**: walkthrough is surgical-character (well-bounded, structured); routes to Sonnet/Haiku via M030's classifier.
- **M025 runtime adapters**: `scripts/dispatch/dispatch-interface.sh` + `scripts/dispatch/adapters/backend/*.sh` — runtime-routing of `AskUserQuestion` vs QUESTIONS.md fallback.
- **M018/P07 runtime parity**: `references/RUNTIME-ASSUMPTIONS.md` — M034 contributes new rows for interactive-review primitives if M009 hasn't broadened the audit yet.
- **`SIGNOFF.md` primitive**: existing artifact, consumed not replaced.

## Source material

- 2026-04-28 lakeledger M066/P01 dogfooding session: catalog spec (197 lines), summary (49 lines), SIGNOFF.md (`approved_by: null`), Claude-the-agent walkthrough transcript covering 8 load-bearing decisions
- Operator quote (verbatim): *"reading the file would have surfaced maybe 2-3 of them as 'hmm, do I agree with this?' The walkthrough surfaced the other 5-6 because each came with a concrete impact framing the file itself didn't carry."*
- Existing infrastructure to reuse:
  - M014 review-queue (`.orchestrator/comments/review-queue/`, `commands/comments.md`, `scripts/comments/`)
  - M025 runtime adapters (`scripts/dispatch/adapters/backend/`)
  - M018 versioned-template-frontmatter pattern (`templates/compression-tier3-prompt.md`)
  - M027 cost surfaces (efficiency-footer, metrics-rollup)
  - M033 P04 ≤N/>N interactive-vs-handoff threshold pattern
  - `SIGNOFF.md` primitive (existing)
- Sibling proposals:
  - `M033-onboarding-experience.md` — closest UX shape (P04 reconciliation) but disjoint scope (bootstrap vs phase-execution)
  - `M031-right-sized-entry.md` — alternative pre-launch host if operator decides to bundle (not recommended)
  - `constitution-amendment-inclusion-criteria.md` — Principle II framing reinforces M034's load-bearing rationale

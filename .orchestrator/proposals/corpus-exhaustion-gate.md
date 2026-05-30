# Proposal: Corpus-Exhaustion Gate

**Captured:** 2026-05-30
**Source:** Brett Kellgren (brett@fivestar.studio), via the PBJ Analyzer downstream project. Original handoff `/tmp/orchestrator-corpus-exhaustion-gate-proposal-2026-05-30.md` (ephemeral) — preserved verbatim in the Appendix below.
**Shape:** Phase 1 standalone paper-cut (blocking artifact checklist) + Phases 2–3 milestone-shaped (the `corpus-gate` automation + doctor lint/telemetry). Provisional milestone ID — pick from the open band when slotted.
**Standalone?** Phase 1 yes (single PR). Phases 2–3 demand-driven post-launch; strong composition with M040 (decision contradiction gate) suggests a paired/absorbed slot — see Triage.
**Predecessors / reuse:** conversus adapter (M011/P07, shipped) for the batched judge; M020 knowledge layer (`KNOWLEDGE-INDEX.md`, graph traversal, grep sweep); `orchestrator-conversus-gate` PASS|BLOCK convention; `orchestrator-verify` 4-tier + gate-artifact convention; build-context intensity profiles; M019 JSONL stream for Phase-3 telemetry.

## TL;DR

Downstream operators report that ~9 of 10 questions an agent drafts for an operator/SME are **already answered** somewhere in the project's stored knowledge — and the agent only discovers this after the operator says "go search the corpus first," at which point it answers its own question. Today this is mitigated only by **soft memory** (per-project habits like `exhaust-corpus-before-operator-questions`), which gets skipped because a habit isn't a gate.

The proposal: a **mandatory, evidence-producing corpus-exhaustion gate** that fires before any question reaches a human and before any plan/spec/roadmap is finalized. Per candidate question it (1) extracts search terms, (2) sweeps a configurable store manifest with cheap grep/index lookup, (3) runs a batched LLM judge to decide `ANSWERED | PARTIAL | IRREDUCIBLE`, (4) drops/rewrites answered questions, leaving only irreducible ones — and emits a per-question audit artifact that doubles as packet provenance. No artifact → **BLOCK**, mirroring the existing `BG-###` / conversus-gate / verify-ladder convention.

## The problem (downstream-observed, repeated)

When an agent drafts questions for an operator or SME, an operator estimate of ~9/10 turn out to be already answered in stored knowledge. Cost of the pattern:

- Wastes scarce operator/SME attention — the most expensive resource in a validator pilot.
- Erodes trust — asking an SME something they already answered reads as not listening.
- Risk: a question that's actually a *locked decision* gets re-litigated and can contradict a DR.

On the PBJ project the relevant guidance already exists as several memories (`exhaust-corpus-before-operator-questions`, `tier1-corpus-before-sme-packet`, `packet-audit-against-locked-drs`, `sme-packet-irreducible-question-bar`) — and it *still* gets skipped, because soft memory depends on the agent remembering. The fix must be **structural**.

## The proposal

A hard, evidence-producing gate before any question is posted to an operator/SME, and before any plan/spec/roadmap is finalized. No question reaches a human until the gate has proven it isn't already answered in the project's own knowledge.

### Checkpoints it fires at

1. **Before an SME/operator question packet is finalized** — `orchestrator:comments`, `materials-intake`, `discuss`, and any step that emits questions to a human.
2. **Before a plan/spec/roadmap is finalized** — `orchestrator:specify` (gate pass), `plan-phase` (must-haves / open questions), `roadmap`. Open questions embedded in plans get the same treatment as standalone SME questions.

### What it does — per candidate question / open item

1. **Extract search terms** — subject nouns, entity names, section IDs (e.g. `§2.4.1`), DR IDs, field names, SME names, dates.
2. **Sweep every configured knowledge store** (cheap deterministic grep / index lookup). The store manifest is **project-configurable** — orchestrator already knows these locations (the CLAUDE.md "Where current state lives" table + `.orchestrator/config.yml`). Default manifest:
   - `.orchestrator/DECISIONS.md` + `.orchestrator/decisions/*.md` (locked DRs)
   - `.orchestrator/memory/constitution.md`
   - `.orchestrator/KNOWLEDGE.md` + `knowledge/KNOWLEDGE-INDEX.md` (+ `knowledge.db` if healthy)
   - `knowledge/reference/**` (REF corpus) + `corpus-staging/**` + `extract-manifest.yaml`
   - `.orchestrator/spec/**` (source docs)
   - the session/runtime `MEMORY.md` + the `memory/` dir
   - milestone `**/*-SUMMARY.md`
   - SME-feedback artifacts via configured globs (`HANDOFF-*.md`, SME reply drafts, Slack exports)
3. **Judge each hit** (one batched LLM call): does any hit *answer* the question (fully / partially) or merely *mention* the topic? Grep finds candidates cheaply; the judge is the load-bearing step — a keyword hit is not an answer, semantic match is.
4. **Verdict per question:** `ANSWERED` (+ citation) · `PARTIAL` (+ citation + residual) · `IRREDUCIBLE` (searched, genuinely not answered).
5. **Auto-resolve:** drop `ANSWERED` questions from the packet, recording the found answer + citation in the audit trail (optionally promote to a new DR/memory). Rewrite `PARTIAL` to only the residual. **Only `IRREDUCIBLE` questions survive to the human.**

### Enforcement (hard gate, not advisory)

- The emitting skill **cannot finalize** a packet/plan unless a corpus-exhaustion **artifact** exists for it, with one verdict row per question + the search evidence. No artifact → **BLOCK**.
- Mirrors patterns orchestrator already has — hard build gates (`BG-###`), the conversus PASS|BLOCK gate (`orchestrator-conversus-gate`), and the 4-tier `orchestrator-verify`. Reuse the gate-artifact convention rather than inventing a new one.

### The artifact (audit trail + SME-trust dividend)

`corpus-exhaustion-<checkpoint>-<date>.md` (or JSONL): per question — search terms · stores searched · hits · verdict · citation/residual. Doubles as packet provenance: "we checked DECISIONS, the REF corpus, prior SME sessions, and memory; here is *why* this question is genuinely open." Showing that work to the SME itself raises trust.

### Integration with the existing "irreducible question bar"

The gate operationalizes the bar that's currently soft: by filtering `ANSWERED`/`PARTIAL`, it mechanically enforces "only irreducible questions reach the SME." Compose, don't duplicate.

## Design constraints / failure modes the implementer must handle

- **Configurable store manifest** — never hardcode paths; read from config so it works on every project regardless of layout.
- **Degrade gracefully when an index is broken.** Real example: PBJ's `KNOWLEDGE-INDEX.md`/`knowledge.db` rebuild has been broken since 2026-05-07; the gate must fall back to grep + `extract-manifest.yaml` and **log what it couldn't search**, never silently skip a store.
- **No silent truncation.** If the gate caps stores or terms, it must say so in the artifact. (Same discipline as the workflow "no silent caps" rule and `M031`'s `QUICK_BUDGET_DRIFT` surfacing.)
- **Cost control / intensity scaling.** Grep is cheap; batch the judge (one call per question, or one over the whole packet) instead of N sub-agents. Scale to the project intensity tier: **Quick** = grep + single judge; **Full** = per-question sub-agent + an adversarial "which store did we NOT search?" pass.
- **Don't deadlock.** If a store is unreachable, mark the question `IRREDUCIBLE-WITH-CAVEAT` and surface the caveat rather than hard-blocking forever.

## Where it slots in (concrete)

- **New reusable skill** `orchestrator:corpus-gate` (or extend the `orchestrator-conversus-gate` shape): input = candidate questions + checkpoint; output = filtered questions + artifact + PASS|BLOCK.
- **Callers add a pre-finalize hook** to: `specify`, `plan-phase`, `discuss`, `comments`, `materials-intake`, `roadmap`.
- **`orchestrator:doctor`** gains a lint: "packet/plan finalized without a corpus-exhaustion artifact" → flag (catches bypasses). Sibling to the `DOCTOR:KNOWLEDGE_GAP` check in `papercut-doctor-knowledge-gap-surface.md` — both surface negative space in the knowledge loop; bundle if the two land together.
- Optionally surface a config knob for the store manifest + per-checkpoint intensity.

## Suggested phased rollout

1. **Phase 1 (cheap, immediate; standalone PR):** a blocking checklist/hook — no packet/plan finalizes without a corpus-exhaustion artifact whose rows assert "searched [stores], result: not-found" per question. Even manual, this catches the 9/10. Ships any time, no demand-signal required.
2. **Phase 2 (the automation; milestone-shaped):** the `corpus-gate` skill that does the grep-sweep + batched judge + auto-resolve, producing the artifact deterministically.
3. **Phase 3:** doctor lint + telemetry (how many questions were auto-answered vs. reached the SME — a direct measure of the problem and of the gate's value), reusing the M019 JSONL stream.

## Triage (upstream-maintainer disposition, 2026-05-30)

**Disposition:** captured as a future-milestone brief; **not promoted** to the active queue yet (proposals are living docs; promotion is deliberate). Phase 1 is independently shippable as a paper-cut in any sweep window.

### Composition with existing/queued surfaces — compose, don't duplicate

- **M040 (ambient feedback loop) — decision contradiction gate.** M040's contradiction gate already fires a **two-agent conversus pass on every `DECISIONS.md` write** (PASS / FLAG / BLOCK, BLOCKs routed through `commands/comments.md`). That is the *same mechanism* this proposal needs for the "is this question actually a locked decision?" risk in §The problem. The corpus-gate's DR-corpus sweep + judge is a near-sibling of M040's contradiction sweep. **Recommend evaluating absorption into M040 / a shared two-agent-conversus-sweep primitive** at queue-entry time, the same way M034/M038/M040 share the decision-packet shape. The PASS|BLOCK + human-gated-apply plumbing would be reused wholesale.
- **`orchestrator-conversus-gate`.** The proposal explicitly suggests extending this shape — correct. The batched judge is a cooperative two-agent deliberation producing a structured verdict; the existing gate skill is the template.
- **`orchestrator-verify` + `BG-###` build gates.** The artifact-or-BLOCK enforcement reuses the established gate-artifact convention. No new enforcement primitive.
- **`papercut-doctor-knowledge-gap-surface.md`.** Phase 3's doctor lint is a sibling to the `DOCTOR:KNOWLEDGE_GAP` negative-space check. Bundle the two doctor checks if they land in the same window.
- **M034 (interactive review gates) — decision-packet schema.** The `IRREDUCIBLE` questions that survive the gate are natural inputs to M034's interactive walkthrough; a surviving question + its search-evidence artifact is decision-packet-shaped. If M034 ships first, the corpus-gate feeds it.
- **M038 (living documents) — section-level binding.** The artifact's citations (`§2.4.1`, DR IDs) are exactly the code/doc anchors M038 binds; an `ANSWERED` verdict could bind to a living-doc section so the answer travels with the source.
- **M020 knowledge layer / build-context profiles.** The grep sweep and intensity scaling reuse existing traversal + `--profile=quick|standard|full` machinery rather than inventing a new context budget.

### Dependencies

No hard blockers. Phase 2's judge needs the conversus adapter (M011/P07, shipped) and the M020 knowledge layer (shipped). Phase 3 telemetry needs the M019 JSONL stream (shipped). Phase 1 needs none of the above — it is a checklist + a `doctor`-style enforcement check.

### Sequencing recommendation

- **Phase 1** ships now as a standalone paper-cut — it is the cheapest catch of the 9/10 and needs no automation. Strong candidate for the next paper-cut sweep window.
- **Phases 2–3** are demand-driven post-launch. **Do not author as a fresh standalone milestone before checking M040's queue-entry absorption decision** — the contradiction-gate overlap is strong enough that a sibling-or-absorbed slot is likely the right shape. Slot in the same demand-driven band as M034 + M038 + M040 (the decision-packet / two-agent-sweep family).

### Open questions for queue-entry

- **Q1 — absorb into M040 or stand alone?** The two-agent-conversus-sweep + PASS|BLOCK + human-gated-apply plumbing is shared. Resolve at the same time as the M034/M038/M040 absorption decision.
- **Q2 — artifact format.** Markdown (human-readable provenance for the SME) vs JSONL (machine-queryable for Phase-3 telemetry) vs both. The SME-trust dividend argues for at least a human-readable projection; the telemetry argues for JSONL. Likely JSONL source-of-truth + rendered Markdown projection, matching the M019→surface pattern.
- **Q3 — auto-promote `ANSWERED` to DR/memory?** The proposal floats this as optional. Auto-promotion risks DR-corpus pollution; recommend default-off, with a flagged suggestion routed through the `comments` apply queue (consistent with M040's BLOCK-routing posture).
- **Q4 — judge false-negative blast radius.** If the judge wrongly marks a genuinely-open question `ANSWERED`, the SME never sees it and the gap surfaces late. Mitigation: the artifact records the cited answer, so a wrong `ANSWERED` is auditable after the fact; Full intensity adds the adversarial "which store did we NOT search?" pass. Worth an explicit confidence-threshold knob (low-confidence `ANSWERED` → downgrade to `PARTIAL` so the residual still reaches the human).

## One-line summary

Make "search everything orchestrator already stores, and prove the question is genuinely open" a **hard gate with an audit artifact** before any question reaches a human — turning the soft "exhaust the corpus first" habit into structure that can't be skipped.

---

## Appendix — original downstream handoff (verbatim)

> Preserved here because the source path `/tmp/orchestrator-corpus-exhaustion-gate-proposal-2026-05-30.md` is ephemeral.

```markdown
# Proposal: a Corpus-Exhaustion Gate for Orchestrator

**For:** the upstream agent maintaining Orchestrator (the meta-framework), not this project.
**From:** Brett Kellgren (brett@fivestar.studio), via the PBJ Analyzer project.
**Date:** 2026-05-30.

## The problem (observed repeatedly)

When an agent drafts questions for an operator or a subject-matter expert (SME), a large
fraction — operator estimate ~9 out of 10 — turn out to be **already answered** somewhere in the
project's stored knowledge. The agent only discovers this when the operator says "go back through
the corpus, memories, decisions, and feedback first," at which point the agent searches and
**answers its own question.**

Cost of the pattern:
- Wastes scarce operator/SME attention (the most expensive resource in a validator pilot).
- Erodes trust — asking an SME something they already told you reads as not listening.
- Risk: a question that's actually a *locked decision* can get re-litigated and contradict a DR.

Today this is mitigated **only by soft memory** ("exhaust corpus before operator questions") that
depends on the agent remembering to do it. On this project the relevant guidance already exists as
several memories (`exhaust-corpus-before-operator-questions`, `tier1-corpus-before-sme-packet`,
`packet-audit-against-locked-drs`, `sme-packet-irreducible-question-bar`) — and it *still* gets
skipped, because a habit isn't a gate. It needs to be **structural**.

## The proposal

A **mandatory, evidence-producing corpus-exhaustion gate** that fires before any question is posted
to an operator/SME, and before any plan/spec/roadmap is finalized. No question reaches a human until
the gate has proven it isn't already answered in the project's own knowledge.

### Checkpoints it fires at
1. **Before an SME/operator question packet is finalized** — `orchestrator:comments`,
   `materials-intake`, `discuss`, and any step that emits questions to a human.
2. **Before a plan/spec/roadmap is finalized** — `orchestrator:specify` (gate pass),
   `plan-phase` (must-haves / open questions), `roadmap`. Open questions embedded in plans get the
   same treatment as standalone SME questions.

### What it does — per candidate question / open item
1. **Extract search terms** from the question: subject nouns, entity names, section IDs (e.g.
   `§2.4.1`), DR IDs, field names, SME names, dates.
2. **Sweep every configured knowledge store** (cheap deterministic grep / index lookup). The store
   manifest is **project-configurable** — Orchestrator already knows these locations (the CLAUDE.md
   "Where current state lives" table + `.orchestrator/config.yml`). Default manifest:
   - `.orchestrator/DECISIONS.md` + `.orchestrator/decisions/*.md` (locked DRs)
   - `.orchestrator/memory/constitution.md`
   - `.orchestrator/KNOWLEDGE.md` + `knowledge/KNOWLEDGE-INDEX.md` (+ `knowledge.db` if healthy)
   - `knowledge/reference/**` (REF corpus) + `corpus-staging/**` + `extract-manifest.yaml`
   - `.orchestrator/spec/**` (source docs)
   - the session/runtime `MEMORY.md` + the `memory/` dir
   - milestone `**/*-SUMMARY.md`
   - SME-feedback artifacts via configured globs (`HANDOFF-*.md`, SME reply drafts, Slack exports)
3. **Judge each hit** (one batched LLM call): does any hit *answer* the question (fully / partially)
   or merely *mention* the topic? Grep finds candidates cheaply; the judge is the load-bearing step
   (a keyword hit is not an answer — semantic match is).
4. **Verdict per question:** `ANSWERED` (+ citation) · `PARTIAL` (+ citation + residual) ·
   `IRREDUCIBLE` (searched, genuinely not answered).
5. **Auto-resolve:** drop `ANSWERED` questions from the packet, recording the found answer + citation
   in the audit trail (optionally promote to a new DR/memory). Rewrite `PARTIAL` to only the residual.
   **Only `IRREDUCIBLE` questions survive to the human.**

### Enforcement (hard gate, not advisory)
- The emitting skill **cannot finalize** a packet/plan unless a corpus-exhaustion **artifact** exists
  for it, with one verdict row per question + the search evidence. No artifact → **BLOCK**.
- This mirrors patterns Orchestrator already has — hard build gates (`BG-###`), the conversus
  PASS|BLOCK gate (`orchestrator-conversus-gate`), and the 4-tier `orchestrator-verify`. Reuse that
  gate-artifact convention rather than inventing a new one.

### The artifact (audit trail + SME-trust dividend)
`corpus-exhaustion-<checkpoint>-<date>.md` (or JSONL): per question — search terms · stores searched ·
hits · verdict · citation/residual. This doubles as packet provenance: "we checked DECISIONS, the REF
corpus, prior SME sessions, and memory; here is *why* this question is genuinely open." Showing that
work to the SME itself raises trust.

### Integration with the existing "irreducible question bar"
The gate operationalizes the bar that's currently soft: by filtering out `ANSWERED`/`PARTIAL`, it
mechanically enforces "only irreducible questions reach the SME." Compose, don't duplicate.

## Design constraints / failure modes the implementer must handle
- **Configurable store manifest** — never hardcode paths; read from config so it works on every
  project regardless of layout.
- **Degrade gracefully when an index is broken.** Real example: this project's
  `KNOWLEDGE-INDEX.md`/`knowledge.db` rebuild has been broken since 2026-05-07; the gate must fall
  back to grep + `extract-manifest.yaml` and **log what it couldn't search**, never silently skip a
  store.
- **No silent truncation.** If the gate caps stores or terms, it must say so in the artifact.
- **Cost control / intensity scaling.** Grep is cheap; batch the judge (one call per question, or one
  over the whole packet) instead of N sub-agents. Scale to the project intensity tier: Quick = grep +
  single judge; Full = per-question sub-agent + an adversarial "which store did we NOT search?" pass.
- **Don't deadlock.** If a store is unreachable, mark the question `IRREDUCIBLE-WITH-CAVEAT` and
  surface the caveat rather than hard-blocking forever.

## Where it slots in (concrete, for the upstream agent)
- **New reusable skill** `orchestrator:corpus-gate` (or extend the `orchestrator-conversus-gate`
  shape): input = candidate questions + checkpoint; output = filtered questions + artifact +
  PASS|BLOCK.
- **Callers add a pre-finalize hook** to: `specify`, `plan-phase`, `discuss`, `comments`,
  `materials-intake`, `roadmap`.
- **`orchestrator:doctor`** gains a lint: "packet/plan finalized without a corpus-exhaustion
  artifact" → flag (catches bypasses).
- Optionally surface a config knob for the store manifest + per-checkpoint intensity.

## Suggested phased rollout
1. **Phase 1 (cheap, immediate):** a blocking checklist/hook — no packet/plan finalizes without a
   corpus-exhaustion artifact whose rows assert "searched [stores], result: not-found" per question.
   Even manual, this catches the 9/10.
2. **Phase 2 (the automation):** the `corpus-gate` skill that does the grep-sweep + batched judge +
   auto-resolve, producing the artifact deterministically.
3. **Phase 3:** doctor lint + telemetry (how many questions were auto-answered vs. reached the SME —
   a direct measure of the problem and of the gate's value), reusing the M019 JSONL stream.

## One-line summary
Make "search everything Orchestrator already stores, and prove the question is genuinely open" a
**hard gate with an audit artifact** before any question reaches a human — turning the soft
"exhaust the corpus first" habit into structure that can't be skipped.
```

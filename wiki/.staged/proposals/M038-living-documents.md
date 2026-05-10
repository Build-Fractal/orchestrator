# Proposal: M038 — Living Documents (framework-owned primitive)

**Captured**: 2026-05-06 from LakeLedger upstream RFC
**Shape**: Post-launch milestone, demand-driven. Sibling/overlap with M034 (interactive review gates) — final shape decided when arc enters queue.
**Predecessors**: [M020](../milestones/M020/index.md) (knowledge-graph layer — node/edge schema M038 extends), [M030](../milestones/M030/index.md) (adaptive model selection — for any LLM-routed binding-detection or section-summarization work), [M032](../milestones/M032/index.md) (wiki distribution — review-surface output mode), [M013](../milestones/M013/index.md) (review-queue convention — CON-5/SC-5 human-gated apply pattern), **M034 (interactive review gates — strong primitive overlap, see § "Relationship to M034")**.
**Source**: 2026-05-06 upstream RFC from LakeLedger (lake-health platform, ~2 years GSD → orchestrator history). Concrete reference artifact: `.planning/MATT-RULES-AUDIT.md` — a 2,400-line evolving rules document the lake manager (Matt) reviews and locks numeric thresholds, alert behaviors, and tier definitions in. Code changes to alert thresholds are bound to audit-doc updates by an in-project convention (`CON-2: audit-doc-same-change-set`) and per-phase grep verifiers (`tools/verify/m###-p##-audit-doc-updated.sh`). The RFC argues this scaffolding is reinvented per project today and should be framework-owned.

## Status

**RFC capture only.** Implementation deferred post-launch, demand-driven within the post-launch fast-follow queue. The brief below is the LakeLedger RFC verbatim with editorial overlay (relationship-to-M034 section, sequencing notes). When the arc enters the queue, this proposal becomes the input to `orchestrator:specify M038` and grows into a full brief.

## TL;DR (from upstream RFC)

Real projects accumulate one or more **living documents** — markdown files that capture business rules, thresholds, decision logs, or domain-expert sign-offs that evolve in lockstep with code but cannot be re-derived from code (because they encode *intent* and *reviewer history*, not just behavior). The framework currently has no first-class concept for these. Today they're managed by hand-rolled per-project conventions: sentinel sentences, manual grep verifiers, commit-message discipline, frontmatter checkboxes. That's brittle (adoption drift, plan-time blind spots, reviewer UX is grep) and doesn't scale across projects.

This proposal captures a generic **Living Document** primitive — detection, storage, graph binding, planner injection, verifier auto-generation, and an optional wiki-rendered review surface — modeled on the LakeLedger MATT-RULES-AUDIT.md pattern but framework-owned and project-agnostic.

## Relationship to M034 — strong primitive overlap

**This is the load-bearing decision when M038 enters the queue.** M034 (interactive review gates, post-launch fast-follow per [`.orchestrator/proposals/M034-interactive-review-gates.md`](../proposals/M034-interactive-review-gates.md)) already specifies a **decision-packet schema** (P01) + interactive walkthrough (P02). The decision-packet primitive is ~80% the same primitive as M038's living-doc section binding:

| Dimension | M034 decision-packet | M038 living-doc section |
|---|---|---|
| Granularity | Per artifact-decision | Per document section |
| Cadence | One-shot (per phase task) | Continuously evolving |
| Reviewer state | `verdict + rationale + alternatives + impact` | `pending / shipped / blocked / deferred / re-confirm-needed` |
| Sign-off surface | `SIGNOFF.md` populated from `REVIEW.md` | `sentinel: "Pass N (slug)"` paragraph + `status: shipped:<date>` field |
| Persistence | Per-phase artifact | Append-only decision-history per section |
| `auto`-mode policy | `defer / accept-with-audit / block / warn` (per plan frontmatter) | TBD — same pattern likely applies |
| Code-anchor binding | Optional (decision-packet may reference files) | Load-bearing (binding *is* the primitive) |

Three resolution paths to flag — decide at queue-entry time, not now:

1. **(a) M038 absorbs M034** — living-docs become the general primitive; decision-packets are a special case (single-section living-doc with one-shot review cadence). Argues for the bigger primitive being the right shape, with the smaller use case as a config / preset.
2. **(b) M034 absorbs M038** — gates become the general primitive; living-docs are a long-running variant with section-level granularity and continuous review cadence. Argues for shipping M034 first (smaller, tighter scope) and growing it.
3. **(c) Sibling milestones with shared schema** — both ship; share the underlying decision-packet / section-binding shape; reuse `commands/comments.md` review-queue convention; differ on lifecycle and granularity. Lowest absorption risk; highest scaffolding cost.

**Recommendation when the arc enters the queue**: option (b) or (c). M034 is smaller, has one concrete dogfood case (LakeLedger M066/P01), and can ship the schema-first phase (P01) standalone with M038 reusing it. M038's full vision (detection / wiki rendering / cross-doc consistency / 9 lifecycle commands / 7 bonus features) is multi-phase milestone scope and benefits from M034's primitive being already in production when M038 begins.

**For now** (RFC-capture phase): treat M034 and M038 as a paired demand-driven slot. When LakeLedger or a second downstream consumer signals "we need this," the work begins with revisiting (a)/(b)/(c).

## Why post-launch (not pre-launch)

Same reasoning as M034: this is **power-user workflow scope**, not first-impression scope. The pre-launch queue ([M037](../milestones/M037/index.md) → [M035](../milestones/M035/index.md) P00+P01 → M035 P02–P06) targets first-time users on small projects; living-docs land when projects accumulate enough decision-state and reviewer-history to justify the scaffolding.

Demand signal: LakeLedger is currently dogfooding the symptom hand-rolled (CON-2 + per-phase verifier scripts × 3 milestones in a row). That's a real signal but one that's already being managed in-project. Pre-launch insertion would dilute launch milestones; post-launch insertion ships when LakeLedger's friction or a second consumer's friction surfaces.

## Strict scope (when arc enters queue)

This is the **living-document primitive + section binding + planner injection + optional wiki review surface**. It is **not**:

- A replacement for `SIGNOFF.md` — composes with it (post-M034) or with section-status fields (M038-only).
- A general-purpose markdown linter — bindings are domain-specific, not stylistic.
- A spec-amendment review surface — `commands/comments.md` review-queue covers that; M038 reuses the convention only.
- A net-new knowledge-graph storage layer — extends M020's existing schema, not replaces it.
- A blocking default — registration is opt-in per project; bindings are opt-in per section.

## Suggested first cut (from RFC §11, smallest viable shape)

If the team wants to ship this incrementally, the minimum-viable cut that captures most of the value:

1. `orchestrator:living-doc declare <path>` + `.orchestrator/living-docs/index.json` (no markdown rewrite).
2. Sidecar bindings file (Option B from RFC §4) — skip Option A (inline HTML markers) for v1; let projects opt in to inline markers later.
3. **Planner injection only** — no auto-generated verifier yet, no wiki integration. When a phase plan touches a bound code anchor, the planner agent's payload carries the binding alert.
4. `orchestrator:living-doc audit` — single CLI that reports "your current diff touches bound anchors X, Y; sections A, B should be edited."

This is ~ a week of work for one engineer and would already retire the per-project hand-rolled CON-2 + verifier-script ceremony in LakeLedger. Wiki integration, auto-verifier, cross-doc consistency, and the 7 bonus features (RFC §9) can land in subsequent passes / sub-milestones.

## RFC body — captured verbatim from upstream

> The remainder of this section is the LakeLedger RFC body, preserved verbatim so design intent is not lost between sessions. When M038 enters the queue, the queue-entry pass authors a full brief in this proposal's structure and may amend / reshape the RFC sections; the RFC body below is the source-of-truth capture.

### 1. The pattern, abstracted

A **living document** has these properties:

- It encodes **decisions** that a reviewer (often a domain expert, not a developer) needs to sign off on, lock, or revisit. The decisions are not derivable from code — they're the *intent* the code implements.
- It is **edit-frequency high** relative to general docs: every related code change should ideally produce one edit.
- It has **section-level granularity**: not every code change touches the whole document. Specific sections bind to specific code anchors (file:line, function name, constant name, behavior).
- It carries **review state** per section: pending / shipped / blocked / deferred / re-confirm-needed.
- It has a **sentinel-and-anchor convention** that's almost always reinvented per project (in LakeLedger: `Pass N (slug)` strings + `CON-2` rule + per-phase verifier scripts).

Examples beyond LakeLedger: API contract docs that bind to handler implementations; threat-model docs that bind to security-sensitive code paths; pricing/billing rule books that bind to billing engine code; compliance attestation docs that bind to data-handling code; game-design balance sheets that bind to combat-formula constants; onboarding-flow specs that bind to UI components + copy.

The framework's current answer is "encode it in spec.md and let the planner read it." That doesn't fit because: spec.md is one-shot per milestone (not continuously evolving); spec.md doesn't carry reviewer-state (living docs *are* the reviewer-state); real living docs are domain-expert-authored, not developer-authored.

### 2. Detection — auto-identification heuristics

Heuristic signals (any one or two should trigger a *suggestion*, not a hard claim):

| Signal | Evidence in LakeLedger |
|---|---|
| **Filename pattern** | `*RULES*`, `*AUDIT*`, `*DECISIONS*`, `*CONVENTIONS*`, `*THRESHOLDS*`, `*REVIEW*`, `*HANDBOOK*` — not in `.orchestrator/` itself |
| **Repeated checkbox state** | `☐ ... ☑ ...` decision-needed/decision-shipped pairs (LakeLedger: 200+ such pairs) |
| **Numbered section anchors with cross-references** | "see §11.10", "per §2.1 row 3" — section-level addressability is the tell |
| **Code-anchor citations** | Inline backticks like `` `lib/alerts/evaluator.ts:39` `` |
| **High edit frequency** | git log over the last N commits shows this file in >X% of merge commits |
| **Cross-cited from commit messages** | Commits mention the file by basename in body text |
| **Reviewer-name patterns** | "Matt's lock", "Matt's revised ladder", "per Matt 2026-05-05" |

**Surface as suggestion, not assertion.** When `orchestrator:init` (or `orchestrator:doctor`) sees a candidate, it prompts: "I noticed `.planning/MATT-RULES-AUDIT.md` looks like a living document — it carries 47 decision-checkboxes, cites 38 code anchors, and has been touched in 23 of the last 30 milestone-close commits. Want to register it as a living document so future phases auto-bind to its sections? [y/n/explain]"

### 3. Registration shape

```json
// .orchestrator/living-docs/index.json
{
  "docs": [
    {
      "id": "matt-rules-audit",
      "path": ".planning/MATT-RULES-AUDIT.md",
      "owner": "Matt (lake manager)",
      "review_cadence": "as-shipped",
      "sentinel_pattern": "Pass {N} ({slug})",
      "section_id_strategy": "header-numbered"
    }
  ]
}
```

Registration **does not** rewrite the document itself by default. Section-binding is opt-in (next section). Operator-friendliness rule: registration alone is a no-op for document content.

### 4. Section-level binding — the load-bearing primitive

**Option A — inline HTML comment markers** (lowest-friction, machine-readable, invisible in rendered markdown):

```markdown
### 11.10 DO tiers — your 2026-05-05 revision
<!-- orchestrator:section id="11.10" anchors="lib/alerts/evaluator.ts:DO_CRITICAL_LOW,lib/alerts/evaluator.ts:DO_WARNING_LOW" reviewer="matt" status="shipped:2026-05-06" sentinel="Pass 3 (do-ladder)" -->
```

**Option B — sidecar file** (`.orchestrator/living-docs/matt-rules-audit.bindings.yaml`) for projects that don't want HTML comments in source markdown:

```yaml
sections:
  "11.10":
    title: "DO tiers — your 2026-05-05 revision"
    anchors:
      - { file: lib/alerts/evaluator.ts, symbol: DO_CRITICAL_LOW }
      - { file: lib/alerts/evaluator.ts, symbol: DO_WARNING_LOW }
    reviewer: matt
    status: shipped
    last_review: 2026-05-06
    sentinel: "Pass 3 (do-ladder)"
```

Both supported. Anchor shapes: `file:line` (brittle but precise), `file:symbol` (resilient, **recommended default**), `glob:pattern` (fuzzier).

**Anchor resolution lazy and tolerant.** Stale bindings produce warnings, not hard errors — the binding might be intentional historical context. Stale-binding cleanup belongs in `orchestrator:living-doc audit --fix`, not normal command flow.

### 5. Knowledge graph integration

- **Node type:** `living-doc/section`
- **Properties:** `doc_id`, `section_id`, `title`, `reviewer`, `status`, `last_review`, `sentinel`
- **Edges:** `living-doc/section --binds-to--> code/anchor`, `living-doc/section --cross-references--> living-doc/section`, `code/anchor --bound-by--> living-doc/section`, `spec/requirement --realizes--> living-doc/section`

**Killer feature: planner injection.** When a phase plan touches a bound code anchor, the planner agent's payload carries:

```
LIVING-DOC BINDING ALERT
  Phase plan touches: lib/alerts/evaluator.ts:DO_WARNING_LOW (line 44)
  Bound to: .planning/MATT-RULES-AUDIT.md §11.10 ("DO tiers")
  Current section status: shipped:2026-04-12 (Pass 2 (warning-floor))
  Reviewer: matt
  Per CON-2 (audit-doc-same-change-set): schedule audit-doc edit + new sentinel + per-phase verifier.
```

This retires the LakeLedger CON-2 + per-phase-verifier ceremony — new projects get it for free.

### 6. Mechanical sync — verifier auto-generation

LakeLedger writes a fresh `tools/verify/m###-p##-audit-doc-updated.sh` per phase (~50 lines, 95% boilerplate). Framework should generate these. Phase plan declares:

```yaml
verification:
  - bash tools/verify/m072-p03-tests-pass.sh
  - orchestrator: living-doc-gate
    doc: matt-rules-audit
    sections: ["11.10", "2.1", "3.5", "11.6"]
    sentinel: "Pass 3 (do-ladder)"
```

Gate asserts: each named section touched in commit range; sentinel string present in each touched section; section status moved from `pending` (or prior shipped) to new shipped state.

### 7. Review surface — wiki integration

Living-doc sections render as wiki pages (one section per page or per top-level header). Frontmatter shows reviewer / status / last_review / anchors / history. Comment thread per page (giscus). Reviewer gets filtered "what needs sign-off" view (`reviewer=matt AND status=pending`). Each anchor renders as permalink to code at bound version.

Wiki rendering is an **output mode** of the source-of-truth markdown — not a fork. Markdown stays canonical; wiki generated. Comments / sign-offs flow back via sync pass or stay in wiki with markdown-side "see wiki for review thread" link.

### 8. Lifecycle commands

```
orchestrator:living-doc declare <path>
orchestrator:living-doc bind <doc> <section> <code-anchor>
orchestrator:living-doc audit
orchestrator:living-doc gate <phase-id>
orchestrator:living-doc graph <doc>
orchestrator:living-doc review <doc> [--reviewer=<name>] [--status=<state>]
orchestrator:living-doc wiki-sync <doc>
orchestrator:living-doc drift
```

### 9. Bonus ideas (not load-bearing)

**9.1 Cross-doc consistency** — bind same business rule across code + audit doc + onboarding + in-app help + README. Editing the section prompts updates to all bound surfaces.

**9.2 Drift detection** — compare audit-doc claims against actual code state. "Did we ship what we said we shipped?" gate.

**9.3 Reviewer profiles** — multi-domain projects with multiple reviewers (lake-health, billing, legal); section ownership + filtered exports.

**9.4 Time-decay alerts** — sections shipped > N months ago without re-review surface as stale. Compliance/audit contexts.

**9.5 Question parking lot as first-class objects** — `Q-1`, `Q-2`, ... markers become structured (`orchestrator:living-doc questions [--status=open]`); closing requires binding to resolution commit.

**9.6 Decision-history per section** — append-only log per section (who shipped what / when / which commit / prior state). Today implicit in git log + sentinel paragraphs.

**9.7 Operator-declared "no user-visible change" exemption** — `docs_sweep_exemption: <reason>` in milestone close summary; living-doc gate honors it.

### 10. Open questions (from upstream RFC)

1. **Markdown ownership.** Inline HTML markers (Option A) vs sidecar bindings (Option B) — default-on which? Recommendation: Option B for v1 (byte-clean source), Option A as opt-in.
2. **Wiki coupling.** Coupled to `orchestrator:wiki-init` (simpler review UX) or independent (works for non-wiki projects)?
3. **Knowledge-graph schema impact.** Additive (new node type + 4 edge types) or breaking change to M020 schema?
4. **Detection-suggestion intrusiveness.** `orchestrator:init` proactive scan (might be noisy on greenfield) vs `orchestrator:doctor` only?
5. **Cross-doc consistency (9.1)** — opt-in or default? Recommendation: default-off, operator flag per-doc.
6. **Reviewer comment-thread storage.** Wiki + giscus is natural; fallback for non-GitHub-discussions infra?

### 11. Suggested first cut (from upstream)

Captured as "Suggested first cut" section above (RFC §11 lifted to top of brief for queue-entry visibility).

### 12. Why this matters (from upstream)

The reviewer (Matt, in LakeLedger's case) is *the* trust-anchor for whether the system behaves correctly. Every project doing this seriously reinvents the same scaffolding. That scaffolding is what the framework should own — exactly the way it owns "phase plans" and "verification gates" today.

Without it: hand-rolled per-project conventions (LakeLedger's CON-2 — works but unportable); or no enforcement, audit doc drifts until it's lying.

## Predecessors

- **M020** (knowledge-graph layer, closed) — node/edge schema M038 extends.
- **M030** (adaptive model selection, closed) — for any LLM-routed binding-detection or section-summarization work.
- **M032** (wiki distribution, closed) — review-surface output mode (post-M037 readability hardening makes living-doc wiki rendering tractable).
- **M013** (review-queue convention, closed) — `commands/comments.md` CON-5/SC-5 human-gated apply pattern reused.
- **M034** (interactive review gates, post-launch fast-follow) — strong primitive overlap; absorption decision deferred to queue-entry time.

## Concrete artifact (for queue-entry research pass)

`.planning/MATT-RULES-AUDIT.md` in the LakeLedger repo. The CON-2 convention is documented in milestone phase plans (e.g., `.orchestrator/milestones/M072/phases/P03/P03-PLAN.md`); per-phase audit-doc verifier shape lives at `tools/verify/m072-p03-audit-doc-updated.sh`. Three milestones in a row (M072 P01 / P02 / P03) ship the same shape — the *symptom* this milestone retires.

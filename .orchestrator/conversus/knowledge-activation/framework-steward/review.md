# Framework-Steward Review — Knowledge-Activation Reliability

*Reviewer: framework-steward (orchestrator framework integrity / constitution alignment / roadmap coherence)*
*Target: `.orchestrator/proposals/knowledge-activation-reliability.md`*
*Grounding: `.orchestrator/memory/constitution.md` v2.3.0; `.orchestrator/proposals/M040-ambient-feedback-loop.md`*
*Date: 2026-06-06*

---

## Executive Summary

This proposal does two things at once, and they are not the same kind of thing. The first is a **proven-bug hotfix bundle** (T1–T3 + parts of T8): five reproducible, file:line-cited defects in the index/rebuild/inject pipeline that have been silently eroding the framework's central value proposition — "the agent always acts with the full stored context." These are exactly the class of failure the constitution exists to prevent: a consumer that fails *open-silent* (`build-context.sh:198–208` injects "first-5" off an empty index with no warning) violates Principle II (Evidence Before Claims) at the framework's own substrate, and a rebuild that fails *closed-silent* (`rebuild-index.sh:117`) makes Principle VII (Knowledge Compounds) a lie on disk. The proposal's two load-bearing principles (P-A "silent degradation is the enemy", P-B "index is a cache, raw corpus is truth") are not novel inventions — they are restatements of constitution Principle II + Principle XI (Single Source of Truth, three-temperature storage) applied to a substrate where they had quietly lapsed. This half is well-scoped, well-grounded, and **should ship as a P0 hotfix independent of any milestone**, exactly as §7 proposes.

The second thing is an **activation-build feature set** (T4–T7): a turnkey capture command (FR-7), auto-graduation (FR-8), two-store bridge (FR-9), freshness automation (FR-10), and default-on corpus-exhaustion across operator-facing surfaces (FR-12). This half is real work the framework wants — but it is, point-for-point, the surfaces already specified in **M040 (ambient feedback loop)**. FR-7 *is* M040's `/orchestrator-capture` + the missing return path; FR-12's "surface conflicting prior decisions" *is* M040's contradiction gate; the system-of-record discipline (FR-9) is the precondition M040 already assumes. The proposal honestly acknowledges this in §6 and §7 — it recommends T4/T5 "fold into M040." My concern is that the proposal then re-specifies these surfaces (new commands, new acceptance criteria, new open questions) rather than simply *promoting the demand signal into M040's queue-entry inputs*. That re-specification is where duplication risk, scope creep (15 FRs), and constitution friction (FR-6 / FR-12 default-on vs. Principle I Context Minimization) concentrate.

**Most important recommendation: cleave the proposal hard along the §7 line — ship T1–T3 + FR-11 + FR-15 as a tightly-bounded P0 hotfix now, and convert T4–T7 from a re-specification into a demand-signal annotation + thin FR-deltas appended to the M040 brief, so the framework gains one capture loop, not two.**

---

## Alignment

- **[provenance discipline]** (§0, §2): Every defect is re-verified against this repo's actual source with live file:line citations, not downstream hearsay. This is Principle II (Evidence Before Claims) practiced *on the proposal itself* — "should work" is not evidence, and the proposal refuses to make a claim it has not ground-truthed. The bug table is the kind of artifact a P0 intake deserves. `[constitution P-II]`

- **[P0/P1 phasing split]** (§7): The proposal voluntarily separates proven-bug hotfixes (small blast radius, milestone-independent) from the larger activation build (composes with M040, demand-driven). This is blast-radius discipline by construction and aligns with Principle XIV (No Speculative Complexity) + Principle XV (Surgical Precision) — the hotfix does not wait on, and is not entangled with, a speculative redesign. `[constitution P-XIV, P-XV]`

- **[index-as-cache principle]** (P-B, §1; FR-10/FR-11, T6): "Index is a cache; the raw corpus is the source of truth; the guarantee runs index-free" is a faithful application of Principle XI's three-temperature storage model (hot index / warm detail / cold archive) — the hot index was never meant to be load-bearing for *possibility*, only for *speed*. FR-11's single `get_index_path`/`get_db_path` resolver directly serves Principle XI ("exactly one authoritative location"). `[constitution P-XI]`

- **[corpus-gate index-independence preserved]** (§6, FR-12; DQ-2): The proposal correctly identifies the corpus-gate's grep-over-raw-files determinism as "the load-bearing asset" and leans (DQ-2, Source 1) toward keeping the guarantee deterministic with embeddings only additive. This protects Principle IX (Reproducibility Over Convenience) — the deterministic evidence artifact (a reproducible grep log, same inputs → same log) is a trust asset, and the proposal treats it as one. `[constitution P-IX; corpus-gate skill]`

- **[round-trip test as acceptance oracle]** (FR-1, AC-1): Making "a decision written by the official capture command is provably resolved by the injector's filter" a mechanical round-trip test is Principle II's "verification is a mechanical gate, not an LLM compliance exercise" applied precisely. The producer/consumer contract becomes checkable without human judgment. `[constitution P-II]`

- **[honest roadmap mapping]** (§6): The proposal does not pretend to be net-new. It explicitly maps FR-7/FR-8 → M040 capture inbox + return path, FR-12 → M040 contradiction gate / M034 decision-packet, FR-10/FR-5 → M038 living-doc primitives, and FR-15 → the `papercut-doctor-knowledge-gap-surface.md` overlap. This is roadmap coherence done in good faith — it gives the steward the seams to fold along rather than hiding them. `[M040 §"Relationship to M038/M034"]`

---

## Missed Opportunities

- **[P1 re-specifies M040 rather than folding into it]**: §7's P1 lists FR-7/FR-8/FR-9/FR-12/FR-13/FR-14 as a self-contained "Activation Build," carrying its own acceptance criteria (AC-5, AC-8) and open questions (DQ-5, DQ-7, DQ-8). M040 already specifies these as Surface 3 (`/orchestrator-capture` + `/orchestrator-promote`), Surface 2 (contradiction gate), and the system-of-record precondition. The benefit of folding (not re-specifying): the framework ships **one** capture command, one inbox, one contradiction gate — not a parallel set that M040 then has to reconcile. Engages Principle XI (Single Source of Truth — including for *roadmap commitments*) and Principle XIV (No Speculative Complexity — a second capture surface is debt). Impact: high — this is the central placement decision. `[M040 §"Three surfaces", §"Strict scope"; constitution P-XI, P-XIV]`

- **[FR-7 should BE M040's `/orchestrator-capture`/`/orchestrator-promote`, not a new `:note`/`:decide`]**: FR-7 proposes `orchestrator:note` / `orchestrator:decide` (DQ-7). M040 already names `/orchestrator-capture` (raw landing) + `/orchestrator-promote --to=mem|decision|task` (explicit graduation). The *one real gap* FR-7 surfaces that M040 under-specifies is the **round-trip confirmation** ("confirms the entry resolves in an inject") — that is the valuable delta. Benefit: contribute the round-trip-confirmation requirement *into* M040's promote path rather than minting a third command name. Engages Principle XIV + Principle X (Templating Over Inference — surfaces are declared, not multiplied). Impact: high. `[M040 Surface 3; constitution P-XIV]`

- **[FR-6 (add Decisions to Quick inject) needs a token-budget justification]**: FR-6 stops omitting the Decisions section from the Quick-profile inject. Principle I (Context Minimization, v2.3.0 clarification) is explicit: "minimize *total* task tokens" — Quick exists precisely to keep small tasks cheap. Adding Decisions unconditionally to Quick risks re-inflating the profile the framework deliberately slimmed. The proposal's own hedge ("at least a compact decisions *digest*") is the right instinct but is not load-bearing in the FR text. Benefit: phrase FR-6 as "compact decisions digest bounded by the Quick token budget," not "include the Decisions section." Engages Principle I directly. Impact: medium — wrong framing here re-opens the M031 right-sizing work. `[constitution P-I; M040 reads, doesn't inflate, inject]`

- **[FR-12 "default-on everywhere" collides with Context Minimization unless gated advisory]**: FR-12 bakes corpus-exhaustion into `comments`, `discuss`, `specify`, `plan-phase`, `materials-intake` as a pre-gate on *every* operator-facing question. A *hard* gate on every question (DQ-5) adds a deterministic sweep + evidence-artifact emission to five entry points. The sweep is zero-LLM (good — preserves Principle IX), but "default-on everywhere as a hard gate" is the kind of unrequested cross-cutting flexibility Principle XIV warns against, and the friction cost is real. Benefit: default *advisory* (warn + surface conflicts), reserve *hard-gate* for the single highest-stakes path (`comments` spec-amendment). Engages Principle XIV + Principle I. Impact: medium-high. `[constitution P-I, P-XIV; corpus-gate skill]`

- **[15 FRs in one brief is over-bundled for a P0 intake]**: A P0 hotfix wants the *smallest correct change*. Bundling 15 FRs (T1–T8) means the proven-bug fixes share an intake with speculative-redesign questions (DQ-1 index demotion, DQ-2 embeddings). Benefit: the §7 split is correct but should be *physical* — the P0 set (FR-1,2,3,4,5,11,15) becomes the `orchestrator:specify` intake; the P1 set becomes M040 brief-deltas. Engages Principle XIV + blast-radius discipline. Impact: medium — affects how cleanly the hotfix ships. `[constitution P-XIV; §7]`

- **[FR-9 two-store bridge is an M040 precondition, not new scope]**: FR-9 (runtime-memory ↔ `.orchestrator/` divergence, declare `.orchestrator/` system of record) is foundational to M040 — M040's contradiction gate and brief *assume* DECISIONS.md is the authoritative store. The proposal treats FR-9 as net-new design (DQ-8). Benefit: surface FR-9 as a **blocking precondition annotation on M040** ("M040 cannot ship correct until the two-store divergence is closed") rather than independent scope. Engages Principle XI + Principle VI (State On Disk Is Truth — if decisions land where dispatch never reads, the disk is not truth). Impact: high. `[constitution P-VI, P-XI; M040 §"Read sources"]`

- **[FR-15 doctor check duplicates a queued paper-cut]**: §6 itself flags the overlap with `papercut-doctor-knowledge-gap-surface.md`. Benefit: reconcile *before* intake — either fold FR-15 into that paper-cut or supersede it explicitly, so two specs don't both add a `doctor` knowledge-gap check. Engages Principle XI (one authoritative location for the check) + Principle VIII (No Dead Infrastructure — don't ship two overlapping checks). Impact: low-medium. `[constitution P-VIII, P-XI; §6]`

- **[determinism trade in DQ-2 should be a stated invariant, not an open question]**: DQ-2 frames grep-vs-embeddings as open. From a framework-integrity stance it is *not* open: the reproducible evidence artifact is the corpus-gate's trust receipt, and Principle IX makes non-determinism "a bug, not a feature." Benefit: resolve DQ-2 in the brief as "deterministic grep is the guarantee floor; embeddings may *only* be an additive recall boost that never gates and never enters the evidence artifact." Engages Principle IX. Impact: medium — leaving it open invites a later trade of the trust asset. `[constitution P-IX; §4 DQ-2]`

- **[no token-budget governor named for FR-12/FR-14 fallback retrieval]**: FR-14's "degrade to deterministic content/grep retrieval when metadata is thin" and FR-12's default-on sweeps both inject content into payloads. M036a shipped a token-budget governor for reference-corpus injection (SC-3/SC-7). Benefit: the grep-fallback path must route through the *existing* governor, not introduce an ungoverned content firehose — otherwise the fail-loud fix trades a silent under-load for a silent over-load, both Principle I violations. Engages Principle I. Impact: medium. `[constitution P-I]`

---

## Off-Base Assumptions

- **[assumption: T4/T5 are net-new "Activation Build" scope]** (§3 T4/T5, §7 P1): The proposal treats the capture loop + two-store bridge as a build it might "fold into M040." Correct understanding: M040's brief already *specifies* these as first-class surfaces with named commands, storage paths, frontmatter schema, and a strict-scope boundary. The work is not "fold a new build into M040" — it is "supply M040 the demand signal it was waiting for (§Trigger condition) and contribute two FR-deltas (round-trip confirmation; system-of-record precondition)." `[M040 §"Three surfaces", §"Trigger condition"]`

- **[assumption: M040 is far-off/abstract, so re-specifying is harmless]** (implicit in §7's standalone P1 framing): M040's `§Trigger condition` fires when "at least two" signals land — and this proposal's §0 provenance *is two independent downstream consumers* (pbj-central + the archive-rooted project) reporting exactly the "I lost track of what we decided" + inbox-friction failure modes M040 lists as trigger conditions #2 and #4. Correct understanding: this proposal is not parallel to M040 — it is M040's **demand signal arriving**. The right move is to promote M040 into the queue, not to build M040's surfaces under a different name. `[M040 §"Trigger condition" #2/#4; proposal §0]`

- **[assumption: FR-12 corpus-gate is only partly wired today]** (§3 FR-12 "today only the triage-question path routes through corpus-gate"): This is accurate as stated, but the framing implies the gate is under-deployed by oversight. Correct understanding: the corpus-gate is a *reusable skill* (`orchestrator-corpus-gate`) intentionally invoked at chosen seams; "default-on everywhere" is a policy expansion, not a bug fix, and belongs in the P1/M040 track under a deliberate Principle-XIV justification — not bundled with the proven-bug P0 set where it would inherit hotfix urgency it has not earned. `[corpus-gate skill; constitution P-XIV]`

(No other material misreadings of the framework or roadmap. The bug diagnoses themselves are accepted as verified per the review scope — not re-litigated here.)

---

## Actionable Recommendations

1. **[cleave-physical-split]** (Priority P1)
   - Current state: 15 FRs in one brief; §7 proposes a logical P0/P1 split but the document is one intake.
   - Proposed change: produce two artifacts — (a) the P0 hotfix intake = FR-1,2,3,4,5,11,15; (b) M040 brief-deltas = FR-7,8,9,12,13,14 contributed as appended FRs + demand-signal note to `M040-ambient-feedback-loop.md`. FR-6 and FR-10 get explicit homes per items 4 and 7 below.
   - Scope boundary: the P0 intake touches only the proven-bug pipeline; it does NOT add capture commands, contradiction gates, or default-on sweeps.
   - Rationale: blast-radius discipline; a P0 hotfix to proven bugs must not be entangled with speculative redesign. `[constitution P-XIV, P-XV; §7]`
   - Risk if ignored: the hotfix's ship date becomes hostage to M040-scope deliberation (DQ-1/DQ-2/DQ-5/DQ-7/DQ-8), and trust-recovery is delayed.

2. **[bound-P0-hotfix]** (Priority P1)
   - Current state: §7's P0 set includes FR-15 (which overlaps a queued paper-cut) and FR-5 (which embeds the grep-fallback + provenance-header design).
   - Proposed change: keep FR-1/2/3/4 (pure proven-bug fixes) + FR-11 (path canonicalization, low-risk) as the hard P0 core; admit FR-5 only at its *minimum* (emit a visible WARNING + provenance flag on degraded/empty index) and defer the grep-fallback *retrieval* to the P1/M040 track where it can route through the token governor; route FR-15 through the paper-cut reconciliation (item 8).
   - Scope boundary: P0 makes degradation *loud*; P0 does not build new *retrieval* paths.
   - Rationale: Principle II is satisfied by fail-loud alone; the grep-fallback retrieval is a feature, not a bug fix, and carries a token-budget concern. `[constitution P-I, P-II; §3 FR-5, FR-15]`
   - Risk if ignored: the hotfix grows a retrieval engine and an ungoverned content path under hotfix urgency.

3. **[defend-determinism / resolve DQ-2]** (Priority P1)
   - Current state: DQ-2 leaves grep-vs-embeddings open; DQ-5 leaves hard-vs-advisory open.
   - Proposed change: write DQ-2's resolution into the brief as an invariant — "deterministic grep over raw files is the activation *guarantee* and the *only* input to the corpus-gate evidence artifact; embeddings, if ever added, are additive recall that never gates and never enters the receipt." Resolve DQ-5 toward *advisory default + hard-gate only on `comments` spec-amendment*.
   - Scope boundary: embeddings remain out of scope entirely for P0; the evidence artifact stays zero-LLM and reproducible.
   - Rationale: the reproducible grep log is a trust asset; Principle IX makes non-determinism a bug. `[constitution P-IX; §4 DQ-2, DQ-5]`
   - Risk if ignored: a later well-meaning recall improvement silently trades away the deterministic trust receipt.

4. **[fold-capture-into-M040 / resolve DQ-7]** (Priority P1)
   - Current state: FR-7 proposes new `orchestrator:note`/`orchestrator:decide`; DQ-7 asks new-command vs `:do` mode.
   - Proposed change: do NOT mint a new command. FR-7 becomes a **delta on M040's existing `/orchestrator-capture` + `/orchestrator-promote`**: add the round-trip-confirmation requirement ("promote --to=decision confirms the entry resolves in the next inject") to M040's promote path.
   - Scope boundary: zero net-new top-level commands; one capture loop framework-wide.
   - Rationale: Single Source of Truth applies to commands; Principle XIV forbids a parallel capture surface. M040 already named these. `[constitution P-XI, P-XIV; M040 Surface 3]`
   - Risk if ignored: the framework ships two capture commands M040 must later reconcile/deprecate.

5. **[promote-M040 / annotate demand signal]** (Priority P1)
   - Current state: M040 is "RFC capture only, deferred post-launch"; its trigger needs "at least two" signals.
   - Proposed change: append a demand-signal note to `M040-ambient-feedback-loop.md` recording that trigger conditions #2 (second consumer "lost track of what we decided") and #4 (inbox-shaped friction) are now met by this proposal's §0 dual-source provenance — promoting M040 toward queue-entry.
   - Scope boundary: this is a roadmap annotation, not an immediate build authorization; standalone-milestone-vs-absorption is decided at M040 queue-entry.
   - Rationale: roadmap coherence — record the signal where the milestone reads it. `[M040 §"Trigger condition"; proposal §0]`
   - Risk if ignored: M040 stays "demand-driven" while its demand sits unrecorded in a sibling proposal, inviting duplicate builds.

6. **[place-FR-9 as M040 precondition]** (Priority P2)
   - Current state: FR-9 (two-store bridge / declare system of record) framed as independent design with open DQ-8.
   - Proposed change: record FR-9 as a **blocking precondition** on M040 ("the contradiction gate and brief are incorrect until runtime-memory ↔ `.orchestrator/` divergence is closed and `.orchestrator/` is the documented system of record"). Resolve DQ-8 toward *graduation step* (keeps `.orchestrator/` self-contained per Principle VI) over live runtime-read (which couples dispatch to a runtime-specific memory shape).
   - Scope boundary: documentation + a graduation path; not a live cross-runtime memory reader by default.
   - Rationale: State On Disk Is Truth + Single Source of Truth; live-coupling to runtime memory risks Principle VI. `[constitution P-VI, P-XI; §4 DQ-8]`
   - Risk if ignored: M040 ships a contradiction gate that reads a store decisions never landed in — re-creating the exact 0-MEM failure this proposal diagnoses.

7. **[budget-bound FR-6 and FR-12/FR-14 retrieval]** (Priority P2)
   - Current state: FR-6 adds Decisions to Quick inject; FR-12/FR-14 inject swept/fallback content.
   - Proposed change: phrase FR-6 as "compact decisions *digest* bounded by the Quick token budget"; require FR-12's default-on sweeps and FR-14's grep-fallback to route injected content through the M036a token-budget governor (SC-3/SC-7).
   - Scope boundary: no inject path may exceed its profile's token budget; fail-loud must not become fail-loud-and-overloaded.
   - Rationale: Principle I (minimize *total* task tokens) — both under-load and over-load are violations; M031 deliberately slimmed Quick. `[constitution P-I; §3 FR-6, FR-12, FR-14]`
   - Risk if ignored: the reliability fix re-inflates the profiles M031 right-sized, or introduces an ungoverned content firehose.

8. **[reconcile-FR-15 with paper-cut]** (Priority P2)
   - Current state: FR-15's `doctor` knowledge-gap check overlaps `papercut-doctor-knowledge-gap-surface.md` (§6 flags it).
   - Proposed change: before intake, either fold FR-15 into the paper-cut or have FR-15 explicitly supersede it; ship exactly one `doctor` knowledge-gap check.
   - Scope boundary: one check, one owner.
   - Rationale: Single Source of Truth + No Dead Infrastructure. `[constitution P-VIII, P-XI; §6]`
   - Risk if ignored: two specs add overlapping `doctor` checks; dead/redundant infra.

9. **[gate-FR-12-with-XIV-justification]** (Priority P2)
   - Current state: FR-12 expands corpus-gate to five entry points "default-on."
   - Proposed change: require each new entry-point integration to carry an explicit Principle-XIV justification at plan time (why this seam needs the gate, advisory vs. hard), default advisory, and ship incrementally — not a single cross-cutting "everywhere" flip.
   - Scope boundary: opt-in-per-seam with declared policy; `comments` spec-amendment is the only hard-gate candidate for v1.
   - Rationale: No Speculative Complexity — cross-cutting default-on is unrequested flexibility absent per-seam justification. `[constitution P-XIV; §3 FR-12]`
   - Risk if ignored: five seams gain friction and cost no one asked for, attributed to a "hotfix."

10. **[keep-DQ-1-index-demotion-out-of-P0]** (Priority P3)
    - Current state: DQ-1 (formally demote the index to "cache, may be absent") sits in the brief alongside hotfix FRs.
    - Proposed change: resolve DQ-1 as a *principle statement* (P-B already restates Principle XI) but keep any *mechanical* demotion (every consumer gains an index-free path) in the P1/M040 track; P0 only needs fail-loud + warn, not a full index-free retrofit of every consumer.
    - Scope boundary: P0 = the index *may be* stale/empty and that is *loud*; full index-free-everywhere is P1.
    - Rationale: Surgical Precision + No Speculative Complexity; a full consumer retrofit is larger than the proven-bug surface. `[constitution P-XIV, P-XV; §4 DQ-1]`
    - Risk if ignored: P0 quietly expands into an architecture migration.

---

## Referenced Documentation

- `.orchestrator/proposals/knowledge-activation-reliability.md` — §0 (provenance), §1 (P-A/P-B/P-C theses), §2 (defect table B-1..B-5, gaps G-1..G-7), §3 (FR-1..FR-15, T1..T8), §4 (DQ-1..DQ-8), §5 (acceptance criteria), §6 (roadmap relationship), §7 (P0/P1 phasing)
- `.orchestrator/memory/constitution.md` v2.3.0 — Principle I (Context Minimization, total-task-tokens clarification), Principle II (Evidence Before Claims), Principle VI (State On Disk Is Truth), Principle VII (Knowledge Compounds), Principle VIII (No Dead Infrastructure), Principle IX (Reproducibility Over Convenience), Principle X (Templating Over Inference), Principle XI (Single Source of Truth), Principle XIV (No Speculative Complexity), Principle XV (Surgical Precision)
- `.orchestrator/proposals/M040-ambient-feedback-loop.md` — §"Three surfaces" (Surface 1 brief / Surface 2 contradiction gate / Surface 3 `/orchestrator-capture` + `/orchestrator-promote`), §"Strict scope", §"Read sources", §"Relationship to M038/M034", §"Trigger condition" (#2, #4), §"Blast radius"
- `orchestrator-corpus-gate` (shipped skill) — deterministic corpus-exhaustion gate + reproducible evidence artifact
- M031 (right-sized entry, closed 2026-05-01) — Quick-profile token-budget context for FR-6
- M036a (reference-corpus ingest, closed 2026-05-02) — token-budget governor (SC-3/SC-7) for FR-12/FR-14 injection
- `papercut-doctor-knowledge-gap-surface.md` — overlapping `doctor` knowledge-gap check (FR-15 reconciliation)

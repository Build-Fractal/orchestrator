# Review — activation-loop (capture→store→inject round-trip perspective)

*Phase 1 cooperative review of `/.orchestrator/proposals/knowledge-activation-reliability.md`, grounded in `~/Sites/archive/.orchestrator/upstream/knowledge-activation-gap.md`.*

## Executive Summary

The proposal is a faithful and substantially complete consolidation of the capture→store→inject round-trip diagnosis. It correctly elevates my core thesis — *the store the agent writes to and the store dispatch reads from must not silently diverge; the official capture commands must produce entries the injector can actually read* — into a named, load-bearing principle (P-C, §1 L32), distinct from the pipeline-integrity principles (P-A, P-B). Every concrete defect my source submission raised is present and ground-truthed: BUG A (producer/consumer format mismatch) as B-3, BUG B (archive skip-glob) as B-4, BUG C (compression filter drops flat knowledge) as B-5, and the four design gaps (Quick-never-captures G-1, Quick-drops-Decisions G-2, two-store divergence G-3, no chat-level capture command G-4). The acceptance battery (§5) carries the two oracles I care most about: the round-trip test (AC-1) and the path-collision test (AC-3). This is a strong, honest synthesis — it did not water down the "even a diligent operator ends up with an unreadable store" thesis; that exact framing survives verbatim in §8's compression and in BUG A's "the official capture command produces unreadable rows."

Where the proposal is weaker — and where my advocacy concentrates — is in *relative prioritization* and in *leaving the round-trip's two hardest decisions as open forks rather than taking positions*. The phasing split (§7) puts the pipeline-integrity bugs (B-1/B-2) and the format mismatch (B-3/BUG A) together in P0, which is correct, but it scatters the round-trip's other halves: G-1 (Quick captures nothing), G-3 (two-store divergence), and G-4 (the capture command) all land in P1 "fold into M040 / demand-driven." That is a mistake. My source's central field note (L161-169) is that a real two-milestone project produced a 0-MEM inject *for its entire life* and nobody noticed — and the proximate cause was not only the rebuild bug but the *absence of any default capture path* (G-1/G-4) combined with the *two-store divergence* (G-3). Fixing B-1 through B-5 makes the happy path *parseable*; it does not make the happy path *exist* at the default intensity. A Quick-profile project with fixed parsers still captures nothing (G-1) and still injects no Decisions (G-2, which IS in P0 as FR-6 — good — but its sibling G-1 is not). Half the loop is hotfixed; the other half is deferred behind a demand signal that the field note shows has *already fired*.

My most important recommendation: **promote BUG A (B-3, FR-1, the round-trip test) and the Quick-default-capture pair (G-1/FR-8) into P0 alongside the rebuild bug — the format mismatch is the happy path silently failing, and a parseable store the default intensity never writes to is still an empty store.**

## Alignment

- **[round-trip-as-principle]** (§1 P-C, L30-32): The proposal names "One system of record, and the happy path must work" as a first-class principle co-equal with the pipeline principles, with the exact framing "Producer and consumer are one contract, covered by a round-trip test." This is my submission's thesis promoted to architecture, not buried as a bug line `[gap-doc, L74, L93-95]`.

- **[BUG-A-verified-and-located]** (§2 B-3, L44): The proposal pins the format mismatch to live file:line with the precise column orders — producer `append-decision.sh:93` writes `| ID | When | Scope | Decision | Choice | Rationale | Revisable |`, consumer `scope-filter.sh:343,351` reads Scope from `$4` / When from `$5` — and explicitly carries the parallel `append-knowledge.sh ↔ filter_knowledge` (`## K###` shape) mismatch. This matches my BUG A exactly and adds the column-index ground truth `[gap-doc, L64-74]`.

- **[round-trip-test-as-oracle]** (§5 AC-1, L117; §3 FR-1, L67): The acceptance criterion makes the round-trip the *acceptance oracle* — "a decision/knowledge entry written by the official capture command is provably resolved by `build-context.sh`'s `filter_decisions`/`filter_knowledge`." This is precisely the producer-and-consumer-are-one-contract test I demanded `[gap-doc, L141-144]`.

- **[capture-command-highest-leverage]** (§3 FR-7, L79): FR-7 carries my framing that the turnkey capture command is the "Single highest-leverage fix" and reproduces the one-step shape: append → `rebuild-index.sh` → confirm the entry resolves in an inject. The "SME said X in chat → durable, re-injected knowledge" loop is named as the target `[gap-doc, L101-107]`.

- **[two-store-divergence-as-root-cause]** (§2 G-3, L54): The proposal records that the injector never reads runtime agent memory, that decisions land in runtime memory + `execution-log.jsonl` `note` fields, and that "Two milestones, 50+ locked decisions, every inject resolved to 0 MEMs, no warning." This is my field note's root cause carried intact `[gap-doc, L53-56, L161-169]`.

- **[archive-glob-and-flat-knowledge-bugs]** (§2 B-4/B-5, L45-46): Both the `*/archive/*` false-match (zeroing the index for any project rooted under a dir named `archive` — the literal `~/Sites/archive/` case) and the `kf_filter_stream` frontmatter-requirement that drops flat `## K###` entries are carried with locations and the "mutually inconsistent" framing `[gap-doc, L76-91]`.

## Missed Opportunities

- **[BUG-A-buried-mid-table]**: BUG A is the third row (B-3) of the pipeline-integrity table, presented at equal weight with the rebuild bug (B-1) — but the proposal's *narrative* prioritization (§2 header "Pipeline integrity bugs," §7 phasing) consistently leads with the rebuild/index story (Source 1's framing) and treats the format mismatch as one more entry. My source is explicit that "even an operator who diligently runs the documented capture commands ends up with a store the injector can't read … These should be the first fixes" `[gap-doc, L93-95]`. The proposal *includes* B-3 in P0, which is correct, but it does not foreground it as co-primary. The benefit of foregrounding: the rebuild bug is a *cache* failure (P-B says the cache is allowed to be absent); BUG A is a *source-of-truth* failure — the canonical store itself is unreadable. A correct index built over BUG-A rows still mis-extracts scope/when. The format mismatch is strictly more fundamental than the rebuild path it sits beside. Impact: high — phasing and emphasis both undersell the defect my perspective considers the worst.

- **[round-trip-half-deferred]**: §7 splits the round-trip across the P0/P1 boundary. FR-1/FR-2 (parser unification) and FR-6 (Quick includes Decisions) are P0; but FR-7 (capture command), FR-8 (Quick always captures / auto-graduate), and FR-9 (two-store bridge) are P1 "demand-driven." The round-trip is *one contract*; you cannot half-ship it. A fixed parser (FR-1) over a store the default intensity never writes (G-1, deferred) yields the same 0-MEM inject the field note describes `[gap-doc, L38-43, L161-169]`. Concrete benefit of moving G-1/FR-8 to P0: the round-trip test (AC-1) and the Quick-milestone-non-empty test (AC-6) become *meaningfully* green on a default project rather than green only on a hand-promoted one. Impact: high.

- **[demand-signal-already-fired]**: §7 P1 and §6 (M040 fold-in) gate the capture loop behind "demand-driven" / "ships when a second downstream consumer hits the friction." But my source IS that downstream consumer, and the field note (L161-169) documents the friction has *already* cost a real production project two milestones of un-activated knowledge. The proposal's own §7 L144 admits "the proven bugs are actively eroding trust on production projects today." The capture-loop absence is part of that same active erosion, not a speculative future need. The benefit of recognizing this: G-4/FR-7 stops being deferred behind a signal that has fired and joins the trust-recovery P0. Impact: high — this is the single most consequential mis-prioritization.

- **[two-store-divergence-left-as-fork]**: G-3 is correctly diagnosed, but FR-9 (§3 L83) and DQ-8 (§4 L111) leave the resolution as an unresolved fork — read runtime memory live (a) vs ingest-memory graduation step (b). My source took a position: declare `.orchestrator/` the system of record with runtime memory as a *convenience cache*, and make silent divergence "not possible by default" `[gap-doc, L117-123]`. The proposal carries the "document system of record" half (FR-9 last sentence, AC-10) but defers the *mechanism* that makes divergence impossible. Leaving it a fork risks shipping the documentation without the enforcement — exactly the fail-open posture P-A forbids. Benefit of resolving: the divergence becomes a verifiable invariant, not a doc note. Impact: high. (See Recommendation 4 for my position.)

- **[FR-7-under-specified-to-build]**: FR-7 (§3 L79) names the command and the three-step shape but leaves the build surface undecided (DQ-7: new command vs `:do` mode) and does not specify (a) where a chat-level decision's text *comes from* — operator-typed argument vs scrape of the current turn — (b) how it classifies decision-vs-knowledge (DECISIONS.md vs KNOWLEDGE.md routing), or (c) what "confirms the entry resolves in an inject" concretely runs (a `build-context.sh --dry-run` round-trip assertion?). My source frames this as "without the operator knowing the internal scripts" `[gap-doc, L101-107]` — which implies the command must own classification and confirmation, not just shell out. Benefit: a spec-ready FR the planner can decompose rather than re-discover. Impact: medium-high.

- **[diligent-operator-thesis-not-an-AC]**: The proposal carries the "even a diligent operator ends up with an unreadable store" thesis in prose (§8, B-3 narrative) but does NOT encode it as a distinct acceptance criterion. AC-1 tests the *new* capture command's round-trip; it does not assert that the *pre-existing documented* `append-decision.sh` / `append-knowledge.sh` primitives (which operators were told to run) now round-trip. My source's AC explicitly lists "the new capture command (`append-decision.sh` / `append-knowledge.sh` / the new capture command)" as the producers under test `[gap-doc, L141-144]`. Benefit: locks the fix for the operators who already followed the docs, not just future callers of the new command. Impact: medium.

- **[init-time-header-fix-implicit]**: My source flags that "The init-time empty `DECISIONS.md` header was itself in the wrong, append-script order" `[gap-doc, L74]`. The proposal mentions this once inside FR-1 ("the init-time empty `DECISIONS.md` header must match it," L67) but does not surface it as its own verifiable item or AC. Whichever column order wins DQ-6, the init template, the append script, AND the consumer must all be re-aligned in one change set — three call sites, not two. Benefit: prevents a partial fix that unifies producer↔consumer but leaves the init header (and thus every fresh project's first decision row) mis-shaped. Impact: medium.

- **[auto-graduate-mechanism-thin]**: FR-8 (§3 L80) offers "auto-graduate decision-bearing `execution-log.jsonl` `note` fields into `DECISIONS.md` regardless of intensity" but does not say *which* notes qualify (all? tagged? a `decision:` note shape?) or *when* (phase close per my source L113, or continuously). My source ties it specifically to phase close `[gap-doc, L109-115]`. Without a qualification rule this risks graduating noise into the authoritative store — which then pollutes every inject. Benefit: a precise trigger keeps `.orchestrator/` (the system of record) clean. Impact: medium.

- **[corpus-manifest-runtime-memory-reach]**: G-5/FR-13 (§2 L56, §3 L94) correctly note the manifest sweeps `MEMORY.md` (a link index) and empty files and "globs are repo-root-relative, can't reach runtime-memory paths." But the resolution ("or guarantees content is graduated into swept files") quietly depends on G-3/FR-9 being resolved first — if runtime memory is never graduated, the manifest still reads near-nothing. The proposal does not flag this ordering dependency. Benefit of flagging: FR-13 is only meaningful once the system-of-record question (FR-9) is settled, so they must phase together. Impact: medium.

## Off-Base Assumptions

- **[G-4-needs-M013/M012]** (§2 G-4, L55; §3 FR-7): The proposal states the chat-level capture gap exists because "`comments.md` ingests only GitHub/Giscus (needs M013/M012)." This framing is accurate as a *description of why comments.md doesn't help*, but it must not leak into FR-7's design as a dependency. My source is explicit that the primitives already exist and the missing piece is a turnkey wrapper, NOT a GitHub/Giscus integration — "The primitives exist (`append-decision.sh`, `append-knowledge.sh`, `rebuild-index.sh`, `consolidate-artifacts.sh`) but must be invoked by hand" `[gap-doc, L44-48, L101-107]`. The new capture command must work in a plain chat turn with zero GitHub dependency. Correct understanding: FR-7 is a thin local wrapper over existing local primitives; the M013/M012 reference is context for G-4's *cause*, not a constraint on G-4's *fix*. (The proposal mostly gets this right in FR-7 itself; the risk is downstream readers inheriting the dependency from the G-4 row.)

- **[P1-is-demand-driven]** (§7 L147; §6 L135): The proposal assumes the activation build (capture loop + two-store bridge) is appropriately "demand-driven" and folds into M040 "rather than ship standalone." For the *contradiction-gate* and *brief* surfaces of M040, fine. But for G-1/G-3/G-4 specifically, the demand is not future — it is the field note (L161-169). Treating the capture loop as demand-driven mis-models it as a feature-want when my source presents it as the *other half of the active trust-erosion bug*. Correct understanding: the capture loop is co-primary trust recovery, not a composable M040 nicety; M040 can still absorb the *brief/contradiction* surfaces while the *capture+graduate+bridge* core ships in the hotfix. `[gap-doc, L93-95, L161-169]`

If the deliberation reads these two as nuance rather than error, I accept that — both are *emphasis* corrections more than factual ones. I found no claim in the proposal that contradicts the round-trip mechanics as my source documents them.

## Actionable Recommendations

1. **[promote-BUG-A-to-P0-co-primary]** (Priority P1)
   - Current state: §7 places B-3/FR-1 in P0 but the §2 table and §7 narrative lead with the rebuild bug, framing BUG A as one row among five.
   - Proposed change: explicitly designate B-3/FR-1 (producer/consumer format unification + round-trip test) as a *co-primary* P0 deliverable, named first in the P0 list and in §8, on equal footing with B-1. State plainly: B-1 is a cache failure (recoverable, P-B-tolerable); BUG A is a source-of-truth failure (the canonical store is unreadable).
   - Scope boundary: emphasis + ordering only; no FR text changes beyond foregrounding.
   - Rationale: the format mismatch is the happy path silently failing — the worst failure mode from the round-trip perspective; a correct index over mis-shaped rows still mis-extracts scope/when `[gap-doc, L64-74, L93-95]`.
   - Risk if ignored: phasing reviewers de-prioritize the format fix behind the more dramatic rebuild story, and the documented capture commands stay broken longest.

2. **[move-Quick-default-capture-to-P0]** (Priority P1)
   - Current state: FR-8/G-1 (Quick always captures explicit decisions + auto-graduate) sits in P1 "demand-driven," while its sibling FR-6/G-2 (Quick includes Decisions in inject) is already P0.
   - Proposed change: move at least the "always run `append-decision.sh` for *explicit* decisions even at Quick" half of FR-8 into P0. Pair it with FR-6 so the Quick profile both *captures* and *injects* decisions in the same change set.
   - Scope boundary: the auto-graduate-from-execution-log half (which needs a qualification rule, see Rec 8) may stay P1; only the explicit-decision capture moves.
   - Rationale: a fixed parser over a store the default intensity never writes is still empty; the most dangerous place to forget a decision is a Quick change, which today gets the least context `[gap-doc, L38-43, L109-115]`.
   - Risk if ignored: AC-1/AC-6 pass only on hand-promoted projects; the default project still produces 0-MEM injects.

3. **[resolve-DQ-6-consumer-order-wins]** (Priority P1)
   - Current state: DQ-6 (§4 L109) leaves the canonical column order open — producer (`append-decision.sh`) vs consumer (`filter_decisions`).
   - Proposed change: take the position that the **consumer's order wins** (`| D### | Decision | Choice | Scope | When | Rationale |`), and rewrite the producer + the init-time empty header to match. Rationale for direction: the consumer's shape is the one already embedded in `scope-filter.sh` scope-matching logic ($4=Scope, $5=When) and in any already-injected expectations; rewriting the producer is a single-file change vs auditing every read site. Whichever wins, the round-trip test (AC-1) is the lock.
   - Scope boundary: pick a direction; do not redesign the row schema. Same applies to the `## K###` knowledge shape — consumer's `## K###: <Title> [<scope-tag>]` block wins.
   - Rationale: an unresolved fork risks a partial unification that misses the init header (three call sites: init template, append script, consumer) `[gap-doc, L70-74]`.
   - Risk if ignored: the spec ships with the format still ambiguous; the planner re-litigates at build time.

4. **[resolve-DQ-8-system-of-record-with-enforcement]** (Priority P1)
   - Current state: DQ-8/FR-9 leaves the two-store resolution a fork (live-read vs ingest-graduation) and carries only the *documentation* half of "declare `.orchestrator/` the system of record."
   - Proposed change: take the position from my source — declare `.orchestrator/` the system of record, runtime memory a convenience cache, and resolve the fork toward **graduation (b)** as the default (an `orchestrator:ingest-memory` step / `consolidate` extension), with live-read (a) as an optional configured augmentation. Critically, add the *enforcement* clause my source demands: "silent divergence must not be possible by default" — operationalized as the 0-MEM-on-mature-project warning (FR-15) plus a doctor check that flags runtime-memory decisions absent from `.orchestrator/`.
   - Scope boundary: graduation is the default mechanism; live-read stays opt-in and out of the hotfix. The hotfix ships the *warning* (divergence becomes loud); the build ships the *graduation* (divergence becomes impossible).
   - Rationale: graduation keeps `.orchestrator/` self-contained and runtime-agnostic, avoiding coupling dispatch to a runtime-specific memory shape; live-read couples to CC's memory format and breaks runtime parity `[gap-doc, L117-123]`.
   - Risk if ignored: the proposal documents a system of record but ships no mechanism to keep the two stores from silently diverging again — the exact fail-open the field note caught.

5. **[specify-FR-7-capture-command]** (Priority P2)
   - Current state: FR-7 names the command + three-step shape but leaves DQ-7 (command vs `:do` mode) open and omits classification + confirmation mechanics.
   - Proposed change: resolve DQ-7 toward a **new first-class command** (`orchestrator:note` with `--decision`/`--knowledge` modes) rather than a `:do` flag — `:do` is task-dispatch-shaped; capture is a distinct verb and deserves discoverability. Specify: (a) decision text from an operator argument or the named chat ruling; (b) routing rule — operator-locked rulings → `DECISIONS.md`, reusable patterns → `KNOWLEDGE.md`; (c) confirmation = a `build-context.sh` round-trip assertion that the just-written entry resolves in the next inject (reuses the AC-1 oracle).
   - Scope boundary: the command owns append + rebuild + confirm locally; zero GitHub/Giscus dependency (see Off-Base 1).
   - Rationale: "without the operator knowing the internal scripts" requires the command to own classification and confirmation, not just shell out `[gap-doc, L101-107]`.
   - Risk if ignored: FR-7 ships under-specified and the planner re-derives the design.

6. **[add-legacy-primitive-round-trip-AC]** (Priority P2)
   - Current state: AC-1 tests the round-trip via the capture command; it does not assert the *pre-existing documented* `append-decision.sh`/`append-knowledge.sh` primitives now round-trip.
   - Proposed change: extend AC-1 (or add AC-1b) so the round-trip oracle runs over the legacy documented primitives directly, not only the new wrapper — the operators who followed the old docs must be made whole.
   - Scope boundary: a test addition, not new FR scope; covered by the FR-1 unification already.
   - Rationale: my source lists `append-decision.sh`/`append-knowledge.sh` as producers-under-test `[gap-doc, L141-144]`; the "diligent operator" thesis is otherwise un-encoded.
   - Risk if ignored: a fix that unifies only the new command's output leaves every project that used the documented primitives still broken.

7. **[bind-FR-13-to-FR-9-ordering]** (Priority P2)
   - Current state: FR-13 (corpus manifest sweeps real content) lists "or guarantees content is graduated into swept files" without flagging its dependency on FR-9's graduation mechanism.
   - Proposed change: note explicitly that FR-13's "graduated into swept files" path is only satisfiable once FR-9's graduation (Rec 4) ships; phase them together (both P1 build, or both reference the same graduation step).
   - Scope boundary: an ordering/dependency note; no FR text rewrite.
   - Rationale: a manifest that sweeps `.orchestrator/` content is empty until runtime-memory decisions are graduated there `[gap-doc, L49-52, L117-123]`.
   - Risk if ignored: FR-13 ships "fixed" but still reads near-nothing because the content was never graduated.

8. **[specify-auto-graduate-qualification]** (Priority P2)
   - Current state: FR-8's auto-graduate half does not say which `execution-log.jsonl` notes qualify or when.
   - Proposed change: specify a `decision:`-tagged (or equivalent structured) note shape as the graduation trigger, fired at phase close (consolidate boundary), not continuously.
   - Scope boundary: defines the trigger only; reuses the existing append + rebuild path.
   - Rationale: my source ties graduation to phase close `[gap-doc, L109-115]`; an unscoped graduation pollutes the system-of-record store and degrades every inject.
   - Risk if ignored: noise graduates into `.orchestrator/DECISIONS.md`, undermining the very injects the fix is meant to enrich.

9. **[surface-init-header-as-discrete-item]** (Priority P3)
   - Current state: the init-time empty `DECISIONS.md` header fix is a sub-clause of FR-1.
   - Proposed change: call it out as a discrete verifiable item (or AC) — init template, append script, and consumer must all align to the DQ-6 winner in one change set (three call sites).
   - Scope boundary: visibility only; within existing FR-1 scope.
   - Rationale: `[gap-doc, L74]` flags the init header was itself wrong-order; a partial fix that misses it leaves every fresh project's first row mis-shaped.
   - Risk if ignored: producer↔consumer unify but the init header drifts, re-breaking the round-trip on row one of a new project.

10. **[keep-grep-fallback-deterministic-for-round-trip]** (Priority P3)
    - Current state: DQ-2 (§4 L105) weighs grep vs embeddings for the thin-metadata fallback.
    - Proposed change: from the round-trip perspective, endorse the grep-floor position — the deterministic grep-over-raw-files fallback is what guarantees a *just-captured* decision is findable *immediately*, before any index/embedding rebuild. Embeddings add latency and nondeterminism between capture and resolution, weakening the "confirms the entry resolves" step of FR-7.
    - Scope boundary: endorse grep as the floor; embeddings stay additive (aligns with Source 1's lean, §4 L105).
    - Rationale: the round-trip's confirmation step needs deterministic, index-free, same-instant retrieval `[gap-doc, L101-107]`.
    - Risk if ignored: a nondeterministic fallback makes "confirms the entry resolves in an inject" flaky, undermining the one-step capture guarantee.

## Referenced Documentation

- `~/Sites/archive/.orchestrator/upstream/knowledge-activation-gap.md` — TL;DR L12-22; Evidence (injector reads three files / Quick drops Decisions / Quick never captures / no chat capture / manifest sweeps wrong / never reads runtime memory) L26-56; BUG A (format mismatch) L64-74; BUG B (archive glob) L76-84; BUG C (compression filter) L86-91; Net effect ("diligent operator … happy path silently fail … first fixes") L93-95; What-to-build §1 capture command L101-107; §2 never-drop-decisions L109-115; §3 two-store bridge / system of record L117-123; §4 manifest content L125-129; §5 observability/fail-loud L131-136; Acceptance criteria L141-157; Field note (two-milestone 0-MEM project) L161-169.
- `/.orchestrator/proposals/knowledge-activation-reliability.md` (target) — §1 principles P-A/P-B/P-C L26-32; §2 defect tables B-1..B-5 / G-1..G-7 L40-58; §3 FR set T1–T8 L66-98; §4 DQ-1..DQ-8 L104-111; §5 acceptance AC-1..AC-10 L117-126; §6 roadmap relationship L130-138; §7 phasing P0/P1 L142-147; §8 compression L153.

# Synthesis — Knowledge-Activation Reliability

*Neutral synthesizer. Cooperative deliberation. Agents: pipeline-reliability, activation-loop, framework-steward.*
*Target: `.orchestrator/proposals/knowledge-activation-reliability.md`.*
*Date: 2026-06-06.*

---

### Process Summary

- **Agents (3):** pipeline-reliability (knowledge-pipeline reliability — fail-loud, index-as-cache, raw-corpus-is-truth, resilience-over-atomicity, provenance-travels-with-context); activation-loop (capture→store→inject round-trip — one-system-of-record, happy-path-must-work, turnkey chat-level capture); framework-steward (framework integrity / constitution alignment / roadmap coherence with M040/M034/M038).
- **Total artifacts read:** 16 — 1 target proposal + 3 Phase-1 reviews + 6 Phase-2 cross-reviews + 3 Phase-3 revisions + 3 Phase-4 disputes.
- **Phase 1 reviews:** 3.
- **Phase 2 cross-reviews:** 6 (each agent reviewed the other two).
- **Phase 3 revisions:** 3.
- **Phase 4 disputes:** 3.
- **Recommendations proposed (Phase 1 total):** 30 — pipeline-reliability 11, activation-loop 10, framework-steward 9 (the proposal also carried 8 DQs; agents resolved DQ-1/2/3/4/5/6/7/8 across their recommendations).
- **Withdrawn:** 0 full recommendations. (Two *clauses* withdrawn by activation-loop: the net-new `orchestrator:note`/`:decide` command name, and live-runtime-memory-read as opt-in augmentation.)
- **Modified:** 18 (pipeline-reliability 7, activation-loop 4, framework-steward 7).
- **Surviving:** 12 (pipeline-reliability 4, activation-loop 6, framework-steward 3 — counting overlap by agent total minus modified).
- **New added (Phase 3):** 7 — pipeline-reliability 2, activation-loop 2, framework-steward 3.
- **Disputes remaining (Phase 4):** 0 hard recommendation-vs-recommendation conflicts. The agents recorded 5 *residual seams / guardrails* (2 pipeline-reliability, 3 activation-loop, 3 framework-steward, with substantial overlap), all of which are sequencing/governance nuances each agent's peers already accepted in revision — flagged only to prevent synthesis from flattening them.
- **Convergence points:** 8 named unanimous convergences across the three Phase-4 statements.

This deliberation converged unusually hard. Every "tension" resolved to composition; all three agents *modified* rather than withdrew; the only two genuine over-reaches (a new command name, live-read coupling) were conceded cleanly by their author without loss of central position.

---

### Recommendation Scorecard

| # | Agent | Recommendation | P1 Priority | P3 Disposition | Challenged By | Convergence | Final Status |
|---|---|---|---|---|---|---|---|
| PR-1 | pipeline-reliability | mandate index-free grep fallback for ALL consumers (enumerated, tested) | P0 | Modified (split: P0 fail-loud+inventory all consumers; grep retrieval budget-bounded via M036a; include G-3 zero-reader negative finding; assert over unified producer) | framework-steward (firehose/budget), activation-loop (empty-store) | High | Accepted-Modified |
| PR-2 | pipeline-reliability | scope unguarded-command audit to a checked-in artifact | P0 | Modified (bounded grep-enumeration of `rebuild-index.sh`+direct libs; fix only reproduced, justify-and-track rest) | framework-steward (blast-radius) | High | Accepted-Modified |
| PR-3 | pipeline-reliability | lock regressions at fixture-byte-equality | P0 | Modified (split static fixtures vs dynamic round-trip oracle; provenance fixture waits for P1 schema) | framework-steward (ordering), activation-loop (frozen-vs-dynamic) | High | Accepted-Modified |
| PR-4 | pipeline-reliability | pin provenance header as versioned byte-contract | P1 | Modified (minimal payload subset P0; full versioned schema+fixture P1; add resolved-id surface) | framework-steward (token cost), activation-loop (2nd consumer) | High | Accepted-Modified |
| PR-5 | pipeline-reliability | resolve DQ-1 — demote index to cache, index-free path every consumer | P0 | Surviving | none | Unanimous | Accepted |
| PR-6 | pipeline-reliability | resolve DQ-2 — deterministic grep floor, embeddings additive-only | P1→resolved | Surviving (elevated to jointly-resolved invariant) | none (mislabel-risk only) | Unanimous | Accepted |
| PR-7 | pipeline-reliability | resolve DQ-3 — rebuild-then-warn-if-still-bad, never silent auto-rebuild | P1 | Surviving | none | High | Accepted |
| PR-8 | pipeline-reliability | resolve DQ-4 — header always + stderr always; hard gate only highest-stakes | P0 | Modified ("minimal" header always in payload, full to stderr) | framework-steward (Context-Min) | High | Accepted-Modified |
| PR-9 | pipeline-reliability | make content-hash the freshness contract (not mtime) | P1 | Surviving (signal adopted; machinery P0/P1 split) | none | High | Accepted |
| PR-10 | pipeline-reliability | assert-no-vestigial-index as standing doctor check | P1 | Modified (folded into one consolidated 3-symptom doctor check) | framework-steward (consolidate) | High | Accepted-Modified |
| PR-11 | pipeline-reliability | keep §7 P0/P1 phasing, milestone-independent | P0 | Modified (P0 membership expands: +FR-6, +explicit-capture half of FR-8) | activation-loop (capture-half) | Unanimous (axis) | Accepted-Modified |
| AL-1 | activation-loop | promote BUG A (B-3/FR-1) to P0 co-primary | P1 | Surviving (rank by which-store-unreadable) | none | Unanimous | Accepted |
| AL-2 | activation-loop | move Quick-default explicit-capture into P0 | P1 | Surviving (narrowed to explicit-decision half; FR-6 as bounded digest) | framework-steward (initially), then conceded | Unanimous | Accepted |
| AL-3 | activation-loop | resolve DQ-6 — consumer column order wins | P1 | Modified (3 disagreeing shapes incl. awk `$5/$6`; drop "single-file" claim; AC-1 is the lock) | pipeline-reliability (awk indices), framework-steward (call-site count) | High | Accepted-Modified |
| AL-4 | activation-loop | resolve DQ-8 — `.orchestrator/` system-of-record with enforcement | P1 | Modified (withdrew live-read; graduation-only + enforcement warning) | framework-steward (runtime coupling), pipeline-reliability (determinism) | Unanimous | Accepted-Modified |
| AL-5 | activation-loop | specify FR-7 capture command | P2 | Modified (withdrew new command name; = M040's `/orchestrator-capture`+`/orchestrator-promote` + deltas; UX M040-track, mechanism P0) | framework-steward (M040 dup) | Unanimous | Accepted-Modified |
| AL-6 | activation-loop | add legacy-primitive round-trip AC | P2 | Surviving (merged with byte-equality: one fixture both guarantees) | none | High | Accepted |
| AL-7 | activation-loop | bind FR-13 to FR-9 ordering | P2 | Surviving (cleaner post-Rec-4) | none | High | Accepted |
| AL-8 | activation-loop | specify auto-graduate qualification (`decision:`-tag, phase-close) | P2 | Surviving (adopted verbatim by both peers as shared rule) | none | Unanimous | Accepted |
| AL-9 | activation-loop | surface init-header as discrete item | P3 | Modified (3→4 call sites: +consumer awk) | pipeline-reliability (4th site) | High | Accepted-Modified |
| AL-10 | activation-loop | keep grep fallback deterministic for round-trip | P3 | Surviving (both rationales into resolved DQ-2; split static/dynamic harness) | none | Unanimous | Accepted |
| FS-1 | framework-steward | cleave physical split (P0 intake vs M040 deltas) | P1 | Modified (line redrawn "local primitive vs UX wrapper", not "bug vs feature") | activation-loop, pipeline-reliability (FR placement) | Unanimous (axis) | Accepted-Modified |
| FS-2 | framework-steward | bound P0 hotfix (FR-5 minimum cut) | P1 | Modified (conceded grep-fallback into P0, budget-bounded) | pipeline-reliability (strips P-B) | High | Accepted-Modified |
| FS-3 | framework-steward | defend determinism / resolve DQ-2 + DQ-5 | P1 | Surviving (strengthened; nondeterminism vectors forbidden) | none | Unanimous | Accepted |
| FS-4 | framework-steward | fold capture into M040 / resolve DQ-7 | P1 | Modified (decouple command-NAME from ship-TIMING) | activation-loop (ship-vs-defer ambiguity) | Unanimous | Accepted-Modified |
| FS-5 | framework-steward | promote M040 / annotate demand signal | P1 | Modified (#2+#3, not #2+#4; demand-note no longer load-bearing for timing) | both (factual #4 error) | High | Accepted-Modified |
| FS-6 | framework-steward | place FR-9 as M040 precondition | P2 | Modified (enforcement-warning P0; graduation+doc M040; live-read out entirely) | activation-loop (doc-without-mechanism) | Unanimous | Accepted-Modified |
| FS-7 | framework-steward | budget-bound FR-6 and FR-12/FR-14 retrieval | P2 | Modified (capture-cost free; inject-cost budgeted) | activation-loop (capture/inject split) | Unanimous | Accepted-Modified |
| FS-8 | framework-steward | reconcile FR-15 with queued paper-cut | P2 | Modified (one check, three symptoms) | pipeline-reliability (add vestigial) | High | Accepted-Modified |
| FS-9 | framework-steward | gate FR-12 with Principle-XIV justification (advisory default) | P2 | Surviving | none | Unanimous | Accepted |
| FS-10 | framework-steward | keep DQ-1 index-demotion out of P0 | P3 | Surviving (full retrofit P1; burning consumer P0) | none | High | Accepted |
| PR-new1 | pipeline-reliability | budget-bound every grep-fallback path via M036a governor | P0 | New | — | Unanimous | Accepted |
| PR-new2 | pipeline-reliability | surface G-3 as named zero-reader finding in inventory | P0 | New | — | High | Accepted |
| AL-new1 | activation-loop | sequence the alarm first within P0 | P1 | New | — | Unanimous | Accepted |
| AL-new2 | activation-loop | merge coverage + byte-stability into one AC-1 | P2 | New | — | High | Accepted |
| FS-newA | framework-steward | ship G-1 capture slice in P0 | P0 | New | — | Unanimous | Accepted |
| FS-newB | framework-steward | bounded unguarded-pipeline audit artifact | P0 | New | — | High | Accepted |
| FS-newC | framework-steward | byte-equality fixtures on schema-settled surfaces | P0/P1 | New | — | High | Accepted |

No recommendation across any agent ended **Rejected** or **Disputed**. The cooperative mode produced full convergence; every item is Accepted or Accepted-Modified.

---

### Dangerous Contradictions Found

**Resolved Contradictions** (cross-review surfaced them; revision resolved them):

(a) **"Resilient rebuild + index-free fallback over an empty/mis-columned store still injects nothing."** Raised by activation-loop against pipeline-reliability's hardening-first framing (cross-review `[index-free guarantee over an empty store]`). A byte-locked grep fallback running over rows the consumer can't parse (B-3) or rows the default intensity never wrote (G-1) is "a trust receipt that certifies an empty/unparseable corpus as activated." **Resolution:** pipeline-reliability conceded in revision (Scope Discipline) — its own P-B principle ("the cache may be absent") *logically ranks a truth-layer failure above a cache-layer failure.* BUG A (B-3 format mismatch) + capture-by-default (FR-6 + explicit-capture half of FR-8) are pulled into P0 as co-primary, sequenced after the alarm but equal in membership. One fixture corpus locks both capture-format and grep-fallback; neither ships green alone.

(b) **"A new capture command duplicates M040's `/orchestrator-capture`."** Raised by framework-steward against activation-loop's proposed `orchestrator:note`/`:decide` (cross-review `[net-new-capture-command-vs-M040-already-specified]`). M040 already names `/orchestrator-capture` (§95-99) + `/orchestrator-promote --to=mem|decision|task` (§111-114) on disk. **Resolution:** activation-loop withdrew the new command name entirely. The deliberation decoupled command-NAME (use M040's design) from ship-TIMING (the minimum write-side *primitive* + round-trip-confirmation *mechanism* ride P0; the discoverable *command UX* lands the M040 track). This dissolved the apparent ship-vs-defer contradiction activation-loop had raised in return (`[does "fold into M040" ship or defer?]`).

(c) **"Read runtime memory directly (live-read)."** activation-loop's Phase-1 DQ-8 resolution kept live-read as optional augmentation; framework-steward (`[read-runtime-memory-directly-vs-runtime-agnostic-posture]`) and pipeline-reliability (`[read-runtime-memory-live-vs-index-free-determinism]`) both showed it couples dispatch to CC's `MEMORY.md` shape (Principle VI / M009 latent debt) and puts a nondeterministic source on the activation-guarantee path. **Resolution:** activation-loop withdrew live-read entirely in favor of *graduation* into `.orchestrator/` as the system of record, with live-read explicitly deferred to M009-era runtime-memory-adapter work. Enforcement (0-MEM warning + doctor check) makes divergence loud in P0; graduation makes it impossible in the M040 track.

Three further cross-review "dangerous contradictions" resolved to alignment: the FR-5-minimum-cut (framework-steward conceded grep-fallback into P0, budget-bounded); the DQ-2 determinism framing (flagged as a *mislabel risk*, not a real fork — all three agree); and the audit blast-radius (bounded to one script + direct libs, enumerate-all/fix-reproduced-only).

**Unresolved Contradictions:** None. No agent holds a Phase-4 position *against* a peer's held position. pipeline-reliability states it plainly: "I have no Phase-4 dispute I will die on." The residuals (next section) are sequencing/governance guardrails each peer already accepted.

---

### Systemic Contradictions

1. **Fix-it-loud vs fix-it-over.** *Manifests in:* the FR-5 split debate — a P0 that warns "degraded" but ships no raw-file retrieval produces fail-loud-without-fail-over (the agent is told it is under-informed, then proceeds under-informed). *Root cause:* "observability" and "recovery" were treated as one FR (FR-5) but are two mechanisms with different cost/blast-radius profiles. *Implication for spec:* FR-5 must explicitly enumerate (a) detection+warning+provenance (cheap, all consumers, P0) and (b) grep-over-raw-files retrieval (governed, P0 for the burning consumer, P1 retrofit for the rest) as distinct, separately-tested deliverables.

2. **Under-load vs over-load (both Principle-I violations).** *Manifests in:* the budget-governor debate — the fail-loud fix can trade a silent *under*-inject for a silent *over*-inject (an ungoverned grep firehose over a large corpus). *Root cause:* the proposal optimized for recall (never lose context) without naming a token ceiling. *Implication for spec:* every read-into-payload path (FR-6 digest, FR-5/FR-12/FR-14 retrieval) must route through the existing M036a governor (SC-3/SC-7); capture-write (disk) is free and unbudgeted; the index-free regression must assert hits *within budget*.

3. **Documentation-as-contract vs enforcement-as-mechanism.** *Manifests in:* FR-9 (declaring `.orchestrator/` system-of-record) and the system-of-record AC — a doc note with no divergence detector is "precisely the fail-open P-A forbids." *Root cause:* several FRs ship the *statement* of an invariant without the *check* that enforces it. *Implication for spec:* every declared invariant (system-of-record, freshness, no-vestigial-index) needs a paired loud check; the consolidated doctor check is where three of these land.

4. **Sequencing-vs-priority conflation inside P0.** *Manifests in:* activation-loop's worry that "alarm is the substrate" reads as "capture is nice-to-have." *Root cause:* build-order (alarm has no dependencies, ships day one) and membership-priority (capture is co-primary) are different axes that English collapses. *Implication for spec:* state P0 as an *unordered set* with an *intra-P0 build sequence* — sequence ≠ priority.

5. **Comment-vs-code drift as a latent off-by-one.** *Manifests in:* B-3 — `scope-filter.sh` *comments* columns `4=Scope,5=When` but its awk reads `$5`/`$6` (leading-pipe `awk -F'|'` shifts every field by one). *Root cause:* the same "assumed, never tested" pathology as the `:117` guard — documentation was trusted as ground truth. *Implication for spec:* the round-trip oracle must assert against *observed awk indices*, and DQ-6 reconciles *three* shapes (producer, consumer-comment, consumer-awk), not two.

---

### Convergence Achieved

1. **Deterministic-grep floor; embeddings additive-only (DQ-2 jointly RESOLVED, not open).** — Strength: **Unanimous.** *Agreed recommendation:* deterministic substring/grep over raw `knowledge/**/*.md` is the activation guarantee and the *sole* input to the corpus-gate evidence artifact; embeddings, if ever added, are additive recall that never gates and never enters the receipt; forbid nondeterminism vectors (`LC_ALL=C` sort, no wall-clock fields in artifact bodies, stable file ordering). *Supporting agents:* pipeline-reliability (revision Rec 6, reproducibility), framework-steward (revision Rec 3, Principle IX + hardening), activation-loop (revision Rec 10, round-trip same-instant confirmation). *Evidence basis:* three independent rationales reach one invariant; corpus-gate skill's deterministic design is verifiable in-repo. *Pre-existing or earned:* **earned** (DQ-2 was open in the proposal; all three explicitly flag the mislabel risk so synthesis does not record a false fork).

2. **Proven bugs B-1/B-2/B-3/B-4/B-5 + BUG A ship P0, milestone-independent.** — Strength: **Unanimous.** *Agreed recommendation:* the §7 cleave axis holds; file:line-verified defects ship as a P0 hotfix not gated on any milestone; B-3 (format mismatch) foregrounded co-primary via the cache-vs-source-of-truth ranking (raw-store-unreadable > index-absent). *Supporting agents:* all three (activation-loop Rec 1; pipeline-reliability "What remains fixed" + Scope Discipline concession; framework-steward Rec 1/New-B, "zero daylight"). *Evidence basis:* live source independently re-verified by two reviewers in different lanes — `rebuild-index.sh:11/40/117`, `build-context.sh:198-208/223`, `scope-filter.sh:351-354`. *Pre-existing or earned:* **pre-existing** on the bugs being P0; **earned** on B-3's co-primary foregrounding.

3. **Round-trip + byte-equality is the acceptance oracle.** — Strength: **High.** *Agreed recommendation:* AC-1 runs the capture→rebuild→grep→assert round-trip over the *legacy documented* `append-decision.sh`/`append-knowledge.sh` primitives on a *default-intensity (Quick)* fixture project AND byte-asserts the resolved row — one AC, both guarantees (coverage + byte-stability) — with the *dynamic* round-trip oracle split from the *static* byte-equality fixtures so a frozen file is never forced to contain a runtime-appended row. *Supporting agents:* all three (activation-loop Rec 6 + New-2; pipeline-reliability Rec 3; framework-steward New-C). *Evidence basis:* the V1.x byte-equality lesson + the field note's "diligent operator ends up with an unreadable store" thesis. *Pre-existing or earned:* **earned** (proposal AC-1 was behavioral and covered only the new command).

4. **One system of record = `.orchestrator/` via graduation, not live-read.** — Strength: **Unanimous / very high.** *Agreed recommendation:* `.orchestrator/` is the system of record reached by *graduation*; live-runtime-memory-read is cut entirely (deferred to M009); divergence is made loud in P0 (FR-15 0-MEM warning + doctor check) and impossible in the M040-track graduation build. *Supporting agents:* all three (activation-loop Rec 4, withdrew live-read; framework-steward Rec 6, Principle VI; pipeline-reliability `[read-runtime-memory-live-vs-index-free-determinism]`). *Evidence basis:* G-3 field note (50+ decisions, two milestones, 0-MEM, no warning) + runtime-agnostic launch posture. *Pre-existing or earned:* **earned** (DQ-8 was an open fork in the proposal).

5. **Capture command = M040's design pulled forward (primitive in P0, UX in M040).** — Strength: **Unanimous / very high.** *Agreed recommendation:* no net-new capture verb; FR-7 = M040's `/orchestrator-capture` + `/orchestrator-promote` extended with round-trip-confirmation + local decision-vs-knowledge classification (zero GitHub/Giscus dependency); the command UX ships M040-track; the underlying write primitive + confirmation mechanism ship P0. *Supporting agents:* all three (activation-loop Rec 5; framework-steward Rec 4; pipeline-reliability "build the mechanism in P0, expose the command in P1"). *Evidence basis:* M040 §95-99 + §111-114 specify the commands, storage paths, frontmatter on disk now; Principle XI. *Pre-existing or earned:* **earned** (DQ-7 was open; activation-loop withdrew its new-command position).

6. **Fail-loud + minimal provenance header + 0-MEM warning, budget-bounded.** — Strength: **Unanimous.** *Agreed recommendation:* every index consumer detects empty/missing/stale index and emits a visible warning into the payload + stderr; prefers grep-over-raw-files over silent first-N; stamps a *minimal* provenance header in the payload (source enum + resolved-id + index_age) with full provenance to stderr/evidence-artifact; FR-15 warns on a 0-MEM inject on a mature project; all grep retrieval routes through the M036a governor. *Supporting agents:* all three. *Evidence basis:* B-2 (`build-context.sh:208` silent `head -5`, no warning) + the field note. *Pre-existing or earned:* **earned** (proposal had FR-5/FR-15 but unbudgeted and with full-header-always).

7. **Bounded audit, not "audit all commands."** — Strength: **High.** *Agreed recommendation:* the unguarded-command audit is a bounded grep-enumeration of `rebuild-index.sh` + its *directly sourced* libs (`lib/index-utils.sh`, `lib/graph-db.sh`) only; `:117` (reproduced) is fixed in P0; any other unguarded pipeline is fixed P0 only if a failure is reproduced, else logged as a justified-and-tracked row; AC = zero *unjustified*-unguarded pipelines. *Supporting agents:* pipeline-reliability (revision Rec 2, conceded the bound), framework-steward (New-B). *Evidence basis:* `:40` guarded `|| true`, `:117` not — "guard assumed, never enumerated." *Pre-existing or earned:* **earned** (Phase-1 framing was "audit the whole script, fix or justify each").

8. **Corpus-gate must stay index-independent (and advisory-default).** — Strength: **Unanimous on index-independence; high on policy.** *Agreed recommendation:* the corpus-gate's grep-over-raw-files determinism is the load-bearing asset and must be preserved; FR-12 bakes in *advisory-default* with a dispatch-refusing hard gate reserved for `comments` spec-amendment only, each seam shipping incrementally with a one-line Principle-XIV justification and a mandatory reproducible evidence artifact. *Supporting agents:* framework-steward (Rec 9), pipeline-reliability (DQ-4, near-zero divergence), activation-loop (mechanism, no hard-gate position). *Evidence basis:* corpus-gate skill is opt-in-per-seam by design; only one seam currently routes through it. *Pre-existing or earned:* **earned** (DQ-5 was open).

---

<!-- CONVERSUS:DISPUTES_BEGIN -->

### Remaining Disputes

The residuals are **governance seams, not hard conflicts.** In every case the "opposing" agent already wrote the compatible shape in revision; these are recorded so synthesis does not flatten a sequencing nuance into a false either/or.

**(1) Scoping capture-by-default — explicit operator decisions only vs broad capture.**
- *Positions:* framework-steward holds capture-by-default at Quick must remain scoped to **explicit operator/SME decisions only** (a one-line `append-decision.sh` row-append), never an "auto-capture all knowledge at Quick" firehose, and that the inject side must stay budgeted (revision Rec 7, New-A scope-boundary). activation-loop's framing is "Quick must *capture*" — broad in spirit, but its revision narrowed the P0 ask to *explicit* decisions and conceded the inject-side budget fully.
- *Arguments:* framework-steward — capture-write is free (zero inject cost) so it ships unbudgeted, but the *read* into payload bites Principle I and the *scope* of what auto-captures must be bounded or it pollutes the system-of-record store and degrades every inject. activation-loop — the most dangerous place to forget a decision is a Quick change, which gets the least context; the explicit-capture primitive is the one item it refuses to concede.
- *Synthesizer assessment:* This is **convergent, not disputed.** Both agents settled on: explicit-decision capture at Quick ships P0 unbudgeted (disk write); the FR-6 inject digest is bounded by the Quick token budget via the M036a governor; auto-graduate (the only "broad" capture path) is gated by activation-loop's own `decision:`-tagged, phase-close qualification rule (AL-8) and defers to the M040 track. The capture/inject cost split (FS-7) dissolves the Principle-I objection cleanly. Evidence: a disk row-append provably carries no payload-token cost; an ungoverned grep firehose provably does when the corpus is large.
- *Recommended resolution:* Spec states two sentences: (a) "explicit-decision capture at Quick ships P0, unbudgeted, scoped to operator/SME decisions only"; (b) "every read-into-payload path routes through the M036a governor; the index-free regression asserts hits *within budget*." Auto-capture-all is not in scope; auto-*graduate* of `decision:`-tagged notes at phase-close is M040-track.

**(2) FR-12 corpus-gate — hard gate default-on vs advisory-default + governor (DQ-5).**
- *Positions:* The proposal's DQ-5 left "hard vs advisory" open and FR-12 reads "default-on… on the entry points that consume feedback or emit human-facing questions." framework-steward holds **advisory-default everywhere, hard-gate only on `comments` spec-amendment**, per-seam Principle-XIV justification, incremental rollout. No agent opposes this.
- *Arguments:* framework-steward — a global hard gate is unrequested cross-cutting complexity (Principle XIV) and converts fail-open into fail-closed-blocking (the single-point-of-failure P-B exists to dissolve); advisory *surfacing* delivers the "don't ask already-answered questions" value without the blocking failure mode. pipeline-reliability and activation-loop both reached the same policy from the single-point-of-failure and grep-mechanism angles respectively.
- *Synthesizer assessment:* **Convergent.** The only live risk is a *synthesis miscount* — DQ-5's "hard vs advisory" wording plus FR-12's "default-on" could be read as license for a global hard gate. The three independent justifications (XIV speculative-complexity, SPOF, grep-floor mechanism) *stack*; they must not be double-counted as agreement-on-strength. Evidence: the corpus-gate skill is opt-in-per-seam by design, and operators value advisory surfacing of already-answered findings without a dispatch block.
- *Recommended resolution:* Resolve DQ-5 as "advisory-default everywhere; hard-gate only on `comments` spec-amendment; each seam ships incrementally with a one-line XIV justification at plan time; the deterministic-grep evidence artifact is mandatory on every seam."

**(3) Residual sequencing-vs-priority seam — is capture-by-default strictly P0 or P0-fast-follow?**
- *Positions:* pipeline-reliability's framing leads with "the alarm is the substrate that makes every P0 fix verifiable," which can read as ranking the alarm P0-primary and capture as a tenant. activation-loop holds capture (FR-6 + G-1) and BUG-A (FR-1) are **co-primary** P0 members, sequenced *after* the alarm in build order but equal in membership. framework-steward's New-A ships the G-1 slice in P0 atomically with FR-6.
- *Arguments:* pipeline-reliability — FR-15 + FR-5 have no dependencies and ship day one; AC-1's "confirms the entry resolves" literally depends on a working observable inject path, so the alarm is a prerequisite. activation-loop — the field-note failure was a *capture* failure observed *through* a missing alarm; both halves are co-primary or the hotfix re-ships the incident with "a smoke detector over an empty room." All three verified M040's formal trigger has NOT cleanly fired (§0 meets #2 + #3, not #4 which needs ≥5 inbox reports), so deferring capture to M040 defers it indefinitely.
- *Synthesizer assessment:* **Convergent on membership; the only seam is wording.** pipeline-reliability's own Scope Discipline says "both are P0, the list is unordered"; activation-loop accepts alarm-first *build order*. The distinction the spec must preserve is build-sequence ≠ membership-priority. The "strictly P0" reading wins on evidence: M040's trigger is borderline-unfired, so P0-fast-follow has no committed date and FR-6 shipped without the capture half would leave a Quick Decisions slot empty-forever (a subtler fail-open — the surface reports healthy).
- *Recommended resolution:* Spec states P0 as an **unordered set** (`FR-1, 2, 3, 4, 5-budgeted, 6, 11, 15 + G-1 explicit-capture slice + FR-9 enforcement-warning`) with an **intra-P0 build sequence** (alarm first by dependency, capture/BUG-A immediately after). Sequence is not priority; capture-by-default is strictly P0, not a fast-follow.

<!-- CONVERSUS:DISPUTES_END -->

---

### Actionable Spec Changes

The primary deliverable. Every change traces to a scorecard recommendation.

#### P1 — Must implement

1. **Correct the BUG-A citation to the actual executing code.** *(AL-3, PR Off-Base, AL Phase-4 Dispute-3)* The proposal (§2 B-3, §8) says `filter_decisions` "reads Scope from `$4`, When from `$5`." The live `scope-filter.sh` *comment* at `:351` says `1=ID, 2=Decision, 3=Choice, 4=Scope, 5=When, 6=Rationale`, but the executing awk at `:353-354` reads `scope_col` from **`$5`** and `when_col` from **`$6`** — because `awk -F'|'` on a leading-pipe markdown row makes `$1` empty and shifts every column by one. Producer `append-decision.sh:93` writes `| ID | When | Scope | Decision | Choice | Rationale | Revisable |` (When=col2, Scope=col3 of the *content*, i.e. `$3`/`$4` under awk). State precisely: DQ-6 reconciles **three** disagreeing shapes — producer, consumer-comment, consumer-awk — and the round-trip oracle (AC-1) must assert against the **observed awk field indices (`$5` scope / `$6` when)**, not the documented column order.

2. **Move BUG A + explicit-capture-by-default into the P0 slice.** *(AL-1, AL-2, PR-11, FS-newA)* P0 = `FR-1, FR-2, FR-3 (bounded audit), FR-4, FR-5 (budgeted), FR-6 (bounded digest), FR-11, FR-15` **+ the G-1 explicit-decision-capture slice of FR-8** (a one-line `append-decision.sh` row-append at Quick) **+ the FR-9 enforcement-warning half.** State P0 as an *unordered membership set* with an *intra-P0 build sequence* (alarm = FR-15 + FR-5 first by dependency; BUG-A + capture immediately after). FR-6 (inject) and the G-1 capture half ship in the **same change set** so a Quick project never ships a Decisions slot that is empty-forever.

3. **Rename FR-7 to "pull M040's `/orchestrator-capture` slice forward," not a net-new command.** *(AL-5, FS-4)* FR-7 is not `orchestrator:note`/`:decide`. It is M040's already-on-disk `/orchestrator-capture` (§95-99) + `/orchestrator-promote --to=mem|decision|task` (§111-114), extended with two deltas: (a) round-trip-confirmation (the command asserts the just-written entry resolves in the next inject — reuses the AC-1 oracle); (b) local decision-vs-knowledge classification ownership (operator-locked rulings → `DECISIONS.md`, reusable patterns → `KNOWLEDGE.md`), zero GitHub/Giscus dependency. The discoverable command **UX is M040-track**; the underlying write primitive + confirmation mechanism ship P0. Resolve DQ-7 accordingly.

4. **Change FR-9 to graduation/ingest + document `.orchestrator/` as system of record; drop live-read to a non-default option.** *(AL-4, FS-6)* Resolve DQ-8: graduation into `.orchestrator/` is the **sole** mechanism on the guarantee path; live-runtime-memory-read is **cut entirely** (deferred to M009-era runtime-memory-adapter work), not kept as opt-in augmentation. Split FR-9: the enforcement-warning (0-MEM-on-mature-project + doctor check flagging runtime-memory decisions absent from `.orchestrator/`) ships **P0**; the graduation mechanism + the "`.orchestrator/` is system of record" documentation lands the **M040 track**. Bind FR-13 (corpus manifest sweeps real content) to the same graduation step (AL-7).

5. **Resolve DQ-2 to the deterministic-grep floor (in-brief invariant, not open question).** *(PR-6, FS-3, AL-10)* Deterministic grep over raw `knowledge/**/*.md` is *the* activation guarantee and the *sole* input to the corpus-gate evidence artifact; embeddings, if ever added, are additive recall that never gates and never enters the receipt. Forbid nondeterminism vectors: `LC_ALL=C` sort, no wall-clock fields in artifact bodies, stable file ordering. Record as **jointly resolved consensus** citing all three reviews — do not carry as a surviving DQ.

6. **Add the M036a token-budget governor to FR-5 / FR-6 / FR-12 / FR-14 retrieval.** *(PR-new1, FS-7)* Every *read-into-payload* path routes through the existing M036a governor (SC-3/SC-7); the index-free regression asserts hits *within budget*, not unbounded. Capture-*write* (disk row-append) is free and unbudgeted. The provenance header carried in the payload is *minimal* (source enum + resolved-id + index_age); full provenance + `schema_version` go to stderr/evidence-artifact.

7. **Bound the FR-3 audit scope.** *(PR-2, FS-newB)* FR-3's "audit the whole script" becomes a bounded grep-enumeration artifact scoped to `rebuild-index.sh` + its directly-sourced libs only (`lib/index-utils.sh`, `lib/graph-db.sh`). `:117` (reproduced) is fixed in P0; any other unguarded pipeline is fixed P0 only with a reproduced failure, else a justified-and-tracked row. AC: artifact lists zero *unjustified*-unguarded pipelines. FR-4 must preserve the genuine `knowledge/archive/` cold-storage exclusion (the script's `:6` header comment declares it) while dropping the bare `*/archive/*` false-match in `resolve-entries.sh:45` and `rebuild-index.sh:74`. (Note: the proposal cites `resolve-entries.sh` under `scripts/dispatch/`; it actually lives at `scripts/knowledge/resolve-entries.sh` — correct the path.)

8. **Resolve DQ-5: corpus-gate advisory-default; hard gate only on `comments`.** *(FS-9, PR-8)* FR-12 bakes in advisory-default at each seam, with a dispatch-refusing hard gate reserved for `comments` spec-amendment only, each seam shipping incrementally with a one-line Principle-XIV justification and a mandatory deterministic-grep evidence artifact.

#### P2 — Should implement

9. **Split the regression harness; sequence byte-equality to schema-settledness.** *(PR-3, AL-new2, FS-newC)* Static byte-equality fixtures ship P0 for schema-settled deterministic surfaces (`INDEXED:/SKIPPED:` summary line, path-collision index count, freshness flag, B-3 round-trip resolution). The provenance-header byte-fixture ships P1 *with* its versioned schema (you cannot byte-lock an unsettled contract). The round-trip oracle is a *separate dynamic* lane (writes → rebuilds → greps → byte-asserts the resolved row against a computed-expected, not a frozen file) — same determinism discipline, different assertion shape. AC-1 runs on a *default-intensity (Quick)* fixture and over the *legacy documented* primitives (AL-6).

10. **Pin the provenance header as a versioned byte-contract (P1) with a resolved-id surface.** *(PR-4)* Full versioned schema (`source:` enum `{index,grep-fallback,degraded}`, `index_age`, `entries_considered`, `resolved-id`, `schema_version`) lands P1 with its fixture and M034/M038/wiki consumer documentation. The header has *two* consumers — downstream parsers and the synchronous capture-confirm — so it must carry a `resolved-id` the confirm-step asserts against, versioned so M034/M038 ignore it gracefully.

11. **Consolidate the doctor knowledge-gap check (one check, three symptoms).** *(FS-8, PR-10)* A single `orchestrator:doctor` check, one owner, covers: (1) 0-MEM inject on a project with prior milestones/decisions (FR-15); (2) a second vestigial index/db exists (PR-10, via FR-11); (3) runtime-memory decisions absent from `.orchestrator/` (FR-9 enforcement). Reconcile-or-supersede `papercut-doctor-knowledge-gap-surface.md` before intake — no second overlapping doctor surface.

12. **Make content-hash the freshness signal (FR-10).** *(PR-9)* Content-hash of the newest `knowledge/**/*.md` set is the freshness contract; mtime is at most a fast pre-filter (`orchestrator:update` re-installs and git checkouts rewrite mtimes wholesale). P0 ships a cheap content-hash compare for stale/empty detection + loud warning; the standing doctor-wired contract + rebuild-then-warn policy (DQ-3, PR-7) lands P1. The capture-confirm runs its own targeted grep independent of the freshness gate (never a hard block on the capture path).

13. **Specify the auto-graduate qualification rule (FR-8 second half).** *(AL-8)* Graduate only `decision:`-tagged (or equivalent structured) `execution-log.jsonl` notes, fired at phase-close (consolidate boundary), not continuously — keeps the system-of-record store clean. This half is M040-track (only the explicit-capture half rides P0).

#### P3 — Consider

14. **Surface the init-header alignment as a four-call-site CI checklist item.** *(AL-9)* Whichever DQ-6 winner is chosen, one change set must re-align all four artifacts — init-template `DECISIONS.md` header, append script, consumer comment, consumer awk — asserted in CI, modeled on the bounded audit-artifact pattern.

15. **Annotate the M040 demand signal (roadmap hygiene only).** *(FS-5)* Append a note to `M040-ambient-feedback-loop.md` recording trigger conditions **#2 (one new consumer: the archive-rooted project) + #3 (M034 branch-active)** are met — *not* #4 (which requires ≥5 inbox reports; §0 supplies one). This is roadmap hygiene; it is **no longer load-bearing** for when the capture loop ships (the P0 primitive ships on a committed timeline regardless).

16. **Surface G-3 as a named zero-reader finding in the consumer inventory.** *(PR-new2)* The FR-5 consumer inventory explicitly records "runtime agent memory is a store with zero readers" as a first-class row, so enumeration surfaces the two-store divergence rather than enumerating only already-wired stores. The *fix* (graduation) is M040-track; only the *surfacing* is P0.

---

### Key Concessions

**pipeline-reliability** — Conceded the central capture-format point: a perfectly hardened, byte-equality-locked, index-free grep rebuild over a *mis-columned (B-3)* or *never-written (G-1)* store still injects nothing — and this follows *directly from its own P-B principle* (the cache may be absent, so a truth-layer failure outranks a cache-layer failure). Therefore FR-1 (B-3) is a *prerequisite* of its index-free fixture suite, and FR-6 + the explicit-capture half of FR-8 join P0 (revision Scope Discipline, Rec 11). Also conceded framework-steward's blast-radius bound: the unguarded audit is a bounded grep-enumeration, not a repo-wide refactor (revision Rec 2), and the all-consumers grep fallback must be budget-bounded through the M036a governor (revision New-rec). Came in leading the rebuild-bug as P0-primary; left holding B-1 and B-3 as co-primary.

**activation-loop** — Withdrew its two genuine over-reaches: the net-new `orchestrator:note`/`:decide` command name (M040 already names `/orchestrator-capture` + `/orchestrator-promote` on disk — Single-Source-of-Truth-for-commands; revision Rec 5) and live-runtime-memory-read as opt-in augmentation (couples dispatch to CC's `MEMORY.md` shape, Principle VI / M009 debt; revision Rec 4). Conceded the FR-6 *inject* side to framework-steward's token-budget framing (capture-write is free, inject is budgeted; cross-review + revision Rec 2). Dropped the "single-file change" justification for DQ-6 (contradicted by its own four-call-site finding; revision Rec 3). Held exactly one item non-negotiable: the explicit-decision-capture-at-Quick *primitive* ships P0 (revision Rec 2, disputes) — because M040's trigger is borderline-unfired.

**framework-steward** — Conceded the FR-5 "minimum cut" stripped P-B's load-bearing fail-over: a P0 that warns "degraded" but ships no raw-file retrieval is fail-loud-without-fail-over; the minimal index-free grep path belongs in P0, budget-bounded (revision Rec 2). Decoupled command-NAME from ship-TIMING — its "fold into M040" had silently read as "defer indefinitely" since M040's trigger is unfired; pulled the G-1 capture slice and FR-9 enforcement-warning into P0 as local primitives (revision Rec 1/4/6, New-A). Corrected its own factual error: M040 trigger #4 needs ≥5 reports (§0 has one) — the met conditions are #2 + #3, not #2 + #4 (revision Rec 5). Held three constitution lines firm: inject-side budget governance, live-read out of scope, deterministic-grep floor — the three places where conceding would trade a proven fix for a new silent failure.

### Recommendation Dispositions

#### Recommendation 1: Declare `packaging/install/` scope disposition explicitly

- **Original position**: Add a sentence to the conversus Tier 2 XII scope declaration paragraph explicitly stating that `packaging/install/*.sh` scripts are outside XII's linter scope, governed instead by XXII's end-to-end install testing.
- **Disposition**: Modified
- **Explanation**:

Two challenges from the coherence-advocate's cross-review require adjusting this recommendation's framing without affecting its substance.

First, the coherence-advocate's cross-review (Dangerous Contradictions §3, "Analytical Baseline: Invalid Current State vs. Accepted Current State") establishes that L175–185 in the current constitution represents a procedural defect under Principle VI — on-disk state attributed to an event (ratification) that has not yet occurred. My original Alignment §3 cited L175–185 as settled on-disk evidence for the VIII/XII scope boundary. That citation is procedurally incorrect: the correct baseline is that L175–185 is pending text, not ratified text. My original Rec 1 proposed text that invoked "XXII's end-to-end install testing invariant" as the governing mechanism for `packaging/install/` scripts — that substance is correct and unaffected — but the internal justification chain in Missed Opportunities §1 traced through L175–185 as the authority for the scope split. That trace must be replaced with a direct reference to CONFORMANCE.md's Component-tier declarations table, which is the authoritative source independent of whether L175–185 exists in the constitution.

Second, the coherence-advocate's cross-review (Dangerous Contradictions §4, "Namespace Qualification: Explicit Recommendation vs. Structural Silence") correctly identifies that using bare "XII" to refer to the inherited build-fractal principle risks a reader navigating to orchestrator §XII (Hook Isolation) instead. Any new sentence in the proposal must use "conversus Tier 2 XII."

**Revised recommendation**: Add to the proposal's conversus Tier 2 XII scope declaration paragraph: "Config-knob-shaped variables inside `packaging/install/*.sh` installer scripts are outside conversus Tier 2 XII's linter scope; their internal variable hygiene is governed by inherited XXII's end-to-end install testing invariant and standard code review, not by `check-dead-infra.sh`." This sentence must be drafted with CONFORMANCE.md's Component-tier declarations table as its evidentiary basis, not the pending L175–185 text, and must be staged in Phase 2 after the baseline is corrected (see New Recommendation 2).

---

#### Recommendation 2: Qualify `references/` inclusion in XII scope with an Extended-bucket callout

- **Original position**: Append text to the XII scope statement distinguishing config-knob content (conversus Tier 2 XII scope) from file-system reachability (Principle VIII scope per CONFORMANCE.md Extended bucket).
- **Disposition**: Modified
- **Explanation**:

Two adjustments are required, both triggered by the coherence-advocate's cross-review.

First, the coherence-advocate's cross-review (Dangerous Contradictions §1 and §3) established that the scope boundary between VIII and conversus Tier 2 XII must not be cited as deriving from L175–185, which is procedurally pending. My original Rec 2 text cited "CONFORMANCE.md § Tier 2 XII — Three-bucket structure" directly, which is correct — but the framing in my original review's Missed Opportunities §2 (which supported the rationale for Rec 2) invoked "CONFORMANCE.md L78" via the constitution's pending note as the explanation for why the Extended bucket exists. After L175–185 is removed, the Extended bucket's authority derives from CONFORMANCE.md alone, so the proposal text should cite CONFORMANCE.md directly as a first-class source, not as a secondary confirmation of the pending constitution amendment.

Second, per the namespace qualification issue (Dangerous Contradictions §4): the callout text must use "conversus Tier 2 XII" throughout.

**Revised recommendation**: Append to the XII scope paragraph in the proposal: "For `references/`: conversus Tier 2 XII governs config-knob-shaped content within reference docs. File-system-level reachability of reference doc files is governed by Principle VIII per the Extended bucket in `CONFORMANCE.md` § Tier 2 XII — Three-bucket structure." This text is self-contained and does not depend on the constitution's pending amendment note for its evidentiary basis — a reader of only the proposal and CONFORMANCE.md can reconstruct the full scope map without constitutional navigation.

---

#### Recommendation 3: Add a pairwise interaction paragraph for the "config knob governs a distribution surface" case

- **Original position**: Add a paragraph between the XII and XXII inheritance declarations stating how the two principles apply independently to dual-governed artifacts, with an example of a config knob controlling a distribution surface.
- **Disposition**: Surviving
- **Explanation**:

The coherence-advocate's cross-review (Dangerous Contradictions §3, "Interaction analysis scope: deliberation-time discovery vs. proposal-time discharge") directly engages this recommendation. The key challenge was whether the coherence-advocate's dismissal of the Change 5/XII tension (as non-existent) could be read as "no interaction analysis is needed." My own cross-review of the coherence-advocate (Dangerous Contradictions §3) correctly resolved this: "The actual pairwise interaction question (config knob governs a distribution surface — XII liveness or XXII correctness?) is a different question than the Change 5/XII tension the charter raised, and the coherence-advocate never addressed it."

The coherence-advocate's cross-review of my work (Tensions §4, "Single Deliberation Set Justification") confirms the conclusion: "Both reviews support the single-set design only if the proposal is strengthened with the text each review recommends. A synthesis that reads coherence-advocate's XII/Change 5 dismissal as 'single-deliberation set is fine' would underweight pairwise-advocate's finding that the scope-separation analysis is still missing from the proposal text."

The recommendation survives. The only needed adjustment is terminology: the proposed paragraph draft should use "conversus Tier 2 XII" rather than bare "XII." The substance of the interaction analysis — that conversus Tier 2 XII governs liveness and XXII governs correctness as non-overlapping sub-properties of the same dual-governed artifact — was not challenged by any cross-review.

---

#### Recommendation 4: Address the "correctly-manifested dead file" edge case

- **Original position**: Add a sentence to the XXII inheritance note acknowledging that XXII's force-include discipline covers manifest completeness, and that installed-artifact reachability from live code paths is a Principle VIII concern requiring `run-doctor.sh` scope evaluation.
- **Disposition**: Surviving
- **Explanation**:

The coherence-advocate's cross-review (Tensions §3, "Whether the 'correctly-manifested dead file' edge case is within coherence-advocate's charter") explicitly declined to challenge the substance of this finding, noting only that the coherence review's Principle VIII analysis was incomplete with respect to installed-artifact reachability. The cross-review's coordination note reads: "Synthesis should treat pairwise-advocate's Recommendation 4 as load-bearing even without coherence validation, because the underlying Principle VIII question is real and consequential." The cross-review further notes that "this specific question warrants explicit attention in the self-consistency deliberation" — which reinforces that the proposal must surface it rather than leave it for the self-consistency deliberation to discover independently.

No cross-review challenged the substance of the finding: a file that satisfies XXII's force-include invariant (appears in the manifest) but is never read from the installed location may fall outside VIII's current `run-doctor.sh` scan scope, XII's linter scope, and XXII's linter scope simultaneously. The recommendation survives without modification.

---

#### Recommendation 5: Separate adoption-feasibility argument from scope-separation argument in L45

- **Original position**: Add a sentence to L45 clarifying that the single-deliberation-set rationale addresses adoption feasibility, while scope-separation analysis is answered in the pairwise interaction paragraph (Rec 3), and is not delegated to the deliberation.
- **Disposition**: Surviving
- **Explanation**:

The coherence-advocate's cross-review (Tensions §4, "Single Deliberation Set Justification") confirms this recommendation's validity by distinguishing the two questions clearly: "Coherence-advocate's dismissal addresses the charter's specific question (XII/Change 5 tension); pairwise-advocate's critique addresses the structural completeness of the justification (scope-separation analysis). Both are correct in their own domains." My own cross-review of the coherence-advocate (Tensions §4) reached the same conclusion through the same analysis.

The recommendation is tightly coupled to Rec 3: Rec 5 adds the meta-clarification at L45 ("scope-separation analysis is answered in the pairwise interaction paragraph"), Rec 3 adds the substance it points to. Neither is complete without the other, and both are confirmed by cross-review analysis as required for the proposal to be self-sufficient before the blind deliberation.

The recommendation survives without modification.

---

#### Recommendation 6: Name governance attribution for config knobs inside XXII evidence scripts

- **Original position**: Add a parenthetical near the XXII evidence-scripts note stating that these scripts are conversus Tier 2 XII-scoped for their internal config-knob hygiene and XXII-governed for their behavioral correctness as distribution-verification evidence.
- **Disposition**: Modified
- **Explanation**:

The coherence-advocate's cross-review (Dangerous Contradictions §4, "Namespace Qualification: Explicit Recommendation vs. Structural Silence") correctly identifies that my original parenthetical draft used bare "XII" twice. Both instances must become "conversus Tier 2 XII" to prevent a constitution reader from navigating to orchestrator §XII (Hook Isolation).

**Revised parenthetical**: "(These scripts reside in `scripts/` and are therefore conversus Tier 2 XII-scoped for their internal config-knob hygiene; XXII governs their behavioral correctness as distribution-verification evidence. Both must be satisfied; no conflict.)"

The substance of the recommendation is unchanged — the governance attribution gap is real. A compliance auditor encountering a dead knob in `manifest-coverage.sh` needs an authoritative governing principle; the proposal should name it rather than leaving it implicit. The modification is solely a namespace-qualification adjustment.

---

#### Recommendation 7: Cite CONFORMANCE.md's three-bucket structure by section heading in the proposal

- **Original position**: Add a sentence to the XII inheritance shape description naming CONFORMANCE.md § Tier 2 XII — Three-bucket structure as the authoritative scope map for XII enforcement decisions.
- **Disposition**: Surviving
- **Explanation**:

The coherence-advocate's cross-review (Tensions §1, "Governance Section Amendment vs. Proposal Text Amendment") confirmed this recommendation and established its relationship to coherence-advocate's Rec 4: "Both should be implemented, but with explicit cross-references. The Governance section pointer (coherence-advocate Rec 4) is the durable structural fix; the proposal citation (pairwise-advocate Rec 7) is the immediate navigational aid for this deliberation set." The Safe Agreements section (Safe Agreement 3, "CONFORMANCE.md Is Load-Bearing and Currently Under-Integrated") further confirmed the underlying diagnosis: "the convergence across different source documents strengthens confidence that this is a real documentation gap."

The recommendation survives. The added nuance from the cross-review is that Rec 7 should carry a clarifying note in its proposed text: the sentence being added to the proposal is the per-deliberation navigational aid; coherence-advocate's Rec 4 addresses the same gap at the constitutional Governance section level for all future amendment authors. The two are complementary, not redundant, and the proposal text should make this explicit so the blind deliberation's review does not flag the two fixes as a documentation collision.

---

### New Recommendations

- **Apply "conversus Tier 2 XII" naming uniformly across all new proposal text** (Priority: P1)
  - **Triggered by**: Coherence-advocate's cross-review of my work, Dangerous Contradictions §4 ("Namespace Qualification: Explicit Recommendation vs. Structural Silence"). The cross-review established: "If synthesis adopts coherence-advocate's Recommendation 6 ('conversus Tier 2 XII' qualifier everywhere) and also incorporates pairwise-advocate's scope-boundary additions into the proposal verbatim, the resulting document will carry 'conversus Tier 2 XII' in sections derived from coherence-advocate's recommendations and bare 'XII' or 'Tier 2 XII' in sections derived from pairwise-advocate's recommendations. The inconsistency would appear in the same proposal document, defeating Recommendation 6's purpose."
  - **Proposed change**: Establish as a cross-cutting synthesis rule: wherever the revised proposal text introduces or quotes "XII" or "Tier 2 XII" as a reference to the inherited build-fractal principle, substitute "conversus Tier 2 XII." This applies to all text added via modified Recs 1, 2, 3, 5, 6, and 7. It is not a revision to a single proposal location but a constraint applied to all edits arising from this deliberation set. The rule does not apply to references to orchestrator §XII (Hook Isolation), which correctly retains the bare form.
  - **Rationale**: After coherence-advocate's P1 fix removes L175–185, the constitution will contain no "conversus Tier 2 XII" pointers. All inherited-principle references will exist only in the proposal and CONFORMANCE.md. Inconsistent naming in the proposal — some sections using the qualified form, others using bare "XII" — would make the blind deliberation's criterion (i) check harder to satisfy and would undermine the namespace separation that coherence-advocate's Rec 6 is designed to enforce. This is a prerequisite for synthesis coherence, not a stylistic preference.

- **Establish a two-phase implementation sequencing rule** (Priority: P1)
  - **Triggered by**: Coherence-advocate's cross-review of my work (Tensions §2, "P1 Priority Ordering: Process Validity vs. Scope Precision") and my own cross-review of coherence-advocate's work (Tensions §2, same section). Both cross-reviews independently concluded that the two sets of P1 recommendations operate at different layers — process integrity vs. substantive completeness — and that process-integrity fixes must precede substantive-completeness fixes.
  - **Proposed change**: The synthesis document should establish an explicit two-phase ordering. **Phase 1** covers coherence-advocate's Rec 1 (remove L175–185 from constitution, place full text in `PENDING-VIII-AMENDMENT.md` in the ratification directory) and Rec 2 (name version bump target as 2.2.0, making it visible in the ratification artifact before any scope text is finalized). **Phase 2** covers pairwise-advocate's modified Recs 1, 2, and 3 (scope-precision text additions to the proposal, drafted with CONFORMANCE.md as the direct authority for the VIII/XII boundary). Phase 2 items must not be drafted until Phase 1 is complete, because the scope-precision text's evidentiary basis changes depending on whether L175–185 exists in the constitution.
  - **Rationale**: Without an explicit sequencing rule, a synthesis implementer could draft pairwise-advocate's Rec 1 text (which previously traced through L175–185 as the authority) before the baseline is corrected, producing a ratification artifact that references pending text as settled evidence. The two-phase rule prevents this by establishing the correct on-disk state before substantive clarifications are written. The sequencing is also required for the version-bump to precede scope changes — coherence-advocate's cross-review (Tensions §2) correctly notes that "each scope addition affects the Sync Impact Report" and that the version target must be declared before scope-precision changes are incorporated.

---

### Position Summary

Of the seven original recommendations: none are withdrawn, three are modified (Recs 1, 2, 6 — all for "conversus Tier 2 XII" naming and baseline-citation framing), and four survive without substantive change (Recs 3, 4, 5, 7 — with minor cross-reference notes added to 5 and 7). Two new recommendations emerged from the cross-review process.

The most significant change in my thinking concerns the analytical baseline. My original Alignment §3 cited L175–185 as settled on-disk evidence that "the constitution already carries" the VIII/XII scope boundary — a finding I used to support the scope-separation analysis in Recs 1 and 2. The coherence-advocate's cross-review correctly established that L175–185 is procedurally pending text, not ratified state, and that treating it as ground truth defeats the deliberation sequence's echo-bias function. I accepted this challenge fully and without reservation: Principle VI (State On Disk Is Truth) is a hard rule, and the substantive content of L175–185 — accurate and necessary as it is — cannot be cited as settled evidence until the third deliberation closes with a PASS verdict. This required modifying Recs 1 and 2 to route their evidentiary basis through CONFORMANCE.md directly, and prompted the new two-phase sequencing recommendation to prevent synthesis from re-introducing the baseline error.

My highest-priority remaining recommendation is the two-phase implementation sequencing rule (New Recommendation 2). It is the structural prerequisite that makes all other recommendations from both reviews coherent with each other. Without it, pairwise-advocate's scope-precision text (Recs 1, 2, 3) can be drafted against an incorrect baseline, producing ratification artifacts that are internally inconsistent from the first implementation step. The sequencing rule ensures coherence-advocate's process-validity corrections precede pairwise-advocate's substantive additions — which means the blind deliberation receives a proposal whose scope-precision text already reflects the corrected baseline rather than the pending-amendment state.
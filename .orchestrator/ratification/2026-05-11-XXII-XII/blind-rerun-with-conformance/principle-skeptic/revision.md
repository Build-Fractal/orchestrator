### Recommendation Dispositions

#### Recommendation 1: Construct structural distinctness argument for Invariant 1 vs. Principle XI

- **Original position**: Required Candidate A to resolve the XI distinctness gap through one of three structural options (definition-grounded argument / XI scope amendment / fold Invariant 1) as a pre-ratification BLOCK condition.
- **Disposition**: Modified
- **Explanation**:

The advocate's cross-review (Dangerous Contradictions §1, "Invariant 1 inclusion threshold: BLOCK vs. answerable challenge") correctly identifies a contradiction between my BLOCK verdict and the advocate's adoption stance. Crucially, the cooperative resolution proposed there — conditional ratification rather than a pre-ratification hard block — is analytically sound, and I accept it.

The original BLOCK treats the distinctness gap as a constitutional defect that prevents ratification. But the advocate is right that the gap is a documentation gap in the current candidate text, not evidence that the principle is fundamentally non-distinct from XI. A principle can be genuinely distinct from XI while having a poorly articulated distinctness argument — these are different failure modes. Post-ratification distinctness resolution via a follow-on amendment produces the same constitutional outcome (a load-bearing distinctness argument on record) without the procedural cost of blocking the entire adoption event.

Modified recommendation: **Candidate A may be ratified under conditional ratification — its CONFORMANCE.md row enters at Provisional status and cannot advance to any stronger designation until a follow-on amendment authors one of the three structural options named in the original Dispute 1 (definition-grounded argument / XI scope amendment / fold).** The three-path resolution is preserved; the change is that it becomes a post-ratification condition rather than a pre-ratification gate.

I credit the advocate's cross-review Dangerous Contradictions §1 for the cooperative resolution framing. In my own cross-review of the advocate (Dangerous Contradictions §1), I had independently proposed conditional ratification as the synthesis resolution — this revision simply applies it to my own position.

---

#### Recommendation 2: Add Principle X distinctness argument to Candidate A

- **Original position**: Required a Principle X distinctness argument as a standalone P1 pre-ratification condition.
- **Disposition**: Modified
- **Explanation**:

Recommendation 1's modification creates a sequencing consequence here: under conditional ratification, the X distinctness argument joins the XI structural argument as a post-ratification deliverable for the follow-on amendment, not a standalone pre-ratification gate.

This is a priority and sequencing change, not a withdrawal of substance. The X distinctness gap is real — Candidate A's distinctness section is entirely silent on Principle X (Templating Over Inference), and a manifest.txt enforcing force-include discipline is structurally analogous to a declarative artifact governing packaging policy, which is exactly the X pattern applied to a different domain. The argument must be made before the CONFORMANCE.md row can advance from Provisional.

Modified recommendation: **The Principle X distinctness argument is a required deliverable for the follow-on amendment that also resolves the XI structural argument (per modified Recommendation 1). The follow-on amendment must address both gaps in a single commit so the conditional ratification's scope is unambiguous and neither gap can be independently closed without the other.** The advocate's original Recommendation 4 (add one sentence addressing X) is the correct remediation shape when performed inside that commit.

---

#### Recommendation 3: Reframe Candidate A verifiers as feasibility claims, not capability claims

- **Original position**: Rename the "Mechanical verification" section to "Mechanical verification feasibility" and add explicit language distinguishing path-existence (feasibility claim) from working enforcement (capability claim).
- **Disposition**: Surviving
- **Explanation**:

This is a safe agreement per the advocate's cross-review (Safe Agreements §2, "Path-existence stubs are insufficient; working enforcement required before marking Satisfied"). Both reviews independently concluded that path-existence stubs do not discharge mechanical enforcement capability, with the skeptic providing the falsifiability argument and the advocate providing the procedural consequence.

The advocate's cross-review Tensions §1 ("Stub framing: status annotation vs. structural section redesign") describes the remaining tension: the advocate prefers a status-note annotation (appending PENDING language within the existing section); I prefer a section rename. Both are compatible when sequenced — rename the section first to make the heading honest, then add the status note within the renamed section. I maintain the section rename is the correct structural fix because a "Mechanical verification" heading with a PENDING caveat still implies verification has been partially performed, whereas "Mechanical verification feasibility" correctly signals the verification chain is designed but not running. These address different layers of the same problem and neither displaces the other.

No cross-review challenged this recommendation as wrong.

---

#### Recommendation 4: Make VIII PATCH an explicit prerequisite for Candidate B inclusion

- **Original position**: Required an explicit VIII PATCH as a P1 prerequisite for Candidate B inclusion, with proposed wording amending § VIII bullet 1 to distinguish file-system config-file reachability from variable-level knob liveness.
- **Disposition**: Surviving
- **Explanation**:

The advocate's cross-review (Tensions §1, "Candidate B's VIII scope boundary: follow-on PATCH vs. implicit establishment") resolves the tension in my favor: "The synthesis should adopt the skeptic's VIII PATCH recommendation... the advocate's own emphasis on mechanical enforceability as a value is directly served by a scope boundary that is derivable from the constitution without reading deliberation artifacts." The advocate yields here.

I maintain the P1 prerequisite classification. Principle VIII's current text says "every file, script, template, and configuration entry MUST be reachable from a live code path" — "configuration entry" is plausibly read as individual config knobs, which would make VIII already cover Candidate B's domain on plain text. The scope boundary Candidate B claims is only load-bearing if VIII is amended; CONFORMANCE.md carries the scope declaration, but CONFORMANCE.md is not the constitution. A future maintainer applying the constitution's plain text can reasonably conclude VIII already governs Candidate B's surface without ever reading CONFORMANCE.md's three-bucket table.

In my cross-review of the advocate (Dangerous Contradictions §2), I identified this as a contradiction where the advocate should yield. The advocate's cross-review concurs. This recommendation survives unchanged at P1.

---

#### Recommendation 5: Lead Candidate A with Invariant 3 as the distinctness anchor

- **Original position**: Restructure Candidate A to present Invariant 3 first as the novel governance concern, positioning Invariants 1–2 as supporting elements — and implicitly allowing that Invariants 1–2 could be relocated to XI/X if their distinctness challenges succeeded.
- **Disposition**: Modified
- **Explanation**:

The advocate's cross-review (Tensions §2, "Invariant 3 as anchor vs. enabling constraint: structural role disagreement") surfaces a productive distinction I accept. My framing allowed that a successful XI/X distinctness challenge could strip Invariants 1–2 from Candidate A entirely, reducing it to a single-invariant principle. The advocate's enabling-constraint framing keeps Invariants 1–2 within Candidate A but changes their argumentative role: they are not independent invariants of equal weight but completeness constraints on the distribution surface that Invariant 3 tests. A challenge under the enabling-constraint framing changes character — rather than "Invariant 1 is redundant with XI," the question becomes "is a version-stability constraint on the distribution surface being tested actually the same as XI's state/config/knowledge SST?" The enabling-constraint framing is more defensible.

In my cross-review of the advocate (Tensions §2), I proposed the cooperative resolution: restructure first (Invariant 3 leads), then the enabling-constraint framing makes the XI and X distinctness arguments precise — Invariant 2 is not a domain application of X's runtime-policy governance but a completeness constraint on the surface Invariant 3 tests.

Modified recommendation: **Restructure Candidate A to lead with Invariant 3; present Invariants 1–2 explicitly as enabling constraints with this framing: "Invariant 1 ensures the end-to-end test (Invariant 3) verifies a determinate version — without version SST, the test cannot confirm which artifact was installed; Invariant 2 ensures the end-to-end test covers the right files — without manifest completeness, the test verifies an incomplete surface. XI governs state/config/knowledge authoritative location at rest; Invariant 1 enables the Invariant 3 test to be version-determinate at test time. X governs template-over-inference for runtime policy; Invariant 2 governs packaging completeness for distribution-time correctness."** This keeps the three-invariant structure cohesive and changes the distinctness argument from a label-swap to a domain-of-operation argument.

---

#### Recommendation 6: Define operational terms for Invariant 3 to enable deterministic verification

- **Original position**: P2 recommendation to define "fresh project fixture" and "the project's status command works" so installer-smoke.sh can emit a deterministic PASS/FAIL.
- **Disposition**: Modified
- **Explanation**:

The advocate's cross-review (Safe Agreements §4) makes a priority argument I accept: "the advocate's P1 rating is more appropriate since undefined operational terms in a mechanical verifier specification render Invariant 3's enforcement claim unfalsifiable, which directly contradicts the falsifiable-scope inclusion criterion."

This is correct, and I had the classification wrong. Undefined operational terms do not merely create implementation ambiguity — they mean the *falsifiable-scope inclusion criterion* is not satisfied on the face of the candidate specification. A candidate claiming falsifiable scope while leaving the key terms of its primary falsifiable example undefined fails the inclusion criterion, not merely the implementation quality bar. I had treated this as an implementation-readiness issue (P2) when it is an inclusion-criterion issue (P1).

Modified recommendation: **Upgrade to P1 under the conditional ratification framework. The follow-on amendment that addresses the XI/X distinctness gaps (modified Recommendations 1 and 2) must also include minimum operational definitions for Invariant 3's verifier: "fresh project fixture" = a temporary directory containing only the files the installer places there, with no prior `.orchestrator/` state; "the project's status command works" = the command exits with code 0 and emits at least one line of output matching the structured status format.** Without these definitions, installer-smoke.sh cannot emit a deterministic PASS/FAIL — a human must judge whether the output constitutes "working," which is the exact human-judgment gate Principle II prohibits in mechanical verification contexts.

I credit the advocate's cross-review Safe Agreements §4 for the priority upgrade argument.

---

#### Recommendation 7: Exclude PENDING frontmatter-scoped clause from Candidate B's normative body

- **Original position**: P2 recommendation to remove "SKILL.md-equivalent config option declared in command frontmatter" from Candidate B's normative body and mark it as a deferred extension.
- **Disposition**: Modified
- **Explanation**:

The advocate's cross-review (Tensions §3, "Frontmatter scope exclusion: P1 pre-adoption gate vs. P2 scope-narrowing exercise") makes a priority argument I accept: "the P1 framing is more rigorous: a declared-but-unenforceable scope is an active contradiction, not an open audit... scope-narrowing before adoption is always cheaper than scope-narrowing after the principle is in the constitution with enforcement expectations attached."

My original P2 framing reflected that removing something from scope feels operationally lighter than adding missing evidence. The advocate is right that this intuition is wrong from a governance cost perspective. Once a principle is ratified with a declared scope, narrowing that scope requires re-opening the amendment — which the Governance section's amendment versioning requirements make procedurally expensive. The CONFORMANCE.md clause-mapping scaffold already labels this cell "PENDING — scope not yet drawn (frontmatter-shaped vs body-shaped)," signaling that `check-dead-infra.sh` cannot lint this surface. A principle that declares an unlintable surface in scope misrepresents its mechanical verification coverage and should not enter the constitution in that state.

Under the conditional ratification framework established for Candidate A, Candidate B's pre-ratification conditions should be equally explicit. The frontmatter scope exclusion is tighter, cheaper, and poses lower risk than the XI/X work required for Candidate A.

Modified recommendation: **Upgrade to P1 (pre-ratification condition). Before Candidate B is ratified, "SKILL.md-equivalent config option declared in command frontmatter" must be removed from the normative body. The removed clause is recorded in the principle's accompanying commentary as a deferred extension: "Frontmatter-shaped config options in command files are deferred from Candidate B's initial enforcement scope pending clause-mapping to orchestrator analogs; check-dead-infra.sh does not currently lint this surface. Inclusion as a follow-on amendment requires populating CONFORMANCE.md's clause-mapping scaffold row 3 with orchestrator analog and verification path."**

I credit the advocate's cross-review Tensions §3 for the P1 framing argument.

---

#### Recommendation 8: Add explicit Criterion 1/3 labels to stub rows in Component-tier declarations

- **Original position**: P3 recommendation to add "Criterion 1 feasibility only (path existence); Criterion 3 sufficiency (working enforcement) deferred to [follow-on amendment slug]" notation to each stub row in CONFORMANCE.md's Component-tier declarations.
- **Disposition**: Surviving
- **Explanation**:

The advocate's cross-review (Tensions §4, "Evidence vocabulary for stub status: Provisional vs. PENDING") describes this as a vocabulary tension: the advocate uses "PENDING" while I use "Provisional" as the bucket label, and both cannot simultaneously appear in the same row without ambiguity. The advocate's cross-review resolves this in my favor on the notation language: "the synthesis should adopt the skeptic's explicit 'Criterion 1 feasibility only; Criterion 3 enforcement deferred' notation... as it is compatible with both 'Provisional' (the row exists and has partial evidence) and 'PENDING' (the active enforcement work is not yet begun)."

The vocabulary question resolves by choosing the label CONFORMANCE.md already uses for the nearest analogous case — "Provisional" — for the Tier 2 XXII Component-tier declarations row (already on disk). The Criterion 1/3 notation is additive within a Provisional row: it makes the gap auditable by future readers who would otherwise need to traverse the deliberation tree to understand whether "Provisional" means "partially satisfied" or "satisfaction not yet begun."

This recommendation survives with one clarification: "Provisional" is the correct bucket label; the "Criterion 1 feasibility only; Criterion 3 enforcement deferred" notation is added within the evidence cell of the Provisional row, not as a label replacement.

---

#### Recommendation 9: Add deliberation path evidence anchor to Criterion (i) PASS finding in CONFORMANCE.md

- **Original position**: P3 recommendation to add a one-line evidence anchor in CONFORMANCE.md's Tier 2 Inheritance Basis section pointing to the blind-deliberation gate result and arbiter resolution files, making the criterion (i) PASS externally verifiable from CONFORMANCE.md in one hop.
- **Disposition**: Surviving
- **Explanation**:

The advocate's cross-review (Tensions §5, "SOURCE B prerequisite typing: operational discoverability vs. semantic disambiguation") describes this as addressing a different failure mode than the advocate's own Recommendation 8 (semantic typing of SOURCE B prerequisites as purpose-clause rather than membership-eligibility). The advocate's cross-review concludes both updates are needed and should land in the same commit: "CONFORMANCE.md should receive both updates in the same commit: the typing declaration the advocate requests AND an inline summary of the 'next MAJOR' trigger condition from SOURCE B L1181."

My recommendation addresses operational discoverability: a re-audit two years from now cannot distinguish self-asserted PASS from externally deliberated PASS without institutional memory of the deliberation tree structure. The advocate's Recommendation 8 addresses semantic re-litigation: a future reader could apply the three prerequisites as membership-eligibility gates rather than purpose-clause descriptors, reopening the independence argument. These are orthogonal failure modes, and both warrant a one-paragraph or one-line fix in CONFORMANCE.md's Tier 2 Inheritance Basis section.

This recommendation survives. The new recommendation below adds the advocate's semantic typing companion, confirming both are needed.

---

### New Recommendations

- **Add purpose-clause typing clarification to the Independence Argument** (Priority: P3)
  - **Triggered by**: The advocate's cross-review (Tensions §5, "SOURCE B prerequisite typing: operational discoverability vs. semantic disambiguation") and the advocate's original Recommendation 8 (P2), which was absent from my original review.
  - **Proposed change**: Add a one-paragraph clarification to CONFORMANCE.md's Tier 2 Inheritance Basis section stating explicitly that SOURCE B's three Purpose-clause prerequisites — multi-agent deliberation substrate, plugin entry-point boundary shape, free/paid partition — are typed here as *purpose-clause prerequisites* describing the architectural context in which SOURCE B's Tier 2 suite constitution was authored, not as *membership-eligibility gates* that any project inheriting Tier 2 principles must satisfy. Include the textual evidence from XXII's and XII's normative bodies demonstrating the three prerequisites are not load-bearing for these specific principles — XXII's invariants govern the installer-distribution domain regardless of deliberation substrate; XII's config-knob detection governs the template-coverage domain regardless of plugin entry-point structure or revenue model.
  - **Rationale**: Without this typing declaration, a future reader can re-litigate the independence argument by treating the three prerequisites as universal membership gates rather than purpose-clause contextual descriptors. The advocate's cross-review Tensions §5 argues both the operational discoverability update (Recommendation 9) and the semantic typing update (this recommendation) address different failure modes and should land together. I adopt the advocate's recommendation as new because it was absent from my original review and the cross-review process correctly surfaced it.

---

### Position Summary

I withdrew zero recommendations, modified five (Recommendations 1, 2, 5, 6, 7), and maintained four (Recommendations 3, 4, 8, 9). The five modifications are: Recommendation 1 from pre-ratification BLOCK to conditional ratification; Recommendation 2 from standalone P1 pre-ratification gate to part of the follow-on amendment package; Recommendation 5 from "Invariant 3 leads with Invariants 1–2 potentially relocated" to "Invariant 3 leads with Invariants 1–2 as enabling constraints within Candidate A"; Recommendation 6 from P2 (implementation quality) to P1 (inclusion criterion); and Recommendation 7 from P2 to P1 (pre-ratification scope-narrowing condition).

The most significant change is Recommendation 1's shift from BLOCK to conditional ratification. The advocate's cross-review correctly exposed that my BLOCK framing conflated two distinct failure modes: a principle that is genuinely non-distinct (which should be blocked) and a principle that is sound but has a poorly-articulated distinctness argument (which can be conditionally ratified with the argument required as a follow-on deliverable). I had treated both identically. Once I accepted conditional ratification — Provisional status locked until the distinctness argument is authored — the downstream modifications to Recommendations 2 and 6 followed naturally: both become part of the same follow-on amendment package with defined scope, and the priority upgrade for Recommendation 6 reflects that undefined operational terms are an inclusion-criterion failure, not merely an implementation gap.

My highest-priority surviving recommendation remains Recommendation 4: the VIII PATCH is an explicit prerequisite for Candidate B inclusion. No cross-review challenged its necessity — the advocate's original review was silent on it until the advocate's cross-review explicitly yielded. This recommendation has the clearest path from principle to action (proposed PATCH wording is in the original review), addresses a genuine constitutional gap (the scope boundary cannot be derived from constitution plain text without the amendment), and forecloses the lowest-cost avenue for future interpretive dispute. Under the modified conditional ratification framework, Candidate B's pre-ratification conditions are fewer and more tractable than Candidate A's — the VIII PATCH is the cleanest of them, and it should be on disk before Candidate B's ratification event closes.
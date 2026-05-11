I have all the files I need. Let me now compose the arbitration resolution.

---

### Process Note

This arbitration was triggered by the `disputes_remain` condition: Phase 5 synthesis identified 2 unresolved disputes after Phase 4 position consolidation. The deliberation participants were **principle-advocate** and **principle-skeptic**, operating in **cooperative** mode with subject arbitration. This is a cooperative deliberation in which the arbiter (the system under review) holds binding authority over unresolved disputes, constrained by the requirement that every ruling cite the grounding document.

The two remaining disputes are:
1. **Invariant 1 Disposition** — Unconditional reassignment vs. PATCH-then-decide
2. **Candidate A Structural Fate** — Aggregate outcome naming and Invariant 2 Principle X evaluation

No echo-bias procedural flag is warranted: neither agent's Phase 4 dispute document references the candidates' provenance (conversus, Tier 2, build-fractal, or any parent-project lineage). The deliberation remained blind throughout.

---

### Decision Framework

The following principles from `.orchestrator/memory/constitution.md` are directly load-bearing for the two remaining disputes. All rulings below trace to at least one of these.

- **Principle XI — Single Source of Truth**: "Every piece of orchestrator state, configuration, and knowledge MUST have exactly one authoritative location. Duplication across files is a consistency bug waiting to happen." (constitution.md §XI) This principle's plain text and normative examples govern whether Invariant 1 is constitutionally distinct or duplicative.

- **Principle X — Templating Over Inference**: "Configuration and policy MUST be declared in templates (YAML recipes, routing config, hooks config), not inferred by scripts at runtime. Scripts implement mechanics; templates declare policy." (constitution.md §X) This principle's normative body is the gating criterion for the Invariant 2 distinctness evaluation.

- **Principle II — Evidence Before Claims**: "No task is marked complete without fresh verification evidence… Verification is a mechanical gate, not an LLM compliance exercise." (constitution.md §II) This principle requires that constitutional independence of Invariant 2 be evaluated against X's actual normative body before ratification issues — not deferred as a post-ratification conditional.

- **Principle XIV — No Speculative Complexity**: "Every implementation MUST deliver exactly what was requested — nothing more… No abstractions for single-use code." (constitution.md §XIV) Applied constitutionally: a PATCH amendment to Principle XI whose sole motivation is creating room for Candidate A's admission is speculative governance complexity — it adds a scope restriction to XI that has no purpose except to solve the Invariant 1 distinctness problem. The Litmus test: would a senior maintainer say this PATCH is overcomplicated? If the PATCH cannot be justified without referencing Candidate A, yes.

- **Governance — Amendment Requirements**: "Amendments require: (1) Explicit version bump following semantic versioning… (2) Documented rationale for the change. (3) Consistency propagation across all dependent templates." (constitution.md §Governance) A PATCH amendment to XI requires documented rationale that stands independently of the amendment's effect on candidate admission. Rationale that cannot be stated without referencing the candidate fails this requirement.

- **Governance — Constitution Supersedes All Other Guidance**: "This constitution supersedes all other project guidance. In case of conflict between the constitution and any other document, the constitution wins." (constitution.md §Governance) The arbiter's grounding is the constitution text as-written. Disputes about XI's scope resolve against XI's text and examples, not against a characterization of what XI "should" have said.

- **Inclusion Criteria — Distinctness**: Both disputes turn on whether Invariant 1 and Invariant 2 are constitutionally distinct from existing principles (XI and X respectively). The Inclusion Criteria require distinctness from existing principles as a ratification gate; an invariant that duplicates an existing principle's scope is not a constitutional candidate regardless of whether its mechanical verification is feasible.

---

### Binding Decisions

#### Dispute: Invariant 1 Disposition — Unconditional Reassignment vs. PATCH-Then-Decide

**Positions:**
- **Principle-advocate**: Maintain a two-branch conditional: issue a PATCH amendment to XI; if the PATCH establishes that XI's scope does not extend to installer distribution surfaces (branch a), Invariant 1 may survive as a constitutional invariant; if the PATCH confirms XI already covers installer version strings (branch b), reassign as a named XI-enforcement script. The independence test (the PATCH rationale must be writable without referencing Candidate A) is the branch selector. The deliberation should not foreclose branch (a) before the PATCH is authored. (advocate disputes.md §"Dispute: Invariant 1 — Conditional survival via PATCH vs. unconditional reassignment")
- **Principle-skeptic**: Invariant 1 must be unconditionally reassigned as a named XI-enforcement script. No PATCH amendment to XI is permissible. XI's text covers installer version strings by plain reading; a PATCH whose sole motivation is enabling Candidate A's admission narrows XI's protection without independent justification and sets a precedent that any new candidate can shrink an existing principle. (skeptic disputes.md §"Dispute: Invariant 1 Disposition")

**Synthesizer's assessment:** The skeptic's position is stronger. XI's plain text admits no explicit exclusion for distribution surfaces; neither review cites evidence of original authorial intent to restrict XI's scope to runtime data. The advocate's independence test is the correct gating criterion but is a high bar; the synthesizer finds no evidence in the deliberation record of a pre-existing, independently-motivated rationale. (synthesis final.md §"Remaining Disputes — Invariant 1 Disposition")

**Ruling:** Adopt the skeptic's position. Invariant 1 is unconditionally reassigned as a named Principle XI enforcement script (`scripts/verify/version-source-of-truth.sh`), with a compliance note added to XI's normative section. No PATCH amendment to Principle XI issues from this deliberation.

**Grounding citation:** Principle XI — "Every piece of orchestrator state, configuration, and knowledge MUST have exactly one authoritative location. Duplication across files is a consistency bug waiting to happen." The normative examples in XI (derive-phase.sh for state, orchestrator-config.yml for configuration, three-temperature storage for knowledge, roadmap file for phase status) are all runtime-operational. Installer version strings — a version field duplicated across three installer scripts — are textually identical to the pattern XI prohibits: multiple files expressing the same version value from no single authoritative source. XI's text draws no boundary at the runtime/distribution surface. Applying Principle XIV: a PATCH amendment to XI whose sole documented purpose is creating room for Invariant 1's admission is speculative governance complexity — it delivers more than what is warranted (a scope-narrowed XI) to achieve what is achievable more simply (reassigning Invariant 1 to XI enforcement). And applying the Governance rationale requirement: a PATCH whose rationale cannot be written without referencing Candidate A fails the documented-rationale gate, because the rationale would be "XI should not cover installer version strings because Candidate A needs to" — a circular admission argument, not a justification.

**Rationale:** The advocate's PATCH-then-decide path is a legitimate governance pathway in principle; the Governance section permits PATCH amendments with documented rationale. The advocate is correct that the PATCH's outcome, not the deliberation, should determine branch selection. But the advocate's own independence test is self-defeating in the current record: the advocate has not produced a PATCH rationale draft that is independently motivated, nor cited any evidence of authorial intent at XI's ratification time that "state, configuration, and knowledge" was bounded to runtime-operational data. The burden of proof for demonstrating independent motivation lies with the party seeking to narrow an existing principle's scope. That burden has not been met. The skeptic's concern — that a PATCH motivated solely by Candidate A's admission sets a precedent that any future candidate can shrink a parent principle — is constitutionally sound: it describes exactly the circular-admission mechanism the Governance amendment requirements are designed to prevent.

**Rejected position:** The advocate's two-branch conditional is rejected for this deliberation. Its strongest argument is that the architectural distinction between runtime-inconsistency (config duplication) and release-time-integrity failure (installer version duplication) could motivate a genuinely independent XI scope restriction. This is plausible as a future argument. But "plausible as a future argument" is not the same as "demonstrated in this record." The deliberation record contains no independently-motivated rationale for restricting XI to runtime data; accordingly, the independence test's failure condition applies and the default — unconditional reassignment — governs.

**Required changes:**
1. Remove Invariant 1 from Candidate A's normative body in `/private/tmp/inheritance-claims-blind.md` (the candidate text under evaluation).
2. In the ratification record, add Invariant 1's verifier (`scripts/verify/version-source-of-truth.sh`) as a named Principle XI enforcement script with scope note: "covers the installer-script surface — verifies that no installer script in `packaging/install/` contains a hardcoded version string; all must derive version from the canonical source (CHANGELOG.md top-line heading)."
3. In the ratification record, document the advocate's independence test as the available exception criterion for future deliberations: "Invariant 1 may be reconsidered as a constitutional invariant only if a PATCH amendment to XI can be authored with a rationale that is demonstrably writable without referencing the new candidate. The current record does not satisfy this criterion."
4. No PATCH amendment to Principle XI issues.

---

#### Dispute: Candidate A Structural Fate — Aggregate Outcome Naming and Invariant 2 Principle X Evaluation

**Positions:**
- **Principle-advocate**: The deliberation must explicitly name all three possible aggregate outcomes for Candidate A before issuing any verdict: (a) ratifies with Invariant 2 as sole surviving invariant; (b) ratifies with Invariants 1 and 2 surviving (if PATCH path applies); (c) fails ratification entirely, with sub-claims distributed to existing principles' enforcement notes. The Principle X evaluation of Invariant 2 must complete before any verdict. Option (c) is a legitimate outcome that must be held open. (advocate disputes.md §"Dispute: Candidate A's structural fate")
- **Principle-skeptic**: The Invariant 2 Principle X evaluation is a ratification prerequisite that must complete before the verdict. If Invariant 2 fails, Candidate A has no constitutional content and cannot be ratified. The evaluation determines structure, not necessarily existence — the skeptic's framing implicitly treats Invariant 2's survival as the probable outcome. (skeptic disputes.md §"Dispute: Whether Invariant 2's Principle X Evaluation Is a Ratification Prerequisite")

**Synthesizer's assessment:** This is not a genuine substantive dispute — both agents agree on substance. The advocate's explicit three-option framing is superior: ratification records should not carry unacknowledged structural assumptions. The advocate's presentation is more complete. The evaluation question is narrow and answerable: is a manifest.txt that must be explicitly populated for every bundle file a "declared" artifact in Principle X's sense? (synthesis final.md §"Remaining Disputes — Candidate A Structural Fate")

**Ruling:** Adopt the advocate's three-option framing as the structure for the Candidate A ratification verdict. The Principle X evaluation of Invariant 2 is completed here as a prerequisite determination (see Rationale). Finding: Invariant 2 is constitutionally distinct from Principle X. Candidate A ratifies under option (a): with Invariant 2 (force-include discipline / manifest.txt completeness) as its sole surviving constitutional invariant.

**Grounding citation:** Principle X — "Configuration and policy MUST be declared in templates (YAML recipes, routing config, hooks config), not inferred by scripts at runtime. Scripts implement mechanics; templates declare policy." The normative examples enumerate: context assembly (`context-recipe.yaml`), compression strategy (recipe `compression:` block), model selection (`routing.yaml`), hook behavior (`hooks.yaml`). These are all runtime behavioral policies — they govern HOW the orchestrator behaves during execution. A `manifest.txt` in a packaging bundle directory is a bill-of-materials: it lists which files ship in the distribution bundle. This is not a behavioral policy (it does not govern orchestrator runtime behavior); it is a packaging completeness invariant (evaluated at bundle-build time to verify that no file ships without explicit inclusion). Principle X targets runtime inference — scripts that infer behavioral choices instead of reading declared templates. Force-include discipline targets build-time completeness — manifests that omit files that will be bundled. The mechanism is different (runtime script inference vs. build-time inventory omission), the enforcement point is different (runtime operation vs. CI pipeline), and the failure mode is different (non-deterministic runtime behavior vs. un-manifested file shipping). Invariant 2 passes the Principle X distinctness evaluation. Principle II grounds the requirement that this evaluation complete before ratification: "Verification is a mechanical gate, not an LLM compliance exercise." A verdict issued before the evaluation would be ratifying on "should work," not demonstrated constitutional independence.

**Rationale:** The Principle X evaluation is straightforward against X's normative body. Principle X's concern is behavioral policy inference at runtime: scripts that guess at how to assemble context, which model to use, or which hooks to fire, rather than reading declared templates. The purpose of X is to make behavioral policy changes template-edits, not script-edits. A `manifest.txt` is not read by scripts to determine behavioral choices; it is validated by a CI check to verify packaging completeness. The architectural function (behavior declaration vs. inventory declaration) and the enforcement point (runtime vs. CI) distinguish Invariant 2 from Principle X's scope. The skeptic's implicit assumption that Invariant 2 is probably constitutional is vindicated by the evaluation. The advocate's explicit three-option framing is adopted not merely because it names option (c) but because it prevents ratification records from carrying unacknowledged structural assumptions — a documentation standard consistent with Principle VII (Knowledge Compounds: "what was built, what patterns were used, what decisions were made").

**Rejected position:** The skeptic's framing, which treats option (c) as implicitly available rather than explicitly named, is rejected on presentation grounds, not substantive grounds. The skeptic's substantive positions (Invariant 2 evaluation is a ratification prerequisite; outcome determines structure) are correct and are adopted. The framing defect — not naming option (c) explicitly — is rejected because a ratification record that acknowledges only the likely positive outcome without naming the failure outcome provides false confidence about the deliberation's completeness. The advocate's contribution here is procedural rigor, not substantive disagreement.

**Required changes:**
1. The ratification record must name all three structural outcomes explicitly and close each branch:
   - Option (b) is closed: the PATCH-then-decide path was rejected in Dispute 1; Invariants 1 and 2 cannot both survive.
   - Option (a) applies: Candidate A ratifies with Invariant 2 (force-include discipline / `manifest.txt` completeness for bundle files) as its sole surviving constitutional invariant.
   - Option (c) is documented as the outcome that would have applied if Invariant 2 had failed the Principle X evaluation; it did not apply because Invariant 2 passed.
2. The ratification record must include the Invariant 2 Principle X evaluation finding verbatim: "Invariant 2 (force-include discipline) is constitutionally distinct from Principle X. A bundle manifest.txt is a packaging completeness inventory, not a behavioral policy declaration. X governs runtime policy inference; Invariant 2 governs build-time bundle completeness. The failure modes are distinct (non-deterministic runtime behavior vs. un-manifested file shipping); the enforcement points are distinct (runtime operation vs. CI pipeline). Invariant 2 passes the Principle X distinctness evaluation."
3. Strip the hardcoded line reference `packaging/install/install-claude-code.sh:524` from Candidate A's Statement text (per A5, contingency now resolved: Invariant 1 is not retained, so the line reference is moot for Invariant 1; if the reference was in the Invariant 1 description, it moves with the reassignment note to the XI enforcement section and need not appear in the constitutional text).
4. Add fail-closed specification to `manifest-coverage.sh` per convergence point A6 (contingency resolved: Invariant 2 survives): "manifest-coverage.sh MUST fail-closed: a bundle directory present in `packaging/bundle/` but absent from the verifier's known-bundle registry MUST produce FAIL with the unknown path listed, not a silent PASS."

---

### Per-Principle Blind Verdicts

**Candidate A — Distribution Surface Integrity:**

`FLAG`

- **Criterion (i) — Mechanical verification capability**: Three named verifiers exist as path-existence stubs. Verification capability is present but not demonstrated (no committed PASS/FAIL fixtures). PENDING/ACTIVE tier required per unanimous convergence. This FLAG does not block ratification; it governs enforcement status.
- **Criterion (ii) — Falsifiable scope**: The falsifiable-scope section of the candidate text accurately describes concrete PRs that would trigger FAIL results for the surviving Invariant 2. PASS.
- **Criterion (iii) — Distinctness from existing principles**: Mixed per-invariant. Invariant 1 fails distinctness from XI — BLOCK for that invariant as constitutional content, resolved by unconditional reassignment. Invariant 2 passes distinctness from X (see Binding Decision 2). Invariant 3 fails structural classification as a constitutional invariant — resolved by unanimous convergence to relocate to Quality Gates.
- **Binding criterion (i) — Implicit relief check (CONFORMANCE.md)**: CONFORMANCE.md was not supplied as a deliberation input to the arbiter's read list. The unanimous convergence point identifies this as a BINDING PROCEDURAL BLOCK on the final ratification verdict. The arbiter notes this gap: the criterion (i) implicit-relief evaluation against CONFORMANCE.md's Three-bucket structure table and membership-basis preamble must complete before the final ratification verdict issues for Candidate A. This arbitration resolution does not constitute the final ratification verdict; it resolves the two disputes. The CONFORMANCE.md evaluation is a prerequisite for the subsequent ratification ceremony.

**Candidate B — No Dead Infrastructure (config-knob class):**

`FLAG`

- **Criterion (i) — Mechanical verification capability**: `check-dead-infra.sh` exists and has demonstrated 0 dead leaves across 41 leaves (baseline 2026-05-11). Mechanical verification is demonstrated at the current scope. PASS at current scope; PENDING for scope extensions.
- **Criterion (ii) — Falsifiable scope**: The falsifiable-scope section accurately describes a concrete PR that would produce FAIL. PASS.
- **Criterion (iii) — Distinctness from existing principles**: Passes distinctness from Principle VIII contingent on the PATCH amendment clarifying that "configuration entry" in VIII means a configuration artifact (file-system object), not a variable-level entry within a configuration artifact. This PATCH is a unanimous convergence prerequisite; until it issues, the distinctness claim rests on a contestable reading. FLAG (conditional on PATCH).
- **Binding criterion (i) — Implicit relief check (CONFORMANCE.md)**: Same gap as Candidate A. CONFORMANCE.md was not supplied as a deliberation input. The criterion (i) evaluation must complete before the final ratification verdict issues for Candidate B.

**Headline verdict: PASS**

Both per-principle blind verdicts are FLAG, not BLOCK. Headline PASS requires both verdicts to be PASS or FLAG; this condition is satisfied. The PASS is contingent on the Required Changes enumerated in this resolution and the CONFORMANCE.md criterion (i) evaluation completing before the final ratification verdict issues.

---

### Summary of Changes Required

**P1 — Required for correctness (blocking)**

1. **Reassign Invariant 1 to XI enforcement** (from Dispute: Invariant 1 Disposition): Remove Invariant 1 from Candidate A's normative constitutional text. Add `scripts/verify/version-source-of-truth.sh` as a named Principle XI enforcement script in the ratification record, with scope note covering the installer-script version-derivation requirement. Document the independence test as the exception criterion for future deliberations.

2. **Name all three structural outcomes in the ratification record** (from Dispute: Candidate A Structural Fate): The ratification record must explicitly close option (b) (rejected — PATCH path ruled out), confirm option (a) applies (Candidate A ratifies with Invariant 2 as sole surviving invariant), and document option (c) as the outcome that would have applied if Invariant 2 had failed the Principle X evaluation.

3. **Record Invariant 2 Principle X evaluation finding** (from Dispute: Candidate A Structural Fate): Insert the evaluation finding verbatim in the ratification record: Invariant 2 is constitutionally distinct from Principle X because a bundle manifest.txt is a packaging completeness inventory (build-time, CI-enforced) not a behavioral policy declaration (runtime, script-read). Outcome: option (a).

4. **Complete CONFORMANCE.md criterion (i) evaluation before final ratification verdict** (from both per-principle blind verdicts — binding criterion (i) gap): Supply CONFORMANCE.md's Three-bucket structure table and membership-basis preamble as a deliberation input. Evaluate each candidate's scope boundary entry for implicit relief from parent-constitution requirements not routed through the Governance amendment pathway. This is a BINDING PROCEDURAL BLOCK on the final ratification verdict for both candidates. This arbitration resolution does not issue the final ratification verdict; the CONFORMANCE.md evaluation must precede it.

**P2 — Required for design integrity**

5. **Add fail-closed specification to manifest-coverage.sh verifier** (from Dispute: Candidate A Structural Fate — contingency resolved): Per convergence point A6, now that Invariant 2 survives: specify that `manifest-coverage.sh` MUST fail-closed — a bundle directory present in `packaging/bundle/` but absent from the verifier's known-bundle registry produces FAIL with the unknown path listed, not silent PASS.

6. **Remove hardcoded line reference from Candidate A constitutional text** (from A5 — contingency resolved): With Invariant 1 reassigned, any reference to `packaging/install/install-claude-code.sh:524` in the Invariant 1 description moves to the XI enforcement note (not the constitutional text). The constitutional text for the surviving Invariant 2 must not embed mutable line numbers.

7. **Document the independence test exception criterion** (from Dispute: Invariant 1 Disposition): The ratification record must include: "Invariant 1 may be reconsidered as a constitutional invariant under a future deliberation only if a PATCH amendment to Principle XI is authored with a rationale that is demonstrably writable without referencing the new candidate. The current deliberation record does not satisfy this criterion; the unconditional reassignment outcome applies."

**P3 — Recommended improvement**

8. **Add PENDING/ACTIVE tier with consequence clause** (from unanimous convergence — applies to both candidates): If Candidate A ratifies with Invariant 2 in PENDING status (because `manifest-coverage.sh` remains a path-existence stub), the ratification record must include: (a) PENDING definition; (b) promotion deadline as a milestone identifier; (c) consequence clause — automatic demotion to ADVISORY on missed deadline without recorded extension; (d) promotion to ACTIVE requires committed PASS/FAIL fixtures in CONFORMANCE.md.

9. **Stub-to-live promotion fixtures for surviving Candidate A verifiers** (from A1 modified, S-N2): For `manifest-coverage.sh` and `scripts/verify/version-source-of-truth.sh` (the latter now XI enforcement): document minimum promotion requirements — at least one committed PASS fixture and one committed FAIL fixture under `tests/fixtures/` before ACTIVE status is claimed.

---

### Confidence Assessment

| Dispute | Ruling | Confidence | Basis |
|---------|--------|------------|-------|
| Invariant 1 Disposition — Unconditional Reassignment vs. PATCH-Then-Decide | Adopt skeptic's position: unconditional reassignment of Invariant 1 to XI enforcement; no PATCH amendment to XI | High | Principle XI's plain text is unambiguous; no independent motivation for XI scope restriction exists in the deliberation record; Principle XIV cautions against governance complexity without independent justification; both Phase 3 revisions conceded XI's text admits no explicit exclusion for distribution surfaces |
| Candidate A Structural Fate — Aggregate Outcome Naming and Invariant 2 Principle X Evaluation | Adopt advocate's three-option framing; Invariant 2 passes Principle X distinctness (option a applies) | High for framing; Medium-High for Invariant 2 evaluation | The framing ruling rests on unanimous agreement that explicit naming is required (no genuine dispute). The Invariant 2 evaluation rests on a first-principles textual analysis of X's normative body and examples — the architectural distinction (runtime behavioral policy vs. build-time completeness inventory) is clear, but a reasonable reader could disagree about whether X's "declared in templates" language reaches bill-of-materials declarations |

**Overall deliberation quality assessment:** This deliberation is of high quality. Both agents engaged substantively with the constitution's text, identified genuine scope ambiguities (VIII "configuration entry," XI coverage of distribution surfaces, X reach to packaging manifests), and produced useful convergence on every point except these two. The two remaining disputes are genuine and appropriately scoped: Dispute 1 is a governance philosophy question (how to treat circular admission arguments), and Dispute 2 is a textual analysis question (does Principle X reach packaging manifests). Both are answerable from the grounding document. The deliberation's systemic contradiction findings (scope boundary as implicit admission mechanism, normative scope exceeding demonstrated verifier coverage, structural classification of quality gates) are accurate diagnoses that should inform the ratification record's framing of the candidates' admission conditions.

**Systemic note:** The CONFORMANCE.md gap is the most consequential unresolved item. Both agents converged that it constitutes a BINDING PROCEDURAL BLOCK on the final ratification verdict, but CONFORMANCE.md was not included in the arbiter's read list. This arbitration resolution resolves the two disputes but does not constitute the final ratification verdict. The ratification ceremony cannot close until CONFORMANCE.md's criterion (i) evaluation completes. The project operators should treat the CONFORMANCE.md evaluation as the next required step after this resolution is recorded.
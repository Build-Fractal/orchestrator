### Executive Summary

The two candidates seek constitutional standing for infrastructure-governance concerns that are real and important in a packaging-heavy project: installer-versioning hygiene and config-knob liveness. The grounding constitution (v2.1.0) already has principle-level coverage for both concern classes — Principle XI (Single Source of Truth) governs canonical data locations, Principle VIII (No Dead Infrastructure) governs unreachable infrastructure, and Principle X (Templating Over Inference) mandates explicit policy declaration. Both candidates must demonstrate that they add governance the existing fifteen principles cannot already compel through direct enforcement. Neither candidate fully passes that test as currently written.

Candidate A partially fails and partially succeeds. Invariant 1 (single-source versioning) is a specific application of Principle XI's SSOT mandate to installer version strings — the distinctness argument does not hold because XI's normative body already covers configuration duplication, and the named mechanical verifier is simply XI enforcement specialized to a new surface. Invariants 2 and 3 address different problems, but Invariant 2 overlaps with Principle X's explicit-declaration mandate and Invariant 3 is a Quality Gate masquerading as a constitutional invariant. The candidate as written is a bundling of one XI application, one X application, and one quality gate: none of its three invariants is independently constitutional.

Candidate B's scope-boundary argument is structurally sound but its mechanical-verification claim is not. The named verifier (`check-dead-infra.sh`) demonstrably covers one of the four artifact classes the principle claims to govern. The remaining three classes are unverified and at least one ("documented consumer in reference docs") is not mechanically verifiable without a machine-readable consumer-registration format that does not exist. The criterion (i) check against the CONFORMANCE.md membership basis preamble cannot be completed: CONFORMANCE.md was not supplied as a review input, and the cross-tier checklist marks that criterion BINDING.

**Most important recommendation**: Candidate A must either reassign its surviving scope to XI/X/Quality Gates where those principles already govern, or reframe the principle to cover only what none of the fifteen existing principles compels; Candidate B must narrow its normative scope to match its demonstrated verifier coverage and supply CONFORMANCE.md before the binding criterion (i) check can be resolved.

---

### Alignment

- **Explicit stub acknowledgment** (Candidate A, "Mechanical verification" section): Candidate A declares its verifiers are "currently path-existence stubs" rather than claiming they are already operational. This is honest accounting consistent with the constitution's Principle II mandate against "should work" assertions [`constitution.md`, Principle II, ¶1]. The constitutional bar for inclusion is verification *feasibility*, not current implementation completeness — acknowledging the stub state satisfies the letter of that distinction.

- **Falsifiability via concrete hypothetical PRs** (both candidates, "Falsifiable scope" sections): Both candidates provide specific hypothetical PRs that would trigger FAIL verdicts — a new installer with a hardcoded version string; a new bundle file absent from manifest; a new knob with no reader. This matches Principle II's requirement that "the task plan MUST specify what evidence constitutes proof" and that the gate be checkable "without human judgment" [`constitution.md`, Principle II, ¶3–4]. The test cases are machine-evaluable.

- **Explicit scope-boundary declaration** (Candidate B, "Scope boundary" paragraph): Rather than silently asserting non-overlap, Candidate B names the boundary: "File-system-level infrastructure reachability... is governed by existing principle VIII... config-knob-shaped variables inside installer scripts are outside Candidate B's linter scope." This respects the governance requirement that "amendments require documented rationale" [`constitution.md`, Governance, ¶1]. The boundary paragraph is structurally correct; the disputes below challenge whether the argument is *strong enough*, not whether the attempt was made.

- **Complementary verifier surface naming** (Candidate B, "Distinctness" section): The candidate names `run-doctor.sh` as VIII's verifier and `check-dead-infra.sh` as its own, making the verification surface boundary discoverable from the principle text alone. This aligns with Principle II's observable evidence-trail requirement and Principle VII's knowledge-compounding expectation that design decisions be discoverable [`constitution.md`, Principles II, VII].

---

### Missed Opportunities

- **Invariant 1 reassignment to XI enforcement**: Candidate A presents single-source versioning as a constitutional invariant rather than recognizing it as Principle XI enforcement specialized to the installer surface. The correct move is to declare `version-source-of-truth.sh` as a named XI-enforcement script in XI's compliance documentation, not to elevate XI's application to a new principle. A principle that restates an existing principle's consequence for a specific artifact class is not a principle — it is a verifier [`constitution.md`, Principle XI, normative body]. Impact: **high** — prevents constitutional scope creep where every future SSOT application could claim independence from XI on the same grounds.

- **Invariant 3 reclassification as a Quality Gate**: The constitution has a dedicated Quality Gates section whose mandate already covers release-time evidence requirements: "No phase advances without verification evidence." End-to-end install testing at every release gate is release evidence, not an architectural mandate. The correct structural home is a named gate entry in the Quality Gates section, not an invariant in a constitutional principle [`constitution.md`, Quality Gates, ¶1]. Impact: **high** — incorrect structural category blurs the principle/gate boundary, making it unclear which section governs CI pipeline requirements.

- **Scope table for Candidate B's four artifact classes**: The principle claims governance over config knobs, schema variables, command frontmatter options, and documented reference consumers — but names one verifier covering one class. A scope table mapping each artifact class to its named verifier, or explicitly marking classes as "not yet mechanically enforced," would make the falsifiability gap legible rather than hidden. Principle II requires that verification be "a mechanical gate, not an LLM compliance exercise" [`constitution.md`, Principle II, ¶3]. Leaving three classes without named verifiers creates an LLM-judgment residue in what purports to be mechanical enforcement. Impact: **high**.

- **"Documented consumer in reference docs" needs a machine-readable format**: Candidate B's scope includes "documented consumer in reference docs" as a sub-category. What constitutes a "reader" of a reference-doc-documented consumer is not determinable without human interpretation. The principle should either exclude this sub-category or define a machine-readable consumer-registration format (e.g., a `consumers:` YAML block in reference doc frontmatter) that `check-dead-infra.sh` can parse. Without this, the sub-category is a human-judgment gate wearing mechanical clothing. Impact: **medium**.

- **Invariant 2 distinctness from Principle X not fully resolved**: Candidate A's Invariant 2 (explicit manifest.txt declarations for bundle files) is the "Templating Over Inference" discipline applied to bundle manifests. Principle X mandates: "Configuration and policy MUST be declared in templates... not inferred by scripts at runtime" [`constitution.md`, Principle X, ¶1]. The candidate's distinctness argument names X and then dismisses it in one sentence without explaining why the manifest requirement is not X's mandate applied to packaging. The dismissal is incomplete. Impact: **medium**.

- **Release gate trigger is undefined**: Candidate A's Invariant 3 requires "every release gate" to run per-runtime installers, but "release gate" is not defined in the constitution or referenced as a named CI artifact. A constitutional invariant must have a defined triggering condition; an invariant whose trigger is undefined cannot be mechanically enforced and is effectively dead text from the moment of ratification [`constitution.md`, Principle II, ¶3]. Impact: **medium**.

---

### Off-Base Assumptions

- **"Principle X (Configuration Over Code)" misidentification**: Candidate A's distinctness paragraph refers to "existing principle X (Configuration Over Code)" (Candidate A, "Distinctness" section, final sentence). The actual principle is titled **"X. Templating Over Inference"** [`constitution.md`, Principle X, heading]. This is not merely a naming error — "Templating Over Inference" is a more precise mandate than "Configuration Over Code," and the two framings have different scopes. The distinctness argument against X has not been evaluated against X's actual normative body. Invariant 2's independence from X's "declared in templates, not inferred" mandate is therefore undemonstrated.

- **Principle XI's scope excludes installer-script version strings**: Candidate A's distinctness argument asserts that XI governs "orchestrator STATE / CONFIG / KNOWLEDGE" in a way that does not reach version strings in installer scripts (Candidate A, "Distinctness" section). Principle XI's normative body does not support this restriction: "Every piece of orchestrator state, configuration, and knowledge MUST have exactly one authoritative location. Duplication across files is a consistency bug waiting to happen" [`constitution.md`, Principle XI, ¶1]. A version string hardcoded in multiple installer scripts is configuration. Its duplication across files is precisely what XI prohibits. The scope restriction is not in XI's text.

- **Principle VIII's "configuration entry" means a config file, not a config knob**: Candidate B's scope-boundary argument depends on reading Principle VIII's phrase "every file, script, template, and configuration entry" as meaning "configuration entry as a file-system object" rather than "individual entry within a config file." The enumeration in VIII lists four distinct noun categories: file, script, template, and configuration entry. If "configuration entry" meant "the config file," it would be redundant with "file." The natural reading is that "configuration entry" means an individual entry — a variable-level unit — within a config artifact. If that reading is correct, Candidate B is a scope-narrowed restatement of VIII, not a distinct principle [`constitution.md`, Principle VIII, normative body, ¶1].

---

### Disputes

The following disputes are raised against the inclusion candidates under the inclusion criteria (mechanical verification feasibility, falsifiable scope, distinctness from existing principles I–XV) and the cross-tier weakening checklist. The criterion (i) finding is named verbatim as required.

**Candidate A — Distribution Surface Integrity:**

D-A1. **Invariant 1 not distinct from Principle XI**: Principle XI's normative body prohibits configuration duplication across files. Version strings hardcoded in multiple installer scripts are configuration duplication. The distinctness argument incorrectly restricts XI's scope in a way XI's text does not support. Invariant 1 fails the distinctness criterion.

D-A2. **Invariant 3 is a Quality Gate, not a constitutional invariant**: End-to-end install testing at release gates is release evidence. The constitution's Quality Gates section already provides the governing mandate. Framing it as a constitutional invariant conflates architectural mandate with release procedure.

D-A3. **Principle X not evaluated under its correct name or normative body**: The distinctness argument misnames Principle X and does not evaluate Invariant 2 against X's actual "declared in templates, not inferred at runtime" mandate. Invariant 2's independence from X is undemonstrated.

**Candidate B — No Dead Infrastructure (config-knob class):**

D-B1. **VIII's "configuration entry" may not be file-level**: Principle VIII's text enumerates "configuration entry" as a distinct noun from "file." The scope-boundary argument implicitly narrows VIII's meaning without a formal PATCH amendment to VIII. Candidate B may be a restatement of VIII with a narrower verifier, not a distinct principle.

D-B2. **Verifier covers one of four claimed artifact classes**: `check-dead-infra.sh` covers config-knob leaves in `orchestrator-config-default.yml`. Three of the four artifact classes claimed in the principle's normative scope (schema variables, command frontmatter options, documented reference consumers) have no named mechanical verifier. The falsifiability claim fails for those classes.

D-B3. **"Documented consumer in reference docs" lacks machine-readable registration format**: This sub-category has no defined mechanism for mechanically identifying readers, making it a human-judgment gate. This contradicts Principle II's mechanical-gate requirement.

**Criterion (i) — BINDING:**

**CRITERION (i): INCONCLUSIVE — CONFORMANCE.md not provided as review input; membership basis preamble for Candidates A and B has not been evaluated; BINDING check incomplete; arbiter must supply CONFORMANCE.md text and re-run criterion (i) before ratification.**

---

### Actionable Recommendations

1. **Reassign Invariant 1 to Principle XI enforcement** (Priority: P1)
   - **Current state**: Candidate A presents single-source versioning as a distinct constitutional invariant (Candidate A, "Invariant 1" section).
   - **Proposed change**: Remove Invariant 1 from Candidate A's normative body. Declare `scripts/verify/version-source-of-truth.sh` as a Principle XI enforcement script for the installer surface in XI's compliance note. If Candidate A continues, renumber its remaining invariants to 1 (manifest discipline) and 2 (install testing — subject to recommendation 2).
   - **Rationale**: Principle XI's "duplication across files is a consistency bug" covers version strings in installer scripts directly [`constitution.md`, Principle XI, ¶1]. A principle that restates XI's application to a new surface is not a distinct principle.
   - **Risk if ignored**: Constitutional scope creep — any future application-specific SSOT enforcement could claim independence from XI on identical grounds.

2. **Reclassify Invariant 3 as a Quality Gate entry** (Priority: P1)
   - **Current state**: End-to-end install testing is framed as a constitutional invariant (Candidate A, "Invariant 3" section).
   - **Proposed change**: Move this to the constitution's Quality Gates section: "Install gates: every version-tag publication runs each per-runtime installer against a fresh project fixture and verifies the status command exits 0." Specify "version-tag publication" (a defined M035 artifact) as the triggering condition rather than "release gate."
   - **Rationale**: The Quality Gates section already governs release-time evidence requirements [`constitution.md`, Quality Gates, ¶1]. Constitutional principles govern architectural mandates; quality gates govern release evidence. The two structural homes are not interchangeable.
   - **Risk if ignored**: The principle/gate boundary blurs; CI pipeline requirements and architectural mandates share the same enforcement namespace, creating ambiguity about which section governs a conflict.

3. **Supply CONFORMANCE.md for binding criterion (i) evaluation** (Priority: P1)
   - **Current state**: CONFORMANCE.md was not provided as a review input. The cross-tier checklist marks criterion (i) BINDING and requires evaluating the membership basis preamble for both candidates.
   - **Proposed change**: Before the arbiter issues a ratification verdict, supply CONFORMANCE.md text and re-run the criterion (i) check. The current finding is INCONCLUSIVE. A BINDING INCONCLUSIVE is a procedural block, not a pass.
   - **Rationale**: The checklist states "the arbiter named criterion (i) as the load-bearing test the blind pass must run" [`inheritance-claims-blind.md`, cross-tier checklist, criterion (i)]. An incomplete load-bearing test is an incomplete blind pass.
   - **Risk if ignored**: Ratification proceeds without the implicit-relief check. If CONFORMANCE.md grants either candidate implicit relief from a parent-constitution requirement without routing through the formal Relief pathway, that relief is admitted unreviewed.

4. **Resolve VIII's "configuration entry" ambiguity before admitting Candidate B** (Priority: P1)
   - **Current state**: Principle VIII enumerates "configuration entry" as a distinct noun from "file," which may already cover variable-level config-knob liveness.
   - **Proposed change**: Issue a PATCH amendment to Principle VIII clarifying: "'configuration entry' in this principle means a configuration artifact (file) as a file-system object reachable from a live code path; the liveness of individual entries within a configuration artifact is governed by Principle [B-number]." Record the clarification in the Governance amendment history.
   - **Rationale**: Without this amendment, Candidate B may be a scope-narrowed restatement of VIII, not a distinct principle. The ambiguity is a compliance risk for future maintainers [`constitution.md`, Principle VIII, normative body].
   - **Risk if ignored**: Two principles govern overlapping scope; enforcement is unpredictable, and a future maintainer can cite VIII to require Candidate B's behavior, making B's verifier (`check-dead-infra.sh`) redundant.

5. **Narrow Candidate B's normative scope to match demonstrated verifier coverage** (Priority: P1)
   - **Current state**: Candidate B's normative statement covers four artifact classes; `check-dead-infra.sh` demonstrably covers one (config-knob leaves in `orchestrator-config-default.yml`).
   - **Proposed change**: Narrow the initial normative statement to: "every config knob declared in `templates/orchestrator-config-default.yml` MUST have at least one reader in the codebase." Add an explicit extension clause: "Additional artifact classes (schema variables, command frontmatter options, reference doc consumers) enter this principle's scope when `check-dead-infra.sh` extends its coverage to that class and the extension is ratified." Mark the other three classes as aspirational scope not yet mechanically enforced.
   - **Rationale**: Principle II requires mechanical gates [`constitution.md`, Principle II, ¶3]. A principle whose scope exceeds its verifier coverage is a partial LLM-judgment gate — exactly what Principle II prohibits.
   - **Risk if ignored**: Compliance with Candidate B cannot be verified for three of its four claimed scope buckets. The principle creates false confidence in constitutional enforcement.

6. **Evaluate Invariant 2 against Principle X's actual normative body** (Priority: P2)
   - **Current state**: Candidate A's distinctness argument dismisses X overlap in one sentence using the incorrect principle name ("Configuration Over Code") without engaging X's mandate.
   - **Proposed change**: Re-evaluate Invariant 2 (force-include discipline / explicit manifest.txt) against Principle X's actual mandate: "Configuration and policy MUST be declared in templates... not inferred by scripts at runtime." If Invariant 2 is subsumable under X, declare `manifest-coverage.sh` as a Principle X enforcement script and remove Invariant 2 from Candidate A.
   - **Rationale**: A manifest.txt that must be explicitly maintained for every bundle file is a "declared in templates" artifact — the architectural move Principle X already requires [`constitution.md`, Principle X, ¶1].
   - **Risk if ignored**: The distinctness argument for the only possibly-surviving invariant of Candidate A rests on an unexamined X overlap. A future maintainer will surface this when enforcing both principles simultaneously.

7. **Add machine-readable consumer registration to "documented consumer in reference docs" scope** (Priority: P2)
   - **Current state**: Candidate B's scope includes "documented consumer in reference docs" without defining how readers are registered or detected.
   - **Proposed change**: Either (a) exclude this sub-category from Candidate B's scope entirely and address it in a future amendment once a machine-readable format exists, or (b) define a `consumers:` YAML block in reference doc frontmatter as the canonical reader-registration format and extend `check-dead-infra.sh` to parse it before claiming this sub-category is mechanically enforced.
   - **Rationale**: Without a machine-readable registration format, determining whether a reference-doc-documented consumer has a reader requires human interpretation. This contradicts Principle II's mechanical-gate requirement and Principle XIV's prohibition on unrequested complexity [`constitution.md`, Principles II, XIV].
   - **Risk if ignored**: The principle's falsifiability claim is false for this sub-category, creating a constitutional principle that requires human judgment to enforce — exactly the failure mode Principle II was designed to prevent.

8. **Define "release gate" trigger in Invariant 3 if retained** (Priority: P2)
   - **Current state**: Candidate A's Invariant 3 says "every release gate runs each per-runtime installer" without naming a defined triggering artifact.
   - **Proposed change**: If Invariant 3 is retained (rather than reclassified per recommendation 2), replace "every release gate" with "every version tag publication triggering the GH release automation workflow introduced in M035" — a named, verifiable trigger.
   - **Rationale**: Constitutional invariants must have defined triggering conditions. An invariant whose trigger is undefined cannot be mechanically enforced and defaults to human-judgment enforcement [`constitution.md`, Principle II, ¶3].
   - **Risk if ignored**: Invariant 3 satisfies any future audit trivially ("it ran at the last release gate, whatever that was") without any actual enforcement.

---

### Referenced Documentation

- `/Users/brettkellgren/Sites/orchestrator/.orchestrator/memory/constitution.md` — Principles II (Evidence Before Claims, ¶1, ¶3–4), VII (Knowledge Compounds), VIII (No Dead Infrastructure, normative body ¶1, audit tooling paragraph), X (Templating Over Inference, ¶1), XI (Single Source of Truth, ¶1, Configuration bullet), XIV (No Speculative Complexity), Quality Gates section (¶1), Governance section (¶1)
- `/private/tmp/inheritance-claims-blind.md` — Candidate A full text (Invariants 1–3, Mechanical verification, Falsifiable scope, Distinctness sections); Candidate B full text (normative statement, Scope boundary paragraph, Mechanical verification section, Distinctness section); Evaluation directive; Cross-tier weakening checklist, criterion (i) (BINDING), criteria (ii)–(iii) (advisory)
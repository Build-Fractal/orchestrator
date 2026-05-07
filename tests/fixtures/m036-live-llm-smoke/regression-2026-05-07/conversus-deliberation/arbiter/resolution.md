I have all the information needed. Here is the arbitration resolution:

---

### Process Note

This arbitration was triggered by the `disputes_remain` condition: Phase 5 synthesis identified 2 remaining disputes that could not be resolved by synthesis alone. The deliberation involved 2 agents — extractor-advocate (structural-preservation charter) and fidelity-advocate (content-fidelity charter) — in cooperative mode with subject arbitration. Extractor-advocate declared no remaining disputes in Phase 4; both remaining disputes were raised by fidelity-advocate. The arbiter is the subject system (spec-kit-orchestrator) whose constitution governs all rulings.

---

### Decision Framework

Principles from `/Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/memory/constitution.md` that bear on the remaining disputes:

- **Principle II (Evidence Before Claims)**: "No task is marked complete without fresh verification evidence... The verification sequence is: run the command → read the output → confirm the result matches expectations → THEN claim completion." A document in which the structural form is corrected but the annotation retains a P1 semantic error cannot provide fresh verification evidence of a complete, correct §4 correction.

- **Principle III (Design Before Code)**: "Every piece of work MUST go through an explicit design step... The design step MUST surface uncertainty, not hide it. When a requirement has multiple valid interpretations, enumerate them and state which was chosen — do not silently pick one." Introducing a new annotation grammar form without first designing and authorizing that form in the schema is implementation without design.

- **Principle VI (State On Disk Is Truth)**: "If it is not on disk, it did not happen. No exceptions." The corollary applies directly: if what is on disk is incorrect, the correction is not complete. An intermediate disk state containing a P1 semantic error is not a valid correction step.

- **Principle XI (Single Source of Truth)**: "Every piece of orchestrator state, configuration, and knowledge MUST have exactly one authoritative location. Duplication across files is a consistency bug waiting to happen." The annotation grammar is schema-governed knowledge; its sole authoritative location is the extraction schema specification. Introducing a new annotation form in an individual document before the schema declares it fragments the grammar definition across locations.

- **Principle XIII (Agent Instruction Schema)**: "Dispatch instructions... MUST follow a declared, inspectable schema... New instruction formats require a recipe change — not a script change." By direct analogy: new annotation grammar forms require a schema change — not document-level improvisation. The principle's intent is to prevent undeclared format extensions from diverging silently from the canonical definition.

- **Principle XIV (No Speculative Complexity)**: "Every implementation MUST deliver exactly what was requested — nothing more... No 'flexibility' that was not requested." The provenance requirement for R-1, R-2, and R-3 is already satisfied by the `derived_from` fix (EC-RUNBOOK-IR-001 addition) and existing section-level `cites:` tags. Inline point-of-mention markers are a phrase-level provenance enhancement — a feature beyond what is required for correctness at this stage.

---

### Binding Decisions

#### Dispute: Inline `[source:*]` markers in §4 requirement prose — schema authorization prerequisite

**Positions:**
- **extractor-advocate**: Rec 6 is maintained as a surviving recommendation and elevated to a Non-Negotiable in the Phase 4 Final Position Statement (extractor-advocate/disputes.md, "Non-Negotiables" item 2). Maintains that the inline markers are grounded in knowledge-graph consumer need for phrase-level provenance edges; that delocalization of citation signals from point-of-mention to section-level trailing tags constitutes a structural change within the structural-preservation charter scope; and that no cross-review challenged Rec 6 in Phases 2–3.
- **fidelity-advocate**: Dispute 1 (fidelity-advocate/disputes.md). Contends that the inline-prose annotation pattern is a schema innovation — extending the `[source:*]` namespace from block-level annotation blocks to inline-prose usage — that requires explicit schema authorization; that the existing extraction uses annotation tags exclusively as discrete paragraph-level blocks visually separated from prose; and that inline markers embedded in prose sentences erode the structural invariant allowing parsers to distinguish annotation-layer additions from source content.

**Synthesizer's assessment:** Fidelity-advocate's position is better supported for the scope of this document's immediate correction. The inline-prose annotation pattern is materially distinct from the block-level annotation grammar used throughout the extraction; a downstream parser reading the structured document cannot reliably distinguish extractor-added inline `[source: EC-*]` markers from source content without a schema rule explicitly defining the inline annotation form. Extractor-advocate's feature-value argument is correct but orthogonal to the authorization question. The provenance intent for R-1, R-2, and R-3 is adequately served by the `derived_from` correction and existing `cites:` tags. (final.md, "Remaining Disputes," Dispute 1.)

**Ruling:** EA-6 is classified as P3 conditional and must not be applied to the current document. Inline `[source: EC-*]` markers are deferred pending explicit schema authorization of the inline-prose annotation grammar.

**Grounding citation:** Principle XI (Single Source of Truth): "Every piece of orchestrator state, configuration, and knowledge MUST have exactly one authoritative location." The annotation grammar is schema-governed knowledge; applying a new annotation form in a production extraction document before that form is declared in the schema means the schema is no longer the single authoritative definition of valid annotation patterns. Principle XIII (Agent Instruction Schema): "New instruction formats require a recipe change — not a script change." By direct analogy, new annotation grammar forms require a schema change first. Principle XIV (No Speculative Complexity): the provenance requirement for R-1, R-2, and R-3 is already satisfied by `derived_from` (once EC-RUNBOOK-IR-001 is added, convergence point 3) and section-level `cites:` tags; inline markers are an enhancement beyond what correctness currently demands.

**Rationale:** Extractor-advocate is correct that phrase-level provenance edges are more valuable than section-level edges for knowledge-graph consumers — that feature argument is not in dispute. However, the value of the feature does not confer authority to introduce it by improvisation in a production artifact. Principle XI requires that annotation grammar have exactly one authoritative location: the extraction schema specification. Applying inline `[source: EC-*]` markers before the schema defines the inline form creates a second authoritative location for the grammar — the document itself — which is precisely what Principle XI prohibits. Future parsers, validators, and extractors encountering these markers will have no schema rule telling them these are annotation-layer additions rather than source content. The ambiguity fidelity-advocate identifies is real, not theoretical.

Extractor-advocate's Non-Negotiables framing in the Phase 4 Final Position Statement does not establish binding authority over the schema authorization requirement. Non-Negotiable status within a charter scope means the finding will not be withdrawn under cross-advocacy pressure — it does not mean the charter scope itself overrides schema governance. The arbitration authority derives from the constitution; the constitution's Principles XI, XIII, and XIV collectively require schema authorization before the inline annotation form can be applied.

**Rejected position:** Extractor-advocate's position (apply immediately; delocalization of citation signals is a structural change within charter scope). Extractor-advocate's strongest argument — that the extraction charter's delocalization concern is a structural-preservation issue, not merely a feature enhancement — is substantively coherent. If inline source attribution is treated as source-structural fidelity, then relocating it to a section-level block is a structural transformation under charter jurisdiction. This framing is acknowledged. But the constitution's Principle XI governs above charter-scope claims: no agent's charter scope authorizes introducing new annotation grammar forms in production artifacts without schema-level approval. Charter scope determines *what* may be reviewed; it does not authorize schema extension by improvisation.

**Required changes:**
- File: `tmp-extracted.structured.md` — Do NOT embed inline `[source: EC-*]` markers in §4 requirement prose in the current correction pass. All provenance coverage for R-1, R-2, and R-3 is expressed through the `derived_from` frontmatter (once EC-RUNBOOK-IR-001 is added per the unanimous P2 fix) and existing section-level `[type: spec/requirement, ..., cites: EC-*]` annotation blocks. No inline annotation markup is applied to this document at this time.
- Schema specification (out-of-scope for this document, P3 follow-up): Open an independent schema action to (a) define the inline `[source:*]` annotation grammar — specifying delimiter conventions, parser disambiguation rules, and which annotation-layer additions are permitted inline vs. required as paragraph-level blocks; (b) once defined and authorized, apply point-of-mention markers to R-1, R-2, and R-3 in a follow-up extraction pass targeting this document.

---

#### Dispute: R-3 `applies_to_field` correction must be applied atomically with §4 structural revert

**Positions:**
- **fidelity-advocate**: Dispute 2 (fidelity-advocate/disputes.md). Asserts that FA-1 (expand R-3 `applies_to_field: personal_data` to `[operational_records, personal_data]`) must be co-applied atomically with EA-2 (§4 structural revert); the structural revert alone produces a correctly formatted structure with a P1 semantic error intact; an intermediate state where structure is correct and annotation is incomplete is not an acceptable synthesis output.
- **extractor-advocate**: Explicitly silent on R-3's `applies_to_field` content in Phase 3 revision and Phase 4 disputes (extractor-advocate/disputes.md: no mention of R-3 annotation). Characterized as a charter scope boundary — structural-preservation charter does not govern annotation tag accuracy for extractor-generated fields — not a contested position.

**Synthesizer's assessment:** This is not a genuine substantive dispute — no agent contests the correctness of the R-3 tag fix. The dispute is a coordination protocol question. Fidelity-advocate is correct that the synthesis should not produce an intermediate state where the structural revert is applied while the tag content remains incorrect. Extractor-advocate's silence is a charter scope boundary, not a denial. (final.md, "Remaining Disputes," Dispute 2.)

**Ruling:** FA-1 (R-3 `applies_to_field` expansion) must be applied atomically with EA-2 (§4 structural revert) as a single inseparable edit to the R-3 entry in `tmp-extracted.structured.md`.

**Grounding citation:** Principle VI (State On Disk Is Truth): "All state MUST be recoverable from files on disk... If it is not on disk, it did not happen. No exceptions." The corollary is binding: if what is on disk is incorrect, the correction is not complete. A document where the §4 structural form is corrected but R-3's annotation reads `applies_to_field: personal_data` is a state on disk containing a P1 semantic error — operators querying "what rules govern operational_records?" will silently miss R-3's 365-day ceiling, the operative upper bound for the most common retention question. An incomplete correction is not a valid intermediate state; disk state must be brought to a correct, coherent condition atomically.

Principle II (Evidence Before Claims): "Verification is a mechanical gate, not an LLM compliance exercise." An implementer who applies EA-2 without FA-1 cannot mechanically verify §4 correctness — the structural form passes but the annotation fails. Both conditions must be satisfied simultaneously for the §4 correction to constitute verifiable evidence of completion.

**Rationale:** Extractor-advocate's scope-boundary silence is not a veto and must not be treated as one. Scope-boundary silence means "my charter does not require me to address this" — it does not mean "the annotation is correct and need not change." No agent in any phase has contested the accuracy of FA-1's correction; the R-3 source text is unambiguous: "Operational Records *containing* Personal Data" binds two dimensions (record class `operational_records` + qualifying predicate `personal_data`). The current annotation captures only the predicate, silently omitting the record-class dimension. The fix is directly grounded in source text that both advocates can independently verify.

Mandating atomic co-application costs the implementer nothing — it is a trivially small additional change to the same entry being reverted. The alternative — applying EA-2 independently — creates a disk state that is simultaneously structurally correct and semantically incorrect, which Principle VI prohibits.

**Rejected position:** The implicit position that EA-2 may be applied independently of FA-1 (i.e., that extractor-advocate's scope-boundary silence constitutes tacit acceptance that no bundling is required). This position fails on two grounds. First, scope-boundary silence is not acceptance; it is non-jurisdiction. Extractor-advocate's charter does not cover annotation tag accuracy for extractor-generated fields, which means extractor-advocate has no authority to either require or waive FA-1 — the determination falls to the fidelity charter and, in the event of a dispute, to arbitration. Second, producing an intermediate incorrect disk state conflicts directly with Principle VI. Even if there were no fidelity-advocate dispute, the constitution itself requires the correction to produce a correct final state.

**Required changes:**
- File: `tmp-extracted.structured.md`, §4 Retention Requirements, R-3 entry — Apply as a single atomic edit that simultaneously (a) converts the `### R-3: 365-day Personal Data ceiling` heading block to bold-bullet-list form and (b) expands the annotation tag. The corrected R-3 entry must read:

  ```
  - **R-3**: Operational Records containing Personal Data SHALL NOT be retained beyond 365 days unless an explicit legal hold is recorded in the legal-hold register. Rationale: data-minimization requirement in EC-POL-PRIV-002 §5.

  [type: spec/requirement, applies_to_field: [operational_records, personal_data], cites: EC-POL-PRIV-002]
  ```

  No intermediate state where the structural form is corrected but `applies_to_field: personal_data` remains is permitted as a saved document state.

---

### Summary of Changes Required

**P1 — Required for correctness**

1. **Atomic §4 R-3 structural revert + tag expansion** (from Dispute: R-3 `applies_to_field` correction must be applied atomically with §4 structural revert): In `tmp-extracted.structured.md`, apply EA-2 and FA-1 as a single inseparable edit to the R-3 entry. Simultaneously convert `### R-3: 365-day Personal Data ceiling` block to `- **R-3**: [prose]` bold-bullet form AND expand the annotation from `[type: spec/requirement, applies_to_field: personal_data, cites: EC-POL-PRIV-002]` to `[type: spec/requirement, applies_to_field: [operational_records, personal_data], cites: EC-POL-PRIV-002]`. Priority: P1.

**P3 — Conditional improvement (deferred)**

2. **Inline `[source:*]` markers deferred pending schema authorization** (from Dispute: Inline `[source:*]` markers in §4 requirement prose — schema authorization prerequisite): Do not apply inline `[source: EC-*]` markers to `tmp-extracted.structured.md` in the current correction pass. Interim provenance coverage is provided by the `derived_from` fix (EC-RUNBOOK-IR-001 addition, unanimous P2 convergence) and existing section-level `cites:` tags. Open independent schema action: (a) define inline `[source:*]` annotation grammar in extraction schema specification; (b) apply point-of-mention markers to R-1, R-2, and R-3 in a follow-up extraction pass once authorized. Priority: P3 (conditional on schema authorization; no document change until then).

---

### Confidence Assessment

| Dispute | Ruling | Confidence | Basis |
|---------|--------|------------|-------|
| Inline `[source:*]` markers — schema authorization prerequisite | EA-6 classified P3 conditional; not applied to current document | High | Principles XI and XIII directly govern annotation grammar authority — both require a schema-level declaration before new forms are introduced in production artifacts. Principle XIV independently supports deferral given that `derived_from` + `cites:` tags already provide adequate provenance coverage. Both Phase 4 documents are internally consistent and fidelity-advocate's Dispute 1 is well-grounded with no extractor-advocate rebuttal to the schema-authorization argument specifically. |
| R-3 atomic co-application | FA-1 and EA-2 applied as single atomic edit | High | No agent in any phase contests R-3 tag fix accuracy. Source-text grounding is unambiguous: "Operational Records *containing* Personal Data" binds two dimensions. Principle VI directly mandates complete disk state. Extractor-advocate's scope-boundary silence is explicit and consistently framed as non-jurisdiction in Phase 3 revision and Phase 4 disputes documents — it cannot be read as a veto or a tacit correctness endorsement. |

The deliberation quality is high. Both advocates conducted disciplined charter-bounded reviews, surfaced their own Phase 1 misses proactively in Phase 3 (extractor-advocate with EA-N1; fidelity-advocate with FA-N1 and FA-N2), and produced clear concession records when Phase 2 cross-reviews established the controlling analysis. The two remaining disputes are not evidence of systemic adversarial conflict — they are edge cases at the boundary of charter jurisdiction: one concerns annotation grammar extension authority (EA-6), the other concerns edit atomicity protocol when a P1 semantic error lies outside one agent's charter scope (R-3). Both are normal and healthy signals that the two-advocate model is working as designed: scope boundaries produce coordination gaps that subject arbitration is specifically equipped to close.

One process observation for future deliberation design, recorded here as an observation rather than a ruling: extractor-advocate's Phase 4 Final Position Statement classifies Rec 6 as a Non-Negotiable despite the same document declaring "no genuine remaining disputes." This creates a tension in the deliberation record — Non-Negotiable framing signals that a position will not be withdrawn under advocacy pressure, but if no dispute is acknowledged, the Non-Negotiable label has no obvious referent. Future deliberation process specifications should clarify whether Final Position Non-Negotiables may only be applied to confirmed convergence points (where the non-negotiability is moot) or also to positions the agent believes are settled but which other agents may still contest in Phase 4.
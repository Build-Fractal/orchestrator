### Recommendation Dispositions

#### Recommendation 1: Fix R-3 `applies_to_field` to include both dimensions

- **Original position**: Expand R-3's annotation from `applies_to_field: personal_data` to `applies_to_field: [personal_data, operational_records]` to reflect the compound scope of "Operational Records *containing* Personal Data."
- **Disposition**: Surviving
- **Explanation**: No cross-review contested this finding directly. Extractor-advocate's cross-review of my work (Tensions section, "`applies_to_field` completeness: two different gaps") framed R-3 as part of a systemic pattern rather than disputing the specific fix. That framing actually strengthens the recommendation: the cross-review established that R-3, R-4, and Erasure together constitute evidence of a structural schema-validation gap. My P1 rating on R-3 stands on its own source-text ground — "Operational Records *containing* Personal Data" is a compound scope in the source (`policy-data-retention.md`, §4, R-3), and the current annotation drops one of the two bound dimensions, creating a compliance blind spot for operational-records retention queries. The systemic framing in the cross-reviews is an inference that belongs in the synthesis, not a reason to reduce confidence in this correction.

---

#### Recommendation 2: Correct `category` from `"regulatory"` to `"internal-policy"`

- **Original position**: Change frontmatter `category: "regulatory"` to `"internal-policy"` (or `"compliance-policy"`) on the grounds that the source self-describes as "Internal — Reference Material," not as a regulatory instrument.
- **Disposition**: Surviving
- **Explanation**: No cross-review contested this finding. Extractor-advocate's cross-review of my work (Dangerous Contradictions item 3, "`category: 'regulatory'` — P1 finding vs. absence from extractor-advocate's review") explicitly acknowledged that `category` classification is "squarely within fidelity-advocate's charter scope" and that "extractor-advocate's silence on `category` is not tacit endorsement." My cross-review of extractor-advocate (Dangerous Contradictions item 3) reached the same framing: "extractor-advocate yields to fidelity-advocate on `category` without qualification." The source evidence is unambiguous — the document header at `policy-data-retention.md` L4 reads "Classification: Internal — Reference Material," and no content in the source supports the `"regulatory"` label. Single-advocate P1 findings with unambiguous source grounding should carry full weight in the synthesis; the scope asymmetry explains the absence of a counterargument, not its absence of merit.

---

#### Recommendation 3: Add EC-RUNBOOK-IR-001 to `derived_from` frontmatter

- **Original position**: Add EC-RUNBOOK-IR-001 as a third entry in `derived_from: ["EC-REG-2024-07", "EC-POL-PRIV-002", "EC-RUNBOOK-IR-001"]`.
- **Disposition**: Surviving
- **Explanation**: This is a Safe Agreement across both cross-reviews. Extractor-advocate's cross-review of my work (Safe Agreements, "EC-RUNBOOK-IR-001 must be added to `derived_from`") confirmed the same fix from a structural-inventory angle: EC-RUNBOOK-IR-001 is cited as normative rationale for a SHALL requirement, making it qualify under any reasonable `derived_from` definition. My cross-review of extractor-advocate (Safe Agreements, same heading) noted that converging evidence from two independent charter perspectives — graph traversal completeness and citation-type classification — both support the same atomic correction. The source text at R-1 is unambiguous: "incident-response teams require a 90-day forensic window per EC-RUNBOOK-IR-001." No challenger arguments exist.

---

#### Recommendation 4: Establish explicit curation rule for `derived_from` selection

- **Original position**: Define and document a selection rule for `derived_from` as an independent P2 action, separate from the EC-RUNBOOK-IR-001 fix, because without a rule every extractor run applies different undeclared judgment.
- **Disposition**: Surviving
- **Explanation**: Extractor-advocate's cross-review of my work (Tensions, "`derived_from` fix vs. `derived_from` schema rule") presented the immediate fix and the schema rule as alternatives rather than sequential actions, implying the rule need not be formalized if the fix is applied. My cross-review of extractor-advocate (Tensions, "`derived_from` scope: define-first vs. fix-and-document-as-alternatives") identified this bundling as a risk — treating them as interchangeable means the schema definition never gets formalized. My original recommendation structure was correct in separating them. The further clarification the cross-review process adds: the schema curation rule should be explicitly framed as a P3 deliverable *independent of and non-blocking to* the P2 EC-RUNBOOK-IR-001 fix. The two actions should not be co-executed or co-conditioned. No cross-review challenged the substance of the schema rule itself.

---

#### Recommendation 5: Mark extractor-generated subsection titles as such

- **Original position**: Add `<!-- xtr:generated -->` annotation markers to extractor-generated `###` headings in this document to make the source/extractor distinction machine-readable.
- **Disposition**: Modified
- **Explanation**: Extractor-advocate's cross-review of my work (Dangerous Contradictions item 1, "`###` subsection headings: acceptable enrichment vs. P1 structural violation") established that form-equivalence requires a full structural revert — the `###` headings must be removed, not annotated. Applying `<!-- xtr:generated -->` markers while leaving the headings intact would perpetuate the structural substitution under an auditability veneer. More importantly, my own cross-review of extractor-advocate (Dangerous Contradictions item 1, "Suggested resolution") had already concluded: "Extractor-advocate's P1 revert is the controlling fix. Fidelity-advocate's `<!-- xtr:generated -->` convention should be adopted as a forward-looking schema rule for future extractions where generated structure is affirmatively permitted — not as a substitute for reverting a prohibited substitution in this document." I cannot maintain a recommendation that my own cross-review analysis had already superseded.

  **Modified recommendation**: The `<!-- xtr:generated -->` convention should be adopted as a schema-level rule for future extractions where generated structure is explicitly permitted — it is not applicable to the present document because extractor-advocate's structural revert eliminates the `###` headings to which markers would attach. For this document, the controlling action is the structural revert (extractor-advocate's charter). Once the revert is applied, there is nothing in §3/§4/§5 to mark; the convention becomes operative only for future extractions that affirmatively permit generated structural additions.

---

#### Recommendation 6: Verify `extracted_by` field against actual model used

- **Original position**: Confirm that `extracted_by: "claude-opus-4-7"` matches the model that actually performed the extraction, since the smoke test is the first real LLM run and model identity should be verified programmatically.
- **Disposition**: Surviving
- **Explanation**: No cross-review challenged this recommendation. It is a provenance metadata concern within fidelity-advocate's charter scope: if the field misattributes authorship, the extraction audit trail is unreliable regardless of content accuracy. The smoke-test context from CLAUDE.md makes this particularly salient — this is the first real-LLM execution, and hardcoded model identifiers in fixture-adjacent outputs are a known risk. The finding requires no cross-review corroboration because it is a procedural verification, not an interpretive claim about the source document.

---

#### Recommendation 7: Add `classification` field to frontmatter mirroring source header

- **Original position**: Add `classification: "Internal — Reference Material"` to the extraction frontmatter, mirroring the source document header field.
- **Disposition**: Surviving
- **Explanation**: No cross-review challenged this recommendation. The source document header at `policy-data-retention.md` L4 contains an explicit classification field; its absence from the extraction frontmatter means downstream systems relying on frontmatter for access decisions have no signal. This is a metadata completeness gap with access-control implications. The connection to Recommendation 2 (correcting `category`) is worth noting: both findings address the same surface (frontmatter metadata accuracy) and should be applied in a single atomic change. Recommendation 7 is not a duplicate of Recommendation 2 — `category` is a schema-defined vocabulary field, while `classification` mirrors a verbatim source header value. Both are needed.

---

### New Recommendations

- **Add `applies_to_field` to Erasure term annotation** (Priority: P2)
  - **Triggered by**: In my cross-review of extractor-advocate (Safe Agreements, "Erasure term requires `applies_to_field` annotation"), I stated that "both reviews identify that the Erasure term definition carries a `[type: spec/term]` tag with no `applies_to_field`." This was true — but my original Phase 1 review did not flag it. I claimed a shared position that my own review did not support. I must formally incorporate this finding rather than leave the cross-review claiming agreement that my original review never established.
  - **Proposed change**: Add `applies_to_field: [operational_records, audit_records, personal_data]` to the Erasure term's inline annotation: `[type: spec/term, applies_to_field: [operational_records, audit_records, personal_data]]`.
  - **Rationale**: The source defines Erasure as "the process of rendering a record permanently unrecoverable, including from backups" with no field-class scoping (`policy-data-retention.md` §3). It applies to all record types governed by this policy. The current annotation leaves a dangling Erasure node — a field-coverage query asking "what operations govern `audit_records`?" will not surface Erasure, even though Erasure is a terminal operation on audit records. Extractor-advocate independently proposed the same three-field value from a structural charter perspective; both reviews reaching identical field values without coordination is strong corroborating evidence. This was a genuine miss in my Phase 1 review.

- **Acknowledge R-4 `applies_to_field` gap as within scope** (Priority: P2)
  - **Triggered by**: Extractor-advocate's cross-review of my work (Dangerous Contradictions item 4, "R-4 `applies_to_field` gap: identified by extractor-advocate only") warned that my silence on R-4 could be read as implicit endorsement of the current annotation by fidelity-advocate. That risk materialized: I read R-4 in my Phase 1 review and did not dispute it, which could be interpreted as a fidelity-advocate sign-off on `applies_to_field: operational_records` as complete.
  - **Proposed change**: Add `audit_records` to R-4's `applies_to_field`, yielding `applies_to_field: [operational_records, audit_records]`.
  - **Rationale**: R-5 in the source explicitly states that retention metadata "is itself an Audit Record and inherits R-2." This means the backup-parity ceiling in R-4 implicitly governs audit records as well as operational records — the R-5 inheritance chain makes R-4's ceiling applicable to audit record backups. The annotation gap is grounded in source text that fidelity-advocate can read directly, not solely in extractor-advocate's structural charter. My failure to flag this in Phase 1 was a scope miss, not a deliberate exclusion. I should not leave my silence on R-4 available as false endorsement in the synthesis.

---

### Position Summary

After the cross-review process: 0 recommendations withdrawn, 1 modified (Recommendation 5), 6 surviving (Recommendations 1–4, 6–7), and 2 new recommendations (Erasure term annotation, R-4 annotation gap acknowledgment).

The most significant change in my thinking is the disposition of Recommendation 5. My original framing treated the `<!-- xtr:generated -->` marker as an adequate correction for the `###` heading problem — a patch that addressed the auditability concern without requiring structural reversion. The cross-review process established that this framing conflates two distinct questions: whether the headings are semantically accurate (they are) and whether they are permitted under the extraction charter (they are not, under form-equivalence). My own cross-review of extractor-advocate had already resolved the conflict in favor of the revert, which means my Phase 1 recommendation had been superseded by my own Phase 2 analysis. Consistency required modifying rather than defending it. The `<!-- xtr:generated -->` convention retains value as a forward-looking schema rule — it belongs in the schema documentation, not in this document.

My highest-priority surviving recommendation is Recommendation 2: correct `category` from `"regulatory"` to `"internal-policy"`. The finding has P1 severity, HIGH downstream impact (corrupts the document-type index for any query filtering by document classification), unambiguous source-text grounding (the document's own header reads "Internal — Reference Material"), and no challenger arguments from either cross-review. Extractor-advocate explicitly yields on this point by charter-scope reasoning. Single-advocate P1 findings with clean source grounding should not be discounted in the synthesis because only one charter covers them; the scope asymmetry is structural, not epistemic. This correction should enter the synthesis at full P1 weight.
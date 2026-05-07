### Remaining Disputes

After reviewing both revised positions in full, there are no genuine remaining disputes between extractor-advocate and fidelity-advocate. The revision process resolved the primary conflicts:

- **Structural revert**: Both advocates now converge on the full revert as the controlling fix; fidelity-advocate's Recommendation 5 was modified to subordinate the `<!-- xtr:generated -->` marking convention to the revert rather than treat it as an alternative.
- **`applies_to_field` completeness**: Both advocates independently arrived at identical fix values for the Erasure term and R-4 from different charter angles; no output conflict remains.
- **`derived_from` framing**: Both advocates now treat the EC-RUNBOOK-IR-001 content fix (P2) and the schema curation rule (P3) as independent deliverables rather than alternatives.
- **`category` misclassification**: Extractor-advocate explicitly yielded and surfaced it as a New Recommendation in Phase 3 to prevent synthesis from discounting fidelity-advocate's uncontested P1 finding.

**The revision process resolved the remaining conflicts.**

One residual tension exists as synthesis guidance, not a dispute requiring arbitration: extractor-advocate and fidelity-advocate both claim charter-scope authority over the `applies_to_field` completeness findings (Erasure and R-4). Since both recommend the same fix, no output difference results. However, the synthesizer should note that this charter overlap has downstream implications for extraction review pipeline design: if `applies_to_field` completeness is a structural invariant (extractor-advocate's framing), it belongs in the structural-compliance check tier; if it is a semantic accuracy question (fidelity-advocate's framing), it belongs in the meaning-preservation check tier. Both framings can be simultaneously valid, but the extraction schema documentation should explicitly assign annotation completeness validation to both tiers rather than leaving it as an implicit jurisdictional overlap.

---

### Convergence

- **Converged: Structural revert of §3, §4, §5 bold-bullet promotions**
  - **Shared position**: Remove all extractor-added `###` subheadings from §3 (Definitions), §4 (Retention Requirements), and §5 (Exceptions); restore the source's `- **Term**: ...` / `- **R-N**: ...` / `- **E-N**: ...` bold-bullet-list format; remove extractor-inserted descriptive subtitles (e.g., "90-day Operational Record floor") that have no source counterpart.
  - **Agreeing agents**: extractor-advocate (Recommendations 1, 2, 3; revision.md); fidelity-advocate (Recommendation 5 modified; revision.md).
  - **Strength**: Unanimous.
  - **Path to convergence**: Phase 1 had direct conflict — extractor-advocate called for full revert; fidelity-advocate proposed `<!-- xtr:generated -->` markers as adequate. Phase 2 cross-reviews established that form-equivalence requires revert and that the marking convention is forward-looking only. Both Phase 3 revisions closed the gap explicitly. This is the strongest and most consequential convergence in the deliberation.

- **Converged: Correct `category` from `"regulatory"` to `"internal-policy"`**
  - **Shared position**: Change `category: "regulatory"` in the YAML frontmatter to `"internal-policy"` (or `"compliance-policy"` if the schema has a distinct internal-compliance bucket). Priority: P1.
  - **Agreeing agents**: fidelity-advocate (Recommendation 2, revision.md); extractor-advocate (New Recommendation, revision.md).
  - **Strength**: Unanimous.
  - **Path to convergence**: Fidelity-advocate raised this at P1 in Phase 1. Extractor-advocate's Phase 1 review omitted it by charter-scope boundary — not disagreement, but a scope silence that Phase 2 cross-review identified as creating a synthesis risk. Extractor-advocate's Phase 3 revision surfaced the finding explicitly as a New Recommendation to ensure the synthesizer does not treat it as a lower-confidence single-source P1. Full bilateral convergence with unambiguous source grounding (`policy-data-retention.md` L4: "Classification: Internal — Reference Material").

- **Converged: Add `applies_to_field` to Erasure term annotation**
  - **Shared position**: Add `applies_to_field: [operational_records, audit_records, personal_data]` to the Erasure term's inline tag.
  - **Agreeing agents**: extractor-advocate (Recommendation 4, revision.md); fidelity-advocate (New Recommendation, revision.md).
  - **Strength**: Unanimous.
  - **Path to convergence**: Extractor-advocate raised this in Phase 1 from structural-inventory analysis (Erasure is the sole term without `applies_to_field`, creating a dangling node). Fidelity-advocate's Phase 1 review did not flag it. Phase 2 cross-review surfaced that both advocates had independently converged on the same three-field value. Fidelity-advocate's Phase 3 revision added it as a New Recommendation, explicitly acknowledging the Phase 1 miss.

- **Converged: `derived_from` EC-RUNBOOK-IR-001 addition and schema curation rule as independent deliverables**
  - **Shared position**: (a) P2 content fix: add EC-RUNBOOK-IR-001 as a third entry to `derived_from`. (b) P3 schema action, independent of and non-blocking to (a): document the selection rule for `derived_from` population before the next extraction run, using fidelity-advocate's proposed formulation as the candidate definition.
  - **Agreeing agents**: extractor-advocate (Recommendation 7 modified, revision.md); fidelity-advocate (Recommendations 3 and 4, revision.md).
  - **Strength**: Unanimous.
  - **Path to convergence**: Phase 1 had extractor-advocate framing the fix and schema rule as interchangeable alternatives; fidelity-advocate treated them as distinct deliverables. Phase 2 cross-review identified the alternatives framing as a structural flaw — it would allow the schema rule to be deferred indefinitely once the immediate fix satisfied the reviewer. Extractor-advocate's Phase 3 revision corrected the framing. Full convergence on both deliverables and their independence.

- **Converged: `<!-- xtr:generated -->` as forward-looking schema rule only, not applicable to this document**
  - **Shared position**: The convention should be adopted at the extraction schema level for future runs where generated structure is explicitly permitted. It is not applicable to the present document because the structural revert eliminates the `###` headings to which markers would attach.
  - **Agreeing agents**: extractor-advocate (Recommendation 1 explanation, revision.md); fidelity-advocate (Recommendation 5 modified, revision.md).
  - **Strength**: Unanimous.
  - **Path to convergence**: Emerged directly from Phase 2 cross-review. Extractor-advocate's cross-review of fidelity-advocate identified the marking convention as subordinate to the revert; fidelity-advocate's cross-review of extractor-advocate reached the same conclusion independently. Both Phase 3 revisions reflect this explicitly, with identical framing.

---

### Final Position Statement

**Non-Negotiables**

1. **Revert all `###` heading promotions in §3, §4, and §5 to the source's bold-bullet-list format, and remove all extractor-inserted descriptive subtitles with no source counterpart.**
   The source (`policy-data-retention.md` §3 L34–L46, §4 L49–L68, §5 L70–L78) uses a flat bold-bullet-list pattern throughout; the extraction promotes these to `###` subheadings, changing the rendered structural element type in HTML/PDF output — adding anchor links, outline entries, and TOC entries — with no source authorization. The preservation charter contains no carve-out for intent-equivalent block-level structural substitutions. This is the extraction's most pervasive structural failure and will propagate identically to every future policy document sharing this layout pattern unless it is treated as a non-negotiable invariant now.

2. **Embed inline `[source:*]` markers at the point of mention for citations explicitly named in §4 requirement body prose.**
   The source cites EC-RUNBOOK-IR-001, EC-REG-2024-07 §4, and EC-POL-PRIV-002 §5 at specific prose locations in R-1, R-2, and R-3 respectively (`policy-data-retention.md` L57, L60, L63). The extraction retains these as prose text but relocates the machine-readable annotation to trailing section-level tags only. Moving a citation signal from its point of mention in source prose to a section-level trailing position changes the knowledge-graph consumer's ability to construct phrase-level provenance edges — this delocalization is a structural change within my charter scope, not minor reflow. No cross-review challenged this recommendation or offered an alternative that preserves phrase-level provenance.

**Flexibility**

1. **The exact `applies_to_field` values and notation for the Erasure term (Recommendation 4).**
   The core fix — closing the dangling Erasure node by adding `applies_to_field` — is not flexible. I am flexible on field-set ordering and YAML notation (comma-separated vs. array notation), provided all three fields (`operational_records`, `audit_records`, `personal_data`) are included. I am also flexible on whether this finding is attributed to the structural-charter or fidelity-charter in the synthesis framing; both framings arrive at the same output-document change, and charter attribution is a downstream review-process concern.

2. **The exact wording of the `derived_from` schema curation rule (Recommendation 7, part b).**
   The structural separation of the P3 schema action from the P2 content fix is not flexible — they must be treated as independent deliverables on different timelines to prevent the schema rule from being abandoned once the immediate fix satisfies the reviewer. I am flexible on the rule's exact wording. Fidelity-advocate's proposed formulation ("include all documents cited as normative authority or rationale source for a SHALL/MUST requirement") is an appropriate candidate definition, but I do not require it verbatim — any rule that is explicit about what citation role qualifies a document for inclusion, and that would deterministically include EC-RUNBOOK-IR-001 while excluding EC-POL-HR-014 and EC-POL-FIN-009, satisfies the underlying intent.
### Executive Summary

The extraction under review converts `policy-data-retention.md` — an EXAMPLE-CORP internal reference document with six major sections — into a Tier-2 structured-Markdown artifact. The extractor's mandate is to preserve every heading hierarchy, block-level structural element, and citation marker present in the source. On the whole, the extraction faithfully preserves the document's top-level section architecture, all prose content, and every citation reference. However, three sections of the source document use a flat bold-bullet-list structural pattern for enumerating items (Definitions in §3, Retention Requirements in §4, Exceptions in §5), and in all three cases the extraction substitutes that pattern with `###` subheadings — a block-level structural substitution that the extractor-advocate charter explicitly marks as a dispute, regardless of whether the result is more navigable.

The citation-tagging additions (`[type: spec/cite, ...]`, `[type: spec/requirement, ...]`, etc.) and the YAML frontmatter block are net-new material not present in the source; these are additions, not removals, and fall outside the structural-preservation dispute scope. No table, figure, or footnote existed in the source, so there are no disputes on those axes. The document-metadata block (Document ID, Version, Classification, Owner, Status) is preserved verbatim.

**Most important recommendation**: The three bold-bullet-list structures in §3, §4, and §5 must be preserved as bullet lists — promoting them to `###` subheadings is a structural substitution that changes the rendering contract and violates the preservation charter.

---

### Alignment

- **Top-level heading hierarchy preserved** (extracted doc, §1–§6): All six `## N. Section` headings from the source (`policy-data-retention.md`, L1–end) appear verbatim and in the same order in the extraction. No heading was dropped, merged, or reordered. [`policy-data-retention.md`, L1–L10 (document header) + L12 `## 1. Purpose` through L88 `## 6. References`]

- **All prose content preserved verbatim** (extracted §1 Purpose, §2 Scope): The body paragraphs for Purpose (source L13–L18) and Scope (source L20–L31) appear word-for-word in the extraction. No sentence was dropped, summarized, or paraphrased.

- **Document metadata block preserved** (extracted doc header, L3–L8): The five metadata fields — Document ID `EC-POL-DR-001`, Version `1.2`, Classification, Owner, Status — are reproduced verbatim from source L3–L7. None was dropped or altered.

- **All in-scope citation markers preserved** (extracted §6, `[type: spec/cite, scope: in-scope]` bullets): Every `EC-*` reference ID from source §6 (L82–L89) appears in the extraction with its associated description text. The four reference items (EC-REG-2024-07, EC-POL-PRIV-002, EC-POL-HR-014, EC-POL-FIN-009, EC-RUNBOOK-IR-001) are all present and attributed correctly.

- **Out-of-scope markers correctly annotated** (extracted §6 references): The two out-of-scope references (EC-POL-HR-014 and EC-POL-FIN-009) carry `scope: out-of-scope` annotations that accurately reflect the source's "explicitly does NOT cover" language (source L28–L30). This is correct structural tagging.

---

### Missed Opportunities

- **Inline citation cross-links not populated inside §4 requirement text**: The source's R-1 body text names `EC-RUNBOOK-IR-001` (source L57), R-2 names `EC-REG-2024-07 §4` (source L60), R-3 names `EC-POL-PRIV-002 §5` (source L63). The extraction carries `[type: spec/requirement, ..., cites: ...]` tags on these items but does not embed a `[source: EC-RUNBOOK-IR-001]` inline reference at the point-of-mention in the prose body. The downstream knowledge-graph consumer would benefit from point-of-mention `[source:*]` tags to enable precise edge attribution. Impact: **medium**.

- **Erasure term missing `applies_to_field`**: Source L46 defines "Erasure" as applying to all retained records (all field classes). The extraction's `[type: spec/term]` tag on Erasure carries no `applies_to_field` value, while the four other term definitions do. This is a tagging gap that will cause the field-coverage graph to miss the Erasure → all-fields edge. [`policy-data-retention.md`, L46–L47] Impact: **medium**.

- **E-1 exception body text truncated at 18-month cap**: Source L73 specifies "not exceeding 18 months" as an explicit constraint on E-1. The extraction preserves this phrase, but the `[type: spec/constraint]` tag does not include a structured `max_duration: "18 months"` field that a downstream retention-rule parser could consume programmatically. This is a schema-enrichment gap, not a structural loss, but it limits machine-readable yield. Impact: **low**.

- **R-4 and R-5 carry `applies_to_field: operational_records` only, not `audit_records`**: R-5 explicitly states that retention metadata "is itself an Audit Record and inherits R-2" (source L67–L68). The extraction tags R-5 with `applies_to_field: audit_records`, which is correct. R-4 (backup propagation parity) applies to all records covered by Retention Ceiling, which includes audit records — but the extraction tags R-4 with `applies_to_field: operational_records` only, dropping the audit-record applicability. [`policy-data-retention.md`, L65–L66] Impact: **medium**.

---

### Off-Base Assumptions

- **Promoting bullet-list items to `###` subheadings is a structural substitution, not a reflow**: The extraction converts three flat bold-bullet-list structures (§3 Definitions: source L34–L46; §4 Requirements: source L49–L68; §5 Exceptions: source L70–L78) into `###`-headed subsections. The charter defines a structural substitution as any block-level element rendered in a different form than the source. Bold-bullet-list and `###`-heading are distinct structural elements: they render differently in HTML/PDF output (no anchor links vs. anchor links, no outline entry vs. outline entry). The extraction treats this promotion as a rendering enhancement that preserves intent — but the preservation charter does not permit intent-equivalence as a defense; it requires form-equivalence. This substitution applies uniformly across all three sections and constitutes the primary structural dispute.

- **YAML frontmatter is not present in the source and its absence from the source is not a gap**: The extraction adds a YAML frontmatter block (lines 1–15 of the extracted file) that has no counterpart in the source document. This is correct — the frontmatter is extractor-generated metadata, not source content. No dispute. However, note that the frontmatter's `derived_from` field (`["EC-REG-2024-07", "EC-POL-PRIV-002"]`) lists only two of the five referenced documents; EC-RUNBOOK-IR-001, EC-POL-HR-014, and EC-POL-FIN-009 are omitted. Whether `derived_from` is meant to capture all references or only normative authorities is a schema question, not a structural-preservation question — flagged here as a documentation gap, not a dispute.

---

### Actionable Recommendations

1. **Revert §3 Definitions to bold-bullet-list form** (Priority: P1)
   - **Current state**: Extraction renders each definition as a `### Term` subsection (e.g., `### Operational Record`, `### Audit Record`).
   - **Proposed change**: Replace each `### Term` block with the source's format: `- **Term**: [definition prose]`. The `[type: spec/term, ...]` annotation tag should follow on the next line, attached to the bullet item, not the heading.
   - **Rationale**: Source document L34–L46 uses a flat bullet-list definition pattern. Promoting to `###` changes the structural element type. [`policy-data-retention.md`, L34–L46]
   - **Risk if ignored**: Downstream consumers that diff source vs. extraction will flag structural divergence; wiki renders will show a spurious additional heading level for this section; heading-anchor IDs will be generated that have no counterpart in the source.

2. **Revert §4 Retention Requirements to bold-bullet-list form** (Priority: P1)
   - **Current state**: Extraction renders each requirement as `### R-N: [descriptive title]` subsection.
   - **Proposed change**: Replace each `### R-N:` block with `- **R-N**: [requirement prose]`. The descriptive subtitle appended by the extractor (e.g., "90-day Operational Record floor") does not appear in the source and must be dropped or demoted to parenthetical within the bullet.
   - **Rationale**: Source L49–L68 uses `- **R-N**:` format. The descriptive titles in the `###` headings are extractor-generated additions with no source counterpart. [`policy-data-retention.md`, L49–L68]
   - **Risk if ignored**: The extractor-added descriptive subtitles in `###` headings constitute inserted content, which fails the verbatim-preservation invariant for heading text.

3. **Revert §5 Exceptions to bold-bullet-list form** (Priority: P1)
   - **Current state**: Extraction renders E-1 and E-2 as `###`-headed subsections.
   - **Proposed change**: Replace with `- **E-N**: [prose]` bullet format matching source L70–L78.
   - **Rationale**: Same structural substitution pattern as §3 and §4. [`policy-data-retention.md`, L70–L78]
   - **Risk if ignored**: Consistent structural substitution across three sections signals a systematic extractor behavior that will propagate to all future policy documents with this layout pattern.

4. **Add `applies_to_field` to Erasure term tag** (Priority: P2)
   - **Current state**: Extraction's Erasure definition carries `[type: spec/term]` with no `applies_to_field`.
   - **Proposed change**: Change to `[type: spec/term, applies_to_field: operational_records, audit_records, personal_data]` to reflect that erasure applies to all record classes.
   - **Rationale**: Source L46–L47 defines Erasure as "rendering a record permanently unrecoverable" without scoping to a specific field class — it applies to all retention-governed records. [`policy-data-retention.md`, L46–L47]
   - **Risk if ignored**: Knowledge graph will have a dangling Erasure node with no field edges, causing field-coverage completeness checks to underreport.

5. **Add `applies_to_field: audit_records` to R-4 tag** (Priority: P2)
   - **Current state**: R-4 tag is `[type: spec/requirement, applies_to_field: operational_records]`.
   - **Proposed change**: Change to `[type: spec/requirement, applies_to_field: operational_records, audit_records]`.
   - **Rationale**: Source L65–L66 states backup parity applies to "the underlying records" — audit records carry a Retention Ceiling (implied by R-2's floor; R-4's ceiling parity applies to any record with a ceiling). [`policy-data-retention.md`, L65–L66]
   - **Risk if ignored**: Audit Record backup obligations will not appear in field-coverage graph queries for audit_records.

6. **Embed point-of-mention `[source:*]` tags in §4 requirement prose** (Priority: P2)
   - **Current state**: Citation references in §4 are only expressed in the trailing `[type: spec/requirement, cites: ...]` tags.
   - **Proposed change**: Within the prose of each requirement, add an inline `[source: EC-*]` marker immediately after the citation text (e.g., after "per EC-RUNBOOK-IR-001" in R-1).
   - **Rationale**: Point-of-mention tagging enables the knowledge graph to build edges at finer granularity than section-level. [`policy-data-retention.md`, L57 (R-1), L60 (R-2), L63 (R-3)]
   - **Risk if ignored**: Graph edges will attach at section level only; phrase-level provenance queries will return no results.

7. **Expand `derived_from` in frontmatter to cover all normative references** (Priority: P3)
   - **Current state**: Frontmatter `derived_from` lists only `["EC-REG-2024-07", "EC-POL-PRIV-002"]`.
   - **Proposed change**: Add `"EC-RUNBOOK-IR-001"` as a third entry; leave EC-POL-HR-014 and EC-POL-FIN-009 out (out-of-scope). Alternatively, document in extraction schema whether `derived_from` means "normative authority" vs. "any cited document."
   - **Rationale**: EC-RUNBOOK-IR-001 is cited as the rationale authority for R-1 (source L57) — it is a normative reference, not merely an informational one. [`policy-data-retention.md`, L57]
   - **Risk if ignored**: Upstream provenance graph will show a dependency gap on R-1's rationale authority; auditors tracing R-1 back to its normative source will not find the link.

---

### Referenced Documentation

- `/Users/brettkellgren/Sites/orchestrator/tests/fixtures/m036-live-llm-smoke/policy-data-retention.md` — sections/lines cited: L1–L10 (document header), L13–L18 (§1 Purpose), L20–L31 (§2 Scope), L34–L46 (§3 Definitions), L46–L47 (Erasure definition), L49–L68 (§4 Retention Requirements), L57 (R-1 EC-RUNBOOK-IR-001 citation), L60 (R-2 EC-REG-2024-07 citation), L63 (R-3 EC-POL-PRIV-002 citation), L65–L66 (R-4 backup parity), L67–L68 (R-5 retention metadata), L70–L78 (§5 Exceptions), L73 (E-1 18-month cap), L82–L89 (§6 References)
- `/private/var/folders/k4/zsz6pfl936bb8nm6_byfn2d80000gn/T/tmp.cwOiKBlTWN/tmp-extracted.structured.md` — sections/lines cited: L1–L15 (YAML frontmatter), §3 Definitions subheadings, §4 Requirements subheadings and `[type: spec/requirement, ...]` tags, §5 Exceptions subheadings, §6 References bullets with scope annotations
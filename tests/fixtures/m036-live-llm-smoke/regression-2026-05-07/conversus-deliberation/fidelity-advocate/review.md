### Executive Summary

This review assesses the Tier 2 structured extraction of EC-POL-DR-001 against the source fixture. The extractor's job was structural enrichment — adding YAML frontmatter, `[type: ...]` annotations, and heading-based subsections — without altering any content that carries policy meaning. By that standard, the extraction succeeds: all numbers, identifiers, RFC 2119 modal verbs, scope boundaries, and requirement statements are reproduced verbatim or with acceptable reflow normalization.

Two metadata-level fidelity issues exist in the YAML frontmatter. First, the `category: "regulatory"` field mischaracterizes the source document's own self-description ("Internal — Reference Material"); the document is a corporate policy that satisfies regulatory requirements, not a regulatory instrument itself. Second, the `applies_to_field` annotation on R-3 is incomplete: the source requirement scopes to "Operational Records *containing* Personal Data," but the annotation records only `personal_data`, silently dropping the `operational_records` dimension. Neither issue corrupts the body text, but both can corrupt downstream knowledge-graph edges constructed from frontmatter alone.

The extraction demonstrates strong fidelity discipline for body content; the principal recommendation is to enforce a schema rule that prohibits the extractor from assigning `category` values that contradict the source's explicit classification field.

---

### Alignment

- **Verbatim number preservation** (extraction L107-109, L116-118, L125-127, L164-170): All five numeric thresholds — 90 days, 7 years, 365 days, 18 months, 24 hours — appear in the extraction with no alteration. Source uses identical values at `policy-data-retention.md` R-1 through E-1. Zero substitutions.

- **Identifier preservation** (extraction frontmatter L8, L9, L13, body throughout): Every document identifier cited in the source — EC-REG-2024-07, EC-POL-PRIV-002, EC-POL-HR-014, EC-POL-FIN-009, EC-RUNBOOK-IR-001, EC-POL-DR-001 — is reproduced exactly, including version and section references (§3, §4, §5). Source: `policy-data-retention.md`, sections 3–6.

- **RFC 2119 keyword fidelity** (extraction L107, L116, L125, L133, L140): SHALL/SHALL NOT/MUST/MAY keywords are preserved throughout R-1 through R-5 and E-1 through E-2. The prompt's carve-out for RFC 2119 normalization is moot here — the source already uses RFC 2119 language; the extractor did not need to normalize.

- **Scope boundary annotation accuracy** (extraction L194-205): EC-POL-HR-014 and EC-POL-FIN-009 are correctly tagged `scope: out-of-scope`; EC-REG-2024-07 and EC-RUNBOOK-IR-001 are correctly tagged `scope: in-scope`. Source explicitly marks these boundaries at `policy-data-retention.md` L16-21 and L64-70.

- **Exception non-overridability preserved** (extraction L170): "This exception is non-overridable by R-3" is reproduced verbatim from source E-2. This is a load-bearing constraint; verbatim preservation is the correct choice.

- **Structural title additions are non-semantic** (extraction L105, L114, L122, L131, L138): The requirement subsection titles — "90-day Operational Record floor," "7-year Audit Record floor," etc. — are editorial additions not present in the source. They are accurate characterizations that do not misstate the requirement body below them.

---

### Missed Opportunities

- **Incomplete `applies_to_field` on R-3**: The extraction annotates R-3 with `applies_to_field: personal_data` (extraction L127), but the source requirement (`policy-data-retention.md`, R-3) scopes to "Operational Records *containing* Personal Data" — a compound scope. The annotation should read `applies_to_field: [personal_data, operational_records]`. A downstream query asking "what requirements govern operational_records?" will silently miss R-3's 365-day ceiling. Impact: **high** — missing a retention ceiling on operational records in a query result is a compliance gap.

- **EC-RUNBOOK-IR-001 absent from `derived_from`**: The frontmatter lists `derived_from: ["EC-REG-2024-07", "EC-POL-PRIV-002"]` (extraction L13), but EC-RUNBOOK-IR-001 is cited as the explicit rationale authority for R-1's 90-day floor (`policy-data-retention.md`, R-1: "per EC-RUNBOOK-IR-001"). As an informing source for a normative requirement, it belongs in `derived_from` or a dedicated `informed_by` edge type. Omitting it breaks the citation chain for R-1. Impact: **medium** — knowledge-graph traversal starting from EC-RUNBOOK-IR-001 will not surface this policy.

- **`category: "regulatory"` contradicts source self-description**: The source header at `policy-data-retention.md` L4 reads "Classification: Internal — Reference Material." The extraction front-matter (L6) assigns `category: "regulatory"`. These are not equivalent: a regulation is an external normative instrument; this document is an internal corporate policy that *implements* regulatory obligations. Conflating them means a graph query for "regulatory instruments" will surface an internal policy document. Impact: **high** — classification errors corrupt the category index.

- **No `cites` annotation on Section 1 body sentence**: The Purpose section's sentence "It exists to satisfy EC-REG-2024-07" receives a standalone `[type: spec/cite, scope: in-scope, cites: EC-REG-2024-07]` tag (extraction L33), which is correct. However, the corresponding frontmatter does not include a `cites` top-level field mirroring this. If the schema supports a top-level `cites:` in frontmatter (parallel to `derived_from:`), omitting it means the citing relationship is only recoverable from body annotation parsing, not from frontmatter-only index passes. Impact: **low** — recoverable but requires full-body parse.

- **Subsection titles are unattributed editorial additions**: The added headings (e.g., "### R-1: 90-day Operational Record floor") are not marked as extractor-generated. A reader of the structured document cannot distinguish extractor-added titles from source headings without cross-referencing the raw document. A consistent annotation convention (e.g., `<!-- extractor-generated -->`) would make this distinction machine-readable. Impact: **low** — does not affect content accuracy, but reduces auditability of the structural layer.

---

### Off-Base Assumptions

- **`category: "regulatory"` implies the extractor treats compliance-satisfying policies as equivalent to regulations**: The extraction front-matter (L6) uses `category: "regulatory"` apparently because the document satisfies regulatory requirements. This conflates the instrument type (internal policy) with the regulatory domain it addresses. The correct category for this document is something like `"internal-policy"` or `"compliance-policy"` — not `"regulatory"`, which should be reserved for the actual regulations (EC-REG-2024-07 itself). The source's own "Classification: Internal — Reference Material" is the ground truth. No documentation in the source supports the `"regulatory"` label.

- **`derived_from` is treated as a complete citation inventory**: The frontmatter (L13) records only EC-REG-2024-07 and EC-POL-PRIV-002 in `derived_from`, suggesting the extractor selected "primary" authorities. But EC-RUNBOOK-IR-001 is cited as a normative rationale source for R-1 and is not in the inventory. The extraction behaves as if `derived_from` is a curated subset of authoritative citations — but without an explicit curation rule documented anywhere in the extraction, this is an implicit, undeclared judgment. The result is a structurally incomplete citation record.

---

### Actionable Recommendations

1. **Fix R-3 `applies_to_field` to include both dimensions** (Priority: P1)
   - **Current state**: Extraction L127: `[type: spec/requirement, applies_to_field: personal_data, cites: EC-POL-PRIV-002]`
   - **Proposed change**: `[type: spec/requirement, applies_to_field: [personal_data, operational_records], cites: EC-POL-PRIV-002]`
   - **Rationale**: Source R-3 explicitly bounds "Operational Records *containing* Personal Data" — both dimensions are load-bearing. `policy-data-retention.md` R-3 text is unambiguous on this compound scope.
   - **Risk if ignored**: A knowledge-graph query on `operational_records` retention rules will miss the 365-day Personal Data ceiling, creating a compliance blind spot.

2. **Correct `category` from `"regulatory"` to `"internal-policy"`** (Priority: P1)
   - **Current state**: Extraction frontmatter L6: `category: "regulatory"`
   - **Proposed change**: `category: "internal-policy"` (or `"compliance-policy"` if the schema supports domain qualification)
   - **Rationale**: Source document self-describes as "Internal — Reference Material" (`policy-data-retention.md` L4). The document is not a regulation; it is a corporate policy implementing regulatory obligations.
   - **Risk if ignored**: The category index conflates internal policies with external regulatory instruments, polluting any query that filters by document type.

3. **Add EC-RUNBOOK-IR-001 to `derived_from` frontmatter** (Priority: P2)
   - **Current state**: Extraction frontmatter L13: `derived_from: ["EC-REG-2024-07", "EC-POL-PRIV-002"]`
   - **Proposed change**: `derived_from: ["EC-REG-2024-07", "EC-POL-PRIV-002", "EC-RUNBOOK-IR-001"]`
   - **Rationale**: EC-RUNBOOK-IR-001 is cited as the explicit authority for R-1's 90-day floor (`policy-data-retention.md` R-1). Omitting it breaks the citation graph traversal from the runbook to this policy.
   - **Risk if ignored**: Traversal from EC-RUNBOOK-IR-001 to dependent policies will miss EC-POL-DR-001, breaking impact analysis when the runbook is updated.

4. **Establish explicit curation rule for `derived_from` selection** (Priority: P2)
   - **Current state**: No documented rule for which cited documents qualify for `derived_from`; selection appears implicit (regulatory authority + definition source only).
   - **Proposed change**: Define and document a selection rule — e.g., "include all documents cited as normative authority or rationale source for a SHALL/MUST requirement; exclude informational or out-of-scope references."
   - **Rationale**: Without a rule, every extractor run applies different judgment, producing inconsistent graph edges. The omission of EC-RUNBOOK-IR-001 in this extraction is evidence of undeclared judgment.
   - **Risk if ignored**: Citation graph completeness is non-deterministic across extraction runs.

5. **Mark extractor-generated subsection titles as such** (Priority: P2)
   - **Current state**: Requirement headings (e.g., "### R-1: 90-day Operational Record floor", extraction L105) appear without attribution.
   - **Proposed change**: Append a machine-readable marker: `### R-1: 90-day Operational Record floor <!-- xtr:generated -->` or equivalent, so tooling can distinguish source structure from extractor-added structure.
   - **Rationale**: The source (`policy-data-retention.md` Section 4) uses flat bullet items with no subsection headings. All `###` headings in Section 4 are extractor-generated. Without marking, diff tooling treating the structured document as ground truth will attribute these titles to the source.
   - **Risk if ignored**: Downstream document comparison treats extractor-generated headings as source-authoritative, introducing phantom attribution.

6. **Verify `extracted_by` field against actual model used** (Priority: P3)
   - **Current state**: Extraction frontmatter L11: `extracted_by: "claude-opus-4-7"`
   - **Proposed change**: Confirm this matches the model that actually performed the extraction (the live-smoke-test is the first real LLM run per CLAUDE.md; model identity should be verified programmatically, not hardcoded).
   - **Rationale**: If the smoke test used a different model version, this field silently misattributes authorship. The fidelity audit cannot verify model identity from document content alone.
   - **Risk if ignored**: Provenance metadata is unreliable, undermining the extraction audit trail.

7. **Add `classification` field to frontmatter mirroring source header** (Priority: P3)
   - **Current state**: Source document header contains "Classification: Internal — Reference Material" (`policy-data-retention.md` L4); this field has no frontmatter equivalent in the extraction.
   - **Proposed change**: Add `classification: "Internal — Reference Material"` to the extraction frontmatter.
   - **Rationale**: Classification governs access control and distribution. Losing it from the structured form means downstream systems relying on frontmatter for access decisions have no signal.
   - **Risk if ignored**: Access control metadata is only recoverable via full-body parse; frontmatter-indexed access decisions will treat the document as unclassified.

---

### Referenced Documentation

- `/Users/brettkellgren/Sites/spec-kit-orchestrator/tests/fixtures/m036-live-llm-smoke/policy-data-retention.md` — sections cited: L1-8 (document header / classification), L9-14 (Purpose / EC-REG-2024-07 authority), L16-26 (Scope / out-of-scope boundaries), R-1 (90-day floor / EC-RUNBOOK-IR-001 rationale), R-2 (7-year floor), R-3 (365-day ceiling compound scope), R-4, R-5, E-1, E-2, L63-70 (References section)
- `/private/var/folders/k4/zsz6pfl936bb8nm6_byfn2d80000gn/T/tmp.cwOiKBlTWN/tmp-extracted.structured.md` — sections cited: L1-14 (YAML frontmatter), L26-33 (Purpose annotation), L44-46 (Scope annotation), L105-143 (R-1 through R-5 with applies_to_field annotations), L157-175 (E-1 through E-2), L177-205 (References with scope annotations)
---
schema_version: "1.0"
type: extraction-prompt
prompt_name: tier-2-structured-md
applies_to: tier-2-llm-extraction
---

# Tier 2 Structured-Markdown Extraction Prompt

Authoritative prompt contract for M036a Tier 2 LLM extraction. Used by
the orchestrating agent layer (in-session extraction) today; read by
the future shell-to-LLM bridge in `extract_tier_2_dispatch live` once
that branch is implemented.

## Input

You will be given:

1. **A source markdown document** — typically a regulatory document, a
   training/runbook document, a glossary, or a similar structured
   reference material.
2. **Manifest metadata** — `cite_id`, `category`, `source`,
   `published`, `version`, `topic_tags`, `applies_to_field`. Treat
   these as authoritative; copy them verbatim into the output
   frontmatter.

## Task

Produce a **structured Markdown** rendering of the source document
that:

1. **Preserves every block-level structural element** of the source —
   every heading, every list, every table, every figure caption,
   every footnote, every citation marker. Tier 2 is **structural
   extraction, NOT summarisation or paraphrase** (Spec NG-5-NEW).
   Where the source's prose is well-formed, copy it verbatim. Where
   reflow is necessary (e.g. to apply consistent heading levels), keep
   the same heading/structure label.
2. **Adds no content not in the source.** No paraphrased summaries.
   No invented requirements. No technical-term substitutions. No
   altered numbers, dates, or identifiers. The arbiter's
   `fidelity-advocate` will raise a dispute against any added content.
3. **Tags chunks with the orchestrator's graph schema.** After each
   definition, requirement, constraint, or citation, add a single
   inline tag line in the form:

   ```
   [type: spec/term, applies_to_field: <field-name>]
   [type: spec/requirement, applies_to_field: <field-name>, cites: <doc-id>]
   [type: spec/constraint, applies_to_field: <field-name>]
   [type: spec/cite, scope: in-scope|out-of-scope]
   ```

   Tag-line keys follow M036a's graph schema:
   - `type` — one of `spec/term`, `spec/requirement`, `spec/constraint`,
     `spec/cite`. Required.
   - `applies_to_field` — one of the manifest's `applies_to_field`
     values. Optional but include where applicable.
   - `cites` — the document ID(s) the chunk derives from or refers to.
     Optional but include where the source explicitly cites another
     document (e.g. `Rationale: X per EC-RUNBOOK-IR-001`).
   - `scope` — for `spec/cite` chunks only; `in-scope` if the source
     uses the citation as authority, `out-of-scope` if the source
     explicitly excludes it.

## Output shape

Emit the structured Markdown to stdout with **YAML frontmatter** at
the top:

```markdown
---
schema_version: "1.0"
type: tier-2-structured-extraction
cite_id: "<from manifest>"
category: "<from manifest>"
source: "<from manifest>"
published: "<from manifest>"
version: "<from manifest>"
topic_tags: [<from manifest>]
applies_to_field: [<from manifest>]
extracted_by: "<model id, e.g. claude-opus-4-7>"
extracted_at: "<ISO 8601 UTC timestamp>"
derived_from: [<list of doc IDs the source cites or derives from>]
---

# <Source title> (Structured)

## <Section heading 1, verbatim from source>

... preserved content ...

[type: spec/term, applies_to_field: <field>]

## <Section heading 2, verbatim from source>

... preserved content ...

[type: spec/requirement, applies_to_field: <field>, cites: <doc-id>]

... etc ...
```

## Hard rules (the fidelity-advocate WILL block on these)

1. **Verbatim where possible.** If the source says "SHALL be retained
   for at least 90 days," the output must say the same — not "must be
   kept for 90+ days" or "should retain ≥ 90 days."
2. **No invented requirements.** If the source has 5 numbered
   requirements, the output has 5 numbered requirements.
3. **No reordering.** Sections appear in the same order as the source.
4. **No deletion.** Every section heading present in the source must
   appear in the output. If a section is empty in the source, mirror
   that — do not drop it.
5. **Identifiers preserved exactly.** Document IDs (`EC-POL-DR-001`,
   `R-1`, `E-2`) are copied character-for-character. No
   normalization, no formatting changes.

## Soft rules (preferred but not blocking)

1. **Add structure tags after the chunks they apply to**, not before.
   This keeps the source content readable as the primary signal and
   the tags as metadata.
2. **Use `derived_from` in frontmatter** for the citing-authority
   document(s) the source explicitly derives from (e.g., the
   regulatory standard the policy implements). Cited references that
   are merely referred to (not derived from) belong in `cites:` tags
   on the relevant chunks, not in `derived_from`.
3. **One tag line per chunk.** If a chunk genuinely needs multiple
   types, prefer the most specific (e.g. `spec/requirement` over
   `spec/term` when both apply).

## Examples (input → output excerpt)

**Source excerpt:**
```
## 4. Retention Requirements

- **R-1**: Operational Records SHALL be retained for at least 90
  days from the date of generation. Rationale: incident-response
  teams require a 90-day forensic window per EC-RUNBOOK-IR-001.
```

**Structured output excerpt:**
```
## 4. Retention Requirements

### R-1: 90-day Operational Record floor

Operational Records SHALL be retained for at least 90 days from the
date of generation. Rationale: incident-response teams require a
90-day forensic window per EC-RUNBOOK-IR-001.

[type: spec/requirement, applies_to_field: operational_records, cites: EC-RUNBOOK-IR-001]
```

Notice: the requirement text is preserved verbatim. The wrapping
`### R-1:` heading is added (the source used a bold inline label,
which is not a heading) — this is a structural promotion, not a
paraphrase. The `[type: ...]` tag line follows the chunk.

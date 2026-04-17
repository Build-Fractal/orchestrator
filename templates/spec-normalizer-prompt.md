---
schema_version: "1.0"
type: normalizer-prompt
---

# Spec Normalizer Prompt

You are a spec normalizer. Your job is to read the source markdown document below and produce a normalized spec-kit-shaped markdown file that downstream ingestion (`scripts/knowledge/ingest-spec.sh`) can parse via `commands/ingest.md`.

## Inputs

- `slug`: `{{slug}}`
- `source_markdown`:

```
{{source_markdown}}
```

## Rules

1. **Preservation.** Preserve every factual claim, requirement, non-goal, constraint, and acceptance criterion from the source document verbatim where the source already states it in a well-formed way. Preserve source quotes verbatim when the source already contains a well-formed requirement sentence.
2. **No new requirements.** Do not introduce new requirements that are not derivable from the source. You must not add requirements the source does not imply. No new requirements beyond what the source text supports.
3. **Section layout.** Emit the normalized output as a complete markdown file using the section layout `commands/ingest.md` already expects, in this exact order:

   - `# Feature Specification: <title derived from source>`
   - `## Problem Statement`
   - `## User Scenarios & Testing`
   - `## Functional Requirements`
   - `## Acceptance Scenarios`
   - `## Constraints`
   - `## Non-Goals`
   - `## Success Criteria`

4. **User stories.** Under `## User Scenarios & Testing`, emit user stories in the form `As a <role>, I want <capability>, so that <outcome>.` Tag each with `US-NNN` identifiers starting at `US-001`.
5. **Functional requirements.** Under `## Functional Requirements`, emit requirements tagged `FR-NNN` starting at `FR-001`. One requirement per bullet. Prefer verbatim sentences from the source.
6. **Acceptance scenarios.** Under `## Acceptance Scenarios`, emit Given/When/Then triples. Tag each with `AC-NNN`.
7. **Constraints, Non-Goals, Success Criteria.** Populate each with bullets extracted from the source. If the source does not mention non-goals, emit the section with a single bullet: `- (none stated in source)`.
8. **Output shape.** Emit ONLY the normalized markdown body. No commentary, no explanation, no leading or trailing code fences. The first line of your output MUST be the `# Feature Specification: ...` line.

## Completion

After the normalized markdown body, stop. Do not add a closing summary or meta-commentary.

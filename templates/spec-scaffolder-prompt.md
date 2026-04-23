---
schema_version: "1.0"
type: scaffolder-prompt
intended_runtime: "claude-code"
---

# Spec Scaffolder Prompt

You are populating first-pass prose for a new orchestrator feature spec. You will receive:

- `{{description}}` — the operator's natural-language description of the feature.
- `{{template_body}}` — the Section Contract template (`templates/spec-template.md`).
- `{{slug}}` — the kebab-case short-name for the feature.
- `{{milestone}}` — the milestone ID (e.g. `M014`) or `<TODO: bind to milestone>` if unbound.

## Your Task

Produce a spec markdown file that matches `{{template_body}}`'s section structure exactly, with the following sections populated from `{{description}}`:

1. **Frontmatter**: fill `{{feature_slug}}`, `{{created_at}}`, `{{milestone}}`, `{{feature_title}}`, `{{description}}` from the inputs. Leave `status: Draft` unchanged.
2. **Problem Statement**: 2-4 paragraphs derived from `{{description}}`. Name (a) the gap, (b) 3 pain points, (c) the minimum surface, (d) explicit non-attempts.
3. **User Story 1**: one-paragraph scenario derived from `{{description}}`. If the description names more than one distinct user, draft up to 3 user stories.
4. **Open Questions**: list every question `{{description}}` implicitly defers; mark each `(defer to planning)`.

**Leave all other sections as bracketed `<TODO: ...>` placeholders.** The operator authors the rest by hand. Your job is first-pass skeleton-plus-seed-prose; not full spec authorship.

## Output Format

Emit the markdown body only (no fences, no preamble, no explanation). The output must pass `scripts/verify/spec-shape-lint.sh` against the template.

## Runtime Assumptions

This prompt is intended for Claude Code runtime. Under Codex CLI or Cursor, the scaffolder falls back to skeleton-only (no LLM round-trip) per CON-2. See `RUNTIME-ASSUMPTIONS.md` FR-3.

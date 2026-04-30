---
description: "Use when the user is unfamiliar with a section of code or wants a higher-level perspective. Renders a one-layer-up map of the relevant modules, callers, and seams using the project's domain vocabulary. Read-only."
---

# orchestrator:zoom-out

Produce a higher-layer-of-abstraction map of the area the user is currently looking at. Borrowed from `mattpocock/skills::zoom-out` (MIT) and reshaped to consume the orchestrator's knowledge graph rather than start from a blank page.

This is a utility command — it never writes state, never dispatches, never modifies files. It only reads and renders.

## When to invoke

- The user says "zoom out", "give me a map", "I don't know this area", "what calls this".
- A dispatched task surfaced an unexpected dependency and the user wants a one-layer-up view before deciding how to proceed.
- Before invoking `orchestrator:plan-phase` on a phase that touches an unfamiliar module — produces grounding that planning consumes.

## Workflow

### 1. Resolve the focus

Identify the focus from the user's message. One of:

- A file path or directory (`scripts/dispatch/dispatch-interface.sh`, `commands/`)
- A symbol or function name (`build-context.sh::_bc_apply_tier1`)
- A domain concept named in the project's glossary (see Step 2)
- A milestone or phase identifier (`M030`, `M030/P04`)

If the focus is ambiguous, ask one targeted clarifying question. Do not guess.

### 2. Load the project's domain vocabulary

Read the project's domain-language source if it exists:

```bash
bash scripts/knowledge/lookup-mems.sh --kind=glossary --limit=20 2>/dev/null || true
```

Also read the wiki glossary section if present (`docs/wiki/glossary.md` or equivalent — the path comes from `templates/orchestrator-config-default.yml::wiki.glossary_path`). Use the project's terms in the rendered map; do not invent synonyms.

### 3. Walk one layer up

Produce four short sections, each ≤ 8 lines:

1. **What this is** — one sentence in domain vocabulary describing the module's job.
2. **Callers** — what depends on this. Run `bash scripts/diagnostics/grep-references.sh <focus>` if available; otherwise `grep -rn <symbol> commands/ scripts/ tests/`. List the top 3–7 callers with a one-line role each.
3. **Seams** — interfaces this module crosses. For bash modules: which env vars / flags / file conventions. For markdown commands: which scripts/templates are referenced.
4. **Adjacent concepts in the graph** — `bash scripts/knowledge/lookup-mems.sh --related-to <focus> --limit=5` if knowledge graph entries reference the focus. Skip the section if zero hits.

### 4. End with a "next zoom" offer

One line: "Want a deeper look at any of {top 2 callers}? Or zoom out further to the milestone level?"

## Output

Single markdown block to stdout. No file writes. ~30–60 lines total.

## Idempotency

Inherently idempotent — purely derived from disk + grep. No state changes.

## Composition

- Pairs with `orchestrator:where` (M029, when shipped) — `where` shows hierarchy; `zoom-out` shows neighborhood.
- Pairs with `orchestrator:plan-phase` — invoke before planning when the phase touches unfamiliar code; the rendered map becomes a verbal anchor in the plan's "Key links" section.

## Reference Files

- `scripts/knowledge/lookup-mems.sh` — knowledge graph reader (M020). Best-effort; if absent, fall back to grep.
- `scripts/diagnostics/grep-references.sh` — caller resolution helper (best-effort; falls back to plain grep).

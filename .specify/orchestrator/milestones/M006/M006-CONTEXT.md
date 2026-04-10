---
schema_version: "1.0"
type: context-draft
milestone: "M006"
status: draft
created_at: "2026-04-10T23:30:00Z"
finalized_at: null
---

## Architectural Decisions

### AD-1: Documentation is verification, not afterthought

Every documentation phase requires the author to execute the documented workflow against the actual codebase. If the docs say "run X and expect Y", the author runs X and confirms Y. Discrepancies are bugs — either in the docs or the code. Documentation phases produce both docs AND bug fix commits.

### AD-2: Progressive disclosure mirrors Conversus references/ pattern

Reference docs are organized for conditional loading — not a monolithic manual. Each doc is self-contained, focused on one concern, and loadable independently. The engine command doc loads only the references relevant to the current subcommand. This follows Conversus Principle XVIII (Progressive Disclosure Contract).

### AD-3: Docs target three audiences

1. **Users** — developers using the orchestrator to manage projects (guides, quickstart, recipes)
2. **Extenders** — developers writing hooks, custom recipes, or provider integrations (reference docs, conventions)
3. **Contributors** — developers working on orchestrator internals (architecture, AGENTS.md, constitution walkthrough)

Each doc declares its audience. No doc tries to serve all three.

### AD-4: CHANGELOG is authoritative for version history

CHANGELOG.md is the single source of truth for what changed in each version. It is updated as part of every milestone completion, not retroactively. Entries reference spec numbers and milestone IDs for traceability.

### AD-5: Bug fixes from documentation are committed inline

When a documentation author discovers a bug (code doesn't match documented behavior), the fix is committed as part of the documentation phase — not deferred to a separate milestone. The commit message references the doc that surfaced it. This is the "docs find bugs" principle made mechanical.

## Scope Boundaries

### In Scope

- Reference docs for all M004-M005 subsystems (engine, recipes, hooks, events, errors, guards, verdicts, providers)
- User guide: getting started, first orchestrated project, recipe authoring, hook development
- Architecture overview: engine pipeline diagram, data flow, state machine, file layout
- AGENTS.md update for contributors (coding conventions, testing patterns, constitution compliance)
- CHANGELOG entries for M001-M006
- Extension.yml documentation (commands, hooks, scripts inventory)
- Constitution v2.0 walkthrough with examples per principle
- Bug fixes discovered during documentation (committed inline)
- All existing M001-M003 scripts verified against their documented behavior

### Out of Scope

- API documentation (no API exists — this is a shell extension)
- Video tutorials or interactive guides
- Internationalization
- Auto-generated docs from code comments (Bash doesn't support this well)

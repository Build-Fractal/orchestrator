---
schema_version: "1.0"
type: context-draft
milestone: "M006"
status: finalized
created_at: "2026-04-10T23:30:00Z"
finalized_at: "2026-04-13T00:00:00Z"
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

- Reference docs for all M004-[M005](../../milestones/M005/index.md) subsystems (engine, recipes, hooks, events, errors, guards, verdicts, providers)
- User guide: getting started, first orchestrated project, recipe authoring, hook development
- Architecture overview: engine pipeline diagram, data flow, state machine, file layout
- AGENTS.md update for contributors (coding conventions, testing patterns, constitution compliance)
- CHANGELOG entries for M001-M006
- Extension.yml documentation (commands, hooks, scripts inventory)
- Constitution v2.0 walkthrough with examples per principle
- Bug fixes discovered during documentation (committed inline)
- All existing M001-[M003](../../milestones/M003/index.md) scripts verified against their documented behavior

### Out of Scope

- API documentation (no API exists — this is a shell extension)
- Video tutorials or interactive guides
- Internationalization
- Auto-generated docs from code comments (Bash doesn't support this well)

## Design Constraints

### DC-1: Doc format follows existing references/ convention

All new reference docs follow the pattern established by `references/state-machine.md`:
- Open with a one-line progressive disclosure statement (audience + self-containment note)
- Use `##` for major sections, `###` for subsections
- Include a `## Overview` section immediately after the title
- Horizontal rules (`---`) separate major conceptual blocks
- ASCII diagrams preferred over external image dependencies
- No inline HTML — pure markdown only

### DC-2: Audience label on every doc

Each document opens with an audience declaration immediately after the title or progressive disclosure line. Valid audiences: `users`, `extenders`, `contributors`. A doc may target at most two audiences. This ensures the reader knows whether the doc is relevant before investing time.

### DC-3: Cross-links use relative paths

All cross-references between docs use relative markdown links (`[State Machine](../references/state-machine.md)`), not absolute paths. This ensures links survive repo moves and work on GitHub, local clones, and spec-kit rendering.

### DC-4: Verify-as-you-write is mechanical, not aspirational

"Verified" means the author:
1. Ran the documented command/script against the actual codebase
2. Confirmed the output matches what the doc says
3. If output diverged — either fixed the doc or fixed the code (with a commit referencing the doc)

A doc section that describes behavior without having been executed is "drafted", not "verified". Phase summaries must distinguish between drafted and verified sections.

### DC-5: Bug fix commits reference the doc that surfaced them

When a documentation author discovers and fixes a code bug, the commit message includes `(found via docs/X.md)` or `(found via references/Y.md)` so that the documentation-as-verification value is traceable in git history.

### DC-6: Bash 3.2 / POSIX compatibility for all code fixes

Any bug fixes committed during documentation phases must maintain Bash 3.2 compatibility (macOS default). No bashisms beyond 3.2 (no `declare -A`, no `${var,,}`, no `|&`). This matches the existing project constraint.

## Open Questions

### OQ-1: RESOLVED — docs/ directory structure

The roadmap specifies `docs/` for user guides and `references/` for reference docs. The `docs/` directory does not exist yet. It will be created during P04 (User Guide). No action needed until then.

### OQ-2: RESOLVED — Scope of "all M001-M005 scripts"

The evaluation references ~90+ scripts. During execution, each phase's boundary map scopes exactly which scripts are relevant — P01 covers state/lifecycle scripts, P02 covers engine/library, P03 covers recipe/routing. No phase attempts to document "everything" — each has a focused subset.

### OQ-3: RESOLVED — AGENTS.md location

The roadmap references `scripts/AGENTS.md`. This is the contributor conventions file scoped to P05. It lives at the scripts root since it governs script authoring conventions.

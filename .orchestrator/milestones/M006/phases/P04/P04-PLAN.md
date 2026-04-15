---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M006"
goal: "Create four user guides in docs/ that walk a new developer through installation, recipe authoring, hook development, and knowledge management — verified by following each guide step-by-step"
demo_sentence: "A new developer reading docs/getting-started.md can install the extension, run their first orchestrated milestone, customize a recipe, write a hook, and understand the output — every command verified by following the guide from scratch on a clean test project."
risk: "medium"
depends_on: ["P01", "P02", "P03"]
---

<!--
  P04 — User Guide
  =================

  Context: M006 (Documentation & Quality) Phase 04 creates four user
  guide documents in docs/ that serve as the primary onboarding path
  for new users of the speckit-orchestrator extension. Each guide is
  audience-labeled "users" and cross-links to the reference docs
  produced in P01-P03. Every workflow described is verified by
  following the documented steps against the actual codebase. Any
  discrepancies produce bug fix commits per DC-5.

  Upstream context:
    P01: references/architecture.md (378 lines), references/file-formats.md (1105 lines)
    P02: references/engine.md (245 lines), references/events.md (617 lines),
         references/errors.md (316 lines), references/hooks.md (361 lines)
    P03: references/recipes.md (531 lines), references/routing.md (260 lines)

  Design constraints from M006-CONTEXT.md:
    DC-1: Progressive disclosure format (## Overview after title, ASCII diagrams)
    DC-2: Audience label on every doc — user guides use "users"
    DC-3: Cross-links use relative paths
    DC-4: Verify-as-you-write — follow each step, confirm output matches
    DC-5: Bug fix commits reference the doc that surfaced them
    DC-6: Bash 3.2 / POSIX compatibility for all code fixes
-->

## Must-Haves

### Truths

- `docs/getting-started.md` exists with progressive disclosure header and audience label "users".
  - Check: `bash scripts/verify/m006-p04-gs-header.sh`
- `docs/getting-started.md` documents installation steps (references `references/installation.md`).
  - Check: `bash scripts/verify/m006-p04-gs-install.sh`
- `docs/getting-started.md` documents first project setup (evaluate, discuss, roadmap, plan-phase).
  - Check: `bash scripts/verify/m006-p04-gs-workflow.sh`
- `docs/getting-started.md` documents running the engine and interpreting output (events, results, state transitions).
  - Check: `bash scripts/verify/m006-p04-gs-engine.sh`
- `docs/recipe-authoring.md` exists with progressive disclosure header and audience label "users".
  - Check: `bash scripts/verify/m006-p04-recipe-header.sh`
- `docs/recipe-authoring.md` documents creating a custom recipe, overriding per-phase, adding sections, and configuring compression.
  - Check: `bash scripts/verify/m006-p04-recipe-content.sh`
- `docs/hook-development.md` exists with progressive disclosure header and audience label "users".
  - Check: `bash scripts/verify/m006-p04-hook-header.sh`
- `docs/hook-development.md` documents verdict protocol, testing hooks, debugging, and includes at least two worked examples.
  - Check: `bash scripts/verify/m006-p04-hook-content.sh`
- `docs/knowledge-management.md` exists with progressive disclosure header and audience label "users".
  - Check: `bash scripts/verify/m006-p04-km-header.sh`
- `docs/knowledge-management.md` documents entry lifecycle (create, update, promote, archive, supersede), staleness, graph relationships, scope filtering, and consolidation.
  - Check: `bash scripts/verify/m006-p04-km-content.sh`
- All four docs cross-link to reference docs and to each other using relative paths (DC-3).
  - Check: `bash scripts/verify/m006-p04-crosslinks.sh`
- Every command name mentioned in `docs/getting-started.md` matches a command listed in `extension.yml`.
  - Check: `bash scripts/verify/m006-p04-commands-match.sh`

### Artifacts

- `docs/getting-started.md` (min 200 lines, contains "## Overview", "Audience: users", "install", "evaluate", "roadmap", "auto", "events")
- `docs/recipe-authoring.md` (min 150 lines, contains "## Overview", "Audience: users", "source", "compression", "override", "per-phase")
- `docs/hook-development.md` (min 150 lines, contains "## Overview", "Audience: users", "verdict", "PASS", "BLOCK", "budget gate", "quality check")
- `docs/knowledge-management.md` (min 150 lines, contains "## Overview", "Audience: users", "create-entry", "staleness", "graph", "consolidat")

### Key Links

- `docs/getting-started.md` -> `references/installation.md` (installation prerequisites)
- `docs/getting-started.md` -> `references/architecture.md` (engine pipeline overview)
- `docs/getting-started.md` -> `references/engine.md` (engine CLI args, env vars)
- `docs/getting-started.md` -> `references/events.md` (event type details)
- `docs/getting-started.md` -> `references/state-machine.md` (state transitions)
- `docs/recipe-authoring.md` -> `references/recipes.md` (full recipe reference)
- `docs/recipe-authoring.md` -> `references/routing.md` (model routing for context_budget)
- `docs/recipe-authoring.md` -> `references/file-formats.md` (context-recipe.yaml schema)
- `docs/hook-development.md` -> `references/hooks.md` (full hook reference)
- `docs/hook-development.md` -> `references/events.md` (event types emitted by hooks)
- `docs/hook-development.md` -> `references/errors.md` (error taxonomy for hook failures)
- `docs/knowledge-management.md` -> `references/architecture.md` (knowledge subsystem in subsystem map)
- `docs/knowledge-management.md` -> `references/file-formats.md` (knowledge entry frontmatter schema)

## Tasks

### T01: Create `docs/getting-started.md` — installation, first project, running the engine

Creates the `docs/` directory and the primary onboarding guide. Reads
`references/installation.md` for installation prerequisites, `extension.yml`
for the command inventory, `references/architecture.md` for the engine pipeline,
and `references/engine.md` for CLI arguments and environment variables. Walks a
new user through: installing the extension, initializing a project (evaluate,
discuss, roadmap), planning and executing a phase (plan-phase, dispatch/auto),
interpreting engine output (events, results, state transitions), and
understanding the output file structure.

Full plan: `tasks/T01-PLAN.md`

### T02: Create `docs/recipe-authoring.md` — custom recipes, overrides, compression

Reads `references/recipes.md` for full recipe schema reference, `references/routing.md`
for context_budget integration, and `templates/context-recipe.yaml` for the default
recipe. Walks a user through: understanding what recipes do, creating a custom
recipe from scratch, overriding a recipe per-phase, adding custom sections,
configuring compression, and troubleshooting common recipe issues.

Full plan: `tasks/T02-PLAN.md`

### T03: Create `docs/hook-development.md` — writing hooks, verdict protocol, examples

Reads `references/hooks.md` for the full hook reference, `references/events.md`
for event types emitted during hook lifecycle, and `references/errors.md` for
error taxonomy related to hook failures. Walks a user through: understanding
hook lifecycle points, the verdict protocol (PASS/BLOCK/WARN/NEEDS_REVIEW),
writing a hook script, testing hooks, debugging hook failures, and includes
two worked examples (budget gate hook, quality check hook).

Full plan: `tasks/T03-PLAN.md`

### T04: Create `docs/knowledge-management.md` — entry lifecycle, staleness, graphs, consolidation

Reads `scripts/knowledge/*.sh` to verify all lifecycle operations, reads
`references/file-formats.md` for knowledge entry frontmatter schema, and
reads `references/architecture.md` for knowledge subsystem context. Walks
a user through: creating knowledge entries, updating entries, promoting
entries, archiving entries, superseding entries, understanding staleness
computation, using graph relationships, scope filtering, and running
consolidation workflows.

Full plan: `tasks/T04-PLAN.md`

### T05: Verification scripts and cross-link validation for P04

Creates all 12 verification scripts referenced in the Truths section
above. Each script is a standalone single-file invocation (AD-19
compliant) that checks one specific property of the P04 documentation
artifacts. Runs the full verification to confirm all checks pass.

Full plan: `tasks/T05-PLAN.md`

## Task Dependencies

```
T01 (getting-started.md) ──────┐
T02 (recipe-authoring.md) ─────┤
T03 (hook-development.md) ─────┼──→ T05 (verification scripts + cross-links)
T04 (knowledge-management.md) ─┘
```

T01 creates the `docs/` directory — T02, T03, T04 depend on T01 having
created the directory (though they can create it themselves if run first).
T05 depends on all four documentation tasks because it validates the
artifacts they produce and checks cross-links between them and to
reference docs.

## Files Likely Touched

- `docs/getting-started.md` (create)
- `docs/recipe-authoring.md` (create)
- `docs/hook-development.md` (create)
- `docs/knowledge-management.md` (create)
- `scripts/verify/m006-p04-gs-header.sh` (create)
- `scripts/verify/m006-p04-gs-install.sh` (create)
- `scripts/verify/m006-p04-gs-workflow.sh` (create)
- `scripts/verify/m006-p04-gs-engine.sh` (create)
- `scripts/verify/m006-p04-recipe-header.sh` (create)
- `scripts/verify/m006-p04-recipe-content.sh` (create)
- `scripts/verify/m006-p04-hook-header.sh` (create)
- `scripts/verify/m006-p04-hook-content.sh` (create)
- `scripts/verify/m006-p04-km-header.sh` (create)
- `scripts/verify/m006-p04-km-content.sh` (create)
- `scripts/verify/m006-p04-crosslinks.sh` (create)
- `scripts/verify/m006-p04-commands-match.sh` (create)
- Bug fix commits for any discrepancies found (files TBD)

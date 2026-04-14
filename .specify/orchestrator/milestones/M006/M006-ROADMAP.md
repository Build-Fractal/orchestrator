---
schema_version: "1.0"
type: roadmap
milestone: "M006"
feature_ref: "006-documentation-quality"
feature_spec: "specs/006-documentation-quality/spec.md"
vision: "Produce reference docs, user guides, and architecture documentation that are verified against the actual codebase — surfacing and fixing bugs as a natural byproduct of documentation, so that the orchestrator is both well-documented and battle-tested before Conversus integration."
tier: "C"
created_at: "2026-04-10T23:30:00Z"
updated_at: "2026-04-13T00:00:00Z"
---

## Phases

- [x] **P01**: Architecture Overview and File Layout — "A developer reading `references/architecture.md` understands the engine pipeline (7 stages), data flow (recipes → build → compress → dispatch → verify → record → advance), state machine, file layout, and how M001-M005 subsystems relate — every diagram and path reference verified against actual codebase."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `references/architecture.md` — engine pipeline diagram (ASCII), data flow, state machine states and transitions, file layout tree, subsystem relationship map
      - `references/file-formats.md` — schema documentation for all file formats: execution-log.jsonl, context-recipe.yaml, hooks.yaml, routing.yaml, knowledge entry frontmatter, checkpoint.json, doctor-history.jsonl
      - Bug fixes for any discrepancy found between documented state machine and actual `phase-transition.sh` / `derive-phase.sh` behavior
    - Consumes:
      - All scripts from M001-M005 (read for verification, not modified unless bugs found)

- [x] **P02**: Engine and Library Reference Docs — "A developer reading `references/engine.md` can understand run context initialization, event types, error taxonomy, result protocol, guard checks, and hook lifecycle without reading source code — every function signature and event type verified by running the engine against a test fixture."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `references/engine.md` — engine run.sh documentation: arguments, environment variables, lifecycle stages, checkpointing, dry-run mode, crash recovery
      - `references/events.md` — complete event type registry with field schemas: SESSION_START, TASK_START, TASK_COMPLETE, PHASE_COMPLETE, GUARD_BLOCKED, HOOK_BLOCKED, plus examples
      - `references/errors.md` — error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) with examples of each, emit_result protocol, error_kind in JSONL
      - `references/hooks.md` — hook lifecycle (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE), hooks.yaml format, frozen snapshot contents, verdict protocol (PASS/BLOCK/WARN/NEEDS_REVIEW), timeout behavior, writing a custom hook walkthrough
      - Bug fixes for any event/error/hook behavior that doesn't match documented protocol
    - Consumes:
      - `scripts/lib/*.sh` (from M004 P02) — verified against documented signatures
      - `scripts/engine/run.sh` (from M004 P03) — verified against documented lifecycle

- [x] **P03**: Recipe and Routing Reference Docs — "A developer reading `references/recipes.md` can author a custom context recipe, override it per-phase, configure compression, and set up model fallback chains — verified by creating a test recipe and running a dispatch with it."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces:
      - `references/recipes.md` — context-recipe.yaml schema: section fields (id, source, filter, priority, order), source types (computed, index, file, phase_summaries, phase_plan, template), compression block, manifest config, recipe resolution order (task > phase > milestone > default), complete examples
      - `references/routing.md` — routing.yaml schema: model tiers, fallback chains, classification rules, budget ceiling, history_weight, complete examples
      - Bug fixes for any recipe parsing edge case found during example authoring
    - Consumes:
      - `templates/context-recipe.yaml` (from M004 P04)
      - `templates/routing.yaml` (from M004 P04)
      - `scripts/lib/recipe-parser.sh` (from M004 P04) — verified against documented parsing behavior

- [x] **P04**: User Guide — "A new developer reading `docs/getting-started.md` can install the extension, run their first orchestrated milestone, customize a recipe, write a hook, and understand the output — every command verified by following the guide from scratch on a clean test project."
  - Risk: medium
  - Depends: P01, P02, P03 (references must exist for cross-linking)
  - Boundary Map:
    - Produces:
      - `docs/getting-started.md` — installation, first project setup, running the engine, interpreting events, understanding output structure
      - `docs/recipe-authoring.md` — creating custom recipes, overriding per-phase, adding sections, configuring compression, troubleshooting common issues
      - `docs/hook-development.md` — writing hooks, verdict protocol, testing hooks, debugging hook failures, example: budget gate hook, example: quality check hook
      - `docs/knowledge-management.md` — creating entries, lifecycle operations, staleness, graph relationships, scope filtering, consolidation workflow
      - Bug fixes for any workflow that doesn't work as documented when followed step-by-step
    - Consumes:
      - All reference docs (from P01-P03) — cross-linked
      - Extension.yml — verified command list matches documented commands

- [x] **P05**: Contributor Guide and AGENTS.md — "A developer reading `AGENTS.md` understands coding conventions (Bash 3.2, double-sourcing guards, error/event emission, atomic writes), testing patterns, constitution v2.0 compliance requirements, and PR review checklist — verified by having the guide review one real M004/M005 phase for compliance."
  - Risk: low
  - Depends: P01 (architecture context needed)
  - Boundary Map:
    - Produces:
      - Updated `scripts/AGENTS.md` — coding conventions (Bash 3.2 patterns, library sourcing, event emission, result protocol), testing patterns, constitution v2.0 compliance checklist, PR review checklist, anti-patterns to avoid
      - `references/constitution-walkthrough.md` — each of the 13 principles with concrete examples from the codebase, common violations, how to check compliance
      - Bug fixes for any convention violations found during guide authoring (existing scripts that don't follow documented patterns)
    - Consumes:
      - `.specify/memory/constitution.md` (v2.0 from M004 P01)
      - `ANTIPATTERNS.md` (from M004 P01) — referenced in contributor guide

- [x] **P06**: CHANGELOG, Extension Inventory, and Final Verification Sweep — "CHANGELOG.md has entries for M001-M006; extension.yml is verified to list every command, hook, and script; run-doctor.sh passes all checks including new documentation conformance — any remaining bugs found during this sweep are fixed."
  - Risk: low
  - Depends: P01, P02, P03, P04, P05
  - Boundary Map:
    - Produces:
      - Updated `CHANGELOG.md` — entries for M001 (v0.1.0), M002 (knowledge), M003 (migration), M004 (engine), M005 (hardening), M006 (documentation)
      - Verified `extension.yml` — every command, hook, script cross-checked against actual file existence
      - Updated `scripts/diagnostics/run-doctor.sh` — adds doc conformance check (references/ files exist for all subsystems, docs/ files exist for all user workflows)
      - Final bug fix commits from verification sweep
      - Updated `CLAUDE.md` — accurate project status, key files list, recent changes
    - Consumes: all prior phases + all M001-M005 artifacts

## Cross-Cutting Concerns

- **Verify-as-you-write** — P01, P02, P03, P04, P05, P06. Every documented command, path, and behavior is executed against the actual codebase during authoring. Discrepancies produce bug fix commits within the documentation phase.

- **Cross-linking** — P04, P05, P06. User guides link to reference docs. Reference docs link to each other. CHANGELOG links to specs. All links verified.

- **Audience labeling** — P01, P02, P03, P04, P05. Each doc begins with a one-line audience note: "Audience: users", "Audience: extenders", "Audience: contributors".

## Dependency Graph

```
P01 (Architecture) ──────────────→ P04 (User Guide)
P02 (Engine/Library Refs) ───────→ P04
P03 (Recipe/Routing Refs) ───────→ P04
P01 ─────────────────────────────→ P05 (Contributor Guide)
P01, P02, P03, P04, P05 ────────→ P06 (CHANGELOG & Sweep)
```

P01, P02, P03 are independent — can execute concurrently.
P04 depends on P01-P03 (needs references to cross-link).
P05 depends on P01 (needs architecture context).
P06 depends on all (final sweep).

## Execution Order

1. **P01** (Architecture), **P02** (Engine Refs), **P03** (Recipe Refs) — all independent, can execute concurrently. Medium/low risk.
2. **P04** (User Guide) and **P05** (Contributor Guide) — can execute concurrently. P04 depends on P01-P03. P05 depends on P01. Medium/low risk.
3. **P06** (CHANGELOG & Sweep) — depends on all. Low risk. Final verification.

## Validation

- **No conflicting producers**: PASS — Each phase produces distinct doc files. P01: references/architecture.md, references/file-formats.md. P02: references/engine.md, events.md, errors.md, hooks.md. P03: references/recipes.md, references/routing.md. P04: docs/*.md. P05: AGENTS.md, references/constitution-walkthrough.md. P06: CHANGELOG.md, extension.yml updates. No overlaps.

- **All consumed items have producers**: PASS — P04 consumes P01-P03 reference docs. P05 consumes P01 architecture. P06 consumes all. All satisfied.

- **DAG is acyclic**: PASS — {P01, P02, P03} → {P04, P05} → {P06}. No cycles.

- **Bug fix expectation**: Each phase is expected to produce 2-5 bug fix commits based on M002/M003 audit experience (where documentation review found 2 critical and 7 medium issues). Total estimated: 10-20 bug fixes across the milestone.

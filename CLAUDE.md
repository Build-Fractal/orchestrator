# CLAUDE.md — spec-kit-orchestrator

## What This Is

A spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's SDD workflow. This is the extension's own repo — it is structured as a standard spec-kit extension and uses spec-kit's own SDD process to develop itself.

## Project Status

Specification phase complete. Next steps: `/speckit.plan` then `/speckit.tasks` then implementation.

## Key Files

- `extension.yml` — spec-kit extension manifest (the deliverable)
- `commands/` — orchestrator command definitions (placeholders, pending implementation)
- `skills/` — skill folders with scripts/templates/references (pending implementation)
- `specs/001-speckit-orchestrator/spec.md` — full feature specification
- `.specify/memory/constitution.md` — 7 governing principles
- `.planning/research/` — deep research on 5 source systems (spec-kit, GSD-2, APM, superpowers, gh-aw)
- `.planning/speckit-orchestrator-playbook.md` — execution playbook

## Architecture

This is a **spec-kit extension** (markdown commands + shell scripts), NOT a standalone CLI. It:

- Registers commands via `extension.yml` following `speckit.orchestrator.*` naming
- Uses hooks at 4 spec-kit lifecycle points (before/after tasks, before/after implement)
- Uses command composition to wrap spec-kit commands for steps without hooks
- Stores orchestrator state at `.specify/orchestrator/` (separate from `specs/`)
- Must work with all spec-kit-supported agents (Claude Code, Copilot, Cursor, Gemini CLI)
- Must NOT require GSD-2 or APM as runtime dependencies (principles ported, not wrapped)

## Constitution Principles (governs all decisions)

1. Context Minimization
2. Evidence Before Claims
3. Design Before Code
4. Plans Assume Zero Context
5. Fresh Context Per Unit
6. State On Disk Is Truth
7. Knowledge Compounds

Read `.specify/memory/constitution.md` for full definitions.

## SDD Workflow

This project uses spec-kit's own slash commands for development:
- `/speckit.specify` — create/update spec
- `/speckit.clarify` — resolve ambiguities
- `/speckit.plan` — create implementation plan
- `/speckit.tasks` — generate task breakdown
- `/speckit.analyze` — consistency check
- `/speckit.implement` — execute tasks

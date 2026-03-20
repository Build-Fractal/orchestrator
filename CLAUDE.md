# CLAUDE.md — spec-kit-orchestrator

## What This Is

A spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's SDD workflow. This is the extension's own repo — it is structured as a standard spec-kit extension and uses spec-kit's own SDD process to develop itself.

## Project Status

Specification and planning phases complete. Plan refined through post-analysis gap closure (15 issues resolved), then a 16-point cross-artifact consistency review addressing spec/plan/data-model/contract alignment gaps. Next step: `/speckit.tasks` then implementation.

## Key Files

- `extension.yml` — spec-kit extension manifest (the deliverable)
- `commands/` — orchestrator command definitions (placeholders, pending implementation)
- `scripts/` — helper scripts organized by concern (state, dispatch, verify, knowledge, lifecycle)
- `templates/` — output templates (roadmap, summaries, dispatch prompt, etc.)
- `references/` — progressive disclosure docs (state machine, verification ladder, tier definitions)
- `specs/001-speckit-orchestrator/spec.md` — full feature specification
- `.specify/memory/constitution.md` — 7 governing principles
- `.planning/research/` — deep research on 5 source systems (spec-kit, GSD-2, APM, superpowers, gh-aw)
- `.planning/speckit-orchestrator-playbook.md` — execution playbook

## Architecture

This is a **spec-kit extension** (markdown commands + shell scripts), NOT a standalone CLI. It:

- Registers commands via `extension.yml` following `speckit.orchestrator.*` naming
- Uses hooks at 5 spec-kit lifecycle points (before/after tasks, before/after implement, before commit)
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

## Active Technologies
- Markdown (spec-kit command format) + Bash 4+ / POSIX sh (helper scripts) + spec-kit >=0.1.0 (extension host), git (version control, worktree isolation), jq (optional, JSON parsing in scripts) (001-speckit-orchestrator)
- File-based state machine — YAML frontmatter + markdown body files, JSONL append-only logs, JSON lock files. All state at `.specify/orchestrator/` (001-speckit-orchestrator)

## Recent Changes
- 001-speckit-orchestrator: Added Markdown (spec-kit command format) + Bash 4+ / POSIX sh (helper scripts) + spec-kit >=0.1.0 (extension host), git (version control, worktree isolation), jq (optional, JSON parsing in scripts)

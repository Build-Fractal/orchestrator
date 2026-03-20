# CLAUDE.md — spec-kit-orchestrator

## What This Is

A spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's SDD workflow. This is the extension's own repo — it is structured as a standard spec-kit extension and uses spec-kit's own SDD process to develop itself.

## Project Status

**v0.1.0 implemented** (M001 complete, 2026-03-20). 10 commands, 21 scripts, 13 templates, 4 reference docs. 294 test assertions, zero failures. User Stories 1-6 delivered. US7 (GitHub Agentic Workflows) and US8 (APM Packaging) deferred.

## Key Files

- `extension.yml` — spec-kit extension manifest (10 commands, 5 hooks, 21 scripts)
- `commands/` — orchestrator command definitions (10 agent instruction documents)
- `scripts/` — helper scripts organized by concern (state, dispatch, verify, knowledge, lifecycle)
- `templates/` — 13 output templates + 1 config default
- `references/` — 4 progressive disclosure docs (state machine, verification ladder, tier definitions, file formats)
- `tests/` — 7 test suites (294 assertions)
- `specs/001-speckit-orchestrator/spec.md` — full feature specification
- `.specify/memory/constitution.md` — 7 governing principles
- `.specify/orchestrator/KNOWLEDGE.md` — consolidated patterns, decisions, lessons
- `.specify/orchestrator/milestone-summary.md` — M001 build summary + extension guide

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
- 001-speckit-orchestrator: M001 v0.1.0 implementation complete. All core orchestration delivered (scope triage, phase decomposition, state machine, autonomous dispatch, verification, crash recovery, knowledge generation, consolidation).

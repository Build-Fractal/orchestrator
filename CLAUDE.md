# CLAUDE.md — spec-kit-orchestrator

## What This Is

A spec-kit extension that adds autonomous multi-phase orchestration to spec-kit's SDD workflow. This is the extension's own repo — it is structured as a standard spec-kit extension and uses spec-kit's own SDD process to develop itself.

## Project Status

**v0.8.0** (2026-04-14). 13 commands, 80+ scripts, 24+ templates, 14 reference docs, 4 user guides, `packaging/` layer, runtime + format + backend adapter tree. M008 standalone-orchestrator milestone complete — adaptive intensity engine, backend-agnostic dispatch interface, intensity-aware pipeline scaling, state/namespace independence, runtime/format adapters, multi-runtime packaging with installers, and onboarding init flow.

## Standalone Mode (M008)

The orchestrator now operates standalone without spec-kit, with three runtimes (Claude Code / Codex CLI / Cursor) and auto-calibrated process intensity (Quick / Standard / Full). Key standalone entry points:

- `orchestrator:init` (commands/init.md, scripts/lifecycle/init-project.sh) — first-run setup: detects project, probes capabilities, generates config + runtime-appropriate instruction file, installs skills. Completes in ~1s.
- `scripts/engine/intensity-recommend.sh` — given a task description + capability profile, recommends Quick/Standard/Full
- `scripts/dispatch/dispatch-interface.sh` — uniform backend-agnostic dispatch (filename-routed to `scripts/dispatch/adapters/backend/*.sh`)
- `scripts/state/resolve-root.sh` — 5-rule state root resolver (ORCHESTRATOR_ROOT env → config → `.orchestrator/` → `.specify/orchestrator/` bridge → default)
- `packaging/bundle/` — installable unit consumed by `packaging/install/install-{claude-code,codex,cursor}.sh`

Live state still lives at `.specify/orchestrator/` in this repo; `scripts/migrate/migrate-state.sh` is available to move to `.orchestrator/` when ready.

## Key Files

- `extension.yml` — spec-kit extension manifest (12 commands, 5 hooks, 55 scripts)
- `commands/` — orchestrator command definitions (12 agent instruction documents)
- `scripts/` — helper scripts organized by concern (state, dispatch, verify, knowledge, lifecycle, diagnostics)
- `templates/` — 21 output templates + 1 config default
- `references/` — 14 reference docs (architecture, engine, events, errors, hooks, recipes, routing, file formats, state machine, verification ladder, tier definitions, installation, provider convention, constitution walkthrough)
- `docs/` — 4 user guides (getting started, recipe authoring, hook development, knowledge management)
- `tests/` — 7 test suites (334 assertions)
- `specs/001-speckit-orchestrator/spec.md` — full feature specification
- `.specify/memory/constitution.md` — 7 governing principles
- `.specify/orchestrator/KNOWLEDGE.md` — consolidated patterns, decisions, lessons
- `.specify/orchestrator/milestone-summary.md` — M001 build summary + extension guide
- `CHANGELOG.md` — version history and audit remediation tracking

## Architecture

This is a **spec-kit extension** (markdown commands + shell scripts), NOT a standalone CLI. It:

- Registers commands via `extension.yml` following `speckit.orchestrator.*` naming
- Uses hooks at 5 spec-kit lifecycle points (before/after tasks, before/after implement, before commit)
- Uses command composition to wrap spec-kit commands for steps without hooks
- Stores orchestrator state at `.specify/orchestrator/` (separate from `specs/`)
- v0.1.0 designed and validated with Claude Code only (agent-neutral architecture, multi-agent validation deferred to M002)
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
- Markdown (spec-kit command format) + Bash 3.2+ / POSIX sh (helper scripts) + spec-kit >=0.1.0 (extension host), git (version control, worktree isolation), jq (optional, JSON parsing in scripts) (001-speckit-orchestrator)
- File-based state machine — YAML frontmatter + markdown body files, JSONL append-only logs, JSON lock files. All state at `.specify/orchestrator/` (001-speckit-orchestrator)

## Recent Changes
- 008-standalone-orchestrator: M008 v0.8.0 complete. 7 phases, 35 tasks. Adaptive intensity engine (P01), backend-agnostic dispatch interface with filename-based routing (P02), intensity-aware pipeline scaling with mid-workflow override (P03), state/namespace independence with 5-rule resolver + migration tool (P04), runtime + format adapters with HOME/project-dir guards (P05), multi-runtime packaging with SKILL.md spec + bundle + 3 installers + offline-safe update check (P06), orchestrator:init onboarding with reinit-handler user-edit preservation (P07). Patterns: filename-based adapter auto-discovery, hermetic-first testing, thin delegation, comment-aware Bash 3.2 compat scan.
- 001-speckit-orchestrator: M006 documentation milestone complete. 14 reference docs, 4 user guides, scripts/AGENTS.md contributor guide, check-docs.sh diagnostic. Full progressive-disclosure reference suite covering architecture, engine internals, events, errors, hooks, recipes, routing, and constitution walkthrough.
- 001-speckit-orchestrator: M001 v0.1.0 implementation complete. All core orchestration delivered (scope triage, phase decomposition, state machine, autonomous dispatch, verification, crash recovery, knowledge generation, consolidation).

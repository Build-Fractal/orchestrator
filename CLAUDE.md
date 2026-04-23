# >>> orchestrator:recent-changes >>>
- 027-conversus-oss-migration: Migrate orchestrator default Conversus integration from paid build to OSS build with paid-escape-hatch preserved (M026).
# <<< orchestrator:recent-changes <<<
# CLAUDE.md — spec-kit-orchestrator

## What This Is

A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself.

## Project Status

**v0.9.1** (2026-04-23). 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 6 user guides, `packaging/` layer, runtime + format + backend adapter tree. M011 (spec management), M012 (spec wiki, 2026-04-21), M013 (GitHub native integration), M015 (standalone cutover), M016 (autonomous hardening), M019 Tier 1 (observability emitter), M021 (autonomous hardening v2), and M025 (installer coexistence, 2026-04-23) complete. **M014 (extended) is next up**.

## Forward Roadmap (revised 2026-04-22 per D016)

Remaining milestones execute in this order: **M014 (extended) → M020 → M024 → M019 Tier 2+3 → M018 → M023 → M009 (extended) → M010 (adjusted)**. **M014** extends to include native `orchestrator:specify` (spec creation, CC-first, written portably), conversus-suggestion logic for complex/controversial specs, and `AGENTS.md` dual-write for Codex parity. **M024 (Universal Intake & Routing)** is a new committed milestone that extends `orchestrator:evaluate` to input-agnostic (idea/paragraph/fragment/spec/empty) and emits a reviewable proposal artifact covering six routing axes (input shape, scope tier, decomposition, design gate, conversus gate, intensity); degenerate fast-path auto-proceeds on trivial tasks. **M023 (Design Layer)** is a new committed milestone — `orchestrator:design` spawns N design-personality agents in parallel via conversus, each producing a DESIGN.md draft + working coded prototype; user picks side-by-side; renderer adapter interface shaped as MCP clients (runtime-agnostic). M023 lands pre-launch because this repo has no internal UI to dogfood against. **M009** extends with a runtime-parity audit as launch gate, consuming a lightweight `RUNTIME-ASSUMPTIONS.md` registry accumulated during M013–M018. **M010** ships Managed Agents primary + Codex Cloud stub (proves abstraction); full Codex Cloud is demand-driven fast-follow. Ultraplan/ultrareview remain parked (CC-only; M013 covers universal case). Dogfooding posture: CC-exclusive through launch, Codex parity concentrated at M009. Conversus integration stays as the M011/P07 reusable adapter — invoked from M013/M014/M023/M024 at opt-in gate points. See `.orchestrator/DECISIONS.md` D004–D016 and `.orchestrator/milestone-summary.md` for details.

## Standalone Mode

The orchestrator operates standalone with three runtimes (Claude Code / Codex CLI / Cursor) and auto-calibrated process intensity (Quick / Standard / Full). Key entry points:

- `orchestrator:init` (commands/init.md, scripts/lifecycle/init-project.sh) — first-run setup: detects project, probes capabilities, generates config + runtime-appropriate instruction file, installs skills. Completes in ~1s.
- `scripts/engine/intensity-recommend.sh` — given a task description + capability profile, recommends Quick/Standard/Full.
- `scripts/dispatch/dispatch-interface.sh` — uniform backend-agnostic dispatch (filename-routed to `scripts/dispatch/adapters/backend/*.sh`).
- `scripts/state/resolve-root.sh` — 4-rule state root resolver (ORCHESTRATOR_ROOT env → config → `.orchestrator/` → default).
- `packaging/bundle/` — installable unit consumed by `packaging/install/install-{claude-code,codex,cursor}.sh`.

All orchestrator runtime state lives at `.orchestrator/` in this repo. The constitution lives at `.orchestrator/memory/constitution.md`.

## Key Files

- `commands/` — orchestrator command definitions (13 agent instruction documents)
- `scripts/` — helper scripts organized by concern (state, dispatch, engine, verify, knowledge, lifecycle, migrate, diagnostics)
- `templates/` — 24+ output templates + 1 config default
- `references/` — 15 reference docs (architecture, engine, events, errors, hooks, recipes, routing, file formats, state machine, verification ladder, tier definitions, installation, provider convention, constitution walkthrough)
- `docs/` — 5 user guides (getting started, recipe authoring, hook development, knowledge management, migrating from spec-kit)
- `packaging/` — installable bundle + per-runtime installers
- `tests/` — 7 test suites (334+ assertions)
- `specs/001-speckit-orchestrator/spec.md` — original feature specification
- `.orchestrator/memory/constitution.md` — 7 governing principles
- `.orchestrator/KNOWLEDGE.md` — consolidated patterns, decisions, lessons
- `.orchestrator/milestone-summary.md` — build summary + extension guide
- `CHANGELOG.md` — version history and audit remediation tracking

## Architecture

This is a standalone orchestrator delivered as a runtime-specific skill bundle (Claude Code / Codex CLI / Cursor). It registers commands via `packaging/install/install-<runtime>.sh`, stores state at `.orchestrator/`, and operates with no runtime dependency on spec-kit.

## Constitution Principles (governs all decisions)

1. Context Minimization
2. Evidence Before Claims
3. Design Before Code
4. Plans Assume Zero Context
5. Fresh Context Per Unit
6. State On Disk Is Truth
7. Knowledge Compounds

Read `.orchestrator/memory/constitution.md` for full definitions.

## SDD Workflow

This project uses its own orchestrator workflow for development:

`orchestrator:evaluate` → `orchestrator:discuss` (Tier C) → `orchestrator:roadmap` → `orchestrator:plan-phase` → `orchestrator:auto` / `orchestrator:dispatch` → `orchestrator:verify` → `orchestrator:consolidate`.

See `commands/` for each command's definition.

## Active Technologies
- Markdown (command format) + Bash 3.2+ / POSIX sh (helper scripts), git (version control, worktree isolation), jq (optional, JSON parsing in scripts) (001-speckit-orchestrator)
- File-based state machine — YAML frontmatter + markdown body files, JSONL append-only logs, JSON lock files. All state at `.orchestrator/` (001-speckit-orchestrator)


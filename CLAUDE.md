# CLAUDE.md — spec-kit-orchestrator

## What This Is

A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself.

## Project Status

**v0.9.0** (2026-04-15). 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 6 user guides, `packaging/` layer, runtime + format + backend adapter tree. M015 (standalone cutover), M016 (autonomous hardening), and M011 (spec management, all 7 phases including P07 Conversus adapter) complete. **M019 Tier 1 metrics emitter is next up** as the kickoff unit of M019 so M012–M014 dogfooding produces real data (see `.orchestrator/DECISIONS.md` D009).

## Forward Roadmap (revised 2026-04-17)

Remaining milestones execute in this order: **M011 (active) → M012 → M013 → M014 → M019 (metrics sketch) → M018 (compression sketch) → M009 → M010**. Dogfooding the spec→wiki→GitHub loop (M011–M014) comes before external launch (M009) so internal usage surfaces the gaps that launch docs need to address. Conversus integration lands inside M011/P07 as a reusable adapter (no standalone M017); M013/M014 invoke it from their own scope at opt-in gate points. **M019 (Observability & Efficiency Metrics)** records time/tokens/$/quality across task/phase/milestone/project; its **Tier 1 emitter ships first thing after M011 closes** as the kickoff unit of M019 so M012–M014 dogfooding produces real data. Tier 2/3 land after M014 and before M018. **M018 (Context Compression Layer — caveman-style token reduction)** follows M019 so compression decisions land on a measured baseline. M010 (Cloud Dispatch) stays at the tail, gated on Managed Agents availability. See `.orchestrator/DECISIONS.md` D004/D005/D006/D007/D008/D009 and `.orchestrator/milestone-summary.md` for details.

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

## Recent Changes
- 016-autonomous-hardening: M016 complete. Eliminated Claude Code safety prompts from auto mode: `write-summary.sh` optional `completed_at` with `now` sentinel, `scripts/verify/run-suite.sh` verify wrapper, Class-A anti-pattern linter (`scripts/verify/anti-pattern-lint.sh`), prohibited-patterns section in dispatch payloads, project-level `.claude/settings.json` with safe Unix tool wildcards, dogfood attestation with zero approval prompts.
- 015-standalone-cutover: M015 v0.9.0 complete. Legacy spec-kit host removed, orchestrator state tree relocated to `.orchestrator/`, constitution moved to `.orchestrator/memory/constitution.md`, 4-rule resolver (bridge removed), all current-state documentation reframed for standalone. Migration adapters preserved for users coming FROM spec-kit (see `docs/migrating-from-speckit.md`).
- 008-standalone-orchestrator: M008 v0.8.0 complete. 7 phases, 35 tasks. Adaptive intensity engine (P01), backend-agnostic dispatch interface with filename-based routing (P02), intensity-aware pipeline scaling with mid-workflow override (P03), state/namespace independence with resolver + migration tool (P04), runtime + format adapters with HOME/project-dir guards (P05), multi-runtime packaging with SKILL.md spec + bundle + 3 installers + offline-safe update check (P06), orchestrator:init onboarding with reinit-handler user-edit preservation (P07). Patterns: filename-based adapter auto-discovery, hermetic-first testing, thin delegation, comment-aware Bash 3.2 compat scan.
- 001-speckit-orchestrator: M006 documentation milestone complete. Reference docs, user guides, scripts/AGENTS.md contributor guide, check-docs.sh diagnostic. Full progressive-disclosure reference suite covering architecture, engine internals, events, errors, hooks, recipes, routing, and constitution walkthrough.
- 001-speckit-orchestrator: M001 v0.1.0 implementation complete. All core orchestration delivered (scope triage, phase decomposition, state machine, autonomous dispatch, verification, crash recovery, knowledge generation, consolidation).

# CLAUDE.md — spec-kit-orchestrator

## What This Is

A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself.

## Project Status

**v0.9.0** (2026-04-15). 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 6 user guides, `packaging/` layer, runtime + format + backend adapter tree. M011 (spec management), M012 (spec wiki, 2026-04-21), M015 (standalone cutover), M016 (autonomous hardening), M019 Tier 1 (observability emitter), and M021 (autonomous hardening v2) complete. **M013 (GitHub native integration) is next up**.

## Forward Roadmap (revised 2026-04-21)

Remaining milestones execute in this order: **M013 → M014 → M020 → M019 Tier 2+3 → M018 → M009 → M010**. Dogfooding the spec→wiki→GitHub loop came before external launch (M009) so internal usage surfaces the gaps that launch docs need to address. Conversus integration lives in M011/P07 as a reusable adapter (no standalone M017); M013/M014 invoke it from their own scope at opt-in gate points. **M020 (Knowledge Layer Maturation)** was promoted as a committed milestone per `.orchestrator/DECISIONS.md` D013 — M012/P02 shipped 1 of 3 D011 evaluation criteria (cross-refs), so the remaining review-state + query-surface + clustering work lands as a dedicated milestone between M014 and M019 Tier 2+3. **M019 Tier 2/3** (rollup + `orchestrator:cost` + full polished surface) follows M020 so A5 on_failure flagging can draw on M020 data. **M018 (Context Compression Layer — four-tier compaction ladder per D010)** follows M019 so compression decisions land on a measured baseline. M010 (Cloud Dispatch) stays at the tail, gated on Managed Agents availability. See `.orchestrator/DECISIONS.md` D004–D013 and `.orchestrator/milestone-summary.md` for details.

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
- 022-spec-wiki: M012 complete (2026-04-21). Dogfood spec→wiki loop: deployable MkDocs Material wiki projecting `.orchestrator/**.md` + `knowledge/**/MEM*.md` via include-markdown SSOT pipeline; scripts/wiki three-stage scanner→stubs→nav pipeline with additive-extension invariant and marker-bounded atomic mkdocs.yml splices; Giscus theme overlay with pathname-keyed threads; `scripts/wiki/wiki-deploy.sh` chained wrapper (4 pre-deploy gates + mkdocs gh-deploy); 37 verification gates across 4 phase suites; `DEPLOY-RECORD.md` first-deploy contract with pending-sentinel path. D011 evaluation (1 of 3 criteria shipped) triggered D013 promoting M020 as a committed milestone between M014 and M019 Tier 2+3. Patterns: chained-gate deploy wrapper with first-non-zero-aborts, graceful-absent-tool/artifact with dry-run-exit-0, pending-sentinel for operator-gated outcomes, SSOT scan with spec-quote exclusion.
- 016-autonomous-hardening: M016 complete. Eliminated Claude Code safety prompts from auto mode: `write-summary.sh` optional `completed_at` with `now` sentinel, `scripts/verify/run-suite.sh` verify wrapper, Class-A anti-pattern linter (`scripts/verify/anti-pattern-lint.sh`), prohibited-patterns section in dispatch payloads, project-level `.claude/settings.json` with safe Unix tool wildcards, dogfood attestation with zero approval prompts.
- 015-standalone-cutover: M015 v0.9.0 complete. Legacy spec-kit host removed, orchestrator state tree relocated to `.orchestrator/`, constitution moved to `.orchestrator/memory/constitution.md`, 4-rule resolver (bridge removed), all current-state documentation reframed for standalone. Migration adapters preserved for users coming FROM spec-kit (see `docs/migrating-from-speckit.md`).
- 008-standalone-orchestrator: M008 v0.8.0 complete. 7 phases, 35 tasks. Adaptive intensity engine (P01), backend-agnostic dispatch interface with filename-based routing (P02), intensity-aware pipeline scaling with mid-workflow override (P03), state/namespace independence with resolver + migration tool (P04), runtime + format adapters with HOME/project-dir guards (P05), multi-runtime packaging with SKILL.md spec + bundle + 3 installers + offline-safe update check (P06), orchestrator:init onboarding with reinit-handler user-edit preservation (P07). Patterns: filename-based adapter auto-discovery, hermetic-first testing, thin delegation, comment-aware Bash 3.2 compat scan.
- 001-speckit-orchestrator: M006 documentation milestone complete. Reference docs, user guides, scripts/AGENTS.md contributor guide, check-docs.sh diagnostic. Full progressive-disclosure reference suite covering architecture, engine internals, events, errors, hooks, recipes, routing, and constitution walkthrough.
- 001-speckit-orchestrator: M001 v0.1.0 implementation complete. All core orchestration delivered (scope triage, phase decomposition, state machine, autonomous dispatch, verification, crash recovery, knowledge generation, consolidation).

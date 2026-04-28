# >>> orchestrator:recent-changes >>>
- 030-context-compression-layer / M018/P07: multi-runtime parity audit complete; tests/compression-runtime-parity/ corpus + scripts/diagnostics/m018-runtime-parity.sh proves zero-LLM tier byte-equality across CC / Codex CLI / Cursor (filter+T1+T2 SHA-256 identical per fixture); scripts/diagnostics/m018-runtime-parity-tier3.sh + tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh proves T3 routes through tier3-llm-call.sh under every runtime with FR-9 failure-passthrough preserved; references/RUNTIME-ASSUMPTIONS.md compression block carries divergence rows + M009 audit-row links.
- 030-context-compression-layer / M018/P06: tier3 auto-compact live in build-context.sh (_bc_apply_tier3: dispatch-interface.sh-routed summarization with intensity-gate, MIT-08 density pre-check, originals persistence to .orchestrator/cache/tier3-originals/, failure-passthrough emitting tier3_failed JSONL); templates/compression-tier3-prompt.md (versioned frontmatter + preserved-pattern body); additive tier3_compression_savings_tokens / tier3_invocations fields on payload_breakdown / dispatch_usage / unit_close (CON-5); compression-eval.sh --tier 3 real cohort logic replaces the P05 stub.
- 030-context-compression-layer / M018/P05: schema extensions on dispatch_usage + unit_close (additive filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations integer fields rolled up from payload_breakdown at emit-time, CON-5); cost-rollup column extension; efficiency-footer 'compression:' tail; doctor compression-regression flag (SC-9 0.347 floor); scripts/diagnostics/compression-eval.sh sourceable+CLI cohort-segmentation diagnostic with --tier <N> filter.
- 030-context-compression-layer / M018/P04: tier2 snip live in build-context.sh (_bc_apply_tier2: section head-drop with protected_tail_ratio + boundary-refusal walker for 4+-backtick fences and frontmatter delimiters); additive tier2_savings_tokens payload_breakdown field (CON-5).
- 030-context-compression-layer / M018/P03: tier1 microcompact live in build-context.sh (_bc_apply_tier1: tool-result paging + SHA-256 cache reuse); cache-prune.sh --max-age utility; tier1_savings_tokens + tier1_invocations additive payload_breakdown fields (CON-5).
- 030-context-compression-layer / M018/P01: compression-grammar contract v1.0.1 Reviewed; conversus --strict gate PASS.
- 030-context-compression-layer / M018/P02: knowledge-aware filter live in build-context.sh; preservation-check library shipped; payload_filter + filter_dropped_tokens emitters additive (CON-5); compression_underperformance self-check operational.
# <<< orchestrator:recent-changes <<<
# CLAUDE.md — spec-kit-orchestrator

## What This Is

A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself.

## Project Status

**v0.9.2** (2026-04-28). 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 6 user guides, `packaging/` layer, runtime + format + backend adapter tree. **Closed**: M011 (spec management), M012 (spec wiki, 2026-04-21), M013 (GitHub native integration), M014 extended (spec management + comment→workflow, 2026-04-25), M015 (standalone cutover), M016 (autonomous hardening), M018 (context compression layer, 2026-04-28), M019 Tier 1+2+3 (observability emitter + cost rollup), M020 (knowledge layer maturation, 2026-04-25), M021 (autonomous hardening v2), M024 (universal intake & routing), M025 (installer coexistence, 2026-04-23), M026 (conversus-OSS migration, 2026-04-25), M027 (cost+quality observability surfaces, 2026-04-27). **Next up**: **M028 (autonomous hardening v3)** — hook portability + four new shape classes + investigation-pattern wrappers + M025 hook-shim follow-up. Brief at `.orchestrator/proposals/M028-autonomous-hardening-v3.md`.

## Forward Roadmap (revised 2026-04-28 — post-M018 close)

M018 closed 2026-04-28. Remaining pre-launch queue:

**M028 → M030 → M031 → M029 → launch**

Post-launch fast-follows (in priority order, demand-driven): **M009 (multi-runtime parity audit) → M023 (design layer) → M010 (Managed Agents + Codex Cloud)**.

Launch posture: **CC-only**. Codex CLI / Cursor / Managed Agents are aspirational fast-follows; we ship CC-exclusive and broaden the runtime story when real users arrive with non-CC projects.

Proposal briefs for M028, M029, M030, M031 are at `.orchestrator/proposals/` (each is an input for `orchestrator:specify` when that milestone enters the queue). Brief summaries:

- **M028 (autonomous hardening v3)** — hook portability across consumer projects (M021's shape guard fails-open in projects outside the orchestrator repo) + 4 new shape classes (AP-010 to AP-013) from the post-M021 screenshot corpus + investigation-pattern wrappers.
- **M030 (adaptive model selection)** — task-character classifier + model routing table; routes surgical/bounded tasks to Haiku/Sonnet, reserves Opus for novel/exploratory work. Verifier-fail auto-escalation (capped at 2 escalations). Empirical shadow-mode validation phase using M027 cost+quality data before flipping live routing.
- **M031 (right-sized entry)** — restores knowledge graph + compression access for Quick intensity (today `commands/dispatch.md:21` skips `build-context.sh` — load-bearing leak) + adds a Tier A+ middle flow (research → plan → build, no auto/roadmap/consolidate) + a universal `orchestrator <task>` entry that lowers adoption friction for small tasks. Composes with M030 as the thrift-and-ergonomics pair.
- **M029 (roadmap visibility & CLI UX)** — `orchestrator:where` tree renderer + invocation-context resolver + headline status (embeds existing M027 efficiency-footer / metrics-rollup / predictive-surface). M013 GitHub sidecar fold-in (no API calls).

Post-launch fast-follows:

- **M009 (multi-runtime parity audit, deferred post-launch)** — runtime-parity audit consuming `references/RUNTIME-ASSUMPTIONS.md` (foundation seeded by M018/P07's compression-tier parity work). Ships when first users arrive with Codex CLI or Cursor projects. Pre-launch dogfooding stays CC-only.
- **M023 (design layer, deferred post-launch)** — `orchestrator:design` spawns N design-personality agents in parallel via conversus, each producing a DESIGN.md draft + working coded prototype; user picks side-by-side; renderer adapter shaped as MCP clients (runtime-agnostic). Originally slotted pre-launch because this repo has no internal UI to dogfood against; revised 2026-04-28 — better as a fast-follow once real users arrive with real UI projects, since pre-launch dogfooding would only exercise synthetic fixtures.
- **M010 (Managed Agents + Codex Cloud, deferred post-launch)** — adds Anthropic Managed Agents as a hosted dispatch backend + Codex Cloud stub (proves abstraction). Net-new capability, not launch readiness; revised 2026-04-28 — explicitly aspirational, demand-driven.

Sequencing rationale: M028 stabilizes autonomous runs (load-bearing for everything after); M030 makes runs cheap; M031 restores the knowledge-graph promise + lowers small-task adoption friction; M029 is launch polish. Four pre-launch milestones, all directly improving the launch experience for early users. Runtime expansion (M009/M010) and design-layer work (M023) defer until post-launch when real-user signal informs which to prioritize.

**Standalone constitution amendment** (any time, single PR, no dependencies): inclusion-criteria gate for new principles + `CONSTITUTION-LOG.md` governance log + Principle XVI (Distribution Surface Integrity) + Principle I clarification (minimize *total task tokens via efficient context delivery*, not payload bytes). Brief at `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`.

Conversus integration stays as the M011/P07 reusable adapter — invoked from M030/M031 at opt-in gate points. See `.orchestrator/proposals/README.md` for full sequencing rationale, `.orchestrator/DECISIONS.md` D004–D016 for the historical D016 ordering, and `.orchestrator/milestone-summary.md` for milestone history.

## Standalone Mode

The orchestrator operates standalone on **Claude Code** at launch, with **Codex CLI / Cursor as aspirational fast-follows** (M009 multi-runtime parity audit ships demand-driven post-launch when non-CC users arrive). M018/P07 has already proven runtime parity for the compression-tier zero-LLM path (CC / Codex CLI / Cursor byte-equality + T3 routing parity, see `references/RUNTIME-ASSUMPTIONS.md`); broader parity audit is M009's job. Auto-calibrated process intensity (Quick / Standard / Full) applies regardless of runtime. Key entry points:

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


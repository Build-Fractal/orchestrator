# >>> orchestrator:recent-changes >>>
M030 P05 close: M027 surface integration — metrics-rollup.sh --by-model flag (FR-15/SC-8 — per-tier dispatch counts + aggregated cost + all-smart counterfactual when cost_rates: present; cost rates not configured warning + zero-savings when absent) + efficiency-footer.sh model_mix: line (FR-16 — fast=N balanced=M smart=K, suppressed when corpus has zero shadow-on records) + doctor --config-check inheritor wrapper (FR-17/SC-9 — P01/T04 surface re-confirmed) + references/model-routing.md ## Cost Rollup Surfaces section; CON-2/FR-19/SC-11 byte-equality preserved (golden-baseline diff against pre-M030 fixture); phase-suite green pass=7 fail=0
M030 P04 close: dispatch-interface live-routing branch (FR-9 programmatic flip-gate via shadow-compare invocation per D-A2; per-class partial-flip authorization per D-A3; --model passing through to backend) + verifier-fail escalation loop (FR-10 fast→balanced→smart with CON-5 hard-cap=2 / 3 records max + escalation_cap_hit on cap) + 2 new JSONL fields (escalation_count, escalation_reason) + 1 new record_type (escalation_cap_hit) + sixth override_source value (shadow_gate_blocked) wired through; CON-4/D-A5 kill-switch supersedes live-mode (live: true is inactive warning); CON-6 append-only preserved (inode + head-2 hash); SC-11 byte-equality preserved; phase-suite green pass=12 fail=0
M030 P03 close: dispatch-interface override-resolution path (kill-switch + plan-frontmatter + min_tier floor + plain-routed precedence chain, CON-4/D-A5 amended) + 5 new override_source values (plan_frontmatter | milestone_floor | disabled | shadow_gate_blocked | none) on shadow-on dispatch_usage records; SC-6 + SC-7 + SC-7a + FR-12 + FR-14 mechanically gated; phase-suite green pass=8 fail=0
M030 P02 close: dispatch-interface shadow hook (M030_SHADOW_MODE=1 + CLAUDECODE=1) + 5 additive JSONL fields + scripts/diagnostics/shadow-compare.sh 4-verdict (ready|partially_ready|block|evidence_insufficient) + SC-3a roundtrip green + SC-11 byte-equality preserved (CON-2/FR-19) + CON-3 closure + CON-6 append-only + stability metric 0.10/N=20/50 traced; phase-suite green pass=9 fail=0
M030 P01 close: classifier (36/40 ground-truth agreement) + routing table (cost_rates SSOT) + classifier-confidence stability metric (variance<=0.10 N=20 cov>=50) + doctor --config-check; phase-suite green pass=7 fail=0
M030 P00 close: classifier-ground-truth corpus authored at tests/fixtures/m030-classifier-corpus/ (40 hand-labeled pre-M030 task plans, 20 mechanical / 15 standard / 5 novel, D-A4 independence by construction, phase-suite green pass=5 fail=0)
- 032-adaptive-model-selection: Adaptive model selection: task-character classifier routes each dispatch to the
- M032 brief: append Findings G–J (PBJ wiki deploy 2026-04-29) — code-to-title resolver, out-of-scope content discovery, nav-preserve user entries, mkdocs gh-deploy cwd-remote hazard
- post-launch arc: stub proposal `post-launch-wiki-ux-and-adapters.md` — knowledge graph as core; wiki UX deep + external tool (Jira/Notion/Obsidian) adapters as the engagement-loop expansion
- M032 Finding H + post-launch brief extended (2026-04-30) — `.orchestrator/proposals/` becomes a first-class wiki section ("Forward Plans") with lifecycle stage badges; engagement-loop closes only when stages 1–3 (stub/brief/specified) are visible alongside 4–5 (active/closed)
# <<< orchestrator:recent-changes <<<
# CLAUDE.md — spec-kit-orchestrator

## What This Is

A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself.

## Project Status

**v0.9.2** (2026-04-28). 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 6 user guides, `packaging/` layer, runtime + format + backend adapter tree. **Closed**: M011 (spec management), M012 (spec wiki, 2026-04-21), M013 (GitHub native integration), M014 extended (spec management + comment→workflow, 2026-04-25), M015 (standalone cutover), M016 (autonomous hardening), M018 (context compression layer, 2026-04-28), M019 Tier 1+2+3 (observability emitter + cost rollup), M020 (knowledge layer maturation, 2026-04-25), M021 (autonomous hardening v2), M024 (universal intake & routing), M025 (installer coexistence, 2026-04-23), M026 (conversus-OSS migration, 2026-04-25), M027 (cost+quality observability surfaces, 2026-04-27). **Next up**: **M028 (autonomous hardening v3)** — hook portability + four new shape classes + investigation-pattern wrappers + M025 hook-shim follow-up. Brief at `.orchestrator/proposals/M028-autonomous-hardening-v3.md`.

## Forward Roadmap (revised 2026-04-28 — post-M018 close, post-M033 capture)

M018 closed 2026-04-28. Remaining pre-launch queue:

**M028 → M030 → M031 → M032 → M033 → M029 → M035 → launch**

Post-launch fast-follows (in priority order, demand-driven): **M009 (multi-runtime parity audit) → M023 (design layer) → M034 (interactive review gates) → wiki-ux-deep + external-tool-adapters (knowledge-graph viewer & multi-tool sync, see `.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`) → M010 (Managed Agents + Codex Cloud)**.

Near-term D021-style hotfixes — **all 19 items shipped or queued for deferred milestones** as of the paper-cut sweep (`papercut-sweep/pre-M030` branch, see `.orchestrator/proposals/papercut-sweep-pre-M030.md`). Two layer-2 follow-ups remain queued:

- **M032 spec-side invariant for staged-dirs collision** — Finding A invariant ("project-owned paths must not collide with staged dirs"). Text-only amendment deferred until M032 enters planning. The runtime fix (planner-template default → `tools/verify/`) shipped in commit `8bcba64` and is already live.
- **M034 boundary-translation decision packet** (Layer-2 of plan-time SQL column drift) — folds into the `boundary_translation` decision-packet type per Finding E in `.orchestrator/proposals/M034-interactive-review-gates.md`. Layer-1 (real-DB verifier or "real-app smoke test pending" callout) shipped in `commands/plan-phase.md` Plan-Time Discipline rule 5.

The historical hotfix list (with patch shapes inline) is preserved verbatim in the paper-cut sweep PR's first commit (`.orchestrator/proposals/papercut-sweep-pre-M030.md`) so future authors can audit the shipped shapes and the original dogfood-incident context.

Launch posture: **CC-only**. Codex CLI / Cursor / Managed Agents are aspirational fast-follows; we ship CC-exclusive and broaden the runtime story when real users arrive with non-CC projects.

Proposal briefs for M028, M029, M030, M031, M032, M033, M035 are at `.orchestrator/proposals/` (each is an input for `orchestrator:specify` when that milestone enters the queue). Brief summaries:

- **M028 (autonomous hardening v3)** — hook portability across consumer projects (M021's shape guard fails-open in projects outside the orchestrator repo) + 5 new shape classes (AP-010 to AP-014, last added 2026-04-28: `xargs-sh-c-compound-body` covering compound chains hidden inside `xargs … sh -c '<body>'`) + investigation-pattern wrappers (now including `peek-files.sh` for the "show first N lines of files matching pattern" investigation shape).
- **M030 (adaptive model selection)** — task-character classifier + model routing table; routes surgical/bounded tasks to Haiku/Sonnet, reserves Opus for novel/exploratory work. Verifier-fail auto-escalation (capped at 2 escalations). Empirical shadow-mode validation phase using M027 cost+quality data before flipping live routing.
- **M031 (right-sized entry)** — restores knowledge graph + compression access for Quick intensity (today `commands/dispatch.md:21` skips `build-context.sh` — load-bearing leak) + adds a Tier A+ middle flow (research → plan → build, no auto/roadmap/consolidate) + a universal `orchestrator <task>` entry that lowers adoption friction for small tasks. Composes with M030 as the thrift-and-ergonomics pair.
- **M032 (wiki distribution + init integration)** — wiki tooling + mkdocs/Giscus templating ship in the install bundle; `orchestrator:wiki-init` + `init --with-wiki [--with-giscus] [--deploy]` produces working wiki for any new project. Promoted to pre-launch because M033 P05 invokes its `--with-wiki` gate.
- **M033 (project onboarding experience)** — `orchestrator:start` warm conversational front door. Branches: greenfield-empty / greenfield-with-materials / existing-codebase / migrating. Authors orchestrator-native constitution (zero spec-kit dep), seeds knowledge graph from materials or codebase, populates CLAUDE.md custom block, integrates M032 + M013 as opt-in gates. The launch first-impression milestone.
- **M029 (roadmap visibility & CLI UX)** — `orchestrator:where` tree renderer + invocation-context resolver + headline status (embeds existing M027 efficiency-footer / metrics-rollup / predictive-surface). M013 GitHub sidecar fold-in (no API calls).
- **M035 (packaging & distribution)** — last pre-launch milestone, two-layer scope: P00 + P01 ship pre-launch (`--mode=symlink` install for dogfooding velocity + `orchestrator:status` version-drift warning) and unblock multi-consumer-project freshness today; P02–P06 ARE the launch event (npm + homebrew + curl-pipe-bash publishing pipelines, GH release automation, install-script integrity, `orchestrator:update` first-class command). Captured 2026-04-28 after the roadmap gap surfaced.

Post-launch fast-follows:

- **M009 (multi-runtime parity audit, deferred post-launch)** — runtime-parity audit consuming `references/RUNTIME-ASSUMPTIONS.md` (foundation seeded by M018/P07's compression-tier parity work). Ships when first users arrive with Codex CLI or Cursor projects. Pre-launch dogfooding stays CC-only.
- **M023 (design layer, deferred post-launch)** — `orchestrator:design` spawns N design-personality agents in parallel via conversus, each producing a DESIGN.md draft + working coded prototype; user picks side-by-side; renderer adapter shaped as MCP clients (runtime-agnostic). Originally slotted pre-launch because this repo has no internal UI to dogfood against; revised 2026-04-28 — better as a fast-follow once real users arrive with real UI projects, since pre-launch dogfooding would only exercise synthetic fixtures.
- **M034 (interactive review gates, deferred post-launch)** — first-class interactive-review stage between artifact authoring and SIGNOFF.md population. Decision-packet schema (P01) + interactive walkthrough consuming it (P02). Inherits `commands/comments.md` review-queue convention + CON-5/SC-5 invariant. `auto`-mode parity via `defer` / `accept-with-audit` / `block` policies declared in plan frontmatter. Demand-signal-driven — ships when a second downstream consumer hits the friction lakeledger M066/P01 surfaced 2026-04-28. Brief at `.orchestrator/proposals/M034-interactive-review-gates.md`.
- **M010 (Managed Agents + Codex Cloud, deferred post-launch)** — adds Anthropic Managed Agents as a hosted dispatch backend + Codex Cloud stub (proves abstraction). Net-new capability, not launch readiness; revised 2026-04-28 — explicitly aspirational, demand-driven.

Sequencing rationale: M028 stabilizes autonomous runs (load-bearing for everything after); M030 makes runs cheap; M031 restores the knowledge-graph promise + lowers small-task adoption friction; M032 ships project-asset distribution that M033 consumes; M033 makes first-time bootstrap warm (the launch first-impression); M029 is launch polish; M035 is launch readiness (P00+P01 pre-launch dev-ergonomics, P02–P06 *constitute* the launch event — package-manager publishing). Seven pre-launch milestones, all directly improving the launch experience for early users. M031 + M033 bracket the user journey — M033 lands the user, M031 keeps them productive on small tasks; M035 is what makes them able to *get* the orchestrator in the first place. Runtime expansion (M009/M010) and design-layer work (M023) defer until post-launch when real-user signal informs which to prioritize.

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

## Commit Message Authoring

For multi-line commit messages, **prefer `git commit -F <message-file>`** with a message file authored via the Write tool. Do **not** use the inline-HEREDOC form `git commit -m "$(cat <<'EOF' ... EOF)"`: the active M021 PreToolUse Bash shape-guard rejects it under AP-008 (`heredoc-with-expansion`) because the inline `$(...)` containing a heredoc is itself a compound substitution. The system-prompt-staged commit guidance recommends the inline-HEREDOC form, but it does not pass through the shape-guard; `-F` is the form that survives every dispatch path. Single-line messages can use `-m "..."` directly.

## Active Technologies
- Markdown (command format) + Bash 3.2+ / POSIX sh (helper scripts), git (version control, worktree isolation), jq (optional, JSON parsing in scripts) (001-speckit-orchestrator)
- File-based state machine — YAML frontmatter + markdown body files, JSONL append-only logs, JSON lock files. All state at `.orchestrator/` (001-speckit-orchestrator)


# >>> orchestrator:recent-changes >>>
- 036-project-onboarding-experience: M033 Project Onboarding Experience: orchestrator:start warm conversational front
# <<< orchestrator:recent-changes <<<
# CLAUDE.md — spec-kit-orchestrator

## What This Is

A standalone autonomous multi-phase orchestrator. This repo holds the orchestrator itself — its commands, scripts, templates, reference docs, and packaging installers. It uses its own orchestration workflow (`orchestrator:*` commands) to develop itself.

## Project Status

**v0.9.3** (2026-05-01). 13 commands, 80+ scripts, 24+ templates, 15 reference docs, 6 user guides, `packaging/` layer, runtime + format + backend adapter tree. **Closed**: M011 (spec management), M012 (spec wiki, 2026-04-21), M013 (GitHub native integration), M014 extended (spec management + comment→workflow, 2026-04-25), M015 (standalone cutover), M016 (autonomous hardening), M018 (context compression layer, 2026-04-28), M019 Tier 1+2+3 (observability emitter + cost rollup), M020 (knowledge layer maturation, 2026-04-25), M021 (autonomous hardening v2), M024 (universal intake & routing), M025 (installer coexistence, 2026-04-23), M026 (conversus-OSS migration, 2026-04-25), M027 (cost+quality observability surfaces, 2026-04-27), M028 (autonomous hardening v3, 2026-04-29), M030 (adaptive model selection, 2026-05-01), **M031 (right-sized entry, 2026-05-01)**, **M036a (reference-corpus pre-launch slice, P00–P07, 2026-05-02)**. **Next up**: **M032 + M033 paired** (wiki distribution + init integration; project onboarding experience) — M033/P05 invokes M032's `--with-wiki` gate, so they ship as a paired unit per the 2026-05-03 launch sequencing amendment. Briefs at `.orchestrator/proposals/M032-wiki-distribution-and-init-integration.md` and `.orchestrator/proposals/M033-onboarding-experience.md`.

## Forward Roadmap (revised 2026-05-03 — post-M036a close)

M028 closed 2026-04-29. M030 (adaptive model selection) closed 2026-05-01: 8 phases (P00–P07), 14 success criteria verified via the M030 acceptance battery (`tests/m030-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=22 fail=0`); `M030-VALIDATED` marker + `M030-SUMMARY.md` + milestone-grain `unit_close` all on disk; `validate-milestone.sh` reports 197/197 PASS. **M036a (P00–P07) closed 2026-05-02** — full reference-corpus pipeline (Tier 0/1/2 extraction + ingest + graph + dispatch injection + supersede chain) live; cross-phase regression spread covers P02 selective + P03/P04/P05/P06/P07 full pass-through. Remaining pre-launch queue, **risk-ranked per the 2026-05-03 launch sequencing amendment** (`.orchestrator/proposals/launch-sequencing-amendment-2026-05-03.md`):

**(M032 + M033 paired) → M029 → M035 P02–P06**

(Was: `M031 → M032 → M033 → M029 → M035`. M031 closed 2026-05-01. Pairing M032+M033 + adding a friendly-tester pass on M033 before lock is the load-bearing change; risk concentrates in M035-publishing blast radius and M033 cold-start UX, not in dependency order.)

**Parallel pre-launch workstream**: **M036a P03 live-LLM smoke test** before 2026-05-08 — single real LLM extraction end-to-end (not stub) against a representative PBJ fixture. Cheap insurance against arriving at the 2026-05-15 pilot with a path that's only ever been exercised mocked. M036a itself is closed.

Post-launch fast-follows (in priority order, demand-driven): **M009 (multi-runtime parity audit) → M023 (design layer) → M034 (interactive review gates) → M036b (reference-corpus post-launch slice — wiki projection + operator-facing scale UX, P08–P09) → wiki-ux-deep + external-tool-adapters (knowledge-graph viewer & multi-tool sync, see `.orchestrator/proposals/post-launch-wiki-ux-and-adapters.md`) → M010 (Managed Agents + Codex Cloud)**.

Near-term D021-style hotfixes — **all 19 items shipped or queued for deferred milestones** as of the paper-cut sweep (`papercut-sweep/pre-M030` branch, see `.orchestrator/proposals/papercut-sweep-pre-M030.md`). Two layer-2 follow-ups remain queued:

- **M032 spec-side invariant for staged-dirs collision** — Finding A invariant ("project-owned paths must not collide with staged dirs"). Text-only amendment deferred until M032 enters planning. The runtime fix (planner-template default → `tools/verify/`) shipped in commit `8bcba64` and is already live.
- **M034 boundary-translation decision packet** (Layer-2 of plan-time SQL column drift) — folds into the `boundary_translation` decision-packet type per Finding E in `.orchestrator/proposals/M034-interactive-review-gates.md`. Layer-1 (real-DB verifier or "real-app smoke test pending" callout) shipped in `commands/plan-phase.md` Plan-Time Discipline rule 5.

The historical hotfix list (with patch shapes inline) is preserved verbatim in the paper-cut sweep PR's first commit (`.orchestrator/proposals/papercut-sweep-pre-M030.md`) so future authors can audit the shipped shapes and the original dogfood-incident context.

Launch posture: **CC-only**. Codex CLI / Cursor / Managed Agents are aspirational fast-follows; we ship CC-exclusive and broaden the runtime story when real users arrive with non-CC projects.

Proposal briefs for M029, M032, M033, M035 are at `.orchestrator/proposals/` (each is an input for `orchestrator:specify` when that milestone enters the queue). Brief summaries:

- ~~**M031 (right-sized entry)**~~ — closed 2026-05-01. 5 phases (P00–P04), 14 success criteria verified via the M031 acceptance battery (`tests/m031-acceptance/run-acceptance-battery.sh` → `BATTERY: pass=15 fail=0`); `M031-VALIDATED` marker + `M031-SUMMARY.md` + milestone-grain `unit_close` all on disk; `validate-milestone.sh` reports 117/117 PASS. Shipped surfaces: `build-context.sh --profile=quick|standard|full` + `--meta-out` JSON sidecar; FR-4 collapse of `commands/dispatch.md:21` Skip-payload-assembly branch; Tier A+ middle flow under `.orchestrator/tier-a-plus/<slug>/`; `commands/do.md` universal-entry skill + `scripts/intake/do-entry.sh` driver; `auto_proceed: true` default flip + AD-9 compound-change banner via `run-doctor.sh`; `QUICK_BUDGET_DRIFT` informational warning in `efficiency-footer.sh`. See `.orchestrator/milestones/M031/M031-SUMMARY.md`.
- ~~**M028 (autonomous hardening v3)**~~ — closed 2026-04-29. Hook portability + 5 shape classes (AP-010..AP-014) + investigation-pattern wrappers + M025 hook-shim follow-up shipped. See `milestones/M028/M028-SUMMARY.md`.
- ~~**M030 (adaptive model selection)**~~ — closed 2026-05-01. 8 phases (P00–P07), 14 SCs verified via M030 acceptance battery (`BATTERY: pass=22 fail=0`); shadow-mode default, FR-9 programmatic flip-gate enforces shadow-corpus threshold before live routing; CON-3 symbolic-tier closure preserved end-to-end. See `.orchestrator/milestones/M030/M030-SUMMARY.md`.
- **M032 (wiki distribution + init integration)** — wiki tooling + mkdocs/Giscus templating ship in the install bundle; `orchestrator:wiki-init` + `init --with-wiki [--with-giscus] [--deploy]` produces working wiki for any new project. Promoted to pre-launch because M033 P05 invokes its `--with-wiki` gate.
- **M033 (project onboarding experience)** — `orchestrator:start` warm conversational front door. Branches: greenfield-empty / greenfield-with-materials / existing-codebase / migrating. Authors orchestrator-native constitution (zero spec-kit dep), seeds knowledge graph from materials or codebase, populates CLAUDE.md custom block, integrates M032 + M013 as opt-in gates. The launch first-impression milestone.
- **M029 (roadmap visibility & CLI UX)** — `orchestrator:where` tree renderer + invocation-context resolver + headline status (embeds existing M027 efficiency-footer / metrics-rollup / predictive-surface). M013 GitHub sidecar fold-in (no API calls).
- **M035 (packaging & distribution)** — last pre-launch milestone, two-layer scope: P00 + P01 ship pre-launch (`--mode=symlink` install for dogfooding velocity + `orchestrator:status` version-drift warning) and unblock multi-consumer-project freshness today; P02–P06 ARE the launch event (npm + homebrew + curl-pipe-bash publishing pipelines, GH release automation, install-script integrity, `orchestrator:update` first-class command). Captured 2026-04-28 after the roadmap gap surfaced.

Post-launch fast-follows:

- **M009 (multi-runtime parity audit, deferred post-launch)** — runtime-parity audit consuming `references/RUNTIME-ASSUMPTIONS.md` (foundation seeded by M018/P07's compression-tier parity work). Ships when first users arrive with Codex CLI or Cursor projects. Pre-launch dogfooding stays CC-only.
- **M023 (design layer, deferred post-launch)** — `orchestrator:design` spawns N design-personality agents in parallel via conversus, each producing a DESIGN.md draft + working coded prototype; user picks side-by-side; renderer adapter shaped as MCP clients (runtime-agnostic). Originally slotted pre-launch because this repo has no internal UI to dogfood against; revised 2026-04-28 — better as a fast-follow once real users arrive with real UI projects, since pre-launch dogfooding would only exercise synthetic fixtures.
- **M034 (interactive review gates, deferred post-launch)** — first-class interactive-review stage between artifact authoring and SIGNOFF.md population. Decision-packet schema (P01) + interactive walkthrough consuming it (P02). Inherits `commands/comments.md` review-queue convention + CON-5/SC-5 invariant. `auto`-mode parity via `defer` / `accept-with-audit` / `block` policies declared in plan frontmatter. Demand-signal-driven — ships when a second downstream consumer hits the friction lakeledger M066/P01 surfaced 2026-04-28. Brief at `.orchestrator/proposals/M034-interactive-review-gates.md`.
- **M036 (reference-corpus ingest, split 2026-05-01 into M036a pre-launch + M036b post-launch)** — extends the knowledge layer with a `reference/` chunk family for non-spec materials (regulatory, training, glossary), three new edge types (`cites` / `derived_from` / `applies_to_field`), `[source:...]` tag namespace, dispatch injection under a token-budget governor, and **orchestrator-owned tiered extraction** (Tier 0 manifest + binary preservation, Tier 1 deterministic shell adapters for PDF/DOCX/XLSX/MD, Tier 2 LLM-driven structured Markdown via M030 routing under conversus fidelity gate). Spec authored 2026-04-30, **amended 2026-05-01** when PBJ Analyzer clarified it has no path-B extractor — extraction-ownership flip required (NG-3/4/5 inverted/narrowed); tier model added as core architecture; DOCX added; #Q-3 (versioning → supersede chain) and #Q-5 (fidelity gate → tiered) resolved at amendment. Roadmap restructured 2026-05-01 from 7 phases → 10 phases under M036a/M036b split.
  - ~~**M036a (pre-launch urgent, P00–P07, 8 phases)**~~ — closed 2026-05-02. Full pipeline live: Tier 0 manifest + binary preservation, Tier 1 PDF/DOCX/XLSX/MD adapters, Tier 2 LLM extraction via M030 routing under conversus fidelity gate, ingest+classifier, graph schema extension (`cites`/`derived_from`/`applies_to_field` + `[source:*]` tag namespace), dispatch injection with token-budget governor (SC-3/SC-7), idempotent re-extract+re-ingest with supersede chain mechanism (SC-5/SC-6/SC-13). Cross-phase regression spread P02 selective + P03/P04/P05/P06/P07 full pass-through. **One follow-up before pilot**: live-LLM smoke test against a real PBJ fixture (P03 has only been exercised against stubs).
  - **M036b (post-launch fast-follow, P08–P09)** — wiki projection (P08, blocked by M032 closure) + operator-facing scale UX (P09: REVIEW queue, change-over-time queries, supersede chain at scale). Demand-driven; ships when validator-pilot feedback surfaces concrete operator pain.
  - Brief at `.orchestrator/proposals/M036-reference-corpus-ingest.md`; roadmap at `.orchestrator/milestones/M036/M036-ROADMAP.md`; spec at `specs/033-reference-corpus-ingest/spec.md`. **NO hard dependency on M013/M014** — those gates fire on spec-shape, not reference content. **Hard dependencies for M036a P03**: M030 (closed 2026-05-01) for Tier 2 model routing; conversus adapter (M011/P07, shipped) for Tier 2 fidelity gate.
- **M010 (Managed Agents + Codex Cloud, deferred post-launch)** — adds Anthropic Managed Agents as a hosted dispatch backend + Codex Cloud stub (proves abstraction). Net-new capability, not launch readiness; revised 2026-04-28 — explicitly aspirational, demand-driven.

Sequencing rationale (amended 2026-05-03 — see `.orchestrator/proposals/launch-sequencing-amendment-2026-05-03.md` for the full risk-ranking): M028 stabilizes autonomous runs (load-bearing for everything after); M030 makes runs cheap; M031 restores the knowledge-graph promise + lowers small-task adoption friction; **M032 + M033 ship as a paired unit** (M033/P05 calls into M032's `--with-wiki` gate, so build them with the integration live the whole time rather than sequentially); M033 includes a **friendly-tester pass on the four init branches before lock** (cold-start UX only resolves with warm bodies); M029 is launch polish; M035 is launch readiness (P00+P01 pre-launch dev-ergonomics, P02–P06 *constitute* the launch event — package-manager publishing in lockstep). Risk concentrates in M035-publishing blast radius and M033 cold-start UX, not in dependency order. **M036a (closed 2026-05-02)** is no longer a parallel workstream — only the pre-pilot live-LLM smoke test remains. Runtime expansion (M009/M010), design-layer work (M023), and M036b (post-launch wiki + scale UX) defer until post-launch when real-user signal informs prioritization.

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


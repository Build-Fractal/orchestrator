# Changelog

All notable changes to spec-kit-orchestrator are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses semantic versioning.

## [Unreleased]

### Changed

- Task plan filename convention canonicalized to `T##-<slug>-PLAN.md` in `commands/plan-phase.md`. The no-slug form `T##-PLAN.md` remains accepted by every discovery glob and downstream tooling — historical milestones are unchanged. Planners producing new task plans should use the slug form for readability and sibling-symmetry with `T##-<slug>-PAYLOAD.md` / `T##-<slug>-SUMMARY.md`. (Bug H)
- `commands/auto.md` Stage 2 dispatch and Planning Dispatch sections now recommend `subagent_type='orchestrator-agent'` (registered into `~/.claude/agents/` by the installer). Adds explicit guard against picking framework-named agents (`gsd-*`) from Claude Code's discovery list — their system prompts impose conventions incompatible with orchestrator output shape. `general-purpose` remains the documented fallback. (FU-7)

### Added

- `packaging/agents/orchestrator-agent.md` — guardrail-style agent system prompt that treats the dispatch payload as authoritative and explicitly forbids imposing framework conventions or rewriting output shape. Registered by the Claude Code adapter `--register` mode into `~/.claude/agents/` alongside the existing slash-command registration. (FU-7)
- `commands/` is now staged into project root by `packaging/install/install-{claude-code,codex,cursor}.sh` so dispatched agents can resolve rubric references like `commands/plan-phase.md`. Manifest-backed `--uninstall` automatically tracks the new files. (FU-8)

### Fixed

- `scripts/integrations/github-init.sh` now canonicalizes task IDs from slugged filenames (e.g. `T01-conversus-resolver-PLAN.md` → orchestrator ID `T01`), so slug-form task plans are projected to GitHub Issues instead of being silently skipped. (Bug H)
- `scripts/lifecycle/phase-transition.sh` deduplicates concatenated task-summary fields (`provides`, `key_files`, `key_decisions`, `patterns_established`) and overrides `requires`/`affects` with roadmap-derived phase graph position instead of leaking internal task IDs into phase frontmatter. Adds a new `affects <P##>` query to `scripts/state/read-roadmap.sh` (reverse-Depends). (Bug F)
- `scripts/lifecycle/check-settings-state.sh` now captures regen/write/merge failure detail to `.orchestrator/diagnostics/settings-regen-<ISO8601>.log` and emits a stderr breadcrumb. Previously the captured stderr was silently dropped behind a `keeping existing` fallback. Exit code unchanged (still 0) — escalation to non-zero in unattended mode deferred pending evidence. (FU-9)

## [0.9.2] — 2026-04-28

v0.9.2 closes **M018 (030-context-compression-layer)** — caveman-style token compression as a four-tier pipeline stage in `scripts/dispatch/build-context.sh`. Eight phases (P00 through P07) all green; `validate-milestone.sh` PASS 75/75. Backfills **M027 (cost+quality observability surfaces, closed 2026-04-27)** which was missing from the changelog. See `.orchestrator/milestones/M018/M018-SUMMARY.md` and `.orchestrator/milestones/M027/M027-SUMMARY.md` for the authoritative scope.

### Added

- **M018 — Context Compression Layer** (eight phases):
  - **P00** — emitter parity probe + section-distribution probe + SC-9 regression-floor calibration to **34.7%** (P00-baseline savings ratio that downstream phases must not regress below).
  - **P01** — `references/compression-grammar.md` v1.0.1 (Reviewed) — in-band marker contract (`<!-- compressed:tierN model=... input_tokens=N output_tokens=M -->`), four-tier definitions (filter / T1 / T2 / T3), preservation contract (FR-2), failure-passthrough discipline (FR-9). Conversus `--strict` gate PASS.
  - **P02** — knowledge-aware status filter live in `build-context.sh`. `scripts/lib/preservation-check.sh` reusable library (used by P03/P04/P06). Additive `payload_filter` and `filter_dropped_tokens` JSONL fields (CON-5). `compression_underperformance` self-check emitter when running mean savings drops below SC-9 floor.
  - **P03** — Tier 1 microcompact (tool-result paging with SHA-256-keyed disposable cache at `.orchestrator/cache/tool-results/`). `scripts/util/cache-prune.sh --max-age <days>` operator utility. Additive `tier1_savings_tokens` + `tier1_invocations` payload_breakdown fields.
  - **P04** — Tier 2 snip (section head-drop with `protected_tail_ratio`) + boundary-refusal walker handling 4+-backtick fences and YAML frontmatter delimiters (MIT-01). Additive `tier2_savings_tokens` payload_breakdown field.
  - **P05** — operator surfaces + eval harness. `scripts/diagnostics/compression-eval.sh` cohort-segmentation diagnostic (`--tier <N>` filter, FR-12 always-exit-0). Schema extensions on `dispatch_usage` + `unit_close` JSONL records (additive `filter_dropped_tokens` / `tier1_savings_tokens` / `tier2_savings_tokens` / `tier1_invocations` rolled up from payload_breakdown at emit-time, CON-5). M027 cost-rollup column extension (cols 13–16). M027 efficiency-footer 'compression: <pct>% reduction' tail. `doctor compression-regression` flag firing below the SC-9 0.347 floor. Two operator-facing config knobs (`compression.efficiency_footer.enabled`, `compression.regression_floor`).
  - **P06** — Tier 3 auto-compact (LLM-routed section summarization). `_bc_apply_tier3` in `build-context.sh` (intensity-gate + MIT-08 density pre-check + dispatch-interface.sh routing + originals persistence to `.orchestrator/cache/tier3-originals/` + FR-9 failure-passthrough emitting `tier3_failed` JSONL). `scripts/dispatch/lib/tier3-llm-call.sh` runtime-portability shim honoring `ORCH_TIER3_LLM_BIN` operator-binary path with `--prompt-file` / `--output` / `--max-tokens` / `--timeout` flags. `templates/compression-tier3-prompt.md` versioned summarization prompt. Additive `tier3_compression_savings_tokens` + `tier3_invocations` payload_breakdown / dispatch_usage / unit_close fields. `compression-eval.sh --tier 3` first-class real-cohort logic (replaces the P05 stub).
  - **P07** — multi-runtime parity audit. `tests/compression-runtime-parity/` fixture corpus (filter / T1 / T2 / T3 fixtures). `scripts/diagnostics/m018-runtime-parity.sh` zero-LLM byte-equality runner (proves filter+T1+T2 produce SHA-256-identical post-pipeline payloads across `ORCH_BACKEND` ∈ {claude-code, codex, cursor} for all fixtures). `scripts/diagnostics/m018-runtime-parity-tier3.sh` Tier 3 routing-parity runner with `tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh` deterministic stub. `references/RUNTIME-ASSUMPTIONS.md` `# Compression (M018)` block (RA-M018-01 zero-LLM byte-equality confirmed; RA-M018-02 T3 byte-equality exempt by design + routing-parity asserted instead). Three canonical truth verifiers (`scripts/verify/m018-p07-zero-llm-parity.sh`, `m018-p07-tier3-routing.sh`, `m018-p07-runtime-assumptions-and-dual-write.sh` — 41 assertions PASS combined).
- **M027 — Cost+Quality Observability Surfaces** (four phases, closed 2026-04-27 — backfilled):
  - **P00** — rollup engine + fixture suite under `tests/fixtures/m027-rollup/`.
  - **P01** — `orchestrator:cost` retrospective + predictive command. Cost data drilldown across milestone / phase / task granularity with cohort segmentation.
  - **P02** — efficiency footer (`scripts/diagnostics/efficiency-footer.sh`) + dispatch-time predictive surface (`scripts/dispatch/predictive-surface.sh`).
  - **P03** — anomaly detection (`scripts/diagnostics/check-anomalies.sh`) + `orchestrator:doctor --config-check` runtime-cost feedback loop.

### Changed

- `scripts/dispatch/build-context.sh` extended through P02–P06: knowledge-aware filter (P02), Tier 1 paging (P03), Tier 2 snip (P04), Tier 3 auto-compact helper (P06), and additive emitter rollups for filter / T1 / T2 / T3 savings fields. Compression is opt-out — `compression.enabled: false` produces byte-identical pre-M018 payload (P02 golden regression upheld through P07).
- `scripts/dispatch/dispatch-interface.sh` + `scripts/knowledge/write-summary.sh` extended with rollup foundation (P05/T01 four savings fields) and tier3 carry-forward (P06/T02 two tier3 fields). `dispatch_usage` and `unit_close` JSONL records now carry six additive integer fields each (CON-5; missing fields → `null` for pre-M018 jq filters).
- `scripts/diagnostics/check-anomalies.sh` / `efficiency-footer.sh` / `metrics-rollup.sh` extended with M027 surfaces foundation (P05/T02) and M018 tier3 carry-forward (P06/T02). `metrics-rollup.sh` cost-rollup columns now run to 18 (cols 17–18 = `tier3_savings_tokens` / `tier3_invocations`).
- `templates/orchestrator-config-default.yml` gains the `compression.tier3` config block (master `enabled: true` but operator-binary-required to engage — set `ORCH_TIER3_LLM_BIN` to opt in) plus the P05/T02 efficiency-footer + regression-floor surface knobs.

### Knowledge

- 5 milestone-scoped entries appended to `.orchestrator/KNOWLEDGE.md` (`milestone:M018` scope): additive emitter schema + pinned column-index contract; preservation-contract self-check + stats-file-first failure-passthrough; `phase-transition.sh --write` as the canonical phase-close path; hermetic runtime-parity-via-operator-binary-stub pattern (stub-fires-before-exit-1 invariant + knowledge-snapshot/restore); `RUNTIME-ASSUMPTIONS.md` registry pattern + documented-divergence carve-out for M009 launch-gate audit.

### Documentation

- `references/RUNTIME-ASSUMPTIONS.md` — new file (M018/P07). `# Compression (M018)` block; M009 launch-gate audit consumes this as a punch-list rather than re-deriving runtime divergences from scratch.
- `references/compression-grammar.md` v1.0.1 (Reviewed) — locked-in marker grammar + tier definitions + preservation contract + failure-passthrough discipline. Conversus `--strict` gate PASS.
- `templates/compression-tier3-prompt.md` — versioned summarization prompt for Tier 3 (frontmatter `prompt_version`).
- `.orchestrator/milestones/M018/M018-SUMMARY.md` synthesized via `scripts/knowledge/write-summary.sh milestone` — 16-field frontmatter + body covering all 8 phases.
- `.orchestrator/milestones/M025/` — runtime adapter at `scripts/dispatch/adapters/runtime/claude-code.sh:170-189` known-issue: emits `orchestrator-post-verify` / `orchestrator-before-commit` as bare command names not on PATH. `scripts/util/settings-merge.sh` accumulates dupes on repeated install (no install-side dedup keyed on `_orchestrator_managed`). Surfaced during M018 close. Folded into M028 P02 as Finding F (`.orchestrator/proposals/M028-autonomous-hardening-v3.md`); operator-side cleanup applied 2026-04-28 (manual `~/.claude/settings.json` edit; backup at `~/.claude/settings.json.bak-m018-cleanup-2026-04-28`).

## [0.9.1] — 2026-04-23

v0.9.1 closes M025 (021-github-installer-coexistence) — remediation of the M013/P04/T04 hook-config regression whose installer overwrote any pre-existing `~/.claude/settings.json` with a schema-invalid wrapper document. See `specs/021-github-installer-coexistence/spec.md` for the authoritative scope.

### Fixed

- M013/P04/T04 hook-config regression: `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` no longer emits wrapper metadata (`runtime`, `hook_count`, `target_file`) with orchestrator-internal event names, and `packaging/install/install-claude-code.sh` no longer overwrites an existing `~/.claude/settings.json` unconditionally.

### Added

- `--uninstall` flag on `packaging/install/install-claude-code.sh` — strips only orchestrator-tagged entries from `~/.claude/settings.json`, preserves every other key byte-identically, reports `UNINSTALLED: hooks-removed=<N> config-removed=<0|1>`.
- `scripts/util/settings-merge.sh` — jq-optional / python3-fallback helper that merges orchestrator hook entries into existing settings.json files via temp-file-then-rename; exposes `merge` and `uninstall` subcommands.
- Coexistence + reversibility + idempotency test fixtures under `tests/fixtures/m025-p01/` and matching gates at `scripts/verify/m025-p01-*.sh` (hook-schema, merge-preservation, coexistence, uninstall-reversibility, idempotency, runtime-scope-guard, bash32-compat, docs, knowledge-entries, recent-changes, phase-suite).
- Knowledge entries MEM026 (lesson: M013/P04/T04 hook-config regression) and MEM027 (pattern: merge-not-overwrite user-scope config).
- **M026 (conversus-OSS migration)**: orchestrator's default Conversus integration flipped from paid (`~/Sites/conversus`) to OSS (`~/Sites/conversus-oss`). New `CONVERSUS_EDITION=oss|paid` env var declares the active edition (operator escape hatch). Adapter `check` subcommand emits `edition=<oss|paid|unknown>` on stdout. Every `conversus_gate_invocation` JSONL record now carries an `edition` field. Presets may declare `edition_required: paid` in their YAML frontmatter; invoking such a preset against an OSS-resolved binary produces an actionable refusal diagnostic. Six doc surfaces updated (commands/conversus-gate.md, commands/ingest.md, commands/specify.md, docs/ingesting-arbitrary-specs.md, references/github-integration.md, references/spec-management.md). New knowledge entries: MEM029 (edition-resolution pattern), MEM030 (paid-escape-hatch env-var convention). DECISIONS.md D022 records the consolidation. See `.orchestrator/milestones/M026/`.

### Changed

- `scripts/dispatch/adapters/runtime/claude-code.sh --hook-config` now emits a valid Claude Code `hooks` schema (`{"hooks": {"Stop": […], "PreToolUse": […]}}`) with each leaf hook object tagged `"_orchestrator_managed": true`. Deferred events (`before_tasks`, `after_tasks`, `before_implement`, `after_implement`) are documented as `TODO(M025+)` in the adapter source and in `references/hooks.md`.
- `packaging/install/install-claude-code.sh` merges the orchestrator hook fragment into any existing `~/.claude/settings.json` via `scripts/util/settings-merge.sh merge` instead of overwriting — idempotent on repeat install, reversible via `--uninstall`.

## [0.9.0] — 2026-04-15

M015 (015-standalone-cutover). Standalone cutover — removes the spec-kit extension host, migrates orchestrator state from `.specify/orchestrator/` to `.orchestrator/`, moves the constitution to `.orchestrator/memory/constitution.md`, reduces the state-root resolver from 5 rules to 4 (bridge removed), and reframes all current-state documentation for the standalone narrative. The orchestrator now runs with zero runtime dependency on spec-kit. Spec-kit migration adapters are preserved — they help users coming FROM spec-kit, not TO it.

### Removed

- `extension.yml` manifest (project root)
- Dogfooded spec-kit slash commands at `.claude/commands/speckit.*.md`
- `.specify/scripts/bash/` spec-kit helper scripts
- `.specify/templates/{plan,spec,tasks,checklist,constitution,agent-file}-template.md` spec-kit-style templates
- `.specify/orchestrator/` bridge rule from `scripts/state/resolve-root.sh`
- `.specify/memory/` directory (after constitution move)

### Changed

- Orchestrator state canonical location: `.specify/orchestrator/` → `.orchestrator/`
- Constitution canonical location: `.specify/memory/constitution.md` → `.orchestrator/memory/constitution.md`
- `scripts/state/resolve-root.sh` reduced from 5-rule to 4-rule resolver
- Documentation reframed across README.md, CLAUDE.md, references/architecture.md, references/installation.md, docs/getting-started.md, and wider reference + user-guide set
- CHANGELOG.md historical entries preserved byte-identical; immutability verified via snapshot diff

### Added

- `docs/migrating-from-speckit.md` — migration guide for users coming from spec-kit (FR-012)
- Six P03 verify scripts under `scripts/verify/m015-p03-*.sh`

### Preserved (migration-source contract)

- `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md` — spec-kit migration path remains functional end-to-end

Originally built as an extension to spec-kit; standalone as of this release.

## [0.8.0] — 2026-04-14

M008 (008-standalone-orchestrator). Standalone multi-runtime orchestrator with adaptive intensity. 7 phases, 35 tasks. Transforms the orchestrator from a spec-kit extension into a standalone distributable with auto-calibrated process intensity and cross-runtime support.

### Added

- **Adaptive Intensity Engine (P01)**:
  - `scripts/engine/intensity-analyze.sh` — scope/risk/complexity analyzer from natural-language task descriptions
  - `scripts/engine/intensity-recommend.sh` — recommendation engine combining analysis + capability profile → Quick/Standard/Full
  - `scripts/engine/context-pressure.sh` — token pressure evaluator with intensity-aware thresholds
  - `templates/intensity-metadata.md` — 10-field YAML schema flowing through pipeline stages
  - Extended `scripts/dispatch/detect-capabilities.sh` with `graph_db`, `mcp_servers`, `ci_pipeline` detection + `--profile` flag
- **Backend-Agnostic Dispatch Interface (P02)**:
  - `scripts/dispatch/dispatch-interface.sh` — uniform entry point with filename-based adapter routing, distinct exit codes 2-6
  - `scripts/dispatch/backend-registry.sh` — auto-discovery of backends in `scripts/dispatch/adapters/backend/`
  - `scripts/dispatch/adapters/backend/local-agent.sh` — Claude Code Agent tool backend (coordination-boundary adapter per MEM018)
  - `scripts/dispatch/adapters/backend/local-codex.sh` — Codex CLI SDK backend with uniform-interface fallback
  - `templates/dispatch-result.md`, `templates/dispatch-error.md` — structured result/error schemas
- **Intensity-Aware Pipeline Scaling (P03)**:
  - `scripts/engine/intensity-gate.sh` — central 7×3 stage×intensity matrix
  - `scripts/engine/intensity-override.sh` — atomic mid-workflow override with awk+mktemp+mv, scope-limited to metadata file
  - `scripts/knowledge/intensity-knowledge.sh` — intensity-aware wrapper over M007 knowledge scripts with `--dry-run`
  - "Intensity Behavior" sections added additively to 5 command docs (discuss/plan-phase/dispatch/verify/auto)
- **State & Namespace Independence (P04)**:
  - `scripts/state/resolve-root.sh` — 5-rule root resolver (env → config → `.orchestrator/` → `.specify/orchestrator/` bridge → default)
  - `scripts/state/detect-speckit.sh` — spec-kit presence detection with integration mode toggle
  - `scripts/state/config-system.sh` — unified get/set/list with dot-notation nested keys
  - `scripts/migrate/migrate-state.sh` — one-shot hard migration with `--dry-run`
  - `scripts/state/namespace-aliases.sh` — `speckit.orchestrator.* → orchestrator:*` doc generator
- **Runtime & Format Adapters (P05)**:
  - `scripts/dispatch/detect-runtime.sh` — auto-detection from env + filesystem (claude-code/codex/cursor/unknown)
  - `scripts/dispatch/adapters/runtime/{claude-code,codex,cursor}.sh` — uniform `--probe`/`--register`/`--hook-config` interface with HOME/project-dir guards
  - `scripts/dispatch/adapters/format/{native,speckit}.sh` — round-trip native + one-directional spec-kit read
- **Multi-Runtime Packaging (P06)**:
  - `packaging/SKILL.md` — open-standard skill file format spec
  - `packaging/skills/` — 12 orchestrator-*.md skills generated from `commands/*.md`
  - `packaging/bundle/` — installable unit (manifest.yml v0.3.0-dev + skills/ + hooks/ + config/ + README.md)
  - `packaging/install/install-{claude-code,codex,cursor}.sh` — thin installers delegating to P05 adapters
  - `scripts/packaging/{generate-skills,build-bundle}.sh` — generator + assembler with `--check` drift detection
  - `scripts/lifecycle/check-update.sh` — offline-safe version checker
- **Init, Onboarding & Spec-Kit Bridge (P07)**:
  - `commands/init.md` — `orchestrator:init` command doc
  - `scripts/lifecycle/detect-project.sh` — scans 10 languages + 9 frameworks + 6 CI systems + 9 tools
  - `scripts/lifecycle/init-project.sh` — top-level detect→probe→generate→verify pipeline (~1s wall-clock)
  - `scripts/lifecycle/reinit-handler.sh` — update/reset/abort modes preserving user custom blocks
  - `templates/project-instruction.md` — template with `<!-- BEGIN CUSTOM -->` markers for user-editable sections
- **60+ verification scripts** under `scripts/verify/m008-p0{1,2,3,4,5,6,7}-*.sh` — hermetic tests using mktemp fixtures; static `m008-p07-hermetic-only.sh` gate prevents real-HOME leaks

### Fixed

- `scripts/verify/check-must-haves.sh` — `grep -q` misinterpreted patterns starting with `--` as options; added `--` separator
- Bash 3.2 compatibility scanners across P05/P06/P07 are now comment-aware (exclude lines starting with `#`) to prevent false positives on documentation

### Patterns Established

- Filename-based adapter auto-discovery (shared across P02 backends, P05 runtime adapters, P05 format adapters)
- Hermetic-first testing: `HOME=$(mktemp -d)` fixtures with static enforcement gate
- HOME guard mandatory on runtime adapters (refuse empty/root)
- Thin delegation pattern (init + installers delegate to existing single-responsibility scripts)
- User-edit preservation via comment-delimited blocks + field-level awk surgery
- Comment-aware Bash 3.2 compat scanning

## [0.6.0] — 2026-04-13

M006 (006-documentation-quality). Reference docs, user guides, contributor guide, and project documentation.

### Added

- **`references/architecture.md`** — engine pipeline diagram, data flow, state machine, file layout, subsystem relationship map
- **`references/engine.md`** — run.sh documentation: arguments, environment variables, lifecycle stages, checkpointing, dry-run, crash recovery
- **`references/events.md`** — complete event type registry with field schemas and examples
- **`references/errors.md`** — error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) with emit_result protocol
- **`references/hooks.md`** — hook lifecycle, hooks.yaml format, verdict protocol, timeout behavior, custom hook walkthrough
- **`references/recipes.md`** — context-recipe.yaml schema: section fields, source types, compression, manifest config, resolution order
- **`references/routing.md`** — routing.yaml schema: model tiers, fallback chains, classification rules, budget ceiling
- **`references/constitution-walkthrough.md`** — all 13 principles with concrete codebase examples and compliance checks
- **`docs/getting-started.md`** — installation, first project setup, running the engine, interpreting output
- **`docs/recipe-authoring.md`** — custom recipes, per-phase overrides, compression config, troubleshooting
- **`docs/hook-development.md`** — writing hooks, verdict protocol, testing, debugging, example hooks
- **`docs/knowledge-management.md`** — entry lifecycle, staleness, graph relationships, scope filtering, consolidation
- **`scripts/AGENTS.md`** — coding conventions (Bash 3.2, double-sourcing guards, event emission, result protocol), testing patterns, constitution v2.0 compliance checklist, PR review checklist

### Changed

- **`CHANGELOG.md`** — added entries for M001 through M006
- **`references/file-formats.md`** — expanded schema documentation for all file formats including execution-log.jsonl, context-recipe.yaml, hooks.yaml, routing.yaml, checkpoint.json, doctor-history.jsonl

## [0.5.0] — 2026-04-13

M005 (005-hardening-integration-prep). Diagnostics, provider conventions, autonomy permissions, and safety refactoring.

### Added

- **Content-hash idempotency** — knowledge entries include `content_hash: sha256:...` in frontmatter; rebuild-index.sh uses hashes to detect actual changes; dispatch results record `outcome: unchanged` when output hash matches prior
- **`scripts/lib/hash.sh`** — `compute_content_hash` utility (SHA-256 of body content)
- **`scripts/lib/payload-transforms.sh`** — pure transform functions (`assemble_section`, `drop_by_priority`, `summarize_section`, `drop_lowest_confidence`) for independently testable payload operations
- **`scripts/lib/manifest-builder.sh`** — pure manifest functions (`build_manifest_header`, `compute_section_tokens`, `format_manifest_row`)
- **`scripts/lib/verdicts.sh`** — verdict protocol functions (`emit_verdict`, `parse_verdict`) with PASS/BLOCK/WARN/NEEDS_REVIEW constants
- **`references/provider-convention.md`** — documented shell interface for execution providers (arguments, env vars, output format, exit codes)
- **`templates/instruction-schema.md`** — declared schema for agent instruction files with required and optional sections
- **`templates/autonomy-defaults.yaml`** — declarative policy for tier-to-mode mapping, deny lists, introspection rules, compound-command patterns
- **`scripts/lifecycle/generate-permissions.sh`** — project-introspecting permission generator reading package.json, Makefile, extension.yml, toolchain configs, and agent host markers
- **`scripts/lifecycle/write-permissions.sh`** — agent-host translator writing `.claude/settings.json` with merge support for user-authored files
- **`scripts/diagnostics/check-permissions.sh`** — permission drift detector comparing current settings to generated baseline
- **`scripts/diagnostics/check-instructions.sh`** — static conformance check for instruction files against schema
- **`scripts/diagnostics/check-providers.sh`** — validates provider scripts against documented convention
- **`scripts/diagnostics/check-hashes.sh`** — verifies all knowledge entries have valid content_hash fields
- **`scripts/diagnostics/check-run-ids.sh`** — verifies recent JSONL entries include run_id field
- **`scripts/diagnostics/check-plans.sh`** — advisory lint over task plan verification blocks for harness safety heuristic triggers (AD-19)

### Changed

- **`scripts/telemetry/record-telemetry.sh`** — adds `cost_source` field (estimated/reported/unknown) to JSONL entries
- **`scripts/telemetry/aggregate-metrics.sh`** — groups by cost_source, distinguishes unknown costs from zero costs
- **`scripts/dispatch/build-context.sh`** — delegates to pure lib functions for section assembly transforms
- **`scripts/dispatch/compress-payload.sh`** — delegates to pure lib functions for compression steps
- **`scripts/lib/hooks.sh`** — parses hook stdout for VERDICT lines, maps to block/warn/continue behavior
- **`commands/auto.md`** — rewrites permission pre-flight section; adds Known Limitations subsection for harness safety heuristics (AD-19)
- **`commands/plan-phase.md`** — adds full AD-19 trigger enumeration to Check guidance; forbids inline compound bash
- **`templates/phase-plan.md`** — verification examples use script-file shape exclusively
- **`templates/task-plan.md`** — verification examples use script-file shape; comments reference AD-19
- **`commands/evaluate.md`** — triggers permission generation during scaffold when `autonomy.generate_on_init` is true
- **`scripts/diagnostics/run-doctor.sh`** — aggregates all new checks into scored health report

## [0.4.0] — 2026-04-13

M004 (004-engine-architecture). Mechanical engine layer with run context, structured events, safety rails, hooks, and declarative YAML recipes.

### Added

- **Constitution v2.0** — 6 new principles (VIII-XIII) added to the original 7; Principle II amended to require structured events; `ANTIPATTERNS.md` append-only register
- **`scripts/lib/errors.sh`** — error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) with `emit_result` function
- **`scripts/lib/events.sh`** — `emit_event` function producing structured `EVENT:{type}` lines with typed event registry
- **`scripts/lib/run-context.sh`** — `init_run_context` setting ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN
- **`scripts/lib/guards.sh`** — safety rail functions: `guard_payload_sanity`, `guard_budget`, `guard_output_sanity`, `guard_phase_complete`
- **`scripts/lib/hooks.sh`** — hook executor reading hooks.yaml, creating frozen snapshots, running hook scripts with timeout and block/warn behavior
- **`scripts/engine/run.sh`** — pipeline coordinator: task loop, run context init, event emission, hook dispatch, safety rails, checkpointing, --dry-run support
- **`scripts/engine/checkpoint.sh`** — checkpoint write/read/detect for crash recovery
- **`templates/context-recipe.yaml`** — default context recipe with 7 section declarations, compression config, manifest config
- **`templates/hooks.yaml`** — default hook configuration with 4 lifecycle points and built-in guard hooks
- **`scripts/lib/recipe-parser.sh`** — YAML recipe reader: `parse_recipe_sections`, `parse_recipe_compression`, `read_recipe_field`
- **`scripts/dispatch/lib/section-handlers.sh`** — handler functions for each recipe section source type (computed, index, file, phase_summaries, phase_plan, template)
- **`scripts/diagnostics/check-recipe.sh`** — validates context-recipe.yaml structure
- **`scripts/diagnostics/check-events.sh`** — verifies engine-path scripts contain emit_event calls
- **`scripts/diagnostics/check-constitution.sh`** — verifies constitution v2.0 principles referenced in phase plans

### Changed

- **`scripts/dispatch/build-context.sh`** — refactored to recipe-driven section assembly reading from context-recipe.yaml
- **`scripts/dispatch/compress-payload.sh`** — reads compression config from recipe
- **`scripts/dispatch/select-model.sh`** — reads fallback chains from routing.yaml, implements retry-on-fallback
- **`templates/routing.yaml`** — extended with `fallback` arrays per tier and `classification` rules block
- **8 engine-path scripts** (`build-context`, `compress-payload`, `select-model`, `check-must-haves`, `record-result`, `record-telemetry`, `aggregate-metrics`, `phase-transition`) — source lib/errors.sh and lib/events.sh, emit structured events and results, while continuing to work standalone when ORCH_RUN_ID is unset
- **`scripts/diagnostics/run-doctor.sh`** — runs recipe conformance, event conformance, and constitution v2.0 compliance checks

## [0.3.0] — Unreleased

M003 (003-migration-tool). Adapter-based migration from GSD2, GSD v1, and standard spec-kit formats. Roadmap defined; implementation not yet started.

### Added (Planned)

- **Pluggable adapter architecture** — common `extract()` interface with normalized intermediate data format; one adapter per source format (gsd2, gsd1, speckit)
- **GSD2 adapter** — SQLite-preferred data extraction with JSON/filesystem fallback
- **Knowledge migration pipeline** — individual detail files with frontmatter, KNOWLEDGE-INDEX.md generation, supersession chain resolution, scope tag derivation
- **Decision and requirements migration** — DECISIONS.md in orchestrator table format with supersession notes, REQUIREMENTS.md/REQUIREMENTS-ARCHIVE.md split
- **Milestone history tiering** — active/recent/historical/archived classification with configurable `--recent-count`; active milestone renumbered as M001; aggregated telemetry in EXECUTION-HISTORY.md
- **GSD v1 adapter** — flat-file `.planning/` directory parsing with inferred categories
- **Spec-kit adapter** — wraps existing `specs/` directories in orchestrator evaluation scaffold
- **Migration CLI** — `/speckit.orchestrator.migrate` command with `--source`, `--path`, `--merge`/`--force`/`--abort` flags, idempotency enforcement, MIGRATION-REPORT.md generation

## [0.2.0] — 2026-04-13

M002 (002-knowledge-architecture). Three-temperature knowledge architecture replacing flat KNOWLEDGE.md.

### Added

- **Three-temperature knowledge architecture** — hot/warm/cold entries with individual detail files at `knowledge/{category}/{entry-id}.md` and pipe-delimited `KNOWLEDGE-INDEX.md` index
- **7 knowledge CRUD scripts** — `create-entry.sh`, `update-entry.sh`, `supersede-entry.sh`, `archive-entry.sh`, `promote-entry.sh`, `rebuild-index.sh`, `scope-filter.sh`
- **3 shared knowledge libraries** — `staleness.sh` (staleness decay with 180-day horizon), `index-utils.sh` (atomic index operations), `detail-utils.sh` (portable frontmatter helpers)
- **Knowledge lifecycle management** — staleness decay, overlap detection, hit count tracking, confidence adjustment
- **Graph traversal** — `traverse-graph.sh` with 1-hop BFS, cycle-safe, max 5 entry cap; `resolve-entries.sh` for detail resolution
- **Pre-inlined dispatch integration** — manifest-header dispatch payloads with static-first ordering for prompt caching (FR-111/FR-112/FR-113)
- **Execution telemetry pipeline** — `record-telemetry.sh` and `aggregate-metrics.sh` for cost/performance monitoring
- **Model routing configuration** — `classify-complexity.sh` and `select-model.sh` with `routing.yaml` for complexity-based model selection with custom keyword classification
- **Diagnostics command** — `run-doctor.sh` with 4 check scripts; `doctor-history.jsonl` for trend tracking

### Changed

- **`scripts/dispatch/build-context.sh`** — knowledge-aware context building with scope-filtered entries and manifest headers
- **`scripts/dispatch/compress-payload.sh`** — graduated compression with knowledge entry awareness

## [0.1.1] — 2026-03-22

### Fixed

- **evaluate command: spec discovery** — Added spec discovery step that lists available specs and confirms with the user instead of requiring the agent to guess the correct spec path
- **evaluate command: extension availability** — Added prerequisite check for extension scripts; exits with clear installation error instead of letting the agent create a manual scaffold that diverges from `scaffold.sh` output
- **evaluate command: scaffold.sh signature** — Fixed documented signature from `scaffold.sh <root> <milestone> <spec-path>` (3 args) to the correct `scaffold.sh <root> <milestone>` (2 args)
- **evaluate command: structured output** — Added `templates/evaluation.md` template for evaluation output; replaces unstructured "brief evaluation summary" that caused agents to invent ad-hoc formats (e.g., config.json with non-standard fields)
- **discuss command: tier awareness** — Added tier reading from `M###-EVALUATION.md` so the command informs the agent whether discussion is required (Tier C), optional (Tier B), or not applicable (Tier A)
- **discuss command: question guidance** — Added spec-driven question generation heuristic so the agent analyzes the spec for technology gaps, integration boundaries, scope edges, and other ambiguities instead of formulating questions from scratch
- **roadmap command: explicit tier reading** — Added explicit instruction to read tier from `M###-EVALUATION.md` with documentation that the Tier C discussion gate is enforced here (not in `derive-phase.sh`)
- **roadmap command: cross-cutting concerns** — Added guidance for identifying, recording, and referencing cross-cutting concerns that span multiple phases
- **roadmap command: dependency graph and execution order** — Added instructions to produce ASCII DAG visualization and ordered execution list with parallelization notes for dispatch scheduling
- **roadmap command: boundary map granularity** — Added scaling heuristic for boundary map specificity based on phase count (file paths < 8, interfaces 8–15, modules > 15)
- **roadmap command: validation output** — Validation results now recorded inline in the roadmap's `## Validation` section instead of ephemeral response text
- **roadmap command: demo sentence traceability** — Clarified that demo sentences are phase-level observables, not acceptance scenario paraphrases; traceability handled at task level during `plan-phase`
- **roadmap command: state/context-draft edge case** — Documented behavior when `derive-phase.sh` returns `planning` but Tier C context draft exists as `status: draft` (treat as `discussing`, block)
- **roadmap command: check-boundary-map.sh reference** — Added `scripts/verify/check-boundary-map.sh` to Reference Files with note that it runs during `verify`, not `roadmap`
- **roadmap template: structural expansion** — Added `## Cross-Cutting Concerns`, `## Dependency Graph`, `## Execution Order`, and `## Validation` sections to `templates/roadmap.md` for consistent roadmap structure across projects

### Added

- **`templates/evaluation.md`** — New template for evaluation output with tier, metrics, reasoning, spec path, and tier source fields
- **`references/installation.md`** — New reference doc documenting how to install the extension in a consumer project (which files to copy, what to exclude, directory structure, verification steps)
- **EVALUATION.md format** documented in `references/file-formats.md` with frontmatter schema and role description
- **auto-loop.sh: `--step=V` verification** — New verification step that reads task plan Verification/Must-Haves section and mechanically executes check commands, reporting `AUTO:VERIFY_PASS` or `AUTO:VERIFY_FAIL` with check counts
- **build-context.sh: `PHASE_PLAN` mode** — New planning payload assembly when task-id is `PHASE_PLAN`; includes roadmap phase section, upstream summaries, feature spec, context draft, decisions, and knowledge
- **auto-loop.sh: planning payload assembly** — `AUTO:PLANNING` output now includes `payload_bytes` and `payload_file` fields pointing to pre-assembled planning context on disk
- **phase-transition.sh: `--write` flag** — Accepts `--body`, `--observability_surfaces`, and `--verification_result` args; calls `write-summary.sh` directly with all derived + provided fields in a single command
- **claude-settings.json: compound command patterns** — Added `echo`, `for`, `if`, `[`, `true`, `false`, `wc -l`, `test -f`, `test -d` permission patterns for verification idioms

### Changed

- **`derive-phase.sh`** — Added design note comment explaining why the script is intentionally not tier-aware (tier-specific policy is at the command layer)
- **`references/state-machine.md`** — Added "Tier-Agnostic Derivation" section documenting the intentional separation between state derivation (file presence) and tier policy (command layer)
- **`references/file-formats.md`** — Added EVALUATION.md to directory structure diagram and file format reference
- **auto-loop.sh: ORCH_ROOT computation** — Fixed off-by-one: changed `$MILESTONE_DIR/..` to `$MILESTONE_DIR/../..` so ORCH_ROOT resolves to `.specify/orchestrator/` instead of `.specify/orchestrator/milestones/`; added stderr logging when `build-context.sh` fails instead of silently falling back to 40-byte minimal payload
- **auto-loop.sh: post-dispatch simplification** — Removed next-task scanning and phase-complete detection from `--step=G` post-dispatch; post-dispatch now only records result and updates lock; next-task determination deferred to pre-dispatch to avoid race with summary writing
- **phase-transition.sh: roadmap sync ordering** — Moved `sync-roadmap.sh --fix` to run after `--write` summary creation so roadmap checkboxes reflect the newly-completed phase
- **auto.md: permission documentation** — Added guidance on common permission patterns that trigger prompts, compound command patterns, and subagent permission inheritance
- **auto.md: verification integration** — Updated task-level verification instructions to use `auto-loop.sh --step=V` instead of manual grep checks
- **auto.md: phase summary workflow** — Updated to use `phase-transition.sh --write` instead of manual `write-summary.sh` invocation with 16 flags
- **auto.md: planning payload** — Updated to reference pre-assembled `payload_file` from `AUTO:PLANNING` output instead of manual context assembly

## [0.1.0] — 2026-03-20

### Added

- **10 orchestrator commands**: evaluate, discuss, roadmap, plan-phase, dispatch, auto, verify, status, resume, consolidate
- **23 helper scripts** organized by concern: state (3), dispatch (3), verify (5), knowledge (4), lifecycle (7), util (1)
- **13 output templates** with `{{placeholder}}` syntax and YAML frontmatter convention
- **4 progressive disclosure reference docs**: state machine, verification ladder, tier definitions, file formats
- **7 test suites** with 334 assertions covering structure, state machine, design artifacts, core commands, autonomous mode, knowledge lifecycle, and cross-slice integration
- **3-tier scope classification** (A/B/C) with manual override and tier promotion
- **9-state file-presence state machine** derived entirely from disk artifacts — no stored state field
- **4-tier verification ladder**: static checks, command execution, behavioral validation, human review
- **Autonomous dispatch loop** with budget enforcement, stuck detection, and pause handling
- **Crash recovery** via lock files, PID liveness checks, and recovery briefing synthesis
- **Knowledge generation**: structured summaries (15/16-field YAML frontmatter), append-only decisions register, scoped knowledge file
- **Artifact consolidation** achieving 87% reduction in test scenarios
- **5 spec-kit lifecycle hooks**: before/after tasks, before/after implement, before commit
- **Multi-layer configuration**: environment vars > local config > project config > extension defaults
- **Git worktree isolation** (optional, via `git_isolation` config)
- **External modification detection** at phase boundaries via git diff
- **7 constitutional principles** governing all development decisions

### Not Included (Deferred)

- US7 — GitHub Agentic Workflows runtime (M002 candidate)
- US8 — APM packaging and distribution (M002 candidate)
- User-facing documentation (`docs/getting-started.md`, `docs/configuration.md`)
- Distribution manifests (`apm.yml`, `SKILL.md`, `.extensionignore`)
- Multi-agent runtime validation (Claude Code-only for v0.1.0)

### Post-Release: Audit Remediation (2026-03-20)

Four sequential remediation phases applied after initial build:

1. **Documentation accuracy + spec clarifications** — frontmatter field counts, FR-029 trigger phrasing, test output format, lock file CI notes, DONE_WITH_CONCERNS documentation
2. **Gotchas sections** — added to all 10 command documents documenting known failure modes, context pollution patterns, and anti-patterns (FR-030)
3. **Structural test coverage** — Tier A zero-artifacts, boundary map enforcement, external modification detection, payload ratio verification (+27 assertions)
4. **Behavioral test coverage** — pause/resume round-trip, idempotency tests, multi-milestone scope filtering (+27 assertions — total: 307 → 334)

### Post-Release: Audit Review (2026-03-20)

- **Spec alignment**: Added implementation notes for FR-045 (destructive ops delegation to agent runtime), FR-067/FR-068/FR-069 (adapter interface mapping to extension architecture), SC-007 (Claude Code-only acknowledgment)
- **Spec field counts**: Added `type` field to file format specifications (task: 15 fields, phase/milestone: 16 fields)
- **Auto mode**: Made roadmap reassessment mandatory at phase transitions (FR-009/FR-061)
- **README fixes**: Architecture diagram (`util/` placement), Bash version (4+ → 3.2+), test counts (307 → 334), agent compatibility (Claude Code-only acknowledgment), quickstart visualization
- **KNOWLEDGE.md**: Added adapter interface design note, Claude Code-only validation note

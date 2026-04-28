## Forward Milestone Sequence (revised 2026-04-28 — post-M018 close)

**Status snapshot (2026-04-28)**: M018 closed today (8 phases, validate-milestone.sh PASS 75/75). The authoritative pre-launch queue is now in `.orchestrator/proposals/README.md` (revised 2026-04-28): **M028 → M030 → M031 → M029 → launch**, with M009 / M023 / M010 deferred post-launch (demand-driven). The original D016 sequence (M013→M014→M020→M024→M019 T2/3→M018→M023→M009→M010) is preserved below for audit. The 2026-04-22 revision is preserved verbatim further down.

Remaining milestones, in execution order:

1. **M028 — Autonomous Hardening v3** *(brief: `.orchestrator/proposals/M028-autonomous-hardening-v3.md`)* — hook portability across consumer projects (M021 shape guard fails-open in projects outside the orchestrator repo) + four new shape classes (AP-010 through AP-013) from the post-M021 screenshot corpus + investigation-pattern wrappers (`grep-files.sh`, `cleanup-stale-results.sh`, `node-eval.sh`) + Finding F: M025 hook-shim follow-up (bare-command-name emission, install-side dedup, `--repair` for flag-less orphans). Five phases or 2 quick PRs depending on P01 baseline. **No planning artifacts on disk yet** — kickoff begins with `orchestrator:specify` consuming the brief.
2. **M030 — Adaptive Model Selection** *(brief: `.orchestrator/proposals/M030-adaptive-model-selection.md`)* — task-character classifier + model routing table; routes surgical/bounded tasks to Haiku/Sonnet, reserves Opus for novel/exploratory. Verifier-fail auto-escalation (capped). Empirical shadow-mode validation phase using M027 cost+quality data before flipping live routing. Four phases or 2-3 quick PRs depending on classifier complexity.
3. **M031 — Right-Sized Entry** *(brief: `.orchestrator/proposals/M031-right-sized-entry.md`)* — restores knowledge graph + compression access for Quick intensity (today `commands/dispatch.md:21` skips `build-context.sh` — load-bearing leak); adds Tier A+ middle flow (research → plan → build, no auto/roadmap/consolidate); universal `orchestrator <task>` entry. Composes with M030 as the thrift-and-ergonomics pair. Four phases + optional P00 baseline.
4. **M029 — Roadmap Visibility & CLI UX** *(brief: `.orchestrator/proposals/M029-roadmap-visibility-and-cli-ux.md`)* — `orchestrator:where` tree renderer + invocation-context resolver + headline status (embeds existing M027 surfaces — efficiency-footer / metrics-rollup / predictive-surface). M013 GitHub sidecar fold-in (no API calls). Three phases. Last thing pre-launch — runtime visible to early users from day one.

**Standalone constitution amendment** (any time, single PR, no dependencies, brief at `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`): inclusion-criteria gate for new principles + `CONSTITUTION-LOG.md` governance log + Principle XVI (Distribution Surface Integrity) + Principle I clarification ("minimize total task tokens via efficient context delivery", not payload bytes). Cheapest, earliest land.

### Post-launch fast-follows (deferred 2026-04-28, demand-driven)

5. **M009 — Launch & Ecosystem (multi-runtime parity audit, deferred post-launch)** *(originally a launch gate per 2026-04-22 D016)* — runtime-parity audit consuming `references/RUNTIME-ASSUMPTIONS.md` (foundation seeded by M018/P07's compression-tier parity work — RA-M018-01 byte-equality + RA-M018-02 T3 routing-parity already proven). Ships when first users arrive with Codex CLI or Cursor projects. Pre-launch dogfooding stays CC-only.
6. **M023 — Design Layer (deferred post-launch)** — `orchestrator:design` design-personality agent dispatch via conversus + DESIGN.md drafts + side-by-side prototype comparison. High-value but better as a fast-follow once real users arrive with real UI projects; pre-launch this repo has no UI to dogfood against (synthetic fixtures only).
7. **M010 — Cloud Dispatch (deferred post-launch)** — Managed Agents primary adapter + Codex Cloud stubbed adapter. Net-new capability, not launch readiness. Demand-driven: ships when a customer-facing reason to ship it appears.

### Recently shipped (this revision)

- **M018 — Context Compression Layer** closed 2026-04-28. Eight phases: P00 emitter parity + section-distribution probe + SC-9 calibration to 34.7% floor, P01 compression-grammar contract v1.0.1 (Reviewed) + conversus PASS, P02 knowledge-aware filter + preservation-check library + underperformance emitter, P03 Tier 1 microcompact + cache-prune utility, P04 Tier 2 snip + 4+-backtick fence boundary-refusal walker, P05 surfaces (efficiency-footer 'compression:' tail + doctor compression-regression flag + cost-rollup column extension) + eval harness + 7 verifiers, P06 Tier 3 auto-compact + LLM routing shim + 5 verifiers, P07 multi-runtime parity (zero-LLM byte-equality across CC/Codex/Cursor + T3 routing parity) + RUNTIME-ASSUMPTIONS.md `# Compression (M018)` block + 3 verifiers (41 assertions PASS combined). validate-milestone.sh PASS 75/75. 5 milestone-scoped knowledge entries appended. See `milestones/M018/M018-SUMMARY.md`.
- **M027 — Cost+Quality Observability Surfaces** closed 2026-04-27. Four phases: P00 rollup engine + fixture suite, P01 `orchestrator:cost` retrospective + predictive, P02 efficiency footer + dispatch-time predictive surface, P03 anomaly detection + `doctor --config-check`. Consolidated 2026-04-27 (80% reduction). See `milestones/M027/M027-SUMMARY.md`.
- **M026 — Conversus-OSS Migration** closed 2026-04-25. Three phases: P01 audit + DC-6 spike-gate, P02 resolver flip + `CONVERSUS_EDITION` env var + JSONL edition field, P03 `edition_required: paid` preset frontmatter contract + six doc-surface revisions + MEM029/MEM030 + DECISIONS D022. See `milestones/M026/M026-SUMMARY.md`.
- **M020 — Knowledge Layer Maturation** closed 2026-04-25. Six phases. MEM031 graduated (`status:` field vocabulary). See `milestones/M020/M020-SUMMARY.md`.
- **M024 — Universal Intake & Routing** closed. `orchestrator:evaluate` extended to input-agnostic with proposal artifact. See `milestones/M024/M024-SUMMARY.md`.
- **M019 Tier 2/3** closed. Rollup CLI + `orchestrator:cost` user-facing command. See `milestones/M019/M019-SUMMARY.md`.
- **M014 — Spec Management + Comment→Workflow Automation (extended)** closed 2026-04-25. Four phases: P01 native `orchestrator:specify` create-path + Section Contract SSOT + dual-write helper, P02 dual-write extension to every CLAUDE.md write-site + FR-13 drift detector + AGENTS.md migration, P03 comment classifier four-class + auto-apply for trivial classes + queue for spec-amendments + adapter-missing graceful degradation, P04 FR-5 complexity probe + FR-7 split + FR-14 three-case `--amend` + spec-pressure-test preset. D019 (three-pass scaffold→author→gate), D020 (chunks-first scoping bug + scaffold-placeholder false-positive), D023 (P03 unblock via Preflight note + SC-16 best-available signal). See `milestones/M014/M014-SUMMARY.md`.
- **M013 — GitHub Native Integration** closed 2026-04-22. Four phases: P01 minimal slice + UAT bug ingestion, P02 US-1 projection create path + 538-line `github-init.sh`, P03 `--re-init` adoption + FR-5 GraphQL whitelist lint + mapping completion, P04 sync cycle + post-verify hook + opt-in conversus UAT PR gate + FR-16 rate-limit + FR-17/18 emitters. D014 Knowledge-Layer Boundary, D015 P02/P03 scope split. See `milestones/M013/M013-SUMMARY.md`.

**Stance — ultraplan / ultrareview**: parked, not integrated per D016. Claude-Code-only surfaces (require CC on web + GitHub repo + Anthropic cloud), fork multi-runtime UX. M013 GitHub integration delivers the equivalent plan/review surface universally via PR comments. Revisit only if concrete CC-only user demand emerges.

**Discipline — `RUNTIME-ASSUMPTIONS.md`** (no milestone cost): a registry file tracking CC-specific shape assumptions as written (`settings.json` hook formats, CLAUDE.md-only writes, `claude` CLI invocation patterns). M009's parity audit consumes it as a punch-list rather than an open-ended investigation. Keeps "CC-first dogfooding" from silently becoming "CC-only."

**M012 — Spec Wiki** closed 2026-04-21. All 4 phases green (P01 scaffold + SSOT pipeline, P02 cross-link + knowledge subtree + link-check, P03 Giscus overlay + diagnostics, P04 deploy wrapper + home page + first-deploy record). 37 verification gates total. D011 evaluation shipped 1 of 3 criteria → M020 promoted (D013). Milestone validator: 87/87. See `milestones/M012/M012-SUMMARY.md`. **Carry-over for human operator**: live first deploy to `gh-pages` via `scripts/wiki/wiki-deploy.sh`, fill `DEPLOY-RECORD.md` pending sentinels, author P04-SUMMARY US1..US5 + SC-1..SC-11 walkthrough.

**M019 Tier 1 emitter** closed 2026-04-18. P00 Opus 4.7 baseline adaptation + P01 Tier 1 emitter shipped. `payload_breakdown` / `dispatch_usage` / `unit_close` JSONL records in `execution-log.jsonl` with Goodhart-paired cost+quality blocks. See `milestones/M019/M019-SUMMARY.md`.

**M021 — Autonomous Hardening v2** closed 2026-04-17. Three-wrapper catalog under `scripts/util/`, linter v2 (AP-005..AP-009), and PreToolUse shape-guard hook enforcing a closed 10-pattern rewrite/reject matrix. See `milestones/M021/M021-SUMMARY.md`.

**M011 — Spec Management** closed 2026-04-17. All 7 phases green (P07 delivered the reusable `scripts/dispatch/adapters/tool/conversus.sh` adapter and format-agnostic intake). Milestone validator: 121/121. See `milestones/M011/M011-SUMMARY.md`.

**M016 — Autonomous Hardening** closed prior to M011 kickoff (commit `696fa34`). Zero-prompt auto runs validated; anti-pattern linter and run-suite wrapper in place.

**M017 — Conversus Deliberation Gate** dropped as a standalone milestone (see `DECISIONS.md` D007). `/conversus gate` already provides the CI-shaped primitive orchestrator needs, so integration collapsed to M011/P07. Later milestones (M013, M014, roadmap decomposition at Full intensity) invoke the adapter from their own scope. Intensity engine owns when-to-gate defaults; users own opt-in/opt-out.

**Why dogfooding (M011–M014) before launch (M009):** The team needs end-to-end spec→wiki→GitHub usability before producing external-facing launch artifacts. Dogfooding will surface the rough edges M009's docs need to address. See `DECISIONS.md` D006.

**Why M010 at the tail:** Anthropic Managed Agents is not yet broadly available. See `DECISIONS.md` D004.

---

## M015 Standalone Cutover Complete (2026-04-15)

v0.9.0. Four phases closed, all 19 FRs PASS in `milestones/M015/M015-VERIFICATION.md`.

- **P01** — Spec-kit host removed: `extension.yml`, 9 `.claude/commands/speckit.*.md`, `.specify/scripts/bash/`, `.specify/templates/`, plus 3 extension-shape test artifacts hard-deleted (`git rm`, no compat shim). Fixed a latent `evaluate-preflight.sh` argument bug opportunistically.
- **P02** — State tree migrated from `.specify/orchestrator/` to `.orchestrator/` via `scripts/migrate/migrate-state.sh` (atomic `mv`). Constitution moved to `.orchestrator/memory/constitution.md`. `scripts/state/resolve-root.sh` dropped from 5 rules to 4 — bridge rule deleted outright. Decision D003 removed a redundant `state_root:` line from `.orchestrator/config.yml`.
- **P03** — Five primary docs reframed as standalone (`README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`) + thirteen wider docs swept. New `docs/migrating-from-speckit.md` covers the spec-kit→orchestrator journey. CHANGELOG `[0.9.0]` entry prepended; historical tail byte-identical.
- **P04** — Four evidence streams captured under `milestones/M015/phases/P04/evidence/`: all 8 `tests/test-s*.sh` suites pass, `orchestrator-doctor` clean, spec-kit migration adapter produces a valid `.orchestrator/` from a fixture, clean-clone shape probe finds zero extension-host artifacts.

Migration adapters preserved verbatim per FR-013: `scripts/migrate/adapters/speckit.sh`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, `commands/migrate.md`. Spec-kit is removed as a runtime host, retained as a migration source.

---

## M003 Refit Complete (2026-04-14)

P07/P08 closed post-M007/M008 drift:
- P07: `migrate.sh` now consumes `scripts/state/resolve-root.sh --absolute`; idempotency probes
  both orchestrator-root and project-root layouts; `rebuild-index.sh` wired as P04 stage.
- P08: `tests/integration/test-m003-e2e-migration.sh` validates the refitted pipeline
  end-to-end against a synthetic GSD2 fixture (`tests/fixtures/m003-p08-gsd-minimal/`)
  and the live lakeledger fixture when present.
- Artifact added: `scripts/orchestrator/status.sh` — thin wrapper on `resolve-root.sh`
  + `derive-phase.sh` that the roadmap demo sentence now points to literally.

Validation (T04): integration test `passed=8 failed=0 skipped=0 warned=2` (warns are the live
lakeledger fixture's concurrent mtime activity — expected, not a harness bug). All 8
`scripts/verify/m003-p08-*.sh` PASS; all 7 `scripts/verify/m003-p07-*.sh` still PASS.
Lakeledger full-scale validation deferred beyond the end-to-end pipeline pass.

---

# M001: spec-kit-orchestrator v0.1.0

Completed: 2026-03-20 | 7 slices, 307 test assertions, zero failures

## What Was Built

A spec-kit extension providing autonomous multi-phase orchestration via 10 commands, 23 helper scripts, 13 templates, and 4 reference documents. All state is file-based under `.specify/orchestrator/`. The extension works with any spec-kit-supported agent (Claude Code, Copilot, Cursor, Gemini CLI).

### Capabilities Delivered
- **Scope triage**: Classify projects as Tier A/B/C based on complexity
- **Phase decomposition**: Roadmap → phases → tasks with dependency graphs and boundary maps
- **State machine**: 9-state lifecycle derived from disk file presence
- **Autonomous dispatch**: Derive state → budget check → stuck detection → context assembly → dispatch → verify → record → advance
- **Mechanical verification**: 4-tier ladder (static → command → behavioral → human)
- **Crash recovery**: Lock-based detection, recovery briefing from surviving artifacts, graceful pause/resume
- **Knowledge generation**: Structured summaries, append-only decisions/knowledge registers, scope-filtered context injection
- **Consolidation**: Artifact compression (87% reduction achieved in tests) + archival

### Not in M001 Scope
- GitHub Agentic Workflows runtime (User Story 7 / P7)
- APM packaging and distribution (User Story 8 / P8)
- `docs/getting-started.md` and `docs/configuration.md`
- `apm.yml`, `SKILL.md`, `.extensionignore`

## Architecture Overview

```
extension.yml          ← manifest: 10 commands, 5 hooks, 23 scripts, 7 config properties
│
├── commands/*.md      ← agent instruction documents (what to do)
│   └── references scripts/ and templates/ by path
│
├── scripts/           ← executable helpers (how to do it)
│   ├── state/         ← derive-phase, read-config, read-roadmap
│   ├── dispatch/      ← build-context, scope-filter, detect-capabilities
│   ├── verify/        ← check-must-haves, check-boundary-map, check-scope, run-commands
│   ├── knowledge/     ← write-summary, append-decision, append-knowledge, consolidate-artifacts
│   └── lifecycle/     ← scaffold, lock-manager, stuck-detector, recovery-briefing, budget-checker,
│                        rollback-phase, mark-complete
│
├── templates/*.md     ← 13 output templates with {{placeholder}} syntax
│
├── references/*.md    ← 4 progressive disclosure docs (state-machine, verification-ladder,
│                        tier-definitions, file-formats)
│
└── tests/             ← 7 test suites, 307 assertions
    ├── test-s01-structure.sh       (20 assertions)
    ├── test-s02-state-machine.sh   (26 assertions)
    ├── test-s03-design-artifacts.sh (60 assertions)
    ├── test-s04-core-commands.sh   (57 assertions)
    ├── test-s05-autonomous-mode.sh (65 assertions)
    ├── test-s06-knowledge-lifecycle.sh (57 assertions)
    ├── test-s07-integration.sh     (22 assertions)
    └── fixtures/                   (~20 fixture directories)
```

### State Flow
```
pre-planning → discussing → planning → executing → summarizing → validating → completing → complete
                                          ↓ (failure)
                                      replanning
```

### Config Resolution (4-layer)
```
Environment vars > .local config > project config > extension defaults
```

## Component Inventory

### Commands (commands/)
| File | Command | Purpose |
|------|---------|---------|
| evaluate.md | speckit.orchestrator.evaluate | Scope triage → Tier A/B/C |
| discuss.md | speckit.orchestrator.discuss | Pre-planning context capture |
| roadmap.md | speckit.orchestrator.roadmap | Spec → phases with boundary maps |
| plan-phase.md | speckit.orchestrator.plan-phase | Phase → tasks with must-haves |
| dispatch.md | speckit.orchestrator.dispatch | Execute one task in fresh context |
| auto.md | speckit.orchestrator.auto | Autonomous dispatch loop |
| verify.md | speckit.orchestrator.verify | Must-haves verification |
| status.md | speckit.orchestrator.status | Progress dashboard |
| resume.md | speckit.orchestrator.resume | Crash/pause recovery |
| consolidate.md | speckit.orchestrator.consolidate | Knowledge compression + archival |

### Scripts (scripts/)
| Directory | Script | Purpose |
|-----------|--------|---------|
| state/ | derive-phase.sh | 9-state derivation from disk |
| state/ | read-config.sh | 4-layer config resolution |
| state/ | read-roadmap.sh | Roadmap parser (6 query modes) |
| dispatch/ | build-context.sh | Assemble minimal dispatch payload |
| dispatch/ | scope-filter.sh | Filter knowledge/decisions by scope |
| dispatch/ | detect-capabilities.sh | Runtime capability detection |
| verify/ | check-must-haves.sh | Artifact/truth/link verification |
| verify/ | check-boundary-map.sh | Cross-phase interface checks |
| verify/ | check-scope.sh | Scope violation warnings |
| verify/ | run-commands.sh | Execute verification commands |
| verify/ | check-external-mods.sh | External modification detection (FR-064) |
| util/ | json-field.sh | Shared JSON field extraction utility |
| knowledge/ | write-summary.sh | Generate structured summaries |
| knowledge/ | append-decision.sh | Append to DECISIONS.md |
| knowledge/ | append-knowledge.sh | Append to KNOWLEDGE.md |
| knowledge/ | consolidate-artifacts.sh | Compress + archive (≥60% reduction) |
| lifecycle/ | scaffold.sh | Idempotent milestone scaffolding |
| lifecycle/ | lock-manager.sh | Create/status/break/update locks |
| lifecycle/ | stuck-detector.sh | Dispatch-twice-without-completion |
| lifecycle/ | recovery-briefing.sh | Crash recovery context synthesis |
| lifecycle/ | budget-checker.sh | Dispatch count + duration budgets |
| lifecycle/ | rollback-phase.sh | Phase rollback with dep flagging |
| lifecycle/ | mark-complete.sh | Milestone validation marker |

### Templates (templates/)
Planning: roadmap.md, phase-plan.md, task-plan.md
Summaries: task-summary.md, phase-summary.md, milestone-summary.md
Dispatch: dispatch-prompt.md, verification-report.md, spec-compliance-review.md
Lifecycle: recovery-briefing.md, continue-file.md, context-draft.md
Config: orchestrator-config-default.yml

### References (references/)
state-machine.md, verification-ladder.md, tier-definitions.md, file-formats.md

## How to Extend

### Adding a new command
1. Create `commands/<name>.md` following the standard structure (see any existing command)
2. Register in `extension.yml` under `provides.commands`
3. Add integration test assertions in appropriate test file
4. If the command uses helper scripts, register those in `provides.scripts`

### Adding a new script
1. Create under the appropriate `scripts/<concern>/` directory
2. Make executable (`chmod +x`)
3. Use structured prefix output (`PREFIX: message`) to stdout
4. Register in `extension.yml` under `provides.scripts`
5. Avoid `declare -A` — use parallel indexed arrays for bash 3.2

### Adding a new template
1. Create in `templates/` with YAML frontmatter (`schema_version`, `type`)
2. Use `{{placeholder}}` syntax for all dynamic values
3. No hardcoded IDs — templates must be context-free
4. Add assertions in `test-s03-design-artifacts.sh`

### Adding a new state
1. Add derivation rule in `scripts/state/derive-phase.sh` (priority-ordered)
2. Add fixture directory in `tests/fixtures/state-<name>/`
3. Update `references/state-machine.md`
4. Add test assertion in `test-s02-state-machine.sh`

### Future milestones
- M002 candidates: GitHub Agentic Workflows (US7), APM packaging (US8), docs
- `check-external-mods.sh` (FR-064) and git worktree isolation (FR-075) implemented in v0.1.0 audit remediation
- `write-lock.sh` and `write-continue.sh` were planned as separate scripts but their functionality was absorbed into `lock-manager.sh` and command-level logic

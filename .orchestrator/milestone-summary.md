## Forward Milestone Sequence (revised 2026-04-17)

Remaining milestones, in execution order:

1. **M019 Tier 1 emitter** *(next — kickoff unit of M019)* — Tier 1 "just emit" lands first after M011 close so M012–M014 dogfooding produces measured data. See `DECISIONS.md` D009.
2. **M012 — Spec Wiki** — MkDocs + Giscus comments; stakeholder-readable site
3. **M013 — GitHub Native Integration** — Issues/Milestones/Projects sync, UAT loop; invokes the M011/P07 conversus adapter for opt-in pre-merge review gates
4. **M014 — Comment→Workflow Automation** — classify/auto-apply wiki+GH comments; invokes the M011/P07 conversus adapter for ambiguous-comment triage
5. **M019 Tier 2/3** — rollup + `orchestrator:cost`, then full polished surface — lands after M014 once ~3 milestones of Tier 1 data reveal what the polished surface should actually expose.
6. **M018 — Context Compression Layer** *(sketch, see `DECISIONS.md` D008)* — caveman-style token compression as a pipeline stage. Phase outline drafted but not yet planned in detail; full planning happens closer to kickoff after M019 Tier 1 reveals which artifacts dominate token spend.
7. **M009 — Launch & Ecosystem** — README, examples, contributor pipeline, release infra
8. **M010 — Cloud Dispatch** — Managed Agents backend; pull forward if Managed Agents GAs earlier

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

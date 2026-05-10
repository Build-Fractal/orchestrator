---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M015"
goal: "Move orchestrator state from .specify/orchestrator/ to .orchestrator/, move the constitution to .orchestrator/memory/constitution.md, remove the .specify/orchestrator/ bridge rule from scripts/state/resolve-root.sh, and update every runtime reference (commands, scripts, templates, references, docs, tests) to the new canonical paths while preserving the spec-kit migration adapters that target .specify/ as a migration source."
demo_sentence: "Running `bash scripts/state/resolve-root.sh --verbose` in the repo root prints `root=.orchestrator` and `source=existing:.orchestrator`; `.specify/orchestrator/` no longer exists; `.specify/memory/constitution.md` no longer exists; `.orchestrator/memory/constitution.md` exists; and no retained runtime file references `.specify/orchestrator/` or `.specify/memory/constitution.md` (migration adapters excepted)."
risk: "high"
depends_on: [P01]
---

## Must-Haves

### Truths

- The orchestrator state directory has moved: `.specify/orchestrator/` no longer exists and `.orchestrator/` exists with the migrated tree (milestones, knowledge files, decisions, telemetry, config.yml, and the constitution under memory/).
  - Check: `bash scripts/verify/m015-p02-state-tree-migrated.sh`

- The constitution has moved to `.orchestrator/memory/constitution.md`; the legacy `.specify/memory/constitution.md` is gone and `.specify/memory/` directory is removed.
  - Check: `bash scripts/verify/m015-p02-constitution-moved.sh`

- `scripts/state/resolve-root.sh` contains no bridge rule for `.specify/orchestrator/`: there is no `Rule 4: .specify/orchestrator/` block, no string literal `bridge:.specify/orchestrator`, and no directory existence test against `.specify/orchestrator` inside the resolver.
  - Check: `bash scripts/verify/m015-p02-resolver-no-bridge.sh`

- `scripts/state/resolve-root.sh` still resolves a populated `.orchestrator/` directory via the canonical `existing:.orchestrator` rule, and `bash scripts/state/resolve-root.sh --verbose` from the repo root emits `root=.orchestrator` and `source=existing:.orchestrator` after migration.
  - Check: `bash scripts/verify/m015-p02-resolver-resolves-new.sh`

- No retained runtime file (outside the migration-adapter allow-list and the historical-artifact allow-list) contains the literal string `.specify/orchestrator` or the literal string `.specify/memory/constitution`. Migration adapters `scripts/migrate/`, `scripts/state/detect-speckit.sh`, `scripts/dispatch/adapters/format/speckit.sh`, and `commands/migrate.md` are exempt — they legitimately reference `.specify/` as a migration source per FR-013. Historical artifacts under `.specify/orchestrator/` phase/milestone summaries are no longer on disk after migration, but migrated summaries under `.orchestrator/` preserve their original text (immutable per constraint) and are exempt. `CHANGELOG.md`, `specs/`, and `.planning/` are exempt as historical. Documentation files slated for P03 reframe (`README.md`, `CLAUDE.md`, `references/architecture.md`, `references/installation.md`, `docs/getting-started.md`, `references/constitution-walkthrough.md`, `docs/knowledge-management.md`) are tolerated here and handled by P03.
  - Check: `bash scripts/verify/m015-p02-no-stale-state-refs.sh`

- `orchestrator-doctor` reports clean status after migration: running `bash scripts/diagnostics/run-doctor.sh` exits 0 with no orphan, stale-reference, or missing-artifact errors.
  - Check: `bash scripts/verify/m015-p02-doctor-clean.sh`

### Artifacts

- scripts/verify/m015-p02-state-tree-migrated.sh (min 5 lines, contains ".orchestrator")
- scripts/verify/m015-p02-constitution-moved.sh (min 5 lines, contains "constitution")
- scripts/verify/m015-p02-resolver-no-bridge.sh (min 5 lines, contains "bridge")
- scripts/verify/m015-p02-resolver-resolves-new.sh (min 5 lines, contains "existing:.orchestrator")
- scripts/verify/m015-p02-no-stale-state-refs.sh (min 10 lines, contains ".specify/orchestrator")
- scripts/verify/m015-p02-doctor-clean.sh (min 3 lines, contains "run-doctor")
- .orchestrator/memory/constitution.md (min 50 lines, contains "Principle")
- .orchestrator/config.yml (min 3 lines, contains "state_root")
- scripts/state/resolve-root.sh (min 80 lines, contains "existing:.orchestrator")

### Key Links

- [.orchestrator/milestones/M015/phases/P02/P02-PLAN.md](../../../../milestones/M015/phases/P02/P02-PLAN.md) → specs/015-standalone-cutover/spec.md
- scripts/state/resolve-root.sh → .orchestrator/config.yml

## Tasks

### T01: Write P02 verify scripts (pre-migration scaffolding)

See .specify/orchestrator/milestones/M015/phases/P02/tasks/T01-PLAN.md.

### T02: Execute state tree migration (.specify/orchestrator/ → .orchestrator/)

See .specify/orchestrator/milestones/M015/phases/P02/tasks/T02-PLAN.md.

### T03: Move constitution and remove .specify/memory/

See .specify/orchestrator/milestones/M015/phases/P02/tasks/T03-PLAN.md.

### T04: Remove bridge rule from resolve-root.sh

See .specify/orchestrator/milestones/M015/phases/P02/tasks/T04-PLAN.md.

### T05: Reference sweep — update runtime refs to new paths

See .specify/orchestrator/milestones/M015/phases/P02/tasks/T05-PLAN.md.

## Task Dependencies

```
T01 → T02 → T03 → T04 → T05
```

Strict linear chain. T01 writes all P02 verify scripts first — they must exist before any later task can be verified. T02 performs the hard state move (the irreversible step); writing verify scripts first means T02's success is provable immediately. T03 moves the constitution as a separate step so T02's move can use the existing `scripts/migrate/migrate-state.sh` unchanged. T04 removes the bridge rule from `resolve-root.sh` only after state has physically moved (so the resolver can be tested against the new layout). T05 sweeps every retained runtime file for stale references, which requires the new layout to be in place (so the sweep's "before" vs "after" is meaningful).

## Files Likely Touched

- .orchestrator/ (create via move — entire tree migrated from .specify/orchestrator/)
- .orchestrator/memory/constitution.md (create via move from .specify/memory/constitution.md)
- .specify/orchestrator/ (delete — moved)
- .specify/memory/constitution.md (delete — moved)
- .specify/memory/ (delete the now-empty directory)
- scripts/state/resolve-root.sh (modify — remove bridge rule, renumber, update header comment)
- scripts/verify/m015-p02-state-tree-migrated.sh (create)
- scripts/verify/m015-p02-constitution-moved.sh (create)
- scripts/verify/m015-p02-resolver-no-bridge.sh (create)
- scripts/verify/m015-p02-resolver-resolves-new.sh (create)
- scripts/verify/m015-p02-no-stale-state-refs.sh (create)
- scripts/verify/m015-p02-doctor-clean.sh (create)
- scripts/verify/check-must-haves.sh (modify — update hardcoded .specify/orchestrator literal if present)
- scripts/verify/m004-p06-check-must-haves-root.sh (modify)
- scripts/verify/m002-p04-*.sh (modify — 7 files reference .specify/orchestrator)
- scripts/verify/m006-p01-arch-layout.sh (modify)
- scripts/verify/m002-p07-e2e.sh (modify)
- scripts/verify/m003-p07-no-hardcoded-state-paths.sh (modify)
- scripts/verify/m003-p07-idempotency-dual-root.sh (modify)
- scripts/verify/m008-p04-*.sh (modify — 7 files reference .specify/orchestrator; keep bridge-test fixture semantics hermetically)
- scripts/verify/m015-p01-no-stale-refs.sh (modify — adjust exclude-dir now that .specify/orchestrator/ has moved)
- scripts/lifecycle/generate-permissions.sh (modify)
- scripts/lifecycle/evaluate-preflight.sh (modify)
- scripts/lifecycle/mark-complete.sh (modify)
- scripts/lifecycle/rollback-phase.sh (modify)
- scripts/lifecycle/recovery-briefing.sh (modify)
- scripts/knowledge/lib/index-utils.sh (modify)
- scripts/knowledge/consolidate-artifacts.sh (modify)
- scripts/knowledge/append-knowledge.sh (modify)
- scripts/knowledge/append-decision.sh (modify)
- scripts/dispatch/build-context.sh (modify)
- scripts/dispatch/detect-capabilities.sh (modify)
- scripts/dispatch/lib/section-handlers.sh (modify)
- scripts/diagnostics/run-doctor.sh (modify)
- scripts/diagnostics/check-plans.sh (modify)
- scripts/diagnostics/check-run-ids.sh (modify)
- scripts/diagnostics/check-hashes.sh (modify)
- scripts/diagnostics/check-cost-spikes.sh (modify)
- scripts/diagnostics/check-constitution.sh (modify)
- scripts/engine/run.sh (modify)
- scripts/engine/checkpoint.sh (modify)
- scripts/engine/test-resume.sh (modify)
- scripts/migrate/lib/idempotency.sh (modify — this is inside scripts/migrate/ but references .specify/orchestrator as a general runtime idempotency key; keep adapter-source refs, update runtime refs)
- commands/auto.md (modify — update 10 literal .specify/orchestrator invocations to use resolve-root.sh output)
- commands/evaluate.md (modify)
- commands/verify.md (modify)
- commands/plan-phase.md (modify)
- commands/resume.md (modify)
- commands/consolidate.md (modify)
- templates/claude-settings.json (modify — update allow-listed paths)
- .gitignore (modify — add .orchestrator/ equivalents if relevant, keep .specify/orchestrator/ ignore for historical)
- scripts/AGENTS.md (modify — update constitution link and state-root references)
- .orchestrator/config.yml (verify content — state_root stays ".orchestrator")
- Any other retained file discovered by T05's sweep (modify)

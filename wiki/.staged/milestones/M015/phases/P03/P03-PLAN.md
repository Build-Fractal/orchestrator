---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M015"
goal: "Reframe current-state documentation from 'spec-kit extension' to 'standalone orchestrator': rewrite README.md, CLAUDE.md, references/architecture.md, references/installation.md, and docs/getting-started.md for the standalone narrative; sweep remaining reference + user-guide docs to replace legacy runtime references (extension.yml, .specify/orchestrator/, .specify/memory/constitution.md, /speckit.* slash commands as SDD entry points) with standalone equivalents; append a new CHANGELOG.md entry for M015 without touching historical entries; add a migration guide (docs/migrating-from-speckit.md) describing how users coming from spec-kit adopt the orchestrator; and tighten the P02 stale-reference sweep's ALLOW_P03_DOCS so that reframed docs graduate out of the tolerance allow-list."
demo_sentence: "Running `bash scripts/verify/m015-p03-standalone-framing.sh` returns PASS after the reframe — the five primary standalone docs no longer describe the orchestrator as 'a spec-kit extension' in runtime context and no longer instruct readers to install via `extension.yml` or invoke `/speckit.*` slash commands as the SDD entry point; `bash scripts/verify/m015-p03-changelog-has-m015.sh` confirms a new M015 changelog entry exists at the top of CHANGELOG.md with historical entries untouched; `bash scripts/verify/m015-p03-migration-doc.sh` confirms docs/migrating-from-speckit.md exists and describes spec-kit as a migration source; and `bash scripts/verify/m015-p02-no-stale-state-refs.sh` still PASSes with the ALLOW_P03_DOCS allow-list reduced to zero entries (all P03-reserved docs reframed) or to the minimum justifiable subset."
risk: "low"
depends_on: [P02]
---

## Must-Haves

### Truths

- The five primary standalone docs (README.md, CLAUDE.md, references/architecture.md, references/installation.md, docs/getting-started.md) no longer describe the orchestrator as "a spec-kit extension" in current-state / runtime framing. The phrase "spec-kit extension" may appear only in (a) changelog-style prose that explicitly frames the project's history, or (b) migration-context callouts that explicitly reference spec-kit as a migration source — not as an installation or runtime instruction.
  - Check: `bash scripts/verify/m015-p03-standalone-framing.sh`

- The five primary standalone docs no longer instruct readers to install `extension.yml`, copy spec-kit hook manifests, or run `/speckit.*` slash commands as the SDD entry point for this project's own development. References to `/speckit.*` as recognized GITHUB spec-kit commands that users may have in their environment remain permissible only in migration-context sections or in the spec-kit migration guide.
  - Check: `bash scripts/verify/m015-p03-no-legacy-install.sh`

- CHANGELOG.md has a new M015 entry at the top of the file (under the file's top-level heading and above the prior top entry). The entry describes the standalone cutover. Historical entries for M001–[M008](../../../../milestones/M008/index.md) remain byte-identical to their state before P03 began.
  - Check: `bash scripts/verify/m015-p03-changelog-has-m015.sh`

- A migration guide exists at docs/migrating-from-speckit.md describing how a user with an existing spec-kit project adopts the orchestrator. The guide explicitly frames spec-kit as a migration *source*, references commands/migrate.md or scripts/migrate/migrate-state.sh, and clarifies that spec-kit is not a runtime dependency of the orchestrator.
  - Check: `bash scripts/verify/m015-p03-migration-doc.sh`

- The wider P03-reserved documentation set (references/engine.md, events.md, errors.md, recipes.md, file-formats.md, state-machine.md, tier-definitions.md, constitution-walkthrough.md, verification-ladder.md; docs/knowledge-management.md, recipe-authoring.md, hook-development.md; scripts/AGENTS.md) no longer contains literal `.specify/orchestrator/` or `.specify/memory/constitution` path references in running text, code blocks, or diagrams that describe current-state runtime behavior. Occurrences may remain only inside explicit historical/migration callouts. Files with no remaining occurrences are removed from ALLOW_P03_DOCS.
  - Check: `bash scripts/verify/m015-p03-wider-docs-sweep.sh`

- scripts/verify/m015-p02-no-stale-state-refs.sh still exits 0 after P03's edits: either because every reframed doc has been removed from ALLOW_P03_DOCS (reduced to the minimum justifiable subset), or because no stale reference appears outside the allow-list and migration adapters. The allow-list file must not grow in P03.
  - Check: `bash scripts/verify/m015-p03-allow-list-tightened.sh`

### Artifacts

- scripts/verify/m015-p03-standalone-framing.sh (min 15 lines, contains "spec-kit extension")
- scripts/verify/m015-p03-no-legacy-install.sh (min 10 lines, contains "extension.yml")
- scripts/verify/m015-p03-changelog-has-m015.sh (min 10 lines, contains "M015")
- scripts/verify/m015-p03-migration-doc.sh (min 8 lines, contains "migrating-from-speckit")
- scripts/verify/m015-p03-wider-docs-sweep.sh (min 15 lines, contains ".specify/orchestrator")
- scripts/verify/m015-p03-allow-list-tightened.sh (min 10 lines, contains "ALLOW_P03_DOCS")
- docs/migrating-from-speckit.md (min 40 lines, contains "migration")
- CHANGELOG.md (min 300 lines, contains "M015")

### Key Links

- [.orchestrator/milestones/M015/phases/P03/P03-PLAN.md](../../../../milestones/M015/phases/P03/P03-PLAN.md) → specs/015-standalone-cutover/spec.md
- docs/migrating-from-speckit.md → commands/migrate.md

## Tasks

### T01: Write P03 verify scripts (pre-reframe scaffolding)

See [.orchestrator/milestones/M015/phases/P03/tasks/T01-PLAN.md](../../../../milestones/M015/phases/P03/tasks/T01-PLAN.md).

### T02: Reframe the five primary standalone docs + append CHANGELOG M015 entry

See [.orchestrator/milestones/M015/phases/P03/tasks/T02-PLAN.md](../../../../milestones/M015/phases/P03/tasks/T02-PLAN.md).

### T03: Sweep wider reference/user-guide docs + write migration guide

See [.orchestrator/milestones/M015/phases/P03/tasks/T03-PLAN.md](../../../../milestones/M015/phases/P03/tasks/T03-PLAN.md).

### T04: Tighten ALLOW_P03_DOCS allow-list and run full P03 verify suite

See [.orchestrator/milestones/M015/phases/P03/tasks/T04-PLAN.md](../../../../milestones/M015/phases/P03/tasks/T04-PLAN.md).

## Task Dependencies

```
T01 → T02 → T03 → T04
```

Strict linear chain. T01 creates all six P03 verify scripts first — they must exist before any reframe work can be proved complete, and writing them first means each reframe task can verify its own landing. T02 reframes the five primary docs and appends the CHANGELOG entry (the narrative core of the reframe). T03 sweeps the wider reference + user-guide documentation and authors the migration guide (FR-012) — this runs after T02 so the narrative set established in the primaries is consistent with the wider sweep. T04 tightens `ALLOW_P03_DOCS` in `scripts/verify/m015-p02-no-stale-state-refs.sh` (reducing it to the minimum justifiable subset after T02/T03 land) and runs the full P03 verification suite end-to-end.

## Scope Decision Notes

The P02 summary flagged that the full ALLOW_P03_DOCS list in `scripts/verify/m015-p02-no-stale-state-refs.sh` covers 16 files, but the roadmap only explicitly names 5 as in-scope for P03. Planning inspection found the other 11 files fall into two categories:

1. **Technical reference docs with many path references** (references/engine.md, events.md, errors.md, recipes.md, file-formats.md, state-machine.md, tier-definitions.md, constitution-walkthrough.md, verification-ladder.md). Greps show 40+ literal `.specify/orchestrator/` path occurrences across these files — these are not narrative framings but location strings inside diagrams, examples, and path tables. A path-only sweep fits cleanly under T03 and graduates these files out of the allow-list.

2. **User guides with lighter narrative framing** (docs/knowledge-management.md, docs/recipe-authoring.md, docs/hook-development.md, scripts/AGENTS.md). These have 10–30 references each, mostly file-path citations in examples. Same treatment — T03 sweep.

Decision: treat all 16 P03-reserved files as in-scope for P03. T02 handles the 5 primary docs where narrative framing (not just paths) must be rewritten. T03 handles the remaining 11 as a path-and-pattern sweep (rewrite runtime-path references to `.orchestrator/`, rewrite constitution references to `.orchestrator/memory/constitution.md`, strip stale `/speckit.*`-as-SDD-entrypoint language where present). T04 empties or minimizes ALLOW_P03_DOCS after T02/T03 land.

CHANGELOG.md is explicitly NOT allow-listed in P02's sweep (it's `--exclude='CHANGELOG.md'`) because historical entries must remain untouched. P03's work on CHANGELOG.md is strictly append-only (a new M015 entry at the top). The `m015-p03-changelog-has-m015.sh` verify script asserts (a) the new M015 entry is present, and (b) historical entries below it are byte-identical to a pre-P03 snapshot captured at T01 time.

docs/migrating-from-speckit.md is NEW content — not a reframe. It satisfies FR-012 (migration documentation for users coming from spec-kit). Its existence is verified mechanically; its content quality is a Tier 3 behavioral concern.

## Files Likely Touched

- scripts/verify/m015-p03-standalone-framing.sh (create)
- scripts/verify/m015-p03-no-legacy-install.sh (create)
- scripts/verify/m015-p03-changelog-has-m015.sh (create)
- scripts/verify/m015-p03-migration-doc.sh (create)
- scripts/verify/m015-p03-wider-docs-sweep.sh (create)
- scripts/verify/m015-p03-allow-list-tightened.sh (create)
- scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt (create — captured in T01, checked in T04)
- README.md (rewrite)
- CLAUDE.md (rewrite)
- references/architecture.md (rewrite current-state sections)
- references/installation.md (rewrite install flow)
- docs/getting-started.md (rewrite quickstart)
- CHANGELOG.md (append M015 entry; historical untouched)
- docs/migrating-from-speckit.md (create)
- references/engine.md (path sweep)
- references/events.md (path sweep)
- references/errors.md (path sweep)
- references/recipes.md (path sweep)
- references/file-formats.md (path sweep)
- references/state-machine.md (path sweep + tier-definitions language touch)
- references/tier-definitions.md (spec-kit-as-SDD-entrypoint language touch)
- references/constitution-walkthrough.md (path sweep + constitution reference move)
- references/verification-ladder.md (single path touch if present)
- docs/knowledge-management.md (path sweep)
- docs/recipe-authoring.md (path sweep)
- docs/hook-development.md (path sweep)
- scripts/AGENTS.md (path sweep — 3 occurrences)
- scripts/verify/m015-p02-no-stale-state-refs.sh (modify — reduce ALLOW_P03_DOCS)

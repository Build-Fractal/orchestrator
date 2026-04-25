---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M026"
goal: "Layer-on: paid-only-preset detection via frontmatter, OSS-edition diagnostic, six-surface doc updates, knowledge graduation, decision row, and Recent Changes dual-write."
demo_sentence: "An operator authoring a preset with `edition_required: paid` frontmatter and running it on an OSS install sees an actionable refusal diagnostic that names `CONVERSUS_EDITION=paid` as the escape; six doc surfaces describe the new resolver order and escape-hatch shape at the reading paths operators already use; consolidate graduates two `knowledge/**/MEM*.md` entries; `CHANGELOG.md` records the migration; and CLAUDE.md + AGENTS.md Recent Changes are dual-written."
risk: "low"
depends_on: ["P02"]
---

## Must-Haves

### Truths

<!-- AD-19: every Check is a single-script-file invocation. No inline compound bash, subshells, or $(...|pipe). -->

- Adapter refuses to invoke `conversus run` when the resolved edition is `oss` and the preset frontmatter declares `edition_required: paid`. Refusal emits a diagnostic to stderr matching the regex `paid-only.*CONVERSUS_EDITION=paid` (case-insensitive) and exits 1. Presets without `edition_required:` behave identically to today (backward-compatible).
  - Check: `bash scripts/verify/m026-p03-edition-required-diagnostic.sh`

- Adapter does not regress the CON-1..CON-5 invariants: 0/1/2 exit codes, full env-var set, `gate-result.md` frontmatter key set, D019 TODO pre-flight, stub-mode fixtures, filename-routed adapter shape, Bash 3.2 compat. Stub-mode path remains untouched (preset frontmatter parsing fires only on real-binary path).
  - Check: `bash scripts/verify/m011-p07-conversus-adapter-shape.sh`

- All six FR-12 doc surfaces grep-match both `conversus-oss` and `CONVERSUS_EDITION` and the original M011-era four-step resolver-order block in `commands/conversus-gate.md` is rewritten to the new edition-aware shape (no longer ends at `$HOME/Sites/conversus/bin/conversus` as the user-local convention).
  - Check: `bash scripts/verify/m026-p03-doc-surface-coverage.sh`

- Two knowledge-layer `MEM*.md` entries are graduated for this milestone: edition-resolution-precedence pattern and paid-escape-hatch env-var convention. `KNOWLEDGE-INDEX.md` lists both entries with the correct categories. Format follows MEM027 shape (frontmatter + `## Problem` + `## Pattern`/`## Convention` + `## Gate shape` body).
  - Check: `bash scripts/verify/m026-p03-mem-graduation.sh`

- `.orchestrator/DECISIONS.md` gains a new `D###` row naming the edition-resolution precedence (env-var primary → metadata probe → fallback) decision, and `CHANGELOG.md` records the M026 migration entry under the current version heading.
  - Check: `bash scripts/verify/m026-p03-decision-row.sh`

- CLAUDE.md and AGENTS.md `>>> orchestrator:recent-changes >>>` regions both contain a fresh M026/P03 entry written via `scripts/util/dual-write-runtime-md.sh --append-entry`, and the existing M026/P02 entry is preserved (append-entry mode is reverse-chronological prepend, not overwrite).
  - Check: `bash scripts/verify/m026-p03-recent-changes.sh`

- Phase verification suite chains every P03 verifier with the three M011/P07 cross-milestone invariant gates (DC-2) and emits `SUMMARY: m026-p03-phase-suite.sh pass=N fail=0`.
  - Check: `bash scripts/verify/m026-p03-phase-suite.sh`

### Artifacts

- `scripts/dispatch/adapters/tool/conversus.sh` (min 560 lines, contains "edition_required")
- `scripts/verify/m026-p03-edition-required-diagnostic.sh` (min 60 lines, contains "edition_required")
- `scripts/verify/m026-p03-doc-surface-coverage.sh` (min 40 lines, contains "CONVERSUS_EDITION")
- `scripts/verify/m026-p03-mem-graduation.sh` (min 30 lines, contains "MEM")
- `scripts/verify/m026-p03-decision-row.sh` (min 25 lines, contains "DECISIONS")
- `scripts/verify/m026-p03-recent-changes.sh` (min 25 lines, contains "recent-changes")
- `scripts/verify/m026-p03-phase-suite.sh` (min 40 lines, contains "SUMMARY:")
- `tests/fixtures/preset-edition-required-paid.yml` (min 5 lines, contains "edition_required: paid")
- `knowledge/patterns/MEM029.md` (min 30 lines, contains "edition")
- `knowledge/conventions/MEM030.md` (min 30 lines, contains "CONVERSUS_EDITION")
- `KNOWLEDGE-INDEX.md` (min 70 lines, contains "MEM029")
- `.orchestrator/DECISIONS.md` (min 27 lines, contains "edition-resolution")
- `CHANGELOG.md` (min 1 line, contains "M026")
- `CLAUDE.md` (min 5 lines, contains "M026/P03")
- `AGENTS.md` (min 5 lines, contains "M026/P03")

### Key Links

- `scripts/dispatch/adapters/tool/conversus.sh` → `references/architecture.md`
- `commands/conversus-gate.md` → `scripts/dispatch/adapters/tool/conversus.sh`
- `docs/ingesting-arbitrary-specs.md` → `commands/conversus-gate.md`
- `references/spec-management.md` → `templates/conversus-presets/spec-pressure-test.yml`
- `references/github-integration.md` → `scripts/dispatch/adapters/tool/conversus.sh`
- `commands/specify.md` → `scripts/dispatch/adapters/tool/conversus.sh`
- `commands/ingest.md` → `scripts/dispatch/adapters/tool/conversus.sh`
- `knowledge/patterns/MEM029.md` → `scripts/dispatch/adapters/tool/conversus.sh`
- `knowledge/conventions/MEM030.md` → `scripts/dispatch/adapters/tool/conversus.sh`

## Tasks

### T01: Preset-frontmatter edition_required parser + paid-only-on-OSS diagnostic (FR-10, FR-11)

See `tasks/T01-PLAN.md`.

### T02: Six doc-surface in-place rewrites (FR-12)

See `tasks/T02-PLAN.md`.

### T03: Knowledge graduation — two MEM entries + index rebuild (FR-13, AD-8)

See `tasks/T03-PLAN.md`.

### T04: DECISIONS.md D-row + CHANGELOG.md entry (DC-2)

See `tasks/T04-PLAN.md`.

### T05: Phase verification suite + Recent Changes dual-write (CON-6, OQ-10)

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 → T05
T02 → T05
T03 → T05
T04 → T05
```

T01–T04 are independent and could run in parallel; the orchestrator's auto-loop will dispatch them sequentially. T05 chains them at phase-close into the suite and writes the Recent Changes entry — depends on T01 (verifier exists) + T02 (verifier exists) + T03 (verifier exists) + T04 (verifier exists).

## Files Likely Touched

- scripts/dispatch/adapters/tool/conversus.sh (modify)
- scripts/verify/m026-p03-edition-required-diagnostic.sh (create)
- scripts/verify/m026-p03-doc-surface-coverage.sh (create)
- scripts/verify/m026-p03-mem-graduation.sh (create)
- scripts/verify/m026-p03-decision-row.sh (create)
- scripts/verify/m026-p03-recent-changes.sh (create)
- scripts/verify/m026-p03-phase-suite.sh (create)
- tests/fixtures/preset-edition-required-paid.yml (create)
- commands/conversus-gate.md (modify)
- commands/ingest.md (modify)
- commands/specify.md (modify)
- docs/ingesting-arbitrary-specs.md (modify)
- references/github-integration.md (modify)
- references/spec-management.md (modify)
- knowledge/patterns/MEM029.md (create)
- knowledge/conventions/MEM030.md (create)
- KNOWLEDGE-INDEX.md (modify)
- .orchestrator/DECISIONS.md (modify)
- CHANGELOG.md (modify)
- CLAUDE.md (modify — RC region only via dual-write)
- AGENTS.md (modify — RC region only via dual-write)
- .orchestrator/milestones/M026/phases/P03/P03-SUMMARY.md (create at phase close)

## Notes

**Knowledge taxonomy deviation**: Roadmap and FR-13 reference `knowledge/decisions/MEM*.md`, but the actual taxonomy under `knowledge/` has only `patterns/`, `conventions/`, and `lessons/` subdirectories (no `decisions/`). T03 places the two graduated entries under the closest matching existing categories — `patterns/MEM029.md` for the edition-resolution code shape and `conventions/MEM030.md` for the env-var naming rule — matching MEM027's precedent (M025 graduation into `patterns/`). The plan does not create a new `decisions/` directory because no other consumer or scaffolder script currently references it.

**Roadmap parser fix landed pre-plan**: `scripts/state/read-roadmap.sh`'s Risk-field parser previously concatenated trailing em-dash prose into `pdepends`, causing `active-phase` to falsely report P03 as having an unparseable dependency. The parser now truncates Risk to its first token (high|medium|low). This is the same bug-class as the parens-in-Risk fix landed in P02 commit 316411e and is in scope for P03's plan-phase pre-flight. Not an FR — a side fix recorded here for audit.

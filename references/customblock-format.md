# Customblock Format (FR-14 SSOT)

This reference is the FR-14 single source of truth for the prescriptive
custom-block format that `orchestrator:customblock-draft` writes into the
marker-delimited region of `<project-dir>/CLAUDE.md`. It documents the
prescribed 5 sections, the `## Source-Docs` vs `## Entry Points`
branch-dependent variant rule, the marker-delimited write region, the
floor-not-ceiling discipline, the strict-aggregation invariant, the upstream
output source map, and a worked example.

## Prescribed 5 sections

The custom block carries exactly five prescribed H2 sections (the floor — see
the floor-not-ceiling section below for the ceiling rule). One of the middle
sections is branch-dependent.

| # | Header           | Semantic role                                                    |
|---|------------------|------------------------------------------------------------------|
| 1 | `## Project`     | Title, mission, and stack summary derived from the constitution. |
| 2 | `## Stack`       | Per-component tech-stack bullets aggregated from architecture MEMs. |
| 3 | `## Source-Docs` | (variant A) Section headers from the intake pre-spec.            |
| 3 | `## Entry Points`| (variant B) Entry-point bullets from architecture MEMs.          |
| 4 | `## Conventions` | Per-convention bullets aggregated from convention MEMs.          |
| 5 | `## Decisions`   | Per-decision bullets aggregated from decision MEMs.              |

The `## Source-Docs` and `## Entry Points` sections are mutually exclusive —
exactly one of the two appears in any given rendered custom block per the
branch-dependent variant rule below.

## Branch-dependent variant rule

`## Source-Docs` is rendered when an intake pre-spec is present:

- `<project-dir>/.orchestrator/intake/<timestamp>/reconciled-pre-spec.md`
  (FR-9 / `orchestrator:materials-intake` output), OR
- `<project-dir>/.orchestrator/intake/<timestamp>/ideation-pre-spec.md`
  (FR-10 / `orchestrator:ideation` output).

`## Entry Points` is rendered when no intake pre-spec exists but
ingest-codebase architecture MEMs do:

- `<project-dir>/.orchestrator/knowledge/architecture/MEM-*.md`
  (FR-7 / `orchestrator:ingest-codebase` output).

The driver picks the variant based on file presence; operator override is via
removing or relocating the upstream output before re-running with `--force`.

## Marker-delimited write region

The custom block lives between two HTML comment markers in
`<project-dir>/CLAUDE.md`:

```
<!-- BEGIN CUSTOM -->
... custom block content ...
<!-- END CUSTOM -->
```

`templates/project-instruction.md` (M001) defines this marker convention. The
driver writes only between the markers; content outside the markers is
untouched. If `CLAUDE.md` exists but lacks the markers, the driver appends a
fresh marker block at the end of the file.

## Floor-not-ceiling discipline

The 5 prescribed sections are a **floor**, not a **ceiling** (US-7 AS-2).
Operators MAY add additional H2 sections inside the custom block (for example
`## Notes`, `## Open Questions`, `## Local Overrides`). The driver scans the
existing custom block before each write and preserves any non-prescribed H2
section verbatim, appending it to the new draft after the prescribed 5
sections. This ensures `--force` regenerations and re-runs never silently
discard operator additions outside the prescribed set.

(Within the prescribed sections, `--force` does discard prior operator edits;
this is documented in the `orchestrator:customblock-draft` Idempotency
section and signaled by the stderr warning `--force discards prior operator
edits`. US-7 AS-3 covers the no-force preserve-byte-identical case; US-7 AS-4
covers the with-force regeneration warning.)

## Strict-aggregation invariant

The `customblock-draft.sh` driver MUST NOT invoke any LLM, MUST NOT call
conversus, and MUST NOT route through any model-selection path. Every line
emitted into the custom block traces verbatim to a file under
`<project-dir>/.orchestrator/{memory,knowledge,intake}/`. This is the
**no LLM** discipline mandated by **Constitution XV** (Strict Aggregation
Discipline). The driver's job is mechanical aggregation of upstream outputs;
the upstream sub-flows (`orchestrator:constitution`, `orchestrator:ingest-codebase`,
`orchestrator:materials-intake`, `orchestrator:ideation`) are the layers
that interact with the operator and any model-routed components.

The `tools/verify/m033-p05-customblock-draft-sh-shape.sh` shape verifier
enforces this invariant via negative-grep: occurrences of `conversus`,
`model_routing`, `claude-code.*--task`, or `scripts/dispatch` in the driver's
non-comment code path cause the verifier to fail.

## Upstream output source map

| Section          | Source path (under `<project-dir>/`)                                                  |
|------------------|---------------------------------------------------------------------------------------|
| `## Project`     | `.orchestrator/memory/constitution.md`                                                |
| `## Stack`       | `.orchestrator/knowledge/architecture/MEM-*.md`                                       |
| `## Source-Docs` | `.orchestrator/intake/<timestamp>/reconciled-pre-spec.md` or `ideation-pre-spec.md`   |
| `## Entry Points`| `.orchestrator/knowledge/architecture/MEM-*.md`                                       |
| `## Conventions` | `.orchestrator/knowledge/conventions/MEM-*.md`                                        |
| `## Decisions`   | `.orchestrator/knowledge/decisions/MEM-*.md` (incl. `MEM-DR-*` rich-context cross-references) |

Every bullet emitted by the driver carries a `[source: <basename>]` provenance
suffix so downstream readers can follow the line back to its upstream MEM.

## Worked example

For a fixture that completed US-1 (start), US-2 (constitution authoring), and
US-3 (ingest-codebase) on an existing-codebase branch with no intake artifact,
the rendered custom block looks like:

```
<!-- BEGIN CUSTOM -->

## Project

- Source: .orchestrator/memory/constitution.md
- Title: Acme Storefront Constitution

## Stack

- Next.js 14 + TypeScript [source: MEM-arch-001-frontend.md]
- Postgres 16 + Prisma [source: MEM-arch-002-data.md]
- Vercel deploy target [source: MEM-arch-003-runtime.md]

## Entry Points

- MEM-arch-001-frontend [source: MEM-arch-001-frontend.md]
- MEM-arch-002-data [source: MEM-arch-002-data.md]
- MEM-arch-003-runtime [source: MEM-arch-003-runtime.md]

## Conventions

- 80-char line limit [source: MEM-conv-001-style.md]
- ESLint strict mode [source: MEM-conv-002-lint.md]

## Decisions

- DR-001 chose Prisma over raw SQL [source: MEM-DR-001-prisma.md]
- DR-002 deferred Redis cache [source: MEM-DR-002-cache.md]

<!-- END CUSTOM -->
```

When the same fixture later runs `orchestrator:materials-intake` and produces
`reconciled-pre-spec.md`, a `--force` re-run swaps `## Entry Points` for
`## Source-Docs` populated from the pre-spec's H2 headers. Operator additions
beyond the prescribed 5 sections (e.g., a hand-added `## Notes`) are preserved
verbatim across the regeneration per the floor-not-ceiling discipline.

## See also

- `commands/customblock-draft.md` — the FR-13 command surface.
- `scripts/lifecycle/customblock-draft.sh` — the FR-13 deterministic driver.
- `references/m033-fr21-dual-write-convention.md` — FR-21 dual-write SSOT.
- `templates/project-instruction.md` — `<!-- BEGIN CUSTOM -->` marker source.

---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M036"
name: "Taxonomy SSOT + frontmatter contract + tier-policy YAML + shape verifiers"
depends_on: []
---

## Prerequisites

- Working tree at `~/Sites/orchestrator/` with `references/` directory present (existing, populated with 21 reference docs).
- `tools/verify/` directory may exist; create it via `mkdir -p tools/verify` if absent (project-owned verifier home per AD-19 path discipline; framework verifiers live under `scripts/verify/` and ship in the install bundle).
- `specs/033-reference-corpus-ingest/spec.md` exists and is the binding contract — FR-1 (taxonomy), FR-2 (provenance frontmatter), FR-4 (chunk-output shape additions), FR-17 (tier-policy declaration), and #Q-8 (per-category default tier proposals) are the requirements this task transcribes into SSOT files.
- T01 is the head of P00; no upstream task dependencies.

## Description

Author three declarative SSOT files that downstream phases (P02 extract, P04 ingest classifier, P05 graph traverser, P08 wiki nav) consume without modification — plus three structural shape verifiers that gate each file's contract. These three files are the load-bearing P00 deliverable: every M036 chunk lifecycle (extract → ingest → graph → dispatch → wiki) reads these to know what is in-policy.

The three SSOT files:

1. `references/reference-taxonomy.md` — names the four reference categories with definitions + example `cite_id` slugs (FR-1).
2. `references/reference-frontmatter-contract.md` — names every required FR-2 frontmatter field + chunk-output FR-4 additions + graph-edge fields (FR-5).
3. `references/reference-source-types.yaml` — declares the per-category default-tier policy (FR-17 + #Q-8 resolution).

The three shape verifiers (`tools/verify/p00-taxonomy-shape.sh`, `p00-frontmatter-contract-shape.sh`, `p00-source-types-shape.sh`) run `grep -q` checks per required header / field / key to assert structure. They do not validate semantics — semantic enforcement lands in T03's chunk-frontmatter validator library.

T01 ships ONLY taxonomy / contract / tier-policy + their shape verifiers. Edge types and adapter registry are T02; scope-tag extension and chunk validator are T03; phase-suite aggregator is T03.

## Steps

1. **Create `tools/verify/` if absent** (project-owned per AD-19): `mkdir -p tools/verify`.

2. **Author `references/reference-taxonomy.md`.** Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-taxonomy
   milestone: "M036"
   phase: "P00"
   created_at: "2026-05-01"
   ---

   # Reference Corpus Taxonomy (M036 SSOT)

   The orchestrator's reference-corpus ingest (M036, spec
   `specs/033-reference-corpus-ingest/spec.md`) recognizes a closed
   four-category taxonomy. Files declared with a `category` field
   outside this list are rejected at ingest (FR-1 / US-1 acceptance
   scenario 3).

   This file is the single source of truth (Principle XI). Consumers:
   - `scripts/knowledge/ingest-reference.sh` (P04) — classifier
   - `scripts/dispatch/extract.sh` (P02) — manifest validation
   - `scripts/wiki/build-nav.sh` (P08) — top-level nav generation
   - `references/reference-source-types.yaml` (P00) — keys must match

   Adding or removing a category requires a follow-on M036 D-row in
   [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) and a coordinated update across the
   four consumers above. Do not hardcode the list in any consumer.

   ## Categories

   ### cms-rule
   CMS-published regulatory rule. Citation-grade; small (typically
   <50 pages); structure (sections, tables) matters for verbatim
   quoting. Default extraction tier: 2 (clean structured Markdown).
   Example `cite_id`: `cms-rule-483-20`.

   ### training-material
   SME-authored training content (e.g., PBJ Circle decks). Already
   prose; relatively small; high reference value across many
   validator agents. Default extraction tier: 2. Example `cite_id`:
   `training-pbj-circle-2024-08`.

   ### glossary
   Definitional content (term → definition mappings). Frequently
   cited in narrow excerpts. Default extraction tier: 2. Example
   `cite_id`: `glossary-pbj-2024`.

   ### regulatory-doc
   Long-form regulatory documents (CMS state operations manuals,
   guidance bulletins). Often hundreds of pages; clean Markdown
   conversion is expensive and produces a worse retrieval surface
   than searchable plain text + read-section workflows. Default
   extraction tier: 1 (searchable text via `pdftotext -layout`).
   Example `cite_id`: `regulatory-cms-som-app-pp`.
   ```

   The four `### <category>` headings are load-bearing — the shape
   verifier greps for each of `cms-rule`, `training-material`,
   `glossary`, `regulatory-doc` plus the `## Categories` parent
   heading.

3. **Author `references/reference-frontmatter-contract.md`.** Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-frontmatter-contract
   milestone: "M036"
   phase: "P00"
   created_at: "2026-05-01"
   ---

   # Reference Chunk Frontmatter Contract (M036 SSOT)

   Every reference markdown file ingested by `orchestrator:ingest`
   into `knowledge/reference/<category>/REF-<cat>-<id>.md` MUST
   carry the following frontmatter. Files missing required fields
   are rejected at ingest (FR-2 / US-1 acceptance scenario 2).

   ## Required Fields

   - `source` — operator-facing identifier of the publishing body
     (e.g., `cms`, `sme-pbj-circle`, `internal-glossary`). String.
   - `published` — publication date in `YYYY-MM-DD` format. The
     extractor MAY auto-derive this from PDF/DOCX metadata; the
     operator manifest is the override path (Assumption A-2).
   - `version` — operator-supplied version string. Free-form;
     orchestrator does not parse semver. The supersede chain
     (FR-10) is content-hash-driven, not version-string-driven —
     `version` is human-facing only.
   - `cite_id` — unique stable identifier for citation. Must be
     unique within an ingest pass; duplicates are rejected (Edge
     Cases — "Two reference files declare the same `cite_id`").
   - `topic_tags` — YAML list (may be empty). Free-form tags
     consumed by dispatch injection (FR-7) for topic-scoped
     retrieval.
   - `applies_to_field` — YAML list (may be empty). Field names
     this content authoritatively governs (e.g., `staff_count`,
     `census`). Consumed by dispatch injection (FR-7) for
     field-scoped retrieval.

   ## Chunk-Output Additions

   Fields the ingest classifier writes into the emitted chunk's
   frontmatter (in addition to preserving the FR-2 fields above):

   - `category` — one of the four taxonomy values
     (`cms-rule|training-material|glossary|regulatory-doc`). See
     `references/reference-taxonomy.md`.
   - `chunk_id` — the assigned `REF-<cat>-<id>` slug.
   - `content_hash` — sha256 of the chunk body. Drives idempotent
     re-ingest (FR-9) and the supersede chain (FR-10).
   - `scope_tags` — YAML list of orchestrator scope tags
     (`[project]`, `[milestone:M###]`, `[source:<cite_id>]`, etc.).
     The `[source:...]` namespace is M036-introduced — see
     `references/file-formats.md` `### Scope Tags`.

   ## Graph Edge Fields

   Fields the ingest classifier interprets as graph edges into the
   `KNOWLEDGE-INDEX.md` graph. Each is a YAML list of `chunk_id`
   targets. Edge directionality is declared in
   `references/reference-edge-types.md`.

   - `cites` — chunk → reference. New in M036. Directional.
   - `derived_from` — chunk → upstream-source-chunk. New in M036.
     Directional (downstream → upstream).
   - `applies_to_field` — chunk → field-name. New in M036.
     (Note: `applies_to_field` is BOTH a frontmatter field name
     AND an edge type — the field is interpreted as an edge by
     the graph layer.)
   - `relates_to` — bidirectional. Pre-existing (M011/[M020](../../../../../milestones/M020/index.md)).
     Listed for completeness; not authored by M036.
   - `supersedes` — directional (newer → older). Pre-existing.
     Listed for completeness; not authored by M036.

   ## Validation

   Frontmatter validation is mechanical: `tools/verify/lib/p00-validate-chunk-frontmatter.sh`
   (T03 deliverable) reads stdin and rejects any chunk whose
   `category` is outside the taxonomy or whose `tier` (when
   present, used by the extract command) is outside `{0, 1, 2}`.
   ```

   The shape verifier greps for the four section headings
   (`## Required Fields`, `## Chunk-Output Additions`,
   `## Graph Edge Fields`, plus a `## Validation` section as a
   forward pointer) and every required-field name.

4. **Author `references/reference-source-types.yaml`.** Required structure:

   ```yaml
   # references/reference-source-types.yaml
   #
   # M036 SSOT for per-category default extraction tier (FR-17).
   # Consumers:
   #   - scripts/dispatch/extract.sh (P02) — resolves `tier` for
   #     manifest entries that don't declare a per-document override.
   #
   # The keys of `source_types:` MUST match the four categories in
   # references/reference-taxonomy.md exactly (Principle XI). The
   # taxonomy SSOT and this file are kept in lockstep — adding or
   # removing a category requires updating both files in the same
   # commit, gated by the M036 D-row that authorizes the change.
   #
   # `default_tier` is one of {0, 1, 2}. Out-of-enum values are
   # rejected by tools/verify/lib/p00-validate-chunk-frontmatter.sh
   # (T03 deliverable).
   #
   # Default rationales (per spec #Q-8 resolution at planning):
   #   - cms-rule:          2  (small, citation-grade, structure matters)
   #   - training-material: 2  (already prose, cheap LLM upgrade)
   #   - glossary:          2  (definitional, frequently cited)
   #   - regulatory-doc:    1  (long-form, clean conversion expensive;
   #                            grep+read-section is the load-bearing
   #                            retrieval pattern)

   schema_version: "1.0"
   type: reference-source-types
   milestone: "M036"
   phase: "P00"

   source_types:
     cms-rule:
       default_tier: 2
       rationale: "small, citation-grade, structure matters"
     training-material:
       default_tier: 2
       rationale: "already prose, cheap LLM upgrade"
     glossary:
       default_tier: 2
       rationale: "definitional, frequently cited"
     regulatory-doc:
       default_tier: 1
       rationale: "long-form; grep+read-section retrieval pattern"
   ```

   The shape verifier greps for the `source_types:` map header and
   each of the four taxonomy keys with `default_tier:` present.

5. **Author `tools/verify/p00-taxonomy-shape.sh`.** Bash 3.2-compatible. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-taxonomy-shape.sh — M036 P00 T01 shape gate for
   # references/reference-taxonomy.md. Asserts frontmatter + ## Categories
   # heading + each of the four taxonomy categories appears as a level-3
   # heading. Single-script-file shape per AD-19.
   set -eu
   FILE="${1:-references/reference-taxonomy.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-taxonomy-shape.sh pass=0 fail=1"
     exit 1
   fi
   for token in 'schema_version' 'type: reference-taxonomy' '## Categories' '### cms-rule' '### training-material' '### glossary' '### regulatory-doc'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   echo "SUMMARY: p00-taxonomy-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Use `grep -qF` (fixed-string) to avoid regex confusion. Loop over
   token list — single command per iteration, no compound shells.

6. **Author `tools/verify/p00-frontmatter-contract-shape.sh`.** Same structural pattern as the taxonomy verifier. Token list:

   - `schema_version`
   - `type: reference-frontmatter-contract`
   - `## Required Fields`
   - `source`
   - `published`
   - `version`
   - `cite_id`
   - `topic_tags`
   - `applies_to_field`
   - `## Chunk-Output Additions`
   - `category`
   - `chunk_id`
   - `content_hash`
   - `scope_tags`
   - `## Graph Edge Fields`
   - `cites`
   - `derived_from`
   - `relates_to`
   - `supersedes`

   Same exit conventions and `SUMMARY:` line shape.

7. **Author `tools/verify/p00-source-types-shape.sh`.** Same pattern; token list:

   - `schema_version`
   - `type: reference-source-types`
   - `source_types:`
   - `cms-rule:`
   - `training-material:`
   - `glossary:`
   - `regulatory-doc:`
   - `default_tier:`

   Same exit conventions.

8. **Self-check.** Run all three verifiers from repo root:

   ```bash
   bash tools/verify/p00-taxonomy-shape.sh
   bash tools/verify/p00-frontmatter-contract-shape.sh
   bash tools/verify/p00-source-types-shape.sh
   ```

   All three exit 0 with `SUMMARY: <name> pass=N fail=0`.

## Must-Haves

This task satisfies these phase truths:

- "`references/reference-taxonomy.md` exists with frontmatter + four categories under `## Categories`" — T01 authors the file; `p00-taxonomy-shape.sh` gates.
- "`references/reference-frontmatter-contract.md` exists naming every FR-2 / FR-4 / FR-5 field" — T01 authors; `p00-frontmatter-contract-shape.sh` gates.
- "`references/reference-source-types.yaml` exists with four-key `source_types:` map and `default_tier:` per category" — T01 authors; `p00-source-types-shape.sh` gates.

This task does NOT satisfy:

- The edge-type SSOT truth (T02 deliverable).
- The adapter registry TSV truth (T02 deliverable).
- The scope-tag extension truths (T03).
- The taxonomy-rejects-unknown negative-test truth (T03).
- The phase-suite aggregator truth (T03).

## Verification

```bash
bash tools/verify/p00-taxonomy-shape.sh
bash tools/verify/p00-frontmatter-contract-shape.sh
bash tools/verify/p00-source-types-shape.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` on success and exits 0.

## Inputs

### From Previous Tasks

- None (T01 is the head of P00).

### From Disk (Pre-existing)

- `specs/033-reference-corpus-ingest/spec.md` — FR-1 (closed taxonomy with the four named categories), FR-2 (six required frontmatter fields), FR-4 (chunk-output additions), FR-5 (three new edge types — informational here; T02 owns), FR-17 (tier-policy with per-category defaults), #Q-8 (default-tier proposals). Authoritative content source.
- `references/file-formats.md` — line 649 declares the existing `### Scope Tags` table. T01 does not modify this file (T03 does); T01 references it informationally in the frontmatter contract's `scope_tags` description.
- `references/` — 21 existing reference docs. T01 adds three new files (`reference-taxonomy.md`, `reference-frontmatter-contract.md`, `reference-source-types.yaml`) without modifying any existing files.

## Constraints

- **Bash 3.2 compatibility**: verifier scripts MUST NOT use `mapfile`/`readarray`, `declare -A`, process substitution `<(...)`, `&>`, or `${var^^}`. Use plain loops with `grep -qF` (fixed-string) — no `$(...)` containing pipes.
- **Single-script-file Truth Check shape (AD-19)**: each verifier is a standalone script invoked as `bash tools/verify/<name>.sh`. No inline compound bash, no plain subshells, no `$(...)` containing a pipe.
- **No semantic validation here**: T01 verifiers are *structural* (does the file contain the required headings / field names / map keys?). Semantic enforcement (does a synthetic chunk with `category: blog-post` actually fail validation?) is T03's job via `tools/verify/lib/p00-validate-chunk-frontmatter.sh` + `tools/verify/p00-taxonomy-rejects-unknown.sh`.
- **CON-2 (cli-first-bash)**: all new scripts are POSIX-sh / Bash 3.2 portable. No Python, no jq hard dependency.
- **CON-5 (no-spec-chunk-schema-change)**: T01 adds new SSOT files; does not modify any existing spec-chunk frontmatter / file layout / chain-walking rules.
- **Principle XI (Single Source of Truth)**: the taxonomy categories are listed in exactly two places — `reference-taxonomy.md` (authoritative) and `reference-source-types.yaml` (keys MUST match). The shape verifier checks both files independently; semantic equivalence is enforced informationally in commentary.

## Expected Output

- `references/reference-taxonomy.md` — created, ≥40 lines, four `### <category>` headings.
- `references/reference-frontmatter-contract.md` — created, ≥60 lines, four section headings + every required field name.
- `references/reference-source-types.yaml` — created, ≥30 lines, four-key `source_types:` map.
- `tools/verify/p00-taxonomy-shape.sh` — created, exits 0 against the new taxonomy file.
- `tools/verify/p00-frontmatter-contract-shape.sh` — created, exits 0 against the new contract file.
- `tools/verify/p00-source-types-shape.sh` — created, exits 0 against the new source-types YAML.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-taxonomy-shape.sh` → stdout ends with `SUMMARY: p00-taxonomy-shape.sh pass=7 fail=0`, exit 0.
- `bash tools/verify/p00-frontmatter-contract-shape.sh` → stdout ends with `SUMMARY: p00-frontmatter-contract-shape.sh pass=19 fail=0`, exit 0.
- `bash tools/verify/p00-source-types-shape.sh` → stdout ends with `SUMMARY: p00-source-types-shape.sh pass=8 fail=0`, exit 0.

Per the planner-template Section-Discipline rule, expected output stays under `## Notes` — everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.

Path discipline (AD-19): all new verifier scripts live under `tools/verify/` (project-owned, slug-bearing filenames `p00-*-shape.sh`). The framework-owned verifier directory `scripts/verify/` is bulk-staged in downstream projects and gitignored — project-owned scripts there are at risk of install-clobber. Stay under `tools/verify/`.

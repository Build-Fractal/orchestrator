---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M036"
goal: "Establish the M036 reference-corpus foundation as five SSOT artifacts (taxonomy, frontmatter contract, source-type tier-policy YAML, format-adapter registry TSV, edge-type list) plus the additive [source:...] tag-namespace extension to the existing scope-tag grammar — every downstream phase (P01 adapters, P02 extract, P04 ingest, P05 graph) reads these files; no list is hardcoded in scripts."
demo_sentence: "An operator runs `cat references/reference-taxonomy.md`, `cat references/reference-source-types.yaml`, and `cat scripts/dispatch/adapters/format/registry.tsv` and observes the four-category taxonomy (cms-rule / training-material / glossary / regulatory-doc), the per-category default-tier policy (e.g., `cms-rule: 2`), and the four-row live-adapter table (markdown / pdf / docx / xlsx, one currently `status=stub` row permitted as a placeholder until P01 lands real adapters); runs `bash tools/verify/m036-p00-phase-suite.sh` and observes `SUMMARY: m036-p00-phase-suite.sh pass=N fail=0` with exit 0; runs `bash tools/verify/p00-taxonomy-rejects-unknown.sh` and observes that a synthetic chunk declaring `category: blog-post` or `tier: 5` is rejected by the taxonomy/tier-policy validator harness."
risk: "low"
depends_on: []
---

## Boundary Map

**Produces** (consumed by P01–P07 of M036a, plus M036b):

- `references/reference-taxonomy.md` — SSOT for the four reference categories (`cms-rule`, `training-material`, `glossary`, `regulatory-doc`). Read by: P02 extract command (validates manifest-declared categories), P04 ingest classifier (rejects out-of-taxonomy chunks per FR-1), P08 wiki nav generator (organizes nav under `Reference > <Category>`).
- `references/reference-frontmatter-contract.md` — SSOT for required + optional reference-chunk frontmatter fields (FR-2 + FR-4). Read by: P02 extract (auto-derived field policy), P04 ingest (validation), P05 graph (edge-bearing field list).
- `references/reference-source-types.yaml` — per-category default tier policy (FR-17). Read by: P02 extract command (resolves `tier` for un-overridden manifest entries).
- `references/reference-edge-types.md` — SSOT enumerating the three new directional edge types (`cites`, `derived_from`, `applies_to_field`) alongside the existing `relates_to` / `supersedes` (informationally listed; their authoring milestones own them per CON-5). Read by: P05 graph traverser extension (additive edge-type registration).
- `scripts/dispatch/adapters/format/registry.tsv` — adapter dispatch table seam (FR-13 surface). At P00 close the registry lists four rows (`markdown`, `pdf`, `docx`, `xlsx`) with `status=stub` placeholders pointing at not-yet-authored scripts; P01 lands the live adapter scripts and flips the rows to `status=live`. Read by: P02 extract command (resolves format → adapter script path).
- Additive scope-tag grammar extension: `[source:<cite_id>]` tag namespace added to `references/file-formats.md` (the SSOT for the Scope Tags table at line ~649) **and** cross-referenced from `references/spec-management.md` (per the roadmap's literal target). Consumed by: scope-filter ([M005](../../../../milestones/M005/index.md)), dispatch context-builder (P07).

**Consumes**:

- `references/file-formats.md` — existing Scope Tags table (`### Scope Tags` at line 649 of file-formats.md). P00 appends a fourth row for the `[source:<cite_id>]` namespace.
- `references/spec-management.md` — receives a one-paragraph cross-reference pointer to the file-formats.md scope-tag table plus a note that `[source:...]` is operator-asserted, not factually verified (see #Q-7 in the spec).
- Existing dispatch-adapter convention at `scripts/dispatch/adapters/{backend,format,runtime,tool}/` (introduced by M005). P00 adds the `format/` registry seam without modifying the existing two format adapter scripts (`native.sh`, `speckit.sh`); those are unrelated to reference extraction.
- `specs/033-reference-corpus-ingest/spec.md` — FR-1, FR-2, FR-4, FR-5, FR-6, FR-13, FR-17 are the binding contracts P00 transcribes.

P00 is dependency-free and the head of the M036a critical path. P01 (Tier 1 live adapters) and P05 (graph schema extension) both consume P00 outputs and can execute in parallel windows after P00 closes (per `M036-ROADMAP.md` execution windows).

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Verifier scripts live under tools/verify/ — project-owned path,
     slug-bearing filenames so install-clobber risk is contained.
     Each verifier is co-authored alongside its corresponding artifact
     within the SAME task (plan-time discipline rule 2). -->

### Truths

- `references/reference-taxonomy.md` exists with YAML frontmatter (`schema_version: "1.0"`, `type: reference-taxonomy`, `milestone: "M036"`, `phase: "P00"`) and declares exactly the four categories `cms-rule`, `training-material`, `glossary`, `regulatory-doc` in a body section titled `## Categories` (each category appears as a level-3 heading `### <category>` with a one-paragraph definition + an example `cite_id` slug).
  - Check: `bash tools/verify/p00-taxonomy-shape.sh`

- `references/reference-frontmatter-contract.md` exists with frontmatter (`schema_version: "1.0"`, `type: reference-frontmatter-contract`) and a body that names every required FR-2 field (`source`, `published`, `version`, `cite_id`, `topic_tags`, `applies_to_field`) under a `## Required Fields` section, every additional FR-4 chunk-output field (`category`, `chunk_id`, `content_hash`, `scope_tags`) under `## Chunk-Output Additions`, and every graph-edge-bearing field (`cites`, `derived_from`, `applies_to_field`, `relates_to`, `supersedes`) under `## Graph Edge Fields`.
  - Check: `bash tools/verify/p00-frontmatter-contract-shape.sh`

- `references/reference-source-types.yaml` exists with frontmatter-style top-of-file comment header pointing at `## Source Types` in `references/reference-source-types.md` (or inline in this YAML — see frontmatter contract), and a `source_types:` map containing exactly the four taxonomy keys with a `default_tier:` value in the closed enum `{0, 1, 2}` for each. Defaults declared per spec #Q-8: `cms-rule: 2`, `training-material: 2`, `glossary: 2`, `regulatory-doc: 1`.
  - Check: `bash tools/verify/p00-source-types-shape.sh`

- `references/reference-edge-types.md` exists with frontmatter (`schema_version: "1.0"`, `type: reference-edge-types`) and a body section `## Edge Types` listing five edges — three new (`cites`, `derived_from`, `applies_to_field`) authored by M036, and two pre-existing (`relates_to`, `supersedes`) cross-referenced for completeness — each with a one-line directionality declaration (`directional from <source> → <target>` or `bidirectional`).
  - Check: `bash tools/verify/p00-edge-types-shape.sh`

- `scripts/dispatch/adapters/format/registry.tsv` exists with a TSV header line (`format	adapter_path	status	notes`) and exactly four data rows (one per format: `markdown`, `pdf`, `docx`, `xlsx`). Each row's `adapter_path` resolves to a script path under `scripts/dispatch/adapters/format/<format>.sh` (the script need NOT exist at P00 close — P01 authors the live adapters; P00 declares the seam). Each row's `status` is one of `live | stub | planned`. At P00 close, all four rows are `status=stub` (placeholder); P01 flips them to `status=live`.
  - Check: `bash tools/verify/p00-adapter-registry-shape.sh`

- `references/file-formats.md` `### Scope Tags` table contains a fourth row introducing the `[source:<cite_id>]` namespace, with a one-line "Applies to" description naming the M036 reference-corpus feature. The existing three rows (`project`, `milestone:M001`, `phase:M001/P02`) are preserved verbatim (CON-1 / CON-5 — no schema change to existing namespaces).
  - Check: `bash tools/verify/p00-scope-tag-extension.sh`

- `references/spec-management.md` contains a cross-reference paragraph pointing to `references/file-formats.md#scope-tags` and explicitly mentioning `[source:<cite_id>]` as the M036-introduced namespace, satisfying the roadmap's literal "added to references/spec-management.md scope-tag grammar section" directive while keeping the SSOT in file-formats.md (Principle XI).
  - Check: `bash tools/verify/p00-spec-management-crossref.sh`

- The taxonomy and tier-policy validators reject out-of-taxonomy categories and out-of-{0,1,2} tiers. The verifier `tools/verify/p00-taxonomy-rejects-unknown.sh` runs the validator helper `tools/verify/lib/p00-validate-chunk-frontmatter.sh` against three synthetic stdin fixtures — (a) `category: blog-post` (out of taxonomy → must reject with non-zero exit), (b) `tier: 5` (out of enum → must reject), (c) `category: cms-rule, tier: 2` (in-policy → must accept) — and asserts the verdicts match.
  - Check: `bash tools/verify/p00-taxonomy-rejects-unknown.sh`

- `bash tools/verify/m036-p00-phase-suite.sh` invokes all seven P00 gates (taxonomy-shape, frontmatter-contract-shape, source-types-shape, edge-types-shape, adapter-registry-shape, scope-tag-extension, spec-management-crossref, taxonomy-rejects-unknown) in order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: m036-p00-phase-suite.sh pass=N fail=M` before exit.
  - Check: `bash tools/verify/m036-p00-phase-suite.sh`

### Artifacts

- `references/reference-taxonomy.md` (min 40 lines, contains "schema_version", contains "type: reference-taxonomy", contains "## Categories", contains "cms-rule", contains "training-material", contains "glossary", contains "regulatory-doc") — create
- `references/reference-frontmatter-contract.md` (min 60 lines, contains "schema_version", contains "type: reference-frontmatter-contract", contains "## Required Fields", contains "source", contains "published", contains "version", contains "cite_id", contains "topic_tags", contains "applies_to_field", contains "## Chunk-Output Additions", contains "content_hash", contains "## Graph Edge Fields", contains "cites", contains "derived_from", contains "relates_to", contains "supersedes") — create
- `references/reference-source-types.yaml` (min 30 lines, contains "source_types:", contains "cms-rule:", contains "training-material:", contains "glossary:", contains "regulatory-doc:", contains "default_tier:") — create
- `references/reference-edge-types.md` (min 30 lines, contains "schema_version", contains "type: reference-edge-types", contains "## Edge Types", contains "cites", contains "derived_from", contains "applies_to_field", contains "relates_to", contains "supersedes") — create
- `scripts/dispatch/adapters/format/registry.tsv` (min 5 lines, contains "format", contains "adapter_path", contains "status", contains "markdown", contains "pdf", contains "docx", contains "xlsx") — create
- `references/file-formats.md` (min 1 added line in scope-tags table, contains "source:<cite_id>") — modify
- `references/spec-management.md` (min 3 added lines, contains "[source:", contains "file-formats.md") — modify
- `tools/verify/p00-taxonomy-shape.sh` (min 25 lines, contains "## Categories", contains "cms-rule", contains "training-material", contains "glossary", contains "regulatory-doc") — create
- `tools/verify/p00-frontmatter-contract-shape.sh` (min 25 lines, contains "Required Fields", contains "Chunk-Output Additions", contains "Graph Edge Fields") — create
- `tools/verify/p00-source-types-shape.sh` (min 25 lines, contains "source_types:", contains "default_tier:") — create
- `tools/verify/p00-edge-types-shape.sh` (min 20 lines, contains "Edge Types", contains "cites", contains "derived_from", contains "applies_to_field") — create
- `tools/verify/p00-adapter-registry-shape.sh` (min 25 lines, contains "format", contains "markdown", contains "pdf", contains "docx", contains "xlsx") — create
- `tools/verify/p00-scope-tag-extension.sh` (min 15 lines, contains "[source:", contains "Scope Tags") — create
- `tools/verify/p00-spec-management-crossref.sh` (min 15 lines, contains "[source:", contains "file-formats.md") — create
- `tools/verify/p00-taxonomy-rejects-unknown.sh` (min 30 lines, contains "blog-post", contains "tier: 5", contains "cms-rule") — create
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (min 30 lines, contains "cms-rule", contains "training-material", contains "glossary", contains "regulatory-doc", contains "tier") — create
- `tools/verify/m036-p00-phase-suite.sh` (min 30 lines, contains "SUMMARY:", contains "p00-taxonomy-shape", contains "p00-frontmatter-contract-shape", contains "p00-source-types-shape", contains "p00-edge-types-shape", contains "p00-adapter-registry-shape", contains "p00-scope-tag-extension", contains "p00-spec-management-crossref", contains "p00-taxonomy-rejects-unknown") — create

### Key Links

- `specs/033-reference-corpus-ingest/spec.md` → `references/reference-source-types.yaml` (FR-17 names the per-category tier-policy SSOT)
- `references/reference-taxonomy.md` → `references/reference-source-types.yaml` (taxonomy categories are the keys of the source-types map)
- `references/reference-frontmatter-contract.md` → `references/reference-edge-types.md` (graph-edge fields enumerated in the contract are typed by the edge-types SSOT)
- `references/file-formats.md` → `references/reference-frontmatter-contract.md` (the `[source:<cite_id>]` row's "Applies to" cell points operators at the M036 reference-corpus contract)
- `references/spec-management.md` → `references/file-formats.md` (cross-reference pointing at the scope-tag SSOT table)
- `tools/verify/m036-p00-phase-suite.sh` → `tools/verify/p00-taxonomy-shape.sh` (suite invokes shape gate)
- `tools/verify/m036-p00-phase-suite.sh` → `tools/verify/p00-taxonomy-rejects-unknown.sh` (suite invokes negative-test gate)

## Tasks

### T01: Taxonomy SSOT + frontmatter contract + tier-policy YAML + their shape verifiers

See `tasks/T01-taxonomy-and-contract-PLAN.md`.

### T02: Edge-type SSOT + adapter registry TSV seam + their shape verifiers

See `tasks/T02-edge-types-and-registry-PLAN.md`.

### T03: Scope-tag namespace extension + chunk-frontmatter validator + phase-suite gate

See `tasks/T03-scope-tag-and-validator-PLAN.md`.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03
```

Linear chain. T01 lands the three "declarative content" SSOT files (taxonomy + frontmatter contract + source-types YAML) plus their three structural shape verifiers — these are the load-bearing taxonomy/contract/tier-policy artifacts the phase exists to declare. T02 lands the edge-type SSOT (read by P05) plus the adapter registry TSV seam (read by P02 + flipped by P01) plus their shape verifiers — both are seams that downstream phases extend, and both can be authored once the taxonomy/contract are pinned. T03 lands the additive scope-tag-namespace extension (touches existing file-formats.md + spec-management.md), the chunk-frontmatter validator library that demonstrates the taxonomy + tier-policy actually reject out-of-policy values (proves the demo sentence's "fail validation if they declare a category outside the taxonomy or a tier outside {0, 1, 2}" property), and the phase-suite aggregator gate. T03 cannot pass without T01's + T02's verifier scripts present.

## Files Likely Touched

- `references/reference-taxonomy.md` (create) — T01
- `references/reference-frontmatter-contract.md` (create) — T01
- `references/reference-source-types.yaml` (create) — T01
- `references/reference-edge-types.md` (create) — T02
- `scripts/dispatch/adapters/format/registry.tsv` (create) — T02
- `references/file-formats.md` (modify — append fourth row to `### Scope Tags` table) — T03
- `references/spec-management.md` (modify — append cross-reference paragraph) — T03
- `tools/verify/p00-taxonomy-shape.sh` (create) — T01
- `tools/verify/p00-frontmatter-contract-shape.sh` (create) — T01
- `tools/verify/p00-source-types-shape.sh` (create) — T01
- `tools/verify/p00-edge-types-shape.sh` (create) — T02
- `tools/verify/p00-adapter-registry-shape.sh` (create) — T02
- `tools/verify/p00-scope-tag-extension.sh` (create) — T03
- `tools/verify/p00-spec-management-crossref.sh` (create) — T03
- `tools/verify/p00-taxonomy-rejects-unknown.sh` (create) — T03
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` (create) — T03
- `tools/verify/m036-p00-phase-suite.sh` (create) — T03

<!-- The phase plan and task plan files themselves (this file +
     tasks/T0[1-3]-*-PLAN.md) are written by the planner, not by the
     executor — they are not listed here. -->

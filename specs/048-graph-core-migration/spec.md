---
schema_version: "1.0"
type: feature-spec
feature_slug: "048-graph-core-migration"
created_at: "2026-08-17"
status: "Ready-for-discuss"
milestone: "M047"
---

# Feature Specification: 048-graph-core-migration

**Feature Branch**: `048-graph-core-migration`
**Created**: 2026-08-17
**Last Revised**: 2026-08-17
**Status**: Ready-for-discuss
**Milestone**: M047
**Input**: User description: "Orchestrator v2 graph core and migration (M047): unify the file-based knowledge families (MEMs, spec chunks, decisions, reference corpus) and execution-log lineage into one typed SQLite+FTS5 knowledge graph with provenance invariants, temporal validity, supersede chains, validation-before-write, hybrid lexical retrieval (FTS+IDF+recency+RRF), CLI query primitives, importers for every existing family, and a rebuild-from-markdown invariant. Markdown stays source of truth. Amends the bash-only dependency posture. Foundation for the v2 runway: M048 MCP surface + ambient capture, M049 graph-native auto mode, M050 onboarding parity. Per proposal orchestrator-v2-graph-native.md."

## Problem Statement

The orchestrator's knowledge layer is its differentiated asset, but it is fragmented into parallel file-based families — MEMs under `knowledge/{patterns,conventions,lessons}/`, spec chunks, the reference corpus, `DECISIONS.md` rows, and execution-log JSONL — each with its own ad-hoc read path. There is no single query surface: retrieval is grep-over-`KNOWLEDGE-INDEX.md` plus family-specific parsing buried inside `build-context.sh`, and M044 proved this injection-only architecture silently degrades (verified bugs B-1..B-4, G-1/G-3) with no observable signal when knowledge stops flowing.

Three concrete pain-points follow from this gap. First, **recall is not guaranteed**: an agent (or the operator's plain Claude Code session) has no way to ask "what does this project already know about X" and trust the answer covered every family — the operator's stated top pain is "making sure all the knowledge is always considered and quick and easy to look up." Second, **lineage is invisible**: execution-log JSONL records what ran, but no query can mechanically answer "what produced this artifact" or "which decision does this claim descend from" — decisions and their provenance are load-bearing for SME trust and currently exist only as prose rows. Third, **ranking is absent**: when multiple entries match, nothing orders them by relevance, recency, or rarity, so payload assembly either over-includes (token waste) or truncates blind (silent knowledge loss).

The minimum surface that fixes all three is a single typed graph store — SQLite with FTS5 — populated by deterministic importers from every existing family, queried through a small CLI offering hybrid lexical retrieval (full-text + IDF weighting + recency decay, fused with reciprocal rank fusion), with provenance and temporal-validity columns on every row and a validation pipeline in front of every write. Markdown remains the human-readable source of truth; the database is a derived, rebuildable index.

This spec explicitly does **not** attempt: the MCP server surface (M048), ambient session capture (M048), embeddings/vector search (deferred behind a measured trigger), the graph-native auto loop (M049), LLM-driven entity resolution or brownfield codebase ingestion at scale (M050), or any change to how MEM/spec/reference markdown files are authored.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

US-1 (unified hybrid query over the imported corpus) + US-2 (deterministic rebuild-from-markdown), exercised against **this repo's own live corpus** (31 MEMs, spec chunks, reference corpus, DECISIONS.md, execution logs). When an agent can run one CLI command and get ranked, provenance-bearing results spanning every knowledge family — and the database can be deleted and rebuilt identically from markdown — the dogfood loop closes: every later phase (lineage, validation, consumer cutover) defends its scope on top of this slice.

### User Story 1 — Unified hybrid knowledge query (Priority: P1)

An agent working a task (or the operator in a plain session) runs `orch-kb search "<query>"` and receives a ranked result list that spans MEMs, spec chunks, decisions, and reference chunks in one pass — each hit carrying its source path, family, node type, provenance fields, and temporal validity. Ranking fuses FTS5 lexical match, IDF term-rarity weighting, and recency decay via reciprocal rank fusion, so a rare config-flag mention outranks boilerplate and a superseded fact ranks below its successor. This is the recall guarantee the operator named as the top pain: all knowledge considered, one lookup, cheap.

**Why this priority**: Every other v2 surface (M048 MCP tools, context-builder v2, M049 loop context) is a consumer of this query path. Without it the graph is storage with no payoff; with it, even before any consumer cutover, agents gain a trustworthy retrieval primitive.

**Independent Test**: A fixture corpus (≥3 families, ≥20 entries, known-relevant targets per query) plus a query battery with expected-hit assertions. Runs without any other story: import fixture → run battery → assert expected IDs appear in top-K with required fields populated.

**Acceptance Scenarios**:

1. **Given** the fixture corpus is imported, **When** `orch-kb search "budget envelope SIGKILL"` runs, **Then** exit code is 0 and the known-relevant entry appears in the top 5 results with `source_path`, `family`, `node_type`, and `temporal_valid_from` populated.
2. **Given** two entries match a query and one supersedes the other, **When** the search runs, **Then** the superseding entry ranks above the superseded one and the superseded row is marked `superseded_by` in output.
3. **Given** a query matching a rare token that appears in exactly one short entry, **When** the search runs, **Then** that entry appears in the top 3 (IDF weighting observable).

### User Story 2 — Deterministic rebuild from markdown (Priority: P1)

The operator deletes `.orchestrator/graph.db` entirely and runs `orch-kb rebuild`. The importers re-read every markdown family and the execution logs and produce a database whose logical content is identical to the previous build — same row counts, same node/edge sets, same content hashes — with no wall-clock timestamps or nondeterministic identifiers introduced during import. Markdown files remain untouched. This is the invariant that keeps markdown the single source of truth and makes the database safe to gitignore.

**Why this priority**: Co-P1 with US-1 because it is the trust foundation — without deterministic rebuild, the database becomes a second source of truth and violates Principle XI, and corruption or schema evolution would require manual repair instead of `rm && rebuild`.

**Independent Test**: On the fixture corpus (and on this repo's live corpus): build, dump canonical form, delete, rebuild, dump again, diff — empty diff required. Runs independently of query behavior.

**Acceptance Scenarios**:

1. **Given** a populated graph.db, **When** it is deleted and `orch-kb rebuild` runs twice from the same markdown tree, **Then** both runs exit 0 and their canonical dumps (`orch-kb dump --canonical`) are byte-identical.
2. **Given** one MEM file's body is edited and committed, **When** rebuild runs, **Then** exactly that node's `content_hash` and `recency_source_date` change (the latter to the new commit date); `temporal_valid_from` and all other rows are unchanged in the canonical dump diff (gate amendment MIT-1).

### User Story 3 — Lineage and provenance queries (Priority: P2)

An agent (or the operator auditing for an SME) runs `orch-kb why <decision-id>` or `orch-kb lineage <artifact-or-unit-id>` and receives the provenance chain: which unit produced it, which decision governs it, what it superseded, which sources support it. Execution-log JSONL (`unit_close`, dispatch records) is imported as `AgentRun`/`Task`/`Evaluation` nodes with `PRODUCED`/`EVALUATES`/`PARENT_OF` edges, and DECISIONS.md rows become `Decision` nodes with `SUPERSEDES`/`DERIVED_FROM` edges where the row text declares them.

**Why this priority**: P2 because it delivers the never-lose-a-decision promise (operator priority #2, SME trust) but consumes the P1 substrate; it can ship one phase later without blocking the minimal slice.

**Independent Test**: Fixture execution-log + DECISIONS fixture with a known chain (task → artifact → decision → superseded decision); assert `orch-kb why`/`lineage` emit the full expected chain.

**Acceptance Scenarios**:

1. **Given** the fixture chain is imported, **When** `orch-kb why D-FIX-2` runs, **Then** output includes the decision body, its source row location, the unit that recorded it, and the decision it supersedes.
2. **Given** an artifact node produced by a fixture `unit_close` record, **When** `orch-kb lineage <artifact>` runs, **Then** the emitting unit, milestone/phase/task IDs, and outcome appear in the chain.

### User Story 4 — Validation before write (Priority: P2)

Any programmatic write into the graph (importers today; M048 ambient capture tomorrow) passes through a validation pipeline: schema validation → ID/duplicate detection → supersede-chain integrity → contradiction flagging. Malformed entries are rejected with a diagnostic naming the file and field; duplicates are skipped idempotently; a new fact contradicting an existing one is written but flagged `CONTRADICTS` for review rather than silently coexisting or overwriting. Nothing enters the graph silently broken — bad edges compound.

**Why this priority**: P2 because M047's only writers are the deterministic importers, but the pipeline must exist *before* M048 puts an LLM extractor in front of it; building it now means M048 inherits a guarded write path instead of retrofitting one.

**Independent Test**: Fixture files with (a) malformed frontmatter, (b) duplicate IDs, (c) a broken supersede pointer, (d) a contradicting fact pair; assert each produces its defined outcome and diagnostic without corrupting the store.

**Acceptance Scenarios**:

1. **Given** a MEM file with missing required frontmatter, **When** import runs, **Then** the file is skipped, a diagnostic names the path and missing field, remaining files import, and exit code signals partial failure.
2. **Given** two fixture entries with the same ID and different content hashes, **When** import runs, **Then** the second is rejected with a duplicate-ID diagnostic and the first is unchanged.
3. **Given** a supersede pointer to a nonexistent ID, **When** import runs, **Then** the edge is flagged `dangling` in a diagnostics table, not silently dropped.

### User Story 5 — Dependency-posture amendment and health integration (Priority: P3)

The constitution's implicit bash-3.2-only dependency posture is amended (operator-authorized 2026-08-17) via the standard governance path: version bump, rationale, consistency propagation. `sqlite3` (with FTS5) becomes a declared, capability-probed dependency: `orchestrator:init`/`context` report its presence, and `run-doctor.sh` gains a graph-health check (db present, rebuild-clean, row counts vs. file counts, dangling-edge count).

**Why this priority**: P3 because the amendment is text + probes, not architecture; it must land within M047 (the milestone introduces the dependency) but nothing in P1/P2 blocks on the ceremony completing first.

**Independent Test**: Constitution diff shows version bump + rationale; `run-doctor.sh` on a healthy fixture reports graph checks PASS, and on a corrupted fixture reports the specific failure.

**Acceptance Scenarios**:

1. **Given** the amendment lands, **When** the constitution is read, **Then** the dependency-posture section names sqlite3+FTS5 as a declared dependency with the graceful-degrade behavior defined by FR-11.
2. **Given** a graph.db whose MEM row count disagrees with the markdown file count, **When** `run-doctor.sh` runs, **Then** a graph-health warning names the discrepancy.

---

## Edge Cases

- **`sqlite3` absent on host**: `orch-kb` commands exit with a distinct code and a one-line install pointer; consumers treat the graph as unavailable and fall back to the legacy index read path (FR-11). No command may hard-crash mid-pipeline.
- **FTS5 not compiled into the host's sqlite3**: probed at init/rebuild time (`PRAGMA compile_options` / trial virtual-table create); same degrade path as absence, with a diagnostic distinguishing "sqlite3 missing" from "sqlite3 lacks FTS5".
- **Interrupted rebuild (SIGKILL mid-import)**: rebuild writes to `graph.db.tmp` then atomically renames — a killed rebuild leaves the previous db intact (whole-old-or-whole-new, matching the M046 atomic-marker discipline).
- **Concurrent access**: reads are safe (WAL mode); writes serialize behind `lock-manager.sh` best-effort; a second concurrent rebuild refuses to start with a held-lock diagnostic.
- **Markdown edited between build and query**: staleness is detectable — `orch-kb status` compares source-tree content hashes against imported hashes and reports drift count; queries still answer from the last build (stale-but-honest, never silently empty).
- **Mutable metadata (e.g., MEM `hit_count`)**: read-telemetry counters live in the database only (a non-canonical table excluded from the deterministic dump); the markdown frontmatter `hit_count` field is imported as an initial value but never written back — importers never mutate markdown.
- **Very large corpus (brownfield future)**: import is incremental by content hash — unchanged files are skipped on re-import; full-rebuild wall time on this repo's corpus is budgeted by SC-8.
- **Legacy `KNOWLEDGE-INDEX.md` consumers during migration**: the index file continues to be generated and byte-compatible throughout M047 (CON-3); no existing consumer breaks before the M048 cutover.

---

## Functional Requirements

- **FR-1 (typed-schema)**: The graph schema defines node types `{Entity, Claim, Decision, Source, Artifact, AgentRun, Evaluation, Task}` and edge types `{MENTIONS, SUPPORTS, CONTRADICTS, SUPERSEDES, DERIVED_FROM, PRODUCED, EVALUATES, DEPENDS_ON, PARENT_OF, APPLIES_TO}` as SQLite tables with an FTS5 content index; every node row carries `id, node_type, family, source_path, content_hash, temporal_valid_from, temporal_valid_until, recency_source_date, superseded_by, provenance_kind` (source-backed | inference). Temporal-validity columns (`temporal_valid_from`/`temporal_valid_until`) are written exclusively by FR-8 supersede semantics and are immutable on content edits; `recency_source_date` is recomputed by FR-5 on every import — the two concerns are deliberately separate columns (gate amendment MIT-1). A `Metric` node type is deliberately NOT declared until a milestone introduces a writer for it (Principle XIV). Satisfies US-1/US-3. The schema version is stamped in the db and checked by every CLI entry point.
- **FR-2 (write-invariants)**: Every write enforces: (a) every claim has a source or is marked inference; (b) every artifact names an authoring run; (c) every evaluation names a rubric; (d) superseded rows remain addressable (no deletes). Violations are rejected at the validation layer with a named-invariant diagnostic. Satisfies US-4.
- **FR-3 (importers)**: Deterministic importers exist for each family — MEMs (`knowledge/{patterns,conventions,lessons}/MEM*.md`), spec chunks (`specs/*/spec.md` via the existing ingest chunker), reference corpus (`knowledge/reference/**/REF-*.md`), `DECISIONS.md` rows, and execution-log JSONL (`.orchestrator/**/execution-log.jsonl` `unit_close` + dispatch records). Each importer maps its family onto FR-1 types, is idempotent by content hash, and never writes to markdown. **ID construction convention (gate amendment MIT-2)**: families whose labels are globally unique by construction keep bare IDs (Decisions `D###`, MEMs `MEM###`, REF ids); collision-prone families use composite namespaced IDs built from the mandatory `source_path` — spec chunks import as `<feature-slug>/<chunk-label>` (e.g., `048-graph-core-migration/FR-1`), since bare chunk labels (`FR-1`, `US-1`, `SC-1`) repeat across every spec in the repo. Satisfies US-2/US-3.
- **FR-4 (deterministic-rebuild)**: `orch-kb rebuild` produces a canonically-dumpable database that is byte-identical across runs given an identical source tree: no wall-clock timestamps, no random identifiers, stable ordering (Principle IX). Telemetry tables are excluded from the canonical dump. Satisfies US-2.
- **FR-5 (hybrid-retrieval)**: `orch-kb search` ranks via reciprocal rank fusion over at least: FTS5 (BM25) lexical rank, IDF-weighted rare-token rank, and recency-decayed rank. The recency signal reads the `recency_source_date` column, which this FR owns and recomputes on every import; its input precedence is: explicit frontmatter date → last git commit date for the source file (operator-confirmed at clarify, 2026-08-17 — deterministic given identical repo state, preserving FR-4; file mtimes are never used). It never reads or writes `temporal_valid_from` (gate amendment MIT-1). **Implementation commitment (gate amendment MIT-5)**: the ranking formula is math-function-free — IDF via FTS5's built-in `bm25()`, recency via harmonic decay (`1/(1+days_since)`), no transcendental functions — so a stock sqlite3 build without `SQLITE_ENABLE_MATH_FUNCTIONS` suffices. Superseded rows are down-ranked below their successors and labeled. Weights and the RRF smoothing constant are declared in config (Principle X), not hardcoded. Satisfies US-1.
- **FR-6 (cli-primitives)**: A single entry point `scripts/kb/orch-kb.sh` exposes `search`, `why <id>`, `lineage <id>`, `rebuild`, `import <family>`, `status`, `dump --canonical`, `contradictions` — each emitting stable, line-oriented output with a `--json` variant, exit 0 on success, distinct nonzero codes for unavailable-dependency vs. bad-args vs. not-found vs. ambiguous-id. **Bare-ID resolution rule (gate amendments MIT-2 + R2/MIT-2)**: `why`/`lineage` attempt an exact whole-ID match first (bare or composite as given). If no exact match, bare-argument matching compares the argument against the label component of composite IDs (the suffix after the `<feature-slug>/` qualifier) in addition to bare-ID rows; a bare argument matching label components across ≥2 distinct qualifiers triggers the ambiguous-match path, which lists every qualified matching ID and exits with the ambiguous-id code — it never guesses. Matching is whole-label at delimiter boundaries only (`/` qualifier separator; full-string label comparison), so `FR-1` never matches `FR-10` or `FR-1a`. Satisfies US-1/US-3 and is the seam M048's MCP tools wrap.
- **FR-7 (validation-pipeline)**: All writes pass schema validation → duplicate detection → supersede-chain integrity → contradiction flagging, in that order, before any row lands; the pipeline is a distinct module invoked by every importer (and by M048 writers later), with per-stage diagnostics written to a `diagnostics` table and surfaced by `orch-kb status`. Satisfies US-4.
- **FR-8 (temporal-supersede)**: Facts carry `temporal_valid_from`/`temporal_valid_until`, written exclusively by supersede semantics and immutable on content edits (gate amendment MIT-1); supersede writes set `superseded_by` on the old row and a `SUPERSEDES` edge on the new one, generalizing the M036 supersede-chain mechanism; `orch-kb search --as-of <date>` filters on the temporal columns only — never on `recency_source_date` — so an unrelated typo-fix commit can never move a fact's apparent validity window. Satisfies US-1 scenario 2 and US-3.
- **FR-9 (parity-harness)**: A retrieval-parity battery (≥15 queries with expected hits, drawn from this repo's live corpus) runs old-path (grep over `KNOWLEDGE-INDEX.md`) vs. new-path (`orch-kb search`) and asserts the new path's hit-rate ≥ the old path's on every query class; regressions fail the suite. **Hit-equivalence definition (gate amendment MIT-3)**: a graph-node result counts as matching a grep-line hit iff it derives from the same `source_path` — file-level identity, matching the granularity grep-over-the-index already resolves to; line-level granularity is not required. Satisfies US-1 and gates the M048 cutover.
- **FR-10 (constitution-amendment)**: The dependency-posture amendment lands via the governance path (semver bump, rationale, template propagation, CONSTITUTION-LOG/ratification convention as applicable), naming sqlite3+FTS5 a declared capability-probed dependency and defining the degrade contract. Satisfies US-5.
- **FR-11 (graceful-degrade)**: Absence of sqlite3/FTS5 is detected by `scripts/dispatch/detect-capabilities.sh` (new `graph_store` field); the probe also verifies every sqlite3 compile-option/function the FR-5 ranking implementation actually uses (gate amendment MIT-5) and fails loudly with a named diagnostic on drift. `orch-kb` exits with the distinct unavailable code; `KNOWLEDGE-INDEX.md` generation and all legacy read paths continue to function so no existing surface regresses. Satisfies US-5 and the standalone-first constraint.
- **FR-12 (observability)**: Rebuild and import emit `emit_event`/`emit_result` structured events (Principle II) and append one `unit_close`-style JSONL record per run with row counts, per-family counts, duration, and diagnostics count.

## Success Criteria

- **SC-1**: `bash scripts/kb/orch-kb.sh search "budget envelope SIGKILL"` on the imported live corpus exits 0 and its top-5 output includes the M046-envelope knowledge entry with `source_path`, `family`, and `temporal_valid_from` fields populated (verified by `tools/verify/m047-search-battery.sh`, exit 0).
- **SC-2**: `tools/verify/m047-rebuild-determinism.sh` builds, canonically dumps, deletes, rebuilds, re-dumps, and diffs — exit 0 with an empty diff, on both the fixture corpus and this repo's live corpus.
- **SC-3**: `tools/verify/m047-importer-coverage.sh` exits 0 asserting per-family coverage on the live corpus: strict equality (`imported_count == source_count`) for MEM files, REF files, and DECISIONS rows; for the execution-log family, `imported_count + skip_count == source_record_count`, with `skip_count` cross-checked against the FR-7 diagnostics table — FR-7-designed skips of malformed historical records are counted evidence, not coverage failures (gate amendment R2/MIT-1).
- **SC-4**: `tools/verify/m047-parity-battery.sh` (FR-9) exits 0: new-path hit-rate ≥ old-path hit-rate on all ≥15 battery queries.
- **SC-5**: `tools/verify/m047-validation-fixtures.sh` exits 0: each of the four US-4 fixture classes (malformed, duplicate, dangling-supersede, contradiction) produces its defined outcome and diagnostic; the malformed class additionally includes one distinctly-labeled fixture per FR-2 sub-invariant — (a) a Claim missing both source and inference marker, (b) an Artifact missing its authoring-run link, (c) an Evaluation missing its rubric name — each rejected with its named-invariant diagnostic (gate amendment R2/MIT-3).
- **SC-6**: `bash scripts/kb/orch-kb.sh why D016` exits 0 and outputs D016's decision body, source location, and owning unit (M046/P04) from the imported live DECISIONS.md.
- **SC-7**: With sqlite3 masked from PATH, `orch-kb search x` exits with the documented unavailable code and `tools/verify/m047-degrade.sh` confirms `KNOWLEDGE-INDEX.md` generation still exits 0 byte-identically.
- **SC-8**: `tools/verify/m047-rebuild-budget.sh` exits 0 having recorded the full-rebuild wall-clock duration into the FR-12 JSONL record and named the reference environment it measured in its own output; the 30-second figure is an informational target checked against that named reference environment, not a machine-relative hard gate (gate amendment MIT-6).
- **SC-9**: `bash scripts/verify/spec-shape-lint.sh specs/048-graph-core-migration/spec.md` exits 0, and the constitution diff shows the FR-10 amendment with a version bump and rationale.
- **SC-10**: `tools/verify/m047-column-split.sh` exits 0: on a fixture where one entry's body is edited and committed, the canonical dump diff shows exactly `content_hash` + `recency_source_date` changed and `temporal_valid_from` unchanged for that node, with all other rows untouched (gate amendment MIT-1).
- **SC-11**: `tools/verify/m047-id-resolution.sh` exits 0: a two-spec fixture with same-named chunk labels imports without collision, both chunks are independently addressable via composite IDs, and `orch-kb why FR-1` against that fixture emits the ambiguous-match diagnostic listing both qualified IDs and exits with the ambiguous-id code; the fixture set also includes a same-prefix-different-label pair (`FR-1` vs. `FR-10`) asserting neither a false-ambiguous nor a false-exact match across that pair (gate amendments MIT-2 + R2/MIT-2).

## Non-Goals

- **MCP server / tool surface** — M048 scope; M047 ships the CLI seam it will wrap. Building both at once couples schema stabilization to protocol design.
- **Embeddings / vector search** — deferred behind a measured trigger (retrieval miss-rate on the FR-9 battery); lexical-first is the evidence-backed default and keeps M047 dependency-light.
- **Ambient session capture, distillation, contradiction gate on live writes** — M048; M047's only writers are deterministic importers.
- **Graph-native auto loop / frontier queries as loop driver** — M049; `lineage` queries here are read-only foundations.
- **LLM entity resolution and brownfield codebase ingestion at scale** — M050; M047 resolution is deterministic ID-based because every existing family already carries stable IDs.
- **Changing any markdown authoring format** (MEM frontmatter, DECISIONS row shape, REF layout) — importers adapt to what exists; format evolution is a separate future decision.
- **Wiki projection changes** — the wiki remains a view; re-pointing it at the graph is post-v2-core work.

## Constraints

- **CON-1 (markdown-is-truth)**: `.orchestrator/graph.db` is a derived index — gitignored, deletable, rebuildable (operator-confirmed at clarify, 2026-08-17). No data may exist only in the db except explicitly-non-canonical telemetry tables. Any future durable-write surface (M048 capture) must write markdown/JSONL truth first, db second.
- **CON-2 (no-server-processes)**: M047 introduces no daemons, no network listeners, no background services. sqlite3 is invoked as a CLI/library by scripts; everything remains file-and-process based.
- **CON-3 (legacy-paths-unbroken)**: Every existing knowledge consumer (`build-context.sh`, `KNOWLEDGE-INDEX.md` readers, dispatch injection) continues byte-compatible through M047. Cutover of consumers is M048 scope, gated on SC-4 parity evidence.
- **CON-4 (blast-radius)**: M047 touches only new files under `scripts/kb/`, `tools/verify/m047-*`, the constitution amendment, a `detect-capabilities.sh` additive field, and an additive `run-doctor.sh` check. No edits to `auto-loop.sh`, dispatch adapters, or existing knowledge scripts beyond additive probe hooks.
- **CON-5 (bash-substrate-this-milestone)**: M047's CLI is Bash + sqlite3 (SQL does the ranking math). Introducing a Node/Python helper is deferred to M048's MCP decision (#Q-3 of the proposal) so this milestone adds exactly one new dependency.

### Knowledge-Layer Boundary (M047 vs. M048)

M047 **owns**: the new `.orchestrator/graph.db` store, `scripts/kb/**`, importer read-access to `knowledge/**`, `specs/**`, `.orchestrator/DECISIONS.md`, and `.orchestrator/**/execution-log.jsonl`, plus continued generation of `KNOWLEDGE-INDEX.md` unchanged. M047 **must not** write to any markdown knowledge file, change MEM/REF/spec chunk formats, or alter `build-context.sh` retrieval behavior. M048 **owns**: consumer cutover (context-builder v2), the MCP surface, and all live-write paths into the graph (ambient capture), which must route through M047's FR-7 validation pipeline.

## Assumptions

- The operator's dev machines and CI images have (or can trivially install) sqlite3 ≥ 3.35 with FTS5 compiled in; the amendment makes this a declared dependency rather than a discovered one.
- Bare IDs are unique for the families that keep them (MEM###, REF-*, D###, unitIds); spec chunk labels are NOT globally unique (every spec reuses `FR-1`/`US-1`/`SC-1`) and are therefore composite-namespaced per FR-3's ID-construction convention (gate amendment MIT-2). Deterministic resolution needs no LLM pass at this corpus size.
- The M046-landed repo state is the baseline; no parallel branch rewrites knowledge-family formats during M047.
- `DECISIONS.md` rows remain parseable by their current table shape; rows that defeat the parser are surfaced as US-4 diagnostics, not silently skipped.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: The graph is the compression mechanism Principle I's clarification names — ranked bounded retrieval delivers *minimum sufficient context via the cheapest pipeline*. FR-9's parity battery is the empirical evidence path the principle demands for retrieval-path changes.
- **Principle II (Evidence Before Claims)**: Every SC names a command, exit code, and artifact; rebuild/import emit `emit_event`/`emit_result` (FR-12); the parity battery turns "retrieval works" into a mechanical gate.
- **Principle VI (State On Disk Is Truth)**: The db is disk state, derived and rebuildable from markdown truth (CON-1, FR-4); crash recovery is `rm graph.db && orch-kb rebuild`; interrupted rebuilds are atomic (whole-old-or-whole-new).
- **Principle IX (Reproducibility Over Convenience)**: FR-4 mandates byte-identical canonical rebuilds — no wall-clock, no random IDs; SC-2 enforces it mechanically on both fixture and live corpora.
- **Principle X (Templating Over Inference)**: RRF weights, decay half-life, and IDF thresholds are config-declared (FR-5), not hardcoded; changing ranking policy means editing config.
- **Principle XI (Single Source of Truth)**: Markdown stays the one authoritative location per concept; the db is an index (CON-1). The three-temperature storage bullet is honored: the graph becomes the hot index's query engine without displacing warm markdown detail files.
- **Principle XIV (No Speculative Complexity)**: Vectors, MCP, LLM resolution, and server processes are all explicitly deferred (Non-Goals); M047 adds one dependency and one new script tree.
- **Constraints (standalone-first / graceful degrade)**: FR-11 preserves full legacy function without sqlite3 — the graph is an enhancement, not a new hard floor, for downstream consumer projects.
- **Governance**: FR-10 follows the amendment path (semver, rationale, propagation) rather than treating operator authorization as self-executing.

## Open Questions (defer to planning)

### Clarifications (resolved at Full-intensity clarify, 2026-08-17, operator-answered)

- **#Q-1 (db-in-git)** → **gitignored-and-rebuilt**; folded into CON-1.
- **#Q-2 (consumer-cutover-timing)** → **strictly parallel**: zero consumers cut over inside M047; folded into CON-3/CON-4 and the Knowledge-Layer Boundary.
- **#Q-4 (recency-signal-source)** → **frontmatter date → git commit date**, never file mtime; folded into FR-5.
- **Substrate (CON-5)** → Bash + sqlite3 only this milestone; Node/Python decision deferred to M048's MCP choice — operator-confirmed.

### Gate amendments (2026-08-17, applied after strict conversus BLOCK — see `conversus/summary/final.md`)

- **MIT-1 (P0)**: `valid_from` split into `temporal_valid_from` (FR-8-owned, supersede-only) + `recency_source_date` (FR-5-owned, recomputed per import) — resolves the RISK-1 internal contradiction between FR-5 and US-2 AS2. New SC-10.
- **MIT-2 (P0)**: per-family ID-construction convention in FR-3 (composite `<feature-slug>/<chunk-label>` for spec chunks) + bare-ID ambiguity resolution rule in FR-6 — resolves RISK-2/RISK-3. New SC-11; Assumptions corrected.
- **MIT-3 (P1)**: FR-9 hit-equivalence defined as `source_path` identity — resolves RISK-4.
- **MIT-5 (P2, trivial)**: FR-5 math-function-free commitment + FR-11 probe extension.
- **MIT-6 (P2, trivial)**: SC-8 reworded to a recorded, reference-environment-scoped metric.
- **MIT-4 (P2)**: deliberately NOT applied in M047 — recorded as an M048 precondition under Downstream Consumers, per the arbiter's owner assignment.
- `Metric` node type removed from FR-1 (accepted-risk residual `dead-schema-metric`; Principle XIV).

### Gate amendments, round 2 (2026-08-17, applied on the re-gate's PASS-with-conditions — see `conversus/summary/final.md`)

- **R2/MIT-1 (P0)**: SC-3 gains the `imported + skip == source` carve-out for the execution-log family (FR-7-designed skips are evidence, not failures); strict equality retained for MEM/REF/DECISIONS.
- **R2/MIT-2 (P0)**: FR-6 bare-ID matching algorithm stated explicitly — label-component matching against composite IDs, ≥2-qualifier ambiguity trigger, whole-label delimiter-boundary rule (`FR-1` ≠ `FR-10`); SC-11 fixture set gains the same-prefix pair.
- **R2/MIT-3 (P1)**: SC-5 enumerates one fixture per FR-2 sub-invariant (source-less Claim, run-less Artifact, rubric-less Evaluation).

### Remaining (defer to plan-phase)

- **#Q-3 (decisions-parser-shape)**: DECISIONS.md rows are markdown-table prose with embedded pipes in code spans; the importer's parsing strategy (strict table parser vs. row-anchored regex) and its failure taxonomy need a plan-time spike against the live file.
- **#Q-5 (schema-migration-policy)**: When the schema version bumps in M048+, is the contract always full-rebuild (cheap at this scale, maximally simple) or ALTER-based migration? Default: full-rebuild while rebuild ≤ SC-8 budget; revisit when brownfield corpora grow.

## Dependencies

- M046 (landed 2026-08-17): atomic temp-then-rename discipline reused by FR-4 rebuild; envelope/JSONL conventions for FR-12 records.
- M036 supersede-chain mechanism: generalized by FR-8 rather than reinvented.
- Existing ingest chunker (spec chunks) and reference-corpus tree (M036a): importer inputs.
- `scripts/lifecycle/lock-manager.sh` (best-effort write serialization), `scripts/dispatch/detect-capabilities.sh` (FR-11 probe site), `scripts/diagnostics/run-doctor.sh` (US-5 health check site).
- Host sqlite3 ≥ 3.35 with FTS5 (declared by FR-10 amendment).

## Downstream Consumers (informational, not binding)

- **M048** — MCP retrieval surface wraps FR-6 CLI primitives; ambient capture writes through FR-7 validation; context-builder v2 cutover gated on SC-4 parity evidence. **Preconditions carried from the 2026-08-17 gate deliberation (accepted-risk triggers)**: before M048's ambient-capture writer lands on the `import` path, add the synchronous post-import row-count self-check (MIT-4 / RISK-5); if the FR-5 math-function-free ranking commitment is ever revisited, close the FR-11 probe gap first (MIT-5 / RISK-6).
- **M049** — graph-native auto mode's frontier/lineage queries build on FR-1 Task/AgentRun nodes and FR-6 `lineage`.
- **M050** — brownfield batch ingest reuses FR-3 importer discipline + FR-7 pipeline with LLM extraction in front.
- **Wiki projection (post-v2)** — future view over the same store.
- **`orchestrator:doctor` / `detective`** — graph-health signals (US-5) enrich diagnostics.

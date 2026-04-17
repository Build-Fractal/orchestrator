---
schema_version: "1.0"
type: roadmap
milestone: "M011"
feature_ref: "011-spec-management"
feature_spec: "specs/011-spec-management/spec.md"
vision: "Ingest any markdown spec into the knowledge system, scope-filter chunks into dispatch payloads, and generate intensity-aware roadmaps from structured spec data"
tier: "C"
created_at: "2026-04-16T13:00:00Z"
updated_at: "2026-04-16T13:00:00Z"
---

## Phases

- [x] **P01**: Knowledge Infrastructure Bootstrap — "A developer runs `create-entry.sh --id SPEC-FR-001 --category spec/requirement ...` and the entry is created at `.orchestrator/knowledge/spec/requirement/SPEC-FR-001.md`, indexed in KNOWLEDGE-INDEX.md, and queryable via `scope-filter.sh --graph --category spec/requirement`."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `.orchestrator/knowledge/spec/` directory tree (6 subdirs: `story/`, `requirement/`, `constraint/`, `nfr/`, `acceptance/`, `non-goal/`)
      - `scripts/knowledge/create-entry.sh` (updated: accepts `--id SPEC-*` prefix, validates SPEC- namespace, `mkdir -p` handles nested `spec/requirement` category paths)
      - `scripts/knowledge/rebuild-index.sh` (updated: scans nested `knowledge/spec/*/` directories, inserts SPEC- entries into KNOWLEDGE-INDEX.md and knowledge.db)
      - `scripts/knowledge/lib/index-utils.sh` (updated: `next_entry_id()` skips SPEC- prefixed IDs when auto-incrementing MEM### sequence)
      - `scripts/dispatch/scope-filter.sh` (updated: `--category spec/non-goal` entries excluded by default; `--include-non-goals` flag added)
    - Consumes: nothing (foundation phase)

- [x] **P02**: Ingest Pipeline — "A developer runs `bash scripts/knowledge/ingest-spec.sh --spec-path specs/016-autonomous-hardening/spec.md --slug 016-autonomous-hardening` and sees `CREATED: SPEC-US-001`, `CREATED: SPEC-FR-001`, ... for every story, requirement, constraint, NFR, acceptance scenario, and non-goal in the spec, with `relates_to` edges linking stories to their acceptance scenarios."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/ingest-spec.sh` (new: parses markdown spec → classifies sections by heading/prefix patterns → calls `create-entry.sh` per chunk → calls `rebuild-index.sh` once at end; emits `CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:` prefixed lines)
      - Content hash population in spec chunk frontmatter (`content_hash` field set via SHA-256 of normalized body)
    - Consumes:
      - `scripts/knowledge/create-entry.sh` from P01 (SPEC- ID support, nested category paths)
      - `scripts/knowledge/rebuild-index.sh` from P01 (nested dir scanning)
      - `.orchestrator/knowledge/spec/` directory tree from P01

- [x] **P03**: Idempotent Re-Ingest & Versioning — "A developer modifies FR-003 in the spec, re-runs `ingest-spec.sh`, and sees `SUPERSEDED: SPEC-FR-003 → SPEC-FR-003-v2` for the changed requirement, `SKIPPED: SPEC-FR-001` for unchanged requirements, and `REMOVED: SPEC-FR-005` for a deleted requirement — with the supersession chain traversable via `traverse-graph.sh --provenance --id SPEC-FR-003`."
  - Risk: high
  - Depends: P02
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/ingest-spec.sh` (updated: re-ingest mode — compares content hashes, calls `supersede-entry.sh` for changed chunks, marks removed chunks as `superseded_by: REMOVED`, skips unchanged chunks)
      - Phase-impact flagging logic (new: when a superseded chunk's `scope_tags` reference a phase, emits `REVIEW: P## affected by SPEC-FR-003 supersession`)
    - Consumes:
      - `scripts/knowledge/ingest-spec.sh` from P02 (initial ingest logic, extended with re-ingest)
      - `scripts/knowledge/supersede-entry.sh` (existing: sets superseded_by/supersedes fields, removes old entry from index)
      - `scripts/knowledge/lib/detail-utils.sh` (existing: `fm_field` for reading content_hash from existing entries)

- [x] **P04**: Dispatch Integration — "A developer dispatches a task whose plan contains `scope_tags: [spec/requirement/SPEC-FR-003]`, and the context payload includes only the SPEC-FR-003 chunk plus its related acceptance criteria and constraints — not the full spec."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/dispatch/scope-filter.sh` (updated: resolves `spec/*` scope tags via graph traversal — a `spec/requirement` tag pulls in related `spec/acceptance` and `spec/constraint` entries via `traverse-graph.sh`)
      - `scripts/dispatch/build-context.sh` (updated: when task plan contains `spec/*` scope tags, includes scope-filtered spec chunks in the dispatch payload as a dedicated `## Spec Context` section)
    - Consumes:
      - `scripts/dispatch/scope-filter.sh` from P01 (non-goal exclusion)
      - `scripts/knowledge/traverse-graph.sh` (existing: `relates_to` edge traversal for graph neighbors)
      - `scripts/knowledge/resolve-entries.sh` (existing: resolves IDs to full content)

- [x] **P05**: Evaluate & Roadmap Command Integration — "A developer runs `orchestrator:evaluate` on a milestone whose spec has been ingested, and the evaluation reads story/AC/FR counts from spec chunks instead of parsing the raw file. Then `orchestrator:roadmap` at Quick intensity produces a roadmap in a single directive pass derived from `spec/story` chunk groupings."
  - Risk: medium
  - Depends: P02, P04
  - Boundary Map:
    - Produces:
      - `commands/evaluate.md` (updated: detects ingested spec chunks via `scope-filter.sh --graph --category spec/story`; reads metrics from chunk counts instead of regex on raw spec; falls back to raw spec if no chunks exist)
      - `commands/roadmap.md` (updated: reads `spec/story` chunks to build phase candidates; branches on intensity: quick=directive, standard=semi-directive, full=collaborative; traces dependency edges from story graph relationships into phase `depends_on`)
    - Consumes:
      - `scripts/knowledge/ingest-spec.sh` from P02 (chunks must exist for evaluate to read them)
      - `scripts/dispatch/scope-filter.sh` from P04 (spec category querying in evaluate and roadmap)
      - `scripts/knowledge/traverse-graph.sh` (existing: story→acceptance edges for dependency derivation)

- [x] **P06**: Ingest Command & End-to-End Validation — "A developer runs `orchestrator:ingest` pointing at a 40-page markdown spec, then runs `orchestrator:evaluate` → `orchestrator:roadmap` at Quick intensity, and the full pipeline produces a tier classification and phase-decomposed roadmap in under 60 seconds with zero manual spec formatting required."
  - Risk: low
  - Depends: P03, P05
  - Boundary Map:
    - Produces:
      - `commands/ingest.md` (new: user-facing orchestrator command wrapping `ingest-spec.sh`; accepts `--spec-path`, `--slug`, `--milestone`; records spec slug → milestone mapping in evaluation file; handles re-ingest with confirmation)
      - `.orchestrator/milestones/M011/phases/P06/evidence/` (dogfood evidence: ingest + evaluate + roadmap pipeline on a real spec, chunk count, timing, zero-error transcript)
      - `scripts/verify/m011-p06-e2e-pipeline.sh` (gate script: ingests fixture spec, verifies chunk count, runs scope-filter, checks evaluate reads chunks, validates < 60s)
    - Consumes:
      - `scripts/knowledge/ingest-spec.sh` from P03 (full ingest + re-ingest pipeline)

- [x] **P07**: Format-Agnostic Intake & Conversus Fidelity Gate — "A developer runs `orchestrator:ingest --spec-path ~/Downloads/random-prd.md --slug 019-foo` on a non-spec-kit-shaped markdown file. The command LLM-normalizes it to spec-kit shape, writes the normalized artifact to `specs/019-foo/spec.md` for review, and at Standard+ intensity (or with `--review`) runs `/conversus gate normalize specs/019-foo/spec.md` — a two-agent cooperative deliberation (source-advocate vs target-advocate) that emits `gate-result.md` with `PASS | BLOCK`. Only on PASS (or explicit `--force`) does the deterministic chunker from P02/P03 run."
  - Risk: medium
  - Depends: P06
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/normalize-spec.sh` (new: LLM-driven normalizer — accepts arbitrary markdown, emits spec-kit-shaped markdown; shells out to configured provider via existing dispatch adapter; deterministic filename + temp-file-then-move write; idempotent against unchanged input)
      - `scripts/dispatch/adapters/tool/conversus.sh` (new: thin adapter — generates `conversus.yml` + `gates.yml` from orchestrator context, invokes `/conversus gate` via CLI or MCP, parses `gate-result.md`, returns verdict + structured disputes to caller; no agent prompts authored here, all via conversus presets)
      - `scripts/engine/intensity-policy.sh` (updated: adds `conversus_gate` policy keys — `normalize_fidelity` default off/off/on for Quick/Standard/Full; `--review` flag forces on; `--no-review` forces off)
      - `commands/ingest.md` (updated from P06: pre-chunker pipeline becomes `detect-shape → normalize-if-needed → fidelity-gate-if-enabled → chunker`; shape detection uses the P02 classifier's heading recognition as a fast probe — if the file already matches spec-kit shape, skip normalize and gate)
      - `presets/conversus/normalize-fidelity.yml` (new: two-agent cooperative preset — source-advocate argues "does normalized spec preserve everything the source said?" vs target-advocate argues "does normalized spec fit spec-kit shape cleanly?"; arbiter grounded in `.orchestrator/memory/constitution.md`)
      - `docs/ingesting-arbitrary-specs.md` (new: user guide — bring-your-own-spec flow, when gates fire, how to interpret BLOCK verdicts, `--force` escape hatch)
      - `scripts/verify/m011-p07-normalize-idempotent.sh`, `m011-p07-shape-detect.sh`, `m011-p07-gate-pass-block.sh`, `m011-p07-intensity-policy.sh`, `m011-p07-e2e-arbitrary-spec.sh` (verification scripts)
    - Consumes:
      - `scripts/knowledge/ingest-spec.sh` from P03 (chunker runs downstream; this phase adds a preprocessor, not a replacement)
      - `commands/ingest.md` from P06 (extended, not recreated)
      - `scripts/engine/intensity-recommend.sh` (existing: resolves Quick/Standard/Full for policy lookup)
      - Conversus CLI at `~/Sites/conversus` or `conversus` on PATH (external dependency; adapter fails gracefully with actionable message if missing, pipeline proceeds without gate)
      - `commands/evaluate.md` from P05 (chunk-aware evaluate)
      - `commands/roadmap.md` from P05 (chunk-aware, intensity-adaptive roadmap)
      - All P01–P05 deliverables (the dogfood run exercises the full surface)

## Cross-Cutting Concerns

- **Bash 3.2 compatibility** — P01, P02, P03, P04. All new and modified scripts must pass `bash -n` under Bash 3.2. No `declare -A`, `mapfile`, `${var,,}`, or process substitution in assignments. P01 establishes the pattern (extensions to create-entry.sh); P02–P04 must conform.
- **Idempotency contract (FR-066)** — P01, P02, P03, P06. Every file write is idempotent. `create-entry.sh` already checks `EXISTS`; `ingest-spec.sh` must honor this on first ingest (P02) and use content-hash comparison on re-ingest (P03). The E2E gate script (P06) must verify running the pipeline twice produces identical disk state.
- **Structured output convention** — P02, P03, P06. `ingest-spec.sh` emits `CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:` prefixed lines to stdout, errors to stderr, exit 0/1. All consuming scripts and the command doc parse these prefixes. P02 establishes the convention; P03 extends it for re-ingest verbs; P06 validates the full set.
- **Knowledge index consistency** — P01, P02, P03. Every operation that creates, supersedes, or removes a spec chunk must leave KNOWLEDGE-INDEX.md and knowledge.db in a consistent state. `rebuild-index.sh` is the escape hatch (P01 ensures it handles nested dirs), but incremental operations (P02/P03) should maintain consistency without requiring a full rebuild.
- **SPEC- ID namespace** — P01, P02, P03, P04, P05. The `SPEC-` prefix is reserved for spec chunks. `next_entry_id()` must not generate MEM### IDs that collide with SPEC- IDs, and SPEC- IDs must not be auto-incremented. P01 establishes the convention; all downstream phases rely on it.

## Dependency Graph

```
P01 ──→ P02 ──→ P03 ──→ P06 ──→ P07
 │               ↑       ↑
 └──→ P04 ──→ P05 ──────┘
```

P01 is the sole foundation — everything depends on it.
P02 (ingest) and P04 (dispatch integration) both depend only on P01 and can execute concurrently.
P03 (re-ingest/versioning) depends on P02 (needs initial ingest to extend).
P05 (evaluate/roadmap integration) depends on P02 (chunks must exist) and P04 (scope-filter wiring).
P06 (command + E2E) depends on P03 and P05 (validates the complete surface).
P07 (format-agnostic intake + conversus gate) depends on P06 (extends `commands/ingest.md` with a normalize+gate preprocessor; chunker itself is unchanged).

## Execution Order

1. **P01** — foundation, no dependencies. High risk: modifies 4 existing scripts + creates directory tree. Must land first because every other phase consumes its deliverables.
2. **P02, P04** — can execute concurrently (both depend only on P01). P02 is the largest phase (new ingest script with parser logic); P04 is smaller (scope-filter + build-context wiring). Concurrent execution shaves a phase off the critical path.
3. **P03** — depends on P02. Extends ingest for re-ingest mode. High risk due to content-hash comparison and supersession coordination.
4. **P05** — depends on P02 + P04. Modifies two core command docs (evaluate, roadmap). Medium risk: command doc changes affect the orchestrator's own workflow.
5. **P06** — depends on P03 + P05. Validation-only + new command doc. Low risk — if the dogfood surfaces issues, the fix is iterating P01–P05.
6. **P07** — depends on P06. Adds normalize + conversus fidelity gate in front of the chunker, and lands the reusable `tool/conversus.sh` adapter that later milestones (M013, M014) can invoke at their own gate points. Medium risk: LLM-driven normalization has quality variance, mitigated by reviewable artifact + opt-in gate; external conversus dependency mitigated by graceful-degradation fallback.

## Validation

- **No conflicting producers**: PASS — each artifact is produced by exactly one phase. `ingest-spec.sh` is created in P02, updated in P03 (not created again). `scope-filter.sh` is updated in P01 (non-goal exclusion) and P04 (graph-neighbor resolution) — P01 adds the exclusion flag, P04 adds the traversal logic; non-overlapping changes. `evaluate.md` and `roadmap.md` are updated only in P05.
- **All consumed items have producers**: PASS — P02 consumes `create-entry.sh` (P01), `rebuild-index.sh` (P01), `knowledge/spec/` (P01). P03 consumes `ingest-spec.sh` (P02), `supersede-entry.sh` (existing). P04 consumes `scope-filter.sh` (P01), `traverse-graph.sh` (existing), `resolve-entries.sh` (existing). P05 consumes `ingest-spec.sh` (P02), `scope-filter.sh` (P04). P06 consumes all upstream. All traced.
- **DAG is acyclic**: PASS — topological sort: P01 → {P02, P04} → {P03, P05} → P06. No back-edges.
- **Demo sentence coverage**: PASS — each phase has a concrete demo sentence describing a specific developer action and observable result.

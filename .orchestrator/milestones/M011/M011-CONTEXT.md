---
schema_version: "1.0"
type: context-draft
milestone: "M011"
status: finalized
created_at: "2026-04-16T12:30:00Z"
finalized_at: "2026-04-16T12:45:00Z"
---

## Architectural Decisions

### AD-1: SPEC-Prefixed Natural IDs for Spec Chunks

Spec chunks use human-readable, namespaced IDs: `SPEC-FR-003`, `SPEC-US-002`, `SPEC-AC-007`, `SPEC-CON-001`, `SPEC-NFR-002`, `SPEC-NG-001`. The `--id` parameter of `create-entry.sh` accepts SPEC-prefixed values. The existing `MEM###` auto-increment sequence remains for non-spec knowledge entries. This preserves natural reference semantics in task plans, scope tags, and graph edges — a developer reading `scope_tags: [spec/requirement/SPEC-FR-003]` immediately knows which requirement is in scope.

### AD-2: Nested Category Directory Structure

Spec categories use nested directories under `knowledge/spec/`: `spec/story/`, `spec/requirement/`, `spec/constraint/`, `spec/nfr/`, `spec/acceptance/`, `spec/non-goal/`. This keeps spec chunks cleanly separated from operational knowledge (patterns, conventions, lessons) while reusing the same `create-entry.sh` → `rebuild-index.sh` pipeline. The category field in frontmatter uses the slash-delimited path (e.g., `category: spec/requirement`), and `create-entry.sh` already uses `mkdir -p` on the category path, so nested directories should work without modification.

### AD-3: Bash Script Parser for Spec Chunking

The core parsing logic lives in `scripts/knowledge/ingest-spec.sh`. It uses heading-level splits and regex pattern matching (FR-NNN, US-NNN, Given/When/Then, "As a... I want...") to classify sections — consistent with project conventions of grep/sed/awk-based text processing and Bash 3.2 compatibility. No agent-driven classification for the parser itself; deterministic regex-based classification is testable and reproducible.

### AD-4: Content Hash for Idempotent Re-Ingest

Change detection during re-ingest uses SHA-256 hashes of normalized chunk bodies (stripped whitespace, normalized line endings). The `content_hash` field already exists in knowledge entry frontmatter but is currently empty. On re-ingest: compute hash → compare to existing entry's `content_hash` → match means skip, mismatch means supersede old + create new. This gives idempotency (FR-007) and supersession-based versioning (FR-008) with a single mechanism.

### AD-5: New Pipeline Entry Point with Chunk-Aware Evaluate

`orchestrator:ingest` is a new command that sits before `evaluate` in the pipeline: `ingest → evaluate → discuss → roadmap`. Evaluate detects whether spec chunks exist in the knowledge system; if so, it reads metrics from chunks instead of parsing the raw spec file. If chunks don't exist, evaluate falls back to its current raw-spec parsing. This makes ingest optional for users who manually write specs in the existing format, while giving the chunk-based pipeline to users who bring external PRDs.

### AD-6: Full Roadmap Integration with Intensity Modes

The `commands/roadmap.md` command is modified to read spec chunks when available and adapt its interaction style to the intensity level: Quick → directive (emit roadmap, ask accept/refine), Standard → semi-directive (show rationale per phase, ask to accept/refine specific phases), Full → collaborative (enter discuss-style loop per candidate phase). Phase candidates are derived from `spec/story` groupings with dependency edges traced through the graph. This delivers the "paste PRD, get roadmap in 30 seconds" value proposition at Quick intensity.

### AD-7: Category-Based Non-Goal Exclusion

`scope-filter.sh` and `build-context.sh` skip entries with `category: spec/non-goal` by default. A `--include-non-goals` flag overrides this for verification contexts where the verifier needs to check "did any task accidentally implement a declared non-goal?" This is a category-level rule, not a scope-tag convention — cleaner and less fragile than tag-based exclusion.

## Scope Boundaries

### In Scope

- **Spec storage infrastructure**: Bootstrap `.orchestrator/knowledge/` directory tree with `spec/` subtree and 6 subcategories
- **Ingest pipeline**: `scripts/knowledge/ingest-spec.sh` — parse markdown specs, classify sections, create knowledge entries, build graph edges
- **New orchestrator command**: `commands/ingest.md` wrapping the ingest pipeline as a user-facing entry point
- **Scope-filter integration**: `scope-filter.sh` handles `spec/*` categories, resolves graph neighbors (related ACs, constraints)
- **Dispatch integration**: `build-context.sh` includes scope-filtered spec chunks in task payloads
- **Evaluate integration**: `evaluate` reads spec chunks when available for metrics
- **Roadmap integration**: `roadmap` reads spec chunks, adapts interaction to intensity level (directive/semi-directive/collaborative)
- **Idempotent re-ingest**: Content-hash-based change detection with supersession chains
- **Phase impact flagging**: Superseded chunks that are scoped to a phase flag that phase for review
- **Index integration**: `rebuild-index.sh` correctly indexes nested `spec/*` categories

### Out of Scope

- **Spec creation/authoring**: No guided spec-writing flow. Users bring their own markdown specs.
- **Non-markdown input**: No PDF, DOCX, HTML parsing. Users convert externally.
- **Wiki/collaboration UI**: M012 scope.
- **GitHub integration**: M013 scope.
- **Comment automation**: M014 scope.
- **Spec quality scoring**: Potential M017 (Conversus) use case.
- **Backfilling existing KNOWLEDGE.md**: The flat `KNOWLEDGE.md` entries (MEM001–MEM029) are not backfilled into detail files as part of M011. This is orthogonal and can be done separately if needed.

## Design Constraints

1. **Bash 3.2 compatibility**: All new scripts must work with macOS built-in bash. No `declare -A`, no associative arrays, no process substitution in assignments.
2. **Existing script contracts**: `create-entry.sh`, `supersede-entry.sh`, `resolve-entries.sh`, `traverse-graph.sh`, `rebuild-index.sh`, `scope-filter.sh`, `build-context.sh` are modified only where necessary. Breaking changes to their APIs require updating all callers.
3. **Idempotency contract (FR-066)**: Every file write is idempotent. Re-running ingest on an unchanged spec produces identical disk state.
4. **Constitution Principle I (Context Minimization)**: Dispatched tasks receive only scope-relevant spec chunks. This is the primary motivation for chunking.
5. **Structured output convention**: `ingest-spec.sh` emits prefixed lines (`CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`) to stdout, errors to stderr, exits 0/1.
6. **Atomic file writes**: All file creation uses temp-file-then-move pattern per existing convention.
7. **SQLite graph database**: `rebuild-index.sh` regenerates `knowledge.db` — spec chunks must be insertable into the existing schema (entries + edges + scope_tags tables).

## Open Questions

All questions from the discussion phase have been resolved. The architectural decisions above capture the answers. No open questions remain for planning.

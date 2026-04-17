# Feature Specification: Spec Management

**Feature Branch**: `011-spec-management`
**Created**: 2026-04-16
**Status**: Draft
**Input**: Prior planning in project memory (M011-M014 sequence), DECISIONS.md D004/D006, milestone-summary.md. The orchestrator needs a way to ingest external specs, chunk them into the existing knowledge infrastructure, and generate roadmaps from those chunks — completing the "paste a 40-page PRD, get a roadmap in 30 seconds" value proposition.

## Problem Statement

The orchestrator currently assumes specs already exist at `specs/{NNN}-{name}/spec.md` and are authored manually or via spec-kit's `specify` command. This creates two gaps:

1. **No ingest path for external specs.** Users arriving with specs from ChatPRD, Cursor, Notion, Google Docs (converted to markdown), or plain text PRDs have no way to feed them into the orchestrator. They must manually create a spec directory and file, then hope the evaluate command picks up their format.

2. **Specs are opaque blobs.** The orchestrator reads the spec file once during evaluation, extracts surface metrics (story count, AC count, FR count), and never touches it again. Downstream commands (`plan-phase`, `dispatch`, `verify`) cannot scope-filter to specific requirements. If a 40-page spec has 80 requirements, every dispatched task gets the full spec in its context or nothing — violating Constitution Principle I (Context Minimization).

The fix: treat specs as structured knowledge. The existing knowledge infrastructure (M002 three-temperature architecture, M007 graph traversal, `scripts/knowledge/*.sh`) already provides storage, indexing, relationships, scope filtering, versioning, and supersession. Spec chunks slot into this infrastructure with `spec/*` category prefixes. No new storage backend is needed.

**Positioning:** The orchestrator does NOT build specs. It picks up where specs leave off. Users bring their own specs — from any tool. The differentiator is **ingest-a-spec**: paste a 40-page PRD, get a roadmap in 30 seconds.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ingest a Markdown Spec (Priority: P1)

A developer has a feature spec written in markdown (from any source — ChatPRD, Cursor, Notion export, hand-written). They run the ingest command, pointing it at the markdown file. The orchestrator parses the spec, classifies sections into chunk types (stories, requirements, constraints, NFRs, acceptance criteria), stores each chunk as a knowledge entry with `spec/*` categories, builds graph relationships between chunks, and indexes them in the knowledge system. The developer can now run `evaluate` and `roadmap` against the ingested spec.

**Why this priority**: This is the core value proposition. Without ingest, users cannot bring external specs into the orchestrator.

**Independent Test**: Take a real-world markdown spec (e.g., `specs/016-autonomous-hardening/spec.md`) and run the ingest pipeline. Verify that the output chunks cover every user story, acceptance scenario, functional requirement, constraint, and non-goal in the source. Verify that chunks are indexed and retrievable via `resolve-entries.sh`.

**Acceptance Scenarios**:

1. **Given** a markdown spec file at an arbitrary path, **When** the developer runs the ingest command with that path, **Then** the spec is parsed into categorized chunks stored under `.orchestrator/knowledge/spec/` with entries in the knowledge index.
2. **Given** an ingested spec with 5 user stories each containing 3 acceptance scenarios, **When** the developer queries for `spec/story` entries, **Then** exactly 5 entries are returned, each with `relates_to` edges pointing to their acceptance scenario chunks.
3. **Given** a spec containing a "Constraints" section with 4 items, **When** the ingest completes, **Then** 4 `spec/constraint` chunks exist, each with the constraint text as body and the source spec path in `source_unit`.
4. **Given** a spec that has already been ingested, **When** the developer runs ingest again on the same file, **Then** the operation is idempotent — existing chunks are not duplicated, unchanged chunks retain their IDs, and only modified sections produce new chunks via supersession.

---

### User Story 2 - Scope-Filtered Spec Context in Dispatch (Priority: P1)

When the orchestrator dispatches a task to a subagent, the task's context payload includes only the spec chunks relevant to that task's scope — not the entire spec. This reduces context size and focuses the subagent on the requirements it needs to satisfy.

**Why this priority**: Constitution Principle I (Context Minimization) is the top governing principle. Feeding 40 pages of spec to a task that touches 3 requirements wastes context and dilutes focus.

**Independent Test**: Dispatch a task whose plan references specific requirement IDs (e.g., FR-003, FR-007). Capture the context payload. Verify it contains only the spec chunks for those requirements (plus their related constraints and acceptance criteria), not the full spec.

**Acceptance Scenarios**:

1. **Given** a task plan that references requirements FR-003 and FR-007, **When** the dispatch builds context via `build-context.sh`, **Then** the payload includes spec chunks for FR-003 and FR-007 plus their related acceptance criteria and constraints, but excludes all other spec chunks.
2. **Given** a task with `scope_tags: [spec/story/US-002]`, **When** `scope-filter.sh` resolves entries, **Then** it returns US-002's story chunk, its acceptance scenarios, and any constraints that `relates_to` US-002, using the existing graph traversal infrastructure.
3. **Given** a dispatched subagent receives scope-filtered spec context, **When** it verifies its work, **Then** it can trace every acceptance criterion back to a spec chunk ID in its payload without needing the full spec.

---

### User Story 3 - Spec Chunking Classifies Section Types (Priority: P1)

The ingest pipeline correctly classifies sections of a markdown spec into semantic chunk types. This classification drives downstream behavior: stories scope to phases, requirements scope to tasks, constraints apply globally, NFRs feed verification criteria.

**Why this priority**: If chunking misclassifies a requirement as a constraint (or vice versa), downstream scope filtering delivers wrong context and verification checks the wrong criteria.

**Independent Test**: Feed the pipeline a spec containing one of each type (story, requirement, constraint, NFR, acceptance scenario, non-goal). Verify each chunk's `category` field matches the expected classification.

**Acceptance Scenarios**:

1. **Given** a spec section starting with "### User Story N" or containing "As a... I want... So that...", **When** the chunker processes it, **Then** it produces a `spec/story` entry.
2. **Given** a section with "FR-NNN" prefixed items or a numbered requirements list, **When** the chunker processes it, **Then** each item becomes a `spec/requirement` entry with the FR ID preserved in the chunk ID.
3. **Given** a "## Constraints" section, **When** the chunker processes it, **Then** each constraint becomes a `spec/constraint` entry with global scope (no phase-specific scope tag).
4. **Given** a "## Non-Goals" section, **When** the chunker processes it, **Then** each item becomes a `spec/non-goal` entry. Non-goals are indexed but excluded from roadmap generation and task dispatch scope filtering.
5. **Given** "Given/When/Then" blocks or "AC-NNN" items nested under a user story, **When** the chunker processes them, **Then** each becomes a `spec/acceptance` entry with a `relates_to` edge to the parent story chunk.

---

### User Story 4 - Intensity-Aware Roadmap Generation from Spec Chunks (Priority: P2)

After ingesting a spec, the developer generates a roadmap. The interaction style adapts to the active intensity level: Quick mode produces a roadmap immediately (directive), Standard mode presents the decomposition with rationale for refinement (semi-directive), Full mode walks through each candidate phase collaboratively.

**Why this priority**: Ingest without roadmap generation is incomplete. The intensity adaptation reuses the existing adaptive intensity engine (M008) and Tier C discussion pattern, so it's not new machinery — it's wiring existing systems to the new input.

**Independent Test**: Ingest a non-trivial spec (10+ requirements, 3+ stories). Run roadmap generation at each intensity level. Verify: Quick produces a roadmap in one pass, Standard presents rationale before finalizing, Full enters an interactive discussion loop.

**Acceptance Scenarios**:

1. **Given** an ingested spec and intensity=quick, **When** the developer runs roadmap generation, **Then** a roadmap is produced in a single pass with a "Here's your roadmap. Accept, refine, or override." prompt. No intermediate discussion.
2. **Given** an ingested spec and intensity=standard, **When** the developer runs roadmap generation, **Then** the orchestrator presents the phase decomposition with rationale for each phase and asks the developer to accept or refine specific phases.
3. **Given** an ingested spec and intensity=full, **When** the developer runs roadmap generation, **Then** the orchestrator enters a collaborative discussion loop (reusing the `discuss` command's Tier C pattern), walking through each candidate phase with the developer.
4. **Given** an ingested spec where story US-003 depends on US-001 completing first, **When** the roadmap is generated, **Then** the phase containing US-003 has an explicit `depends_on` referencing the phase containing US-001, and the dependency is traceable to the `spec/story` graph relationships.

---

### User Story 5 - Spec Versioning and Revision (Priority: P2)

When a spec changes (requirements added, modified, or removed), the developer re-ingests the updated spec. The orchestrator detects what changed, supersedes modified chunks (preserving history), adds new chunks, and flags affected phases/tasks for review. Removed requirements are marked superseded with no replacement.

**Why this priority**: Specs change. Without versioning, re-ingest either duplicates everything or requires manual cleanup. The existing supersession chain infrastructure (M002/M007) handles this — M011 wires it to spec chunks.

**Independent Test**: Ingest a spec, then modify one requirement and remove another. Re-ingest. Verify: the modified requirement has a new chunk superseding the old one, the removed requirement is superseded with no replacement, unmodified chunks are untouched, and the affected phase is flagged.

**Acceptance Scenarios**:

1. **Given** an ingested spec where FR-003 text changes, **When** the developer re-ingests the updated spec, **Then** a new `spec/requirement` chunk supersedes the original FR-003 chunk via `supersedes` edge, and the original chunk's `superseded_by` field points to the new chunk.
2. **Given** an ingested spec where FR-005 is deleted, **When** the developer re-ingests, **Then** FR-005's chunk is marked superseded with `superseded_by: REMOVED` and no replacement chunk is created.
3. **Given** a superseded requirement that was scoped to phase P02, **When** the re-ingest completes, **Then** P02 is flagged for review in the roadmap (e.g., a `needs_review: true` annotation or equivalent signal).
4. **Given** an unchanged requirement FR-001, **When** the developer re-ingests, **Then** FR-001's chunk retains its original ID, timestamps, and content — no supersession chain is created.

---

## Success Criteria

- **SC-1**: A markdown spec of any size can be ingested into `.orchestrator/knowledge/spec/` with correct chunk classification in under 60 seconds for specs up to 50 pages.
- **SC-2**: `scope-filter.sh` with `--scope-tags spec/requirement/FR-003` returns exactly the chunks relevant to FR-003 (requirement + related ACs + constraints), not the full spec.
- **SC-3**: The ingest pipeline is idempotent — running it twice on the same unmodified spec produces identical disk state.
- **SC-4**: Re-ingesting a modified spec uses supersession chains (not delete-and-recreate) to preserve history.
- **SC-5**: Roadmap generation from ingested chunks supports all three intensity modes (directive/semi-directive/collaborative).
- **SC-6**: Every spec chunk has a `source_unit` field pointing back to the original spec file path and section.
- **SC-7**: Dispatched task payloads include only scope-relevant spec chunks, not the full spec.
- **SC-8**: The knowledge index (`KNOWLEDGE-INDEX.md` or equivalent) correctly indexes all `spec/*` category entries after ingest.

## Non-Goals

- **Building specs.** The orchestrator does not compete with spec-kit, ChatPRD, Cursor, or other spec-creation tools. Users bring their own specs.
- **Non-markdown input formats.** Users convert Word, PDF, Google Docs, etc. to markdown externally (pandoc, copy-paste). The pipeline accepts markdown only.
- **Wiki generation or collaboration UI.** That's M012. This milestone focuses on storage, chunking, and integration with the orchestrator's existing knowledge and dispatch infrastructure.
- **GitHub integration.** That's M013. No issue sync, milestone mapping, or project board integration in this milestone.
- **Comment-to-workflow automation.** That's M014. No comment classification or auto-apply pipeline here.
- **Spec quality scoring or validation.** The orchestrator ingests what it's given. Quality judgment is a potential Conversus (M017) use case, not an M011 concern.

## Constraints

- **Must build on existing knowledge infrastructure.** Spec chunks use `scripts/knowledge/create-entry.sh`, `supersede-entry.sh`, `resolve-entries.sh`, `traverse-graph.sh`, and `rebuild-index.sh`. No new storage backend (no SQLite, no relational DB).
- **Must use `spec/*` category prefix.** Categories: `spec/story`, `spec/requirement`, `spec/constraint`, `spec/nfr`, `spec/acceptance`, `spec/non-goal`. This integrates with the existing category-based directory structure under `.orchestrator/knowledge/`.
- **Bash 3.2 compatible.** All scripts must work with macOS's built-in bash. No `declare -A`, no associative arrays.
- **Markdown-only input.** The ingest pipeline accepts `.md` files. No PDF parsing, no DOCX parsing, no HTML parsing.
- **Graph relationships via existing infrastructure.** Chunk-to-chunk edges (story→acceptance, requirement→constraint) use `--relates-to` in `create-entry.sh` and are traversable via `traverse-graph.sh`. No new graph backend.
- **Idempotent ingest.** Re-running ingest on an unchanged spec must not create duplicate chunks or modify existing ones (FR-066 contract).
- **Intensity engine integration.** Roadmap generation interaction style is driven by `scripts/engine/intensity-recommend.sh` output. No hardcoded interaction modes.

## Dependencies

- **M002 (Knowledge Architecture)**: Three-temperature knowledge model, category-based storage, index infrastructure. *Completed.*
- **M007 (Graph-Enhanced Knowledge)**: `traverse-graph.sh`, `relates_to`/`supersedes`/`superseded_by` edge traversal, supersession chains. *Completed.*
- **M008 (Standalone Orchestrator)**: Adaptive intensity engine (`intensity-recommend.sh`), backend-agnostic dispatch, scope filtering. *Completed.*
- **M015 (Standalone Cutover)**: State tree at `.orchestrator/`, no spec-kit host dependency. *Completed.*
- **M016 (Autonomous Hardening)**: Zero-prompt auto mode. *In progress — M011 does not depend on M016 for its own implementation, but the autonomous execution of M011's phases benefits from M016's fixes landing first.*

## Functional Requirements

- **FR-001**: Ingest command accepts a path to a markdown file and parses it into spec chunks.
- **FR-002**: Spec chunks are stored under `.orchestrator/knowledge/spec/{type}/` using `create-entry.sh`.
- **FR-003**: Each chunk has a `category` field with `spec/` prefix (one of: `spec/story`, `spec/requirement`, `spec/constraint`, `spec/nfr`, `spec/acceptance`, `spec/non-goal`).
- **FR-004**: The chunker classifies sections by heading patterns, prefix patterns (FR-NNN, US-NNN, AC-NNN), and structural cues (Given/When/Then, As a... I want...).
- **FR-005**: Chunks include `relates_to` edges encoding parent-child relationships (story→acceptance, requirement→constraint).
- **FR-006**: Chunks include `source_unit` pointing to the source spec path and section identifier.
- **FR-007**: The ingest pipeline is idempotent — re-ingesting an unchanged spec produces identical disk state.
- **FR-008**: Re-ingesting a modified spec uses `supersede-entry.sh` for changed chunks, `create-entry.sh` for new chunks, and marks removed chunks as superseded with no replacement.
- **FR-009**: `scope-filter.sh` resolves `spec/*` scope tags to the relevant chunks plus their graph neighbors (related ACs, constraints).
- **FR-010**: `build-context.sh` includes scope-filtered spec chunks in dispatch payloads when task plans reference spec scope tags.
- **FR-011**: Roadmap generation reads ingested spec chunks (not the raw spec file) to build phase decomposition.
- **FR-012**: Roadmap interaction style adapts to intensity level: directive (quick), semi-directive (standard), collaborative (full).
- **FR-013**: `rebuild-index.sh` correctly indexes all `spec/*` entries after ingest.
- **FR-014**: A new orchestrator command (`orchestrator:ingest` or equivalent) wraps the ingest pipeline as a user-facing entry point.
- **FR-015**: The ingest command records the spec slug (from directory name or file name) and maps it to the milestone in the evaluation file.
- **FR-016**: Affected phases are flagged for review when spec chunks they depend on are superseded.

# Feature Specification: Knowledge Architecture

**Feature Branch**: `002-knowledge-architecture`
**Created**: 2026-04-09
**Status**: Draft
**Input**: Replace the flat, append-only KNOWLEDGE.md with a three-temperature knowledge architecture that supports supersession, staleness decay, confidence scoring, and graph-based relationships — enabling the orchestrator to serve precise, minimal context to dispatched agents even on projects with hundreds of milestones and thousands of knowledge entries.

## Problem Statement

The current knowledge system (append-only `KNOWLEDGE.md` with scope tags) works for small-to-medium projects but degrades on large, long-running projects:

1. **Linear growth**: Every phase appends knowledge. A 100-milestone project accumulates hundreds of entries, all loaded into the index.
2. **No supersession**: When a pattern changes, the old entry stays forever. The context builder cannot distinguish "current truth" from "historical artifact."
3. **No staleness signal**: A gotcha discovered in M005 about a React Native 0.72 quirk may no longer apply after upgrading to 0.76 in M043. Without freshness tracking, it sits at 0.95 confidence forever.
4. **No relationship graph**: When entry MEM042 (auth token gotcha) relates to decision D089 (chose JWT over sessions), that relationship is implicit. The context builder cannot traverse "give me everything related to auth."
5. **Flat storage**: The entire knowledge base is one file. Scope filtering reduces injection size but scanning the full file is O(n) for every dispatch.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Three-Temperature Knowledge Storage (Priority: P1)

As an orchestrator user on a large project, knowledge entries are automatically tiered into hot (always-loaded index), warm (loaded when scope-matched), and cold (archived, searchable but never auto-injected) — so that the context builder scales to thousands of entries without payload bloat.

**Why this priority**: This is the foundational data structure. Every other story in this spec depends on knowledge entries being stored individually (not in a monolithic file) with metadata that enables filtering, ranking, and retrieval.

**Independent Test**: Can be tested by creating 500+ knowledge entries across 10 milestones and verifying that a dispatch payload for a task in milestone 8 contains only scope-matched entries (not all 500), and that the index file stays under 10KB.

**Acceptance Scenarios**:

1. **Given** a project with 500+ knowledge entries, **When** the context builder runs for a task dispatch, **Then** it loads only `KNOWLEDGE-INDEX.md` (lightweight manifest), filters by scope tags, and inlines only the matched detail files — never scanning all 500 entries.
2. **Given** a knowledge entry from M005 that has not been verified in 90+ days and has zero hit count, **When** the consolidation process runs, **Then** the entry is moved to cold storage (`knowledge/archive/`) and removed from the index — preserving it for manual search but excluding it from automatic injection.
3. **Given** a knowledge entry that is scope-tagged `[project]`, **When** any task in any milestone is dispatched, **Then** the entry is included in the context payload (project-scoped entries are always warm).
4. **Given** a knowledge entry that is scope-tagged `[milestone:M008]`, **When** a task in M008 is dispatched, **Then** the entry is included. **When** a task in M012 is dispatched, **Then** the entry is NOT included unless M012 declares a dependency on M008.
5. **Given** a cold-storage entry that a developer wants to re-activate, **When** the developer runs a promote command, **Then** the entry is moved back to warm storage with its confidence reset to a configurable default and its `last_verified` timestamp set to now.

---

### User Story 2 - Knowledge Entry Lifecycle (Priority: P2)

As an orchestrator user, knowledge entries have a full lifecycle — created with source provenance, updated with confidence adjustments, superseded when replaced by better knowledge, and archived when stale — so that the knowledge base converges toward essential truths over time rather than growing linearly.

**Why this priority**: Without lifecycle management, the knowledge base is write-only. Supersession is what enables knowledge to evolve. Staleness decay is what prevents noise accumulation. Together they make the knowledge base sharper over time, not bigger.

**Independent Test**: Can be tested by creating an entry, superseding it with a new entry, verifying the old entry is marked superseded and excluded from injection, and then verifying the new entry appears in dispatches.

**Acceptance Scenarios**:

1. **Given** a knowledge entry MEM042 that is no longer accurate, **When** the developer or agent creates a replacement entry MEM128, **Then** MEM042 is marked `superseded_by: MEM128`, excluded from the index, and preserved in the detail file for audit trail.
2. **Given** a knowledge entry with confidence 0.95 created 120 days ago and never verified since, **When** the staleness decay function runs, **Then** the effective confidence is reduced by the decay formula: `effective_confidence = confidence * decay_factor(days_since_verified)`. The decay function is configurable (default: linear decay to 0.5 at 180 days).
3. **Given** a knowledge entry that was loaded into 15 dispatch payloads (hit_count=15), **When** the consolidation process evaluates entries, **Then** the entry's persistence priority is higher than an entry with hit_count=0 and the same confidence score.
4. **Given** two knowledge entries about the same subsystem with overlapping content, **When** the consolidation process runs, **Then** it flags the overlap for human review with a suggested merge — it does NOT auto-merge.
5. **Given** a completed phase that produced 3 new knowledge entries, **When** the phase summary is written, **Then** each entry includes provenance: `source_unit` (which phase), `source_type` (execution, research, verification failure), and `created_at` timestamp.

---

### User Story 3 - Knowledge Index Format (Priority: P3)

As a context builder, I need a lightweight index that I can load in O(1) and scan in O(n) where n is the number of index lines (not the total content of all entries) — so that dispatch payload assembly is fast even on large projects.

**Why this priority**: The index is the performance-critical data structure. If the context builder must read all detail files to decide what to include, the three-temperature architecture provides no benefit.

**Independent Test**: Can be tested by creating an index with 1000 entries and verifying that the context builder selects the correct entries without reading any detail files that aren't ultimately included in the payload.

**Acceptance Scenarios**:

1. **Given** a `KNOWLEDGE-INDEX.md` file, **When** it is loaded, **Then** each line contains: entry ID, scope tags, category, confidence score, last_verified date, hit_count, and a one-line description — sufficient to make inclusion/exclusion decisions without reading the detail file.
2. **Given** the index format, **When** parsed by `scope-filter.sh`, **Then** filtering by scope tag, category, or confidence threshold can be done with `grep` and `awk` on the index alone — no detail file reads required.
3. **Given** an index with 1000 entries, **When** the context builder selects 12 entries for a dispatch, **Then** only those 12 detail files are read from `knowledge/{category}/{entry-id}.md`.
4. **Given** a knowledge entry is created, updated, superseded, or archived, **When** the operation completes, **Then** the index is updated atomically (write to temp file, then `mv`).
5. **Given** a corrupted or missing index, **When** the orchestrator starts, **Then** it rebuilds the index by scanning all detail files in `knowledge/` — the index is a derived artifact, not the source of truth.

### Index Entry Format

```
MEM127 | [project] | convention | 0.90 | 2026-04-01 | verified:2026-04-08 | hits:12 | Screen wrappers must use SafeAreaProvider not SafeAreaView
```

Fields: `id | scope_tags | category | confidence | created_at | last_verified | hit_count | description`

---

### User Story 4 - Knowledge Graph Relationships (Priority: P4)

As an orchestrator user, knowledge entries can declare relationships to other entries, decisions, and phases — so that the context builder can traverse related knowledge clusters rather than relying solely on scope tags for relevance.

**Why this priority**: Scope tags are a coarse filter. Two entries can share the same scope tag but be completely unrelated (e.g., a UI convention and a database gotcha both tagged `[milestone:M008]`). Graph relationships enable the context builder to pull in a coherent cluster: "this gotcha relates to this decision which established this pattern."

**Independent Test**: Can be tested by creating a cluster of 3 related entries (gotcha + decision + pattern) with explicit relationships, then verifying that when the context builder includes one, it can optionally traverse and include the related entries.

**Acceptance Scenarios**:

1. **Given** a knowledge entry MEM042 with `relates_to: [D089, MEM015]`, **When** the context builder includes MEM042, **Then** it can optionally traverse the relationships and include D089 and MEM015 if they aren't already in the payload. Traversal depth is configurable (default: 1 hop).
2. **Given** a decision D089 that established a pattern, **When** D089 is included in a dispatch, **Then** any knowledge entries that reference D089 in their `relates_to` field are candidates for inclusion (bidirectional traversal).
3. **Given** a relationship graph with cycles (A relates to B, B relates to A), **When** the context builder traverses, **Then** it visits each entry at most once (cycle-safe traversal).
4. **Given** an entry with no `relates_to` field, **When** the context builder processes it, **Then** it is treated as a standalone entry with no graph traversal — relationships are optional, not required.

---

### User Story 5 - Pre-Inlined Dispatch with Manifest (Priority: P5)

As a dispatched agent, I receive a complete context payload with a manifest header listing all included sections, their line ranges, and token estimates — so that I can start executing immediately without spending tool calls reading files.

**Why this priority**: This is the highest-impact efficiency improvement. Each tool call an agent spends reading context files costs tokens and time. Pre-inlining eliminates these calls entirely. The manifest enables the agent to navigate the payload and skip sections it doesn't need.

**Independent Test**: Can be tested by dispatching a task and verifying that the agent's prompt contains all required context inlined, that the manifest accurately describes the payload sections, and that the agent completes the task with zero file-read tool calls for context (tool calls for actual implementation files are expected and normal).

**Acceptance Scenarios**:

1. **Given** a task dispatch, **When** the context builder assembles the payload, **Then** the payload is a single markdown document with all content inlined — the agent receives task plan, phase context, upstream summaries, knowledge entries, and decisions as literal text in the prompt.
2. **Given** the dispatch payload, **When** the agent reads the manifest header, **Then** the manifest lists each section with line range and estimated token count.
3. **Given** the dispatch payload, **When** the context builder writes it, **Then** static content (project context, architectural decisions, project-wide knowledge) appears FIRST in the document, and dynamic content (task-specific plan, upstream summaries) appears LAST — maximizing prompt caching hit rates.
4. **Given** a context budget of 30,000 tokens, **When** the assembled payload exceeds this budget, **Then** the context builder applies compression: first reduce optional sections, then summarize verbose upstream summaries, then drop lowest-confidence knowledge entries — never truncating the task plan.
5. **Given** a payload with sections from knowledge, decisions, and upstream summaries, **When** the agent references a specific knowledge entry, **Then** the entry's ID (e.g., MEM042) is preserved in the payload for traceability.

### Manifest Format

```markdown
# Dispatch Context — T03 (Phase P02, Milestone M001)
## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Task Plan | 15-89 | ~2,400 | required |
| Phase Goal & Must-Haves | 91-110 | ~600 | required |
| Upstream Summaries (P01) | 112-165 | ~1,800 | required |
| Knowledge (8 entries) | 167-230 | ~2,100 | filtered |
| Decisions (3 entries) | 232-255 | ~800 | filtered |
| Codebase Orientation | 257-310 | ~1,800 | optional |
| **Total** | | **~9,500** | |
```

---

### User Story 6 - Execution Telemetry (Priority: P6)

As an orchestrator user, every dispatch records structured telemetry — model used, tokens consumed, cache hit rate, duration, verification result — so that execution patterns become visible and inform future routing and budgeting decisions.

**Why this priority**: Without telemetry, the orchestrator operates blind. You cannot optimize what you cannot measure. Telemetry enables model routing, cost tracking, and identification of expensive task types.

**Independent Test**: Can be tested by dispatching 10 tasks and verifying that the execution log contains one entry per task with all required telemetry fields, and that the `/status` command surfaces aggregate metrics.

**Acceptance Scenarios**:

1. **Given** a task dispatch that completes, **When** the result is recorded, **Then** the `execution-log.jsonl` entry includes: `timestamp`, `unit_id`, `milestone`, `phase`, `task`, `model_used`, `tokens_input`, `tokens_output`, `tokens_cache_read`, `cost_estimated`, `duration_ms`, `tool_calls_count`, `verification_result`, `payload_bytes`.
2. **Given** a completed milestone, **When** the developer runs `/status`, **Then** the output includes aggregate metrics: total cost, average cost per task, average duration per task, cache hit rate, success rate, and comparison to prior milestones (if data exists).
3. **Given** execution telemetry from 50+ tasks, **When** the orchestrator classifies a new task's complexity, **Then** it can reference historical data: "tasks similar to this one (same category, similar scope) averaged X tokens and $Y cost."

---

### User Story 7 - Model Routing Configuration (Priority: P7)

As an orchestrator user, I can configure model routing so that task complexity classification maps to specific models — enabling cost optimization without sacrificing quality on complex tasks.

**Why this priority**: Model routing is a cost multiplier. Sending simple config changes to an expensive model wastes money. Sending complex architectural work to a cheap model wastes time on retries. The routing system should be configurable, not baked in.

**Independent Test**: Can be tested by configuring a routing table, dispatching tasks of varying complexity, and verifying that each task is routed to the correct model tier.

**Acceptance Scenarios**:

1. **Given** a `routing.yaml` configuration file, **When** a task is dispatched, **Then** the orchestrator classifies the task's complexity (light/standard/heavy) from task plan metadata and selects the model from the matching tier in the routing config.
2. **Given** no `routing.yaml` exists, **When** a task is dispatched, **Then** the orchestrator uses a sensible default (single model for all tasks) — routing configuration is optional.
3. **Given** a routing history showing that "light" tasks dispatched to the "standard" model had 100% success rate, **When** the orchestrator reviews routing effectiveness, **Then** it logs an optimization suggestion: "light tasks could use a cheaper model."
4. **Given** a task plan with explicit `complexity: heavy` frontmatter, **When** the orchestrator routes it, **Then** the explicit classification overrides the automatic classification.

### Routing Configuration Format

```yaml
# .specify/orchestrator/routing.yaml
models:
  heavy:
    id: "claude-opus-4-6"
    context_budget: 200000
  standard:
    id: "claude-sonnet-4-6"
    context_budget: 150000
  light:
    id: "claude-haiku-4-5"
    context_budget: 80000

classification:
  heavy: "new subsystem, >5 files, architectural decision, first phase"
  standard: "feature implementation, 2-5 files, follows established pattern"
  light: "config change, test addition, single-file edit, documentation"

history_weight: 0.3
budget_ceiling_usd: 50.00
```

---

### User Story 8 - Diagnostics Command (Priority: P8)

As an orchestrator user, I can run a diagnostics command that scans for anomalies — orphaned artifacts, stale knowledge, scope mismatches, cost spikes — so that I can maintain project health proactively.

**Why this priority**: Large projects accumulate drift. Without periodic diagnostics, orphaned artifacts waste context, stale knowledge misleads agents, and cost spikes go unnoticed until the budget is exhausted.

**Independent Test**: Can be tested by introducing deliberate anomalies (orphaned files, stale entries, scope mismatches) and verifying that the diagnostics command detects and reports each one.

**Acceptance Scenarios**:

1. **Given** a knowledge entry referencing a file that no longer exists, **When** diagnostics runs, **Then** it reports the stale reference with severity "warning" and suggests archiving the entry.
2. **Given** a task that cost 5x the average for its complexity tier, **When** diagnostics runs, **Then** it flags the cost spike with the unit ID, actual cost, and expected cost range.
3. **Given** knowledge entries with no scope tags, **When** diagnostics runs, **Then** it reports them as "unscoped — will be injected into all dispatches" and suggests adding scope tags.
4. **Given** diagnostics results, **When** written to disk, **Then** they are appended to `doctor-history.jsonl` for trend tracking across sessions.

---

### Edge Cases

- What happens when a knowledge entry's detail file exists but it has no index entry? The index rebuild (`rebuild-index` subcommand) must detect orphaned detail files and add them to the index.
- What happens when the index has an entry but the detail file is missing? The context builder must skip the entry, log a warning, and the diagnostics command must flag it for repair.
- What happens when two entries have the same `relates_to` target but conflicting content? The diagnostics command flags the conflict; the context builder includes both with a "CONFLICT" annotation.
- What happens when staleness decay reduces an entry's effective confidence below the injection threshold, but it has a high hit count? Hit count acts as a "keep-alive" signal: entries with hit_count > configurable threshold (default: 10) are exempt from staleness archival until manually reviewed.
- What happens when the knowledge graph has a deeply connected cluster (20+ entries reachable from one entry)? Traversal depth is capped (configurable, default: 1 hop) and total graph-injected entries are capped (configurable, default: 5) to prevent context bloat from a single traversal.
- What happens when a project has zero knowledge entries (fresh project)? The context builder emits an empty knowledge section — the knowledge architecture is additive, not required for basic operation.
- What happens when the manifest's estimated token counts are significantly wrong? The manifest includes a disclaimer that estimates are approximate. A future enhancement could use tokenizer-aware counting, but the initial implementation uses character-based estimation (4 chars per token).

## Requirements *(mandatory)*

### Functional Requirements

| ID | Description | Source |
|----|-------------|--------|
| FR-100 | Three-temperature knowledge storage: hot (index), warm (detail files, loaded on scope-match), cold (archived, never auto-injected) | US1 |
| FR-101 | Knowledge index file (`KNOWLEDGE-INDEX.md`) with one-line entries containing: ID, scope tags, category, confidence, created_at, last_verified, hit_count, description | US3 |
| FR-102 | Individual knowledge detail files at `knowledge/{category}/{entry-id}.md` with full content and metadata frontmatter | US1 |
| FR-103 | Cold storage at `knowledge/archive/` for entries below confidence threshold or past staleness limit | US1 |
| FR-104 | Knowledge entry lifecycle: create, update confidence, supersede (with `superseded_by` pointer), archive, promote from cold to warm | US2 |
| FR-105 | Staleness decay function: effective_confidence = confidence * decay_factor(days_since_verified). Configurable decay curve, default linear to 0.5 at 180 days | US2 |
| FR-106 | Hit count tracking: increment when entry is included in a dispatch payload | US2 |
| FR-107 | Overlap detection: flag entries with >70% content similarity in the same category for human review during consolidation | US2 |
| FR-108 | Source provenance on every entry: source_unit, source_type (execution/research/verification-failure), created_at | US2 |
| FR-109 | Index is a derived artifact: rebuildable from scanning all detail files. Atomic writes (temp file + mv) | US3 |
| FR-110 | Graph relationships via optional `relates_to` field in entry frontmatter. Bidirectional traversal, cycle-safe, depth-capped (default: 1 hop, max 5 entries per traversal) | US4 |
| FR-111 | Pre-inlined dispatch payload: single markdown document with all context inlined, manifest header with section line ranges and token estimates | US5 |
| FR-112 | Payload ordering: static content first (project context, decisions, project-wide knowledge), dynamic content last (task plan, upstream summaries) — for prompt caching optimization | US5 |
| FR-113 | Context budget enforcement: if payload exceeds budget, compress optional sections first, then summarize verbose summaries, then drop lowest-confidence knowledge. Never truncate task plan | US5 |
| FR-114 | Execution telemetry in `execution-log.jsonl`: model, tokens (input/output/cache), cost, duration, tool calls, verification result, payload bytes per dispatch | US6 |
| FR-115 | Aggregate metrics surfaced in `/status`: total cost, avg cost/task, avg duration, cache hit rate, success rate, cross-milestone comparison | US6 |
| FR-116 | Model routing configuration via `routing.yaml`: model map, complexity classification rules, history weight, budget ceiling | US7 |
| FR-117 | Automatic complexity classification from task plan metadata. Override via explicit `complexity` frontmatter field | US7 |
| FR-118 | Diagnostics command: detect orphaned artifacts, stale knowledge, scope mismatches, cost spikes. Output to `doctor-history.jsonl` | US8 |

### Non-Functional Requirements

| ID | Description |
|----|-------------|
| NFR-100 | Index load time: <50ms for 1000-entry index on commodity hardware |
| NFR-101 | Context builder total time (index load + scope filter + detail file reads + payload assembly): <500ms for typical dispatch (12 entries selected from 500-entry index) |
| NFR-102 | Index file size: <15KB for 1000 entries |
| NFR-103 | All knowledge operations (create, supersede, archive, promote) are idempotent |
| NFR-104 | Knowledge architecture is backward-compatible: existing KNOWLEDGE.md can be imported via migration (see spec 003) |
| NFR-105 | All scripts maintain Bash 3.2 compatibility (macOS default) |
| NFR-106 | No new hard dependencies: jq optional, no python3 required |

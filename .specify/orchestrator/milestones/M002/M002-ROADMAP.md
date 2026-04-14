---
schema_version: "1.0"
type: roadmap
milestone: "M002"
feature_ref: "002-knowledge-architecture"
feature_spec: "specs/002-knowledge-architecture/spec.md"
vision: "Replace flat KNOWLEDGE.md with a three-temperature knowledge architecture supporting supersession, staleness, graph relationships, and pre-inlined dispatch — enabling precise, minimal context for agents on projects of any size."
tier: "C"
created_at: "2026-04-09T22:30:00Z"
updated_at: "2026-04-09T22:30:00Z"
---

## Phases

- [x] **P01**: Knowledge Storage Foundation — "A developer can create individual knowledge detail files under `knowledge/{category}/`, each with YAML frontmatter, and the system builds a pipe-delimited `KNOWLEDGE-INDEX.md` that is scannable with grep/awk and rebuildable from disk."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `knowledge/{category}/{entry-id}.md` — individual detail file format with YAML frontmatter (id, scope_tags, category, confidence, created_at, last_verified, hit_count, relates_to, source_unit, source_type, superseded_by)
      - `KNOWLEDGE-INDEX.md` — pipe-delimited index file (one line per entry: `id | scope_tags | category | confidence | created_at | last_verified | hit_count | description`)
      - `scripts/knowledge/create-entry.sh` — creates a detail file and updates the index atomically
      - `scripts/knowledge/rebuild-index.sh` — scans all detail files and regenerates `KNOWLEDGE-INDEX.md`
      - `knowledge/archive/` — cold storage directory for archived entries
    - Consumes: nothing (foundation phase)

- [x] **P02**: Knowledge Entry Lifecycle — "A developer can supersede an entry with a replacement, observe staleness decay reduce effective confidence over time, promote a cold entry back to warm, and see overlap flagged during consolidation — all operations idempotent."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/supersede-entry.sh` — marks old entry `superseded_by: NEW_ID`, removes from index, preserves detail file
      - `scripts/knowledge/archive-entry.sh` — moves entry to `knowledge/archive/`, removes from index
      - `scripts/knowledge/promote-entry.sh` — moves archived entry back to warm, resets confidence, updates `last_verified`
      - `scripts/knowledge/update-confidence.sh` — adjusts confidence and updates index atomically
      - `scripts/knowledge/compute-staleness.sh` — computes `effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))`
      - `scripts/knowledge/detect-overlap.sh` — flags entries with >70% content similarity for human review
      - `scripts/knowledge/increment-hits.sh` — increments hit_count on an entry and updates index
    - Consumes:
      - `knowledge/{category}/{entry-id}.md` (from P01)
      - `KNOWLEDGE-INDEX.md` (from P01)
      - `scripts/knowledge/rebuild-index.sh` (from P01)
      - `knowledge/archive/` directory (from P01)

- [x] **P03**: Graph Relationships and Scope Filtering — "When the context builder includes a knowledge entry, it traverses the entry's `relates_to` links up to 1 hop (max 5 entries), handles cycles safely, and scope-filter.sh filters the index by tag/category/confidence without reading detail files."
  - Risk: medium
  - Depends: P01, P02
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/traverse-graph.sh` — given an entry ID, returns related entry IDs (1-hop, max 5, cycle-safe via visited set)
      - `scripts/knowledge/scope-filter.sh` — enhanced scope filter that operates on `KNOWLEDGE-INDEX.md` (filters by scope tag, category, confidence threshold using grep/awk)
      - `scripts/knowledge/resolve-entries.sh` — given a list of entry IDs, reads their detail files and returns content (used after scope-filter selects IDs from index)
    - Consumes:
      - `KNOWLEDGE-INDEX.md` (from P01)
      - `knowledge/{category}/{entry-id}.md` (from P01) — detail files read only for selected entries
      - `scripts/knowledge/compute-staleness.sh` (from P02) — effective confidence used in filtering decisions

- [x] **P04**: Pre-Inlined Dispatch with Manifest — "A dispatched agent receives a single markdown document containing an accurate manifest header with section line ranges and token estimates, all context inlined (static first, dynamic last), compressed to fit within the context budget — zero file-read tool calls needed for context."
  - Risk: high
  - Depends: P01, P02, P03
  - Boundary Map:
    - Produces:
      - `scripts/dispatch/build-context.sh` — rewritten context builder producing pre-inlined payload with manifest header
      - Manifest header format — table with Section, Lines, Est. Tokens, Priority columns
      - Payload section ordering — static content (project context, decisions, project-wide knowledge) first, dynamic content (task plan, upstream summaries) last
      - `scripts/dispatch/compress-payload.sh` — compression strategy when payload exceeds budget (drop optional sections, summarize verbose summaries, drop lowest-confidence knowledge; never truncate task plan)
      - Context budget enforcement interface — configurable token budget per dispatch
    - Consumes:
      - `KNOWLEDGE-INDEX.md` (from P01)
      - `knowledge/{category}/{entry-id}.md` (from P01) — selected detail files
      - `scripts/knowledge/scope-filter.sh` (from P03) — filters index to select entries
      - `scripts/knowledge/traverse-graph.sh` (from P03) — pulls related entries
      - `scripts/knowledge/resolve-entries.sh` (from P03) — reads selected detail files
      - `scripts/knowledge/increment-hits.sh` (from P02) — increments hit_count on included entries

- [x] **P05**: Execution Telemetry — "After dispatching 10 tasks, the execution log contains one entry per task with model, tokens, cost, cache hit rate, duration, and verification result; the /status command surfaces aggregate metrics including cross-milestone comparison."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - Extended `execution-log.jsonl` schema — adds fields: `model_used`, `tokens_input`, `tokens_output`, `tokens_cache_read`, `cost_estimated`, `cache_hit_rate`, `payload_bytes`
      - `scripts/telemetry/record-telemetry.sh` — appends a telemetry entry to execution-log.jsonl
      - `scripts/telemetry/aggregate-metrics.sh` — computes aggregate metrics (total cost, avg cost/task, avg duration, cache hit rate, success rate, cross-milestone comparison)
      - Updated `/status` output section — displays aggregate telemetry metrics
    - Consumes: nothing (telemetry schema is additive to existing execution-log.jsonl; does not depend on knowledge architecture)

- [x] **P06**: Model Routing Configuration — "A developer configures routing.yaml with model tiers, dispatches tasks of varying complexity, and each task routes to the correct model based on automatic classification from task plan metadata or explicit complexity frontmatter override."
  - Risk: low
  - Depends: P05
  - Boundary Map:
    - Produces:
      - `routing.yaml` format definition — model map (heavy/standard/light), classification rules, history_weight, budget_ceiling_usd
      - `scripts/dispatch/classify-complexity.sh` — classifies task complexity (light/standard/heavy) from task plan metadata; respects explicit `complexity` frontmatter override
      - `scripts/dispatch/select-model.sh` — selects model from routing config based on complexity classification
      - `templates/routing.yaml` — default routing configuration template
    - Consumes:
      - `scripts/telemetry/aggregate-metrics.sh` (from P05) — historical data for routing optimization suggestions
      - Extended `execution-log.jsonl` schema (from P05) — model_used field for routing history analysis

- [x] **P07**: Diagnostics Command — "Running /speckit.orchestrator.doctor detects orphaned artifacts, stale knowledge, unscoped entries, scope mismatches, and cost spikes; results appear on screen and are appended to doctor-history.jsonl for trend tracking."
  - Risk: low
  - Depends: P01, P02, P03, P04, P05, P06
  - Boundary Map:
    - Produces:
      - `commands/doctor.md` — agent instruction document for `speckit.orchestrator.doctor`
      - `scripts/diagnostics/run-doctor.sh` — orchestrates all diagnostic checks
      - `scripts/diagnostics/check-orphaned.sh` — detects index entries without detail files and detail files without index entries
      - `scripts/diagnostics/check-stale.sh` — detects entries past staleness threshold
      - `scripts/diagnostics/check-scope.sh` — detects unscoped entries and scope mismatches
      - `scripts/diagnostics/check-cost-spikes.sh` — detects tasks costing >5x their complexity tier average
      - `doctor-history.jsonl` — append-only log of diagnostic results for trend tracking
      - Updated `extension.yml` — registers the doctor command
    - Consumes:
      - `KNOWLEDGE-INDEX.md` (from P01) — for orphaned entry detection
      - `knowledge/{category}/{entry-id}.md` (from P01) — for detail file existence checks
      - `knowledge/archive/` (from P01) — for cold storage checks
      - `scripts/knowledge/compute-staleness.sh` (from P02) — for staleness threshold checks
      - `scripts/knowledge/scope-filter.sh` (from P03) — for scope mismatch detection
      - Extended `execution-log.jsonl` schema (from P05) — for cost spike detection
      - `routing.yaml` (from P06) — for complexity tier cost baselines

## Cross-Cutting Concerns

- **Bash 3.2 compatibility (NFR-105)** — P01, P02, P03, P04, P05, P06, P07. P01 establishes the pattern (no associative arrays, no `readarray`, no `mapfile`, no `[[ ]]` for portability where possible). All subsequent phases must conform. Test with `/bin/bash --posix` where practical.

- **Atomic writes via temp file + mv (FR-109)** — P01, P02, P03, P04. P01 establishes the pattern in `rebuild-index.sh`. P02 follows it in lifecycle scripts. P03 and P04 use it when updating index or writing payloads. Any script that modifies `KNOWLEDGE-INDEX.md` must use the temp-file-then-mv pattern.

- **Idempotent operations (NFR-103)** — P01, P02, P03, P04, P05, P06, P07. All knowledge operations and script executions must be idempotent. P01 establishes the convention (creating an already-existing entry is a no-op or update, not an error). All phases follow.

- **No hard dependencies — jq optional (NFR-106)** — P01, P02, P03, P04, P05, P06, P07. P01 establishes the convention: use jq if available, fall back to grep/sed/awk if not. P05 is particularly affected (JSONL parsing). All phases must include jq-free fallback paths.

- **Entry ID format (MEM###)** — P01, P02, P03, P04, P07. P01 defines the ID format and auto-increment logic. All phases that reference entries by ID must use the same format. IDs are immutable once assigned.

- **Error logging conventions** — P01, P02, P03, P04, P05, P06, P07. P01 establishes stderr output format for warnings and errors. All scripts follow the same convention for consistency.

## Dependency Graph

```
P01 ──→ P02 ──→ P03 ──→ P04
                              ↘
P05 ──→ P06 ──────────────────→ P07
```

Expanded view:

```
P01 (Storage Foundation)
 │
 ├──→ P02 (Entry Lifecycle)
 │     │
 │     └──→ P03 (Graph & Scope Filter)
 │           │
 │           └──→ P04 (Pre-Inlined Dispatch)
 │                 │
 │                 └──────────────────┐
 │                                    ▼
P05 (Telemetry) ──→ P06 (Routing) ──→ P07 (Diagnostics)
```

Two independent tracks converge at P07:
- Track A: P01 → P02 → P03 → P04 (knowledge architecture)
- Track B: P05 → P06 (telemetry and routing)
- P07 depends on all of P01-P06 (diagnoses every subsystem)

## Execution Order

1. **P01** (Storage Foundation) and **P05** (Telemetry) — can execute concurrently. P01 is the knowledge track foundation with no dependencies. P05 is the telemetry track foundation with no dependencies. High risk for P01 (all downstream phases depend on it); medium risk for P05.
2. **P02** (Entry Lifecycle) — depends on P01. High risk (lifecycle operations are foundational to knowledge quality). Executes after P01 completes.
3. **P03** (Graph & Scope Filter) and **P06** (Model Routing) — can execute concurrently. P03 depends on P01 + P02 (needs detail files and lifecycle scripts for graph traversal and filtering). P06 depends on P05 (needs telemetry for routing history). Medium risk for P03; low risk for P06.
4. **P04** (Pre-Inlined Dispatch) — depends on P01, P02, P03. High risk (complete rewrite of build-context.sh). Executes after P03 completes.
5. **P07** (Diagnostics) — depends on all prior phases (P01-P06). Low risk (read-only analysis of all subsystems). Executes last.

## Validation

- **No conflicting producers**: PASS — Each phase produces distinct scripts and artifacts. No two phases produce the same file. P01 produces `create-entry.sh` and `rebuild-index.sh`; P02 produces lifecycle scripts (`supersede-entry.sh`, `archive-entry.sh`, etc.); P03 produces `traverse-graph.sh`, `scope-filter.sh`, `resolve-entries.sh`; P04 produces `build-context.sh` and `compress-payload.sh`; P05 produces telemetry scripts; P06 produces routing scripts; P07 produces diagnostics scripts. No overlapping producers detected.

- **All consumed items have producers**: PASS — Every item in each phase's Consumes list maps to a Produces entry in an upstream phase. P02 consumes P01 outputs. P03 consumes P01 and P02 outputs. P04 consumes P01, P02, and P03 outputs. P05 consumes nothing. P06 consumes P05 outputs. P07 consumes outputs from P01-P06. All dependencies are satisfied.

- **DAG is acyclic**: PASS — The dependency graph forms two independent chains (P01→P02→P03→P04 and P05→P06) that converge at P07. No back-edges or cycles exist. Topological sort yields: {P01, P05} → {P02} → {P03, P06} → {P04} → {P07}.

- **Demo sentence coverage**: PASS — All 7 phases have concrete, testable demo sentences describing observable outcomes. P01: file creation and index scanning. P02: supersession, staleness, promotion, overlap detection. P03: graph traversal and scope filtering. P04: pre-inlined payload with manifest. P05: telemetry entries and aggregate metrics. P06: routing configuration and model selection. P07: diagnostic detection and doctor-history.jsonl.

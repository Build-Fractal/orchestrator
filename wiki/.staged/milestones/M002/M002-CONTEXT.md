---
schema_version: "1.0"
type: context-draft
milestone: "M002"
status: finalized
created_at: "2026-04-09T22:00:00Z"
finalized_at: "2026-04-09T22:00:00Z"
---

## Architectural Decisions

### AD-1: Shell scripts, not TypeScript — this is a spec-kit extension

This is a spec-kit extension using Bash 3.2+ shell scripts and markdown commands. It is NOT a standalone CLI or TypeScript project. All scripts must be Bash 3.2 compatible (macOS default). No python3 or jq hard dependencies (jq is optional for JSON parsing convenience). This aligns with NFR-105 and NFR-106 in the spec.

### AD-2: Pipe-delimited plain text knowledge index

The knowledge index (`KNOWLEDGE-INDEX.md`) uses pipe-delimited plain text, one entry per line. The format is parseable by grep/awk/sed without requiring jq or other tooling:

```
MEM### | [scope_tags] | category | confidence | created_at | verified:date | hits:N | description
```

This directly satisfies FR-101 and US3-AS2 (filtering with grep and awk on the index alone).

### AD-3: Individual markdown detail files with YAML frontmatter

Knowledge detail files are stored as individual markdown files at `knowledge/{category}/{entry-id}.md`. Each file has YAML frontmatter containing full metadata (confidence, scope_tags, relates_to, source_unit, source_type, superseded_by, etc.). The body contains the actual knowledge content. This satisfies FR-102 and enables the three-temperature architecture (FR-100) by making entries individually addressable.

### AD-4: Cold storage via directory separation

Entries below confidence threshold or past staleness limit move to `knowledge/archive/` — same file format as warm storage, just a different directory. This means archival is a simple `mv` operation, and promotion is a `mv` back. The index is rebuilt after any move. This satisfies FR-103.

### AD-5: Linear staleness decay with configurable floor

Staleness decay uses a linear function: `effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))`. The floor of 0.5 prevents entries from decaying to zero — even stale knowledge retains some value. The 180-day window and 0.5 floor are configurable via orchestrator config. This satisfies FR-105.

### AD-6: Optional graph relationships with bounded traversal

The `relates_to` field in entry frontmatter is optional. When present, the context builder can traverse 1-hop relationships by default. Graph traversal is capped at 5 entries pulled per dispatch to prevent context bloat from deeply connected clusters. Traversal is cycle-safe (visited set). Entries without `relates_to` are treated as standalone. This satisfies FR-110 and the deeply-connected-cluster edge case.

### AD-7: Pre-inlined dispatch payload — zero file reads for agents

`build-context.sh` outputs a complete markdown document with a manifest header. All content is inlined — agents receive everything in the prompt and make zero file-read tool calls for context. Static content (project context, architectural decisions, project-wide knowledge) appears first for prompt caching optimization, dynamic content (task plan, upstream summaries) appears last. This satisfies FR-111, FR-112, and US5.

### AD-8: Model routing via routing.yaml with complexity classification

Model routing is configured via `routing.yaml`. Complexity classification comes from task plan metadata (light/standard/heavy). The routing system is optional — if no `routing.yaml` exists, the orchestrator defaults to a single model for all tasks. Explicit `complexity` frontmatter in the task plan overrides automatic classification. This satisfies FR-116, FR-117, and US7.

### AD-9: Telemetry extends existing execution-log.jsonl

Execution telemetry expands the existing `execution-log.jsonl` schema with additional fields: `model_used`, `tokens_input`, `tokens_output`, `tokens_cache_read`, `cost_estimated`, `cache_hit_rate`. Aggregate metrics are surfaced in the `/status` command output. This satisfies FR-114, FR-115, and US6.

### AD-10: Diagnostics via new /speckit.orchestrator.doctor command

A new command `speckit.orchestrator.doctor` performs health checks: orphaned artifacts, stale knowledge, cost spikes, scope mismatches. Results are appended to `doctor-history.jsonl` for trend tracking. This satisfies FR-118 and US8.

### AD-11: Backward compatibility — existing KNOWLEDGE.md is importable

The existing flat KNOWLEDGE.md format must be importable into the new architecture. The new system is additive — projects can adopt incrementally. A project with no knowledge entries operates normally (empty knowledge section in dispatch payload). This satisfies NFR-104.

### AD-12: Constitution alignment

All design decisions align with the 7 governing principles, especially:
- **Principle I (Context Minimization)**: Three-temperature storage, scope filtering, and context budgets minimize what agents receive.
- **Principle V (Fresh Context Per Unit)**: Pre-inlined payloads give each dispatched agent a complete, self-contained context.
- **Principle VI (State On Disk Is Truth)**: The index is derived from detail files on disk; all state is file-based.
- **Principle VII (Knowledge Compounds)**: The entire architecture exists to make knowledge compound — supersession sharpens, staleness prunes, graph relationships connect, and the index makes it searchable.

## Scope Boundaries

### In Scope

- Three-temperature knowledge storage (hot/warm/cold) with index and detail files
- Knowledge entry lifecycle: create, update confidence, supersede, archive, promote
- Staleness decay function with configurable parameters
- Hit count tracking and persistence priority
- Overlap detection during consolidation (flag for human review, no auto-merge)
- Source provenance on all entries
- Pipe-delimited knowledge index with atomic writes and rebuild capability
- Graph relationships with bounded, cycle-safe traversal
- Pre-inlined dispatch payload with manifest header and section ordering for prompt caching
- Context budget enforcement with compression strategy
- Execution telemetry (model, tokens, cost, cache, duration, verification result)
- Aggregate metrics in /status output
- Model routing configuration via routing.yaml
- Complexity classification from task plan metadata
- Diagnostics command detecting orphaned artifacts, stale knowledge, scope mismatches, cost spikes
- Doctor history tracking in doctor-history.jsonl
- Backward-compatible import of existing KNOWLEDGE.md content

### Out of Scope

- Auto-merging overlapping knowledge entries (only flagging for human review)
- Tokenizer-aware token counting (initial implementation uses 4 chars/token estimation)
- Multi-agent validation (deferred — v0.1.0 is Claude Code only)
- Cross-project knowledge sharing or federation
- UI/dashboard for telemetry visualization
- Machine-learning-based complexity classification (rule-based only)
- Real-time knowledge updates during dispatch (knowledge is snapshotted at payload assembly time)

## Design Constraints

### Technical Constraints

- **Bash 3.2 compatibility**: All scripts must run on macOS default Bash (no associative arrays, no `readarray`, no `mapfile`). This is NFR-105.
- **No hard dependencies**: No python3, no jq required. jq is optional for JSON parsing convenience. This is NFR-106.
- **Performance targets**: Index load <50ms for 1000 entries (NFR-100). Context builder total time <500ms for typical dispatch (NFR-101). Index file <15KB for 1000 entries (NFR-102).
- **Idempotent operations**: All knowledge operations (create, supersede, archive, promote) must be idempotent (NFR-103).
- **Atomic writes**: Index updates use temp file + `mv` to prevent corruption.
- **spec-kit extension architecture**: All new functionality registers via extension.yml as commands, hooks, or scripts. No standalone binaries.

### Compatibility Constraints

- Existing KNOWLEDGE.md format must remain importable (NFR-104)
- Existing execution-log.jsonl entries must remain valid after schema expansion (additive fields only)
- Existing build-context.sh interface must be preserved (new capabilities are additive)

### Process Constraints

- This is a Tier C project requiring full orchestration: roadmap decomposition, cross-phase coordination, autonomous dispatch
- The 7 governing principles (especially I, V, VI, VII) constrain all design decisions
- Each phase must be independently dispatchable with zero-context task plans

## Open Questions

### Resolved During Discussion

1. **Shell scripts vs TypeScript?** — Resolved: Bash 3.2+ shell scripts. This is a spec-kit extension, not a standalone CLI.
2. **Knowledge index format?** — Resolved: Pipe-delimited plain text, parseable by grep/awk/sed.
3. **Detail file storage?** — Resolved: Individual markdown files at `knowledge/{category}/{entry-id}.md` with YAML frontmatter.
4. **Cold storage mechanism?** — Resolved: Move to `knowledge/archive/`, same format, different directory.
5. **Staleness decay function?** — Resolved: Linear decay with 0.5 floor at 180 days. Configurable.
6. **Graph traversal bounds?** — Resolved: 1-hop default, max 5 entries per traversal, cycle-safe.
7. **Dispatch payload format?** — Resolved: Pre-inlined markdown with manifest header. Static first, dynamic last.
8. **Model routing?** — Resolved: routing.yaml with complexity classification. Optional, defaults to single model.
9. **Telemetry storage?** — Resolved: Extend existing execution-log.jsonl. Aggregates in /status.
10. **Diagnostics command?** — Resolved: New /speckit.orchestrator.doctor. Output to doctor-history.jsonl.
11. **Backward compatibility?** — Resolved: KNOWLEDGE.md importable. New architecture is additive.
12. **Constitution alignment?** — Resolved: All decisions align, especially principles I, V, VI, VII.

### Remaining Open Questions

- **Migration story details**: The spec references "spec 003" for KNOWLEDGE.md migration. Should phase decomposition include migration scripting, or is that deferred to a separate milestone? (Likely deferred per the spec reference, but worth confirming during roadmap generation.)
- **Config location for decay parameters**: Should staleness decay configuration live in orchestrator.yaml, a dedicated knowledge-config.yaml, or in the extension.yml defaults? (Recommend orchestrator.yaml for simplicity — single config file for all orchestrator settings.)
- **Token estimation accuracy**: The spec acknowledges 4 chars/token is approximate. Should we track estimation accuracy in telemetry to calibrate later? (Low priority — could be a future enhancement flagged in knowledge.)

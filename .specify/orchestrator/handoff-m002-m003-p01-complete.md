# Handoff: M002 + M003 Phase P01 Complete

**Date**: 2026-04-09
**Context**: Building two features for spec-kit-orchestrator in parallel using the orchestrator's own workflow (dog-fooding).
**Working directory**: /Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator (git submodule of lakeledger)

## What We're Building

Two features for the spec-kit-orchestrator extension, specified, evaluated, roadmapped, and partially executed:

### M002 — Knowledge Architecture (spec 002)
**Spec**: `specs/002-knowledge-architecture/spec.md`
**Vision**: Replace flat KNOWLEDGE.md with three-temperature knowledge storage (hot index / warm detail files / cold archive) with supersession, staleness decay, graph relationships, pre-inlined dispatch, telemetry, model routing, and diagnostics.
**Tier**: C (full orchestration)
**8 user stories, 19 FRs (FR-100 to FR-118), 7 NFRs**

### M003 — Migration Tool (spec 003)
**Spec**: `specs/003-migration-tool/spec.md`
**Vision**: Build `/speckit.orchestrator.migrate` command to import knowledge, decisions, requirements, and milestone history from GSD2/GSD1/spec-kit into orchestrator format.
**Tier**: C (full orchestration)
**8 user stories, 20 FRs (FR-200 to FR-219), 6 NFRs**

## Current State

### M002 Roadmap (7 phases, 2 parallel tracks)
```
Track A: P01 ✅ → P02 → P03 → P04
Track B: P05 → P06
Convergence: P07 (depends on all)
```

| Phase | Title | Status | Depends |
|-------|-------|--------|---------|
| P01 | Knowledge Storage Foundation | **COMPLETE** (T01-T05 all pass) | none |
| P02 | Knowledge Entry Lifecycle | NOT STARTED | P01 |
| P03 | Graph Relationships & Scope Filtering | NOT STARTED | P01, P02 |
| P04 | Pre-Inlined Dispatch with Manifest | NOT STARTED | P01-P03 |
| P05 | Execution Telemetry | NOT STARTED | none |
| P06 | Model Routing Configuration | NOT STARTED | P05 |
| P07 | Diagnostics Command | NOT STARTED | P01-P06 |

### M003 Roadmap (6 phases)
```
P01 ✅ → P02 → P04 → P06
       → P03 ────→ P06
       → P05 ────→ P06
```

| Phase | Title | Status | Depends |
|-------|-------|--------|---------|
| P01 | Adapter Architecture & GSD2 Reader | **COMPLETE** (T01-T05 all pass) | none |
| P02 | Knowledge Migration Pipeline | NOT STARTED | P01 |
| P03 | Decision & Requirements Migration | NOT STARTED | P01 |
| P04 | Milestone History Tiering | NOT STARTED | P01, P02 |
| P05 | GSD v1 & Spec-Kit Adapters | NOT STARTED | P01 |
| P06 | Validation, Reporting & CLI | NOT STARTED | P02-P05 |

### Parallelism Opportunities (Next Wave)
- **M002/P02** and **M002/P05** can run in parallel (no dependency between tracks)
- **M003/P02**, **M003/P03**, and **M003/P05** can all run in parallel after P01
- Cross-milestone: M002 and M003 phases have NO file overlap and can execute concurrently
- **Caveat**: The orchestrator lock prevents two `/auto` runs simultaneously. Use manual dispatch via sub-agents (Option 3 pattern from this session) to parallelize.

## Files Created in This Session

### M002/P01 Scripts (knowledge storage foundation)
```
scripts/knowledge/lib/staleness.sh       — staleness decay: compute_effective_confidence()
scripts/knowledge/lib/index-utils.sh     — index CRUD: add/remove/update/has/get/format/next_id/write_full
scripts/knowledge/create-entry.sh        — create detail file + update index (idempotent)
scripts/knowledge/rebuild-index.sh       — regenerate index from all detail files
scripts/knowledge/update-entry.sh        — modify confidence/last_verified/hit_count
scripts/knowledge/supersede-entry.sh     — mark old superseded, remove from index, preserve file
scripts/knowledge/archive-entry.sh       — move warm→cold, remove from index
scripts/knowledge/promote-entry.sh       — move cold→warm, reset confidence, add to index
```

### M002/P01 Modified
```
scripts/dispatch/scope-filter.sh         — added filter_knowledge_index(), --min-confidence, --category
                                           (227 → 322 lines, auto-detects index vs flat format)
```

### M002/P01 Directories
```
knowledge/.gitkeep
knowledge/archive/.gitkeep
```

### M003/P01 Scripts (migration adapter infrastructure)
```
scripts/migrate/adapter-interface.sh     — adapter contract, TSV utilities, field constants (237 lines)
scripts/migrate/lib/sqlite-reader.sh     — sqlite3 CLI reader for 7 GSD2 tables (359 lines)
scripts/migrate/lib/json-fallback.sh     — jq-optional JSON parser + filesystem scanner (804 lines)
scripts/migrate/adapters/gsd2.sh         — GSD2 adapter: SQLite>JSON>empty fallback (268 lines)
scripts/migrate/lib/detect-source.sh     — auto-detect gsd2/gsd1/speckit/unknown (121 lines)
scripts/migrate/migrate.sh              — full CLI entry point with extraction pipeline (403 lines)
```

### M003/P01 Directories
```
scripts/migrate/adapters/
scripts/migrate/lib/
scripts/migrate/transform/               — empty, created for P02-P04
```

### Orchestrator Artifacts
```
specs/002-knowledge-architecture/spec.md  — full feature spec
specs/003-migration-tool/spec.md          — full feature spec
.specify/orchestrator/milestones/M002/    — evaluation, context, roadmap, P01 plans (T01-T05)
.specify/orchestrator/milestones/M003/    — evaluation, context, roadmap, P01 plans (T01-T05)
```

## Git State

**Nothing committed yet.** All changes are unstaged/untracked. The user should review and commit when ready. Key changes:
- 1 modified file: `scripts/dispatch/scope-filter.sh`
- ~20 new files across specs/, scripts/knowledge/, scripts/migrate/, knowledge/, .specify/orchestrator/milestones/

## Verified Against Real Data

The M003 migration adapter was tested against lakeledger's actual `.gsd/` directory:
- `gsd.db` (7.7MB): 152 knowledge, 153 decisions, 53 requirements, 43 milestones, 228 slices, 380 tasks, 1168 telemetry
- `memories-snapshot.json` (103KB): 128 active + 24 superseded entries
- Full CLI pipeline (`bash scripts/migrate/migrate.sh --path /Users/brettkellgren/Sites/lakeledger`) extracts all data successfully

## How to Continue

### Recommended next action
Run `/speckit.orchestrator.plan-phase` for the next phases. Multiple phases can be planned and executed in parallel:

**Priority 1 (both can start immediately):**
1. `M002/P02` — Knowledge Entry Lifecycle (overlap detection, compute-staleness, detect-overlap scripts)
2. `M003/P02` — Knowledge Migration Pipeline (transform intermediate TSV → detail files + index)

**Priority 2 (can start after P02 plans or in parallel with P02):**
3. `M002/P05` — Execution Telemetry (independent track, no deps on P02-P04)
4. `M003/P03` — Decision & Requirements Migration (depends only on P01)
5. `M003/P05` — GSD v1 & Spec-Kit Adapters (depends only on P01)

### Execution pattern used in this session
We bypassed the orchestrator lock by manually dispatching tasks via Claude Code sub-agents (Agent tool). The pattern:
1. Read the task plan
2. Spawn a sub-agent with the plan content as prompt, telling it to implement and verify
3. Wait for completion, check results
4. Dispatch next wave of independent tasks in parallel

This approach successfully executed 10 tasks across 2 milestones with up to 3 concurrent sub-agents.

### Note on M002/P02 overlap with P01 deliverables
The M002 roadmap's P02 boundary map lists some scripts that were already delivered in P01 (supersede-entry.sh, archive-entry.sh, promote-entry.sh). P02 should focus on what P01 didn't deliver:
- `scripts/knowledge/detect-overlap.sh` — content similarity detection
- `scripts/knowledge/compute-staleness.sh` — wrapper that applies decay to all entries
- Integration of staleness into the consolidation workflow
- Hit count increment integration into build-context.sh dispatch flow

Read the P02 boundary map in M002-ROADMAP.md carefully before planning.

## Key Architecture Decisions (from discuss phase)

### M002 (Knowledge Architecture)
- AD-1: Bash 3.2+ shell scripts (spec-kit extension, not standalone CLI)
- AD-2: Pipe-delimited plain text index (grep/awk/sed parseable)
- AD-3: Individual markdown detail files with YAML frontmatter
- AD-5: Linear staleness decay: `confidence * max(0.5, 1.0 - (days/180))`
- AD-6: Optional graph relationships (1-hop, max 5 entries, cycle-safe)
- AD-7: Pre-inlined dispatch (static first for prompt caching)
- AD-8: Model routing via routing.yaml (optional)

### M003 (Migration Tool)
- AD-1: Pluggable adapter architecture (one script per source format)
- AD-2: SQLite preferred, JSON fallback, filesystem fallback
- AD-3: Active milestone renumbered as M001 (fresh start)
- AD-5: Knowledge IDs preserved from source (MEM042 stays MEM042)
- AD-6: Decision numbering continues from source max +1
- AD-9: Bash 3.2, sqlite3 CLI, no jq hard dependency
- AD-10: Source directory NEVER modified (read-only)

## References
- Constitution: `.specify/memory/constitution.md` (7 governing principles)
- Orchestrator knowledge: `.specify/orchestrator/KNOWLEDGE.md`
- CLAUDE.md: project conventions and status
- Full roadmaps: `.specify/orchestrator/milestones/M002/M002-ROADMAP.md` and `M003/M003-ROADMAP.md`
- All task plans: `.specify/orchestrator/milestones/M00{2,3}/phases/P01/tasks/T0{1-5}-PLAN.md`

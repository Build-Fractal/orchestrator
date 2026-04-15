---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M007"
goal: "Add graph health checks to the diagnostics system"
demo_sentence: "Running `run-doctor.sh` reports graph health: disconnected components, orphaned entries with no relationships, broken supersession chains, and graph statistics (node count, edge count, average degree) -- all computed via SQL queries against knowledge.db."
risk: "low"
depends_on: ["P03"]
---

<!--
  P04 -- Graph-Aware Diagnostics
  ================================

  Context: P01 delivered graph-db.sh (get_db_path, db_query, db_init) and the
  knowledge.db schema (entries, edges, scope_tags). P02 rewrote traverse-graph.sh
  with recursive CTEs and added scope-filter.sh --graph mode. P03 added
  --provenance for supersession chain queries. The diagnostics system already
  has run-doctor.sh as a runner that calls individual check-*.sh scripts and
  aggregates scored results with the DOCTOR: protocol.

  This phase adds check-graph-health.sh -- a standalone diagnostic script that
  queries knowledge.db via graph-db.sh and reports graph health. It then
  integrates with run-doctor.sh as a new check in the diagnostic suite.

  Architectural decisions:
    AD-1  Source graph-db.sh for all DB access (db_query, get_db_path).
          No direct sqlite3 calls.
    AD-2  All graph analysis uses pure SQL queries (recursive CTEs for
          connected components, LEFT JOINs for orphan detection, etc.).
          No external graph algorithm libraries.
    AD-3  Emits DOCTOR:GRAPH_HEALTH structured output for run-doctor.sh
          consumption. Follows the same status=<ok|warn|skip> protocol as
          all other check-*.sh scripts.
    AD-4  Skips gracefully if knowledge.db does not exist (status=skip).

  Cross-phase dependencies:
    - P01 delivered graph-db.sh and the knowledge.db schema.
    - P03 delivered --provenance for supersession chain queries (used
      conceptually but not called -- check-graph-health.sh validates
      supersession integrity via direct SQL, not via traverse-graph.sh,
      to keep the diagnostic self-contained).
-->

## Must-Haves

### Truths

- check-graph-health.sh exists and sources graph-db.sh for DB access.
  - Check: `bash scripts/verify/m007-p04-check-graph-health-exists.sh`
- check-graph-health.sh reports graph statistics: entry count, edge count, scope_tag count, avg degree.
  - Check: `bash scripts/verify/m007-p04-graph-statistics.sh`
- check-graph-health.sh detects orphaned entries (entries with no edges).
  - Check: `bash scripts/verify/m007-p04-orphan-detection.sh`
- check-graph-health.sh detects broken supersession chains and dangling edges.
  - Check: `bash scripts/verify/m007-p04-integrity-checks.sh`
- check-graph-health.sh emits DOCTOR:GRAPH_HEALTH structured output.
  - Check: `bash scripts/verify/m007-p04-doctor-protocol.sh`
- run-doctor.sh includes graph health check in the diagnostic suite.
  - Check: `bash scripts/verify/m007-p04-doctor-integration.sh`

### Artifacts

- scripts/diagnostics/check-graph-health.sh (min 80 lines, contains "graph-db.sh" and "DOCTOR:GRAPH_HEALTH" and "orphan")
- scripts/diagnostics/run-doctor.sh (contains "check-graph-health.sh" and "Graph Health")
- scripts/verify/m007-p04-check-graph-health-exists.sh (min 10 lines, contains "check-graph-health.sh")
- scripts/verify/m007-p04-graph-statistics.sh (min 10 lines, contains "entries" and "edges")
- scripts/verify/m007-p04-orphan-detection.sh (min 10 lines, contains "orphan")
- scripts/verify/m007-p04-integrity-checks.sh (min 10 lines, contains "supersedes" and "dangling")
- scripts/verify/m007-p04-doctor-protocol.sh (min 10 lines, contains "DOCTOR:GRAPH_HEALTH")
- scripts/verify/m007-p04-doctor-integration.sh (min 10 lines, contains "run-doctor.sh")

### Key Links

- scripts/knowledge/lib/graph-db.sh -> scripts/diagnostics/check-graph-health.sh
- knowledge.db (entries, edges, scope_tags) -> scripts/diagnostics/check-graph-health.sh
- scripts/diagnostics/check-graph-health.sh -> scripts/diagnostics/run-doctor.sh

## Tasks

### T01: Create check-graph-health.sh + update run-doctor.sh + create verification scripts

Creates `scripts/diagnostics/check-graph-health.sh` -- a standalone diagnostic
script that sources graph-db.sh, queries knowledge.db, and reports graph health.
Implements five diagnostic checks via SQL: graph statistics, orphaned entries,
disconnected components, broken supersession chains, and dangling edges. Emits
DOCTOR:GRAPH_HEALTH structured output. Updates `scripts/diagnostics/run-doctor.sh`
to include the graph health check in the diagnostic suite (with knowledge.db
existence guard). Creates six static verification scripts.

Full plan: `tasks/T01-PLAN.md`

### T02: Integration testing with fixture knowledge.db

Creates a temporary fixture directory with a knowledge.db containing entries,
edges, and scope_tags that exercise all five health checks. Tests check-graph-health.sh
output against expected results: statistics are correct, orphans are detected,
components are counted, broken chains and dangling edges are flagged. Also
verifies run-doctor.sh integration. Creates one runtime verification script.

Full plan: `tasks/T02-PLAN.md`

## Task Dependencies

```
T01 (check-graph-health.sh + run-doctor.sh update + 6 static verification scripts)
  |
  +---> T02 (integration tests + 1 runtime verification script)
```

T01 is the entry point -- it creates the diagnostic script and wires it into
run-doctor.sh. T02 depends on T01 because it tests the script against fixture data.

## Files Likely Touched

- scripts/diagnostics/check-graph-health.sh (create)
- scripts/diagnostics/run-doctor.sh (modify -- add graph health check)
- scripts/verify/m007-p04-check-graph-health-exists.sh (create)
- scripts/verify/m007-p04-graph-statistics.sh (create)
- scripts/verify/m007-p04-orphan-detection.sh (create)
- scripts/verify/m007-p04-integrity-checks.sh (create)
- scripts/verify/m007-p04-doctor-protocol.sh (create)
- scripts/verify/m007-p04-doctor-integration.sh (create)
- scripts/verify/m007-p04-e2e.sh (create -- runtime integration test)

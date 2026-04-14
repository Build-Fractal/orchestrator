---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M007"
goal: "Rewrite traverse-graph.sh and scope-filter.sh to use SQLite recursive CTEs"
demo_sentence: "The context recipe declares graph_hops: 3 and traverse-graph.sh retrieves entries up to 3 relationship hops away using a recursive CTE, ranked by effective_confidence weighted by path distance — replacing the 172-line Bash BFS with a ~10-line SQL query."
risk: "medium"
depends_on: ["P01"]
---

<!--
  P02 -- Multi-Hop Context Retrieval
  ====================================

  Context: P01 delivered the SQLite graph backend — graph-db.sh library with
  6 functions and a 3-table schema (entries, edges, scope_tags), populated by
  rebuild-index.sh. The knowledge system now has a queryable relational store.

  This phase rewrites two scripts to consume that store:

  1. traverse-graph.sh — currently a 172-line Bash BFS with temp files, visited
     sets, and frontier swapping. Replaced by a ~10-line recursive CTE that
     queries both edge directions (relates_to is stored as directed edges but
     semantically bidirectional), with path-distance ranking.

  2. scope-filter.sh — currently 349 lines of grep/sed/awk parsing of flat
     markdown files. Gains a new --graph mode that queries entries and
     scope_tags tables directly via SQLite. The existing flat-file modes are
     preserved for backward compatibility.

  Architectural decisions:
    AD-1  Recursive CTE queries both source_id and target_id columns in the
          edges table to treat relates_to as bidirectional.
    AD-2  Path-distance ranking formula: effective_confidence * (1 / hop_distance).
    AD-3  scope-filter.sh --graph mode is an ADDITION, not a replacement.
          Existing flat-file filtering modes remain unchanged.
    AD-4  traverse-graph.sh preserves its existing CLI interface (--id,
          --max-depth, --max-entries) and adds --hops as an alias for
          --max-depth and --ranked for scored output.

  Cross-phase dependencies:
    - P01 delivered graph-db.sh (get_db_path, db_query) and the populated
      knowledge.db with entries, edges, scope_tags tables.
    - M004 delivered the recipe system and context-recipe.yaml schema.
-->

## Must-Haves

### Truths

- traverse-graph.sh uses a recursive CTE instead of Bash BFS for multi-hop traversal.
  - Check: `bash scripts/verify/m007-p02-traverse-recursive-cte.sh`
- traverse-graph.sh queries both edge directions (source_id and target_id) to treat relates_to as bidirectional.
  - Check: `bash scripts/verify/m007-p02-traverse-bidirectional.sh`
- traverse-graph.sh supports --hops flag for configurable hop depth (alias for --max-depth).
  - Check: `bash scripts/verify/m007-p02-traverse-hops-flag.sh`
- traverse-graph.sh --ranked mode outputs entries with path-distance-ranked scores.
  - Check: `bash scripts/verify/m007-p02-traverse-ranked-output.sh`
- scope-filter.sh supports --graph mode that queries knowledge.db via SQLite.
  - Check: `bash scripts/verify/m007-p02-scope-filter-graph-mode.sh`
- scope-filter.sh --graph mode applies scope, confidence, and category filters via SQL.
  - Check: `bash scripts/verify/m007-p02-scope-filter-graph-filters.sh`
- Both scripts source graph-db.sh and use db_query() for all SQLite access.
  - Check: `bash scripts/verify/m007-p02-scripts-source-graph-db.sh`

### Artifacts

- scripts/knowledge/traverse-graph.sh (min 50 lines, contains "recursive" and "graph-db.sh" and "db_query")
- scripts/dispatch/scope-filter.sh (min 200 lines, contains "graph-db.sh" and "--graph")
- scripts/verify/m007-p02-traverse-recursive-cte.sh (min 10 lines, contains "recursive")
- scripts/verify/m007-p02-traverse-bidirectional.sh (min 10 lines, contains "target_id")
- scripts/verify/m007-p02-traverse-hops-flag.sh (min 10 lines, contains "--hops")
- scripts/verify/m007-p02-traverse-ranked-output.sh (min 10 lines, contains "--ranked")
- scripts/verify/m007-p02-scope-filter-graph-mode.sh (min 10 lines, contains "--graph")
- scripts/verify/m007-p02-scope-filter-graph-filters.sh (min 10 lines, contains "scope_tags")
- scripts/verify/m007-p02-scripts-source-graph-db.sh (min 10 lines, contains "graph-db.sh")

### Key Links

- scripts/knowledge/lib/graph-db.sh -> scripts/knowledge/traverse-graph.sh
- scripts/knowledge/lib/graph-db.sh -> scripts/dispatch/scope-filter.sh
- knowledge.db (entries, edges, scope_tags) -> scripts/knowledge/traverse-graph.sh
- knowledge.db (entries, scope_tags) -> scripts/dispatch/scope-filter.sh

## Tasks

### T01: Rewrite traverse-graph.sh with recursive CTE

Replaces the 172-line Bash BFS in `scripts/knowledge/traverse-graph.sh` with
a SQLite recursive CTE query against knowledge.db. Sources `graph-db.sh` for
`get_db_path()` and `db_query()`. The recursive CTE queries both edge
directions (source_id and target_id) since relates_to is stored as directed
edges but is semantically bidirectional. Adds `--hops` as an alias for
`--max-depth`. Adds `--ranked` flag to output entries with path-distance
scores using the formula `effective_confidence * (1.0 / hop_distance)`.
Preserves the existing CLI interface: `--id`, `--max-depth`, `--max-entries`.
Default output remains one entry ID per line. Creates four verification
scripts for the traverse-graph.sh truths.

Full plan: `tasks/T01-PLAN.md`

### T02: Add --graph mode to scope-filter.sh

Adds a `--graph` mode to `scripts/dispatch/scope-filter.sh` that queries
knowledge.db directly via SQLite instead of parsing flat KNOWLEDGE-INDEX.md
or KNOWLEDGE.md files. Sources `graph-db.sh` for `get_db_path()` and
`db_query()`. The new mode queries the `entries` and `scope_tags` tables with
SQL WHERE clauses for scope matching, confidence thresholds, and category
filtering. Output format matches the existing pipe-delimited KNOWLEDGE-INDEX.md
format for downstream consumer compatibility. The existing flat-file filtering
modes (knowledge, knowledge_index, decisions) are preserved unchanged. Creates
three verification scripts for the scope-filter.sh truths.

Full plan: `tasks/T02-PLAN.md`

### T03: Integration testing + end-to-end verification

Creates a temporary fixture directory with knowledge entries and a populated
knowledge.db, then runs both rewritten scripts end-to-end to validate correct
behavior. Tests: multi-hop traversal returns correct entries at each depth,
bidirectional edge traversal works, ranked output includes correct scores,
scope-filter --graph mode filters correctly by scope/confidence/category.
Runs all seven phase verification scripts and confirms all print PASS. Cleans
up fixtures. No permanent files created.

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (traverse-graph.sh rewrite + 4 verification scripts)
  |
  +---> T03 (integration tests)
  |
T02 (scope-filter.sh --graph mode + 3 verification scripts)
  |
  +---> T03 (integration tests)
```

T01 and T02 are independent of each other — they modify different scripts and
can execute in parallel. T03 depends on both T01 and T02 because it tests the
full pipeline with both scripts against a populated knowledge.db.

## Files Likely Touched

- scripts/knowledge/traverse-graph.sh (rewrite)
- scripts/dispatch/scope-filter.sh (modify — add --graph mode)
- scripts/verify/m007-p02-traverse-recursive-cte.sh (create)
- scripts/verify/m007-p02-traverse-bidirectional.sh (create)
- scripts/verify/m007-p02-traverse-hops-flag.sh (create)
- scripts/verify/m007-p02-traverse-ranked-output.sh (create)
- scripts/verify/m007-p02-scope-filter-graph-mode.sh (create)
- scripts/verify/m007-p02-scope-filter-graph-filters.sh (create)
- scripts/verify/m007-p02-scripts-source-graph-db.sh (create)

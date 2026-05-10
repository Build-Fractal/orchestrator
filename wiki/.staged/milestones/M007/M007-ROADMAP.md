---
schema_version: "1.0"
type: roadmap
milestone: "M007"
feature_ref: "007-graph-enhanced-knowledge"
feature_spec: "specs/007-graph-enhanced-knowledge/spec.md"
vision: "Enable multi-hop graph traversal and provenance chain queries on the knowledge base via a SQLite recursive CTE backend — transforming context retrieval from conservative 1-hop grep to graph-powered discovery with zero new runtime dependencies."
tier: "C"
created_at: "2026-04-14T12:00:00Z"
updated_at: "2026-04-14T12:00:00Z"
---

## Phases

- [x] **P01**: SQLite Graph Backend — "A developer runs `rebuild-index.sh` and a `knowledge.db` SQLite database is created alongside the flat index, containing entries, edges, and scope_tags tables populated from knowledge entry frontmatter — with a NULL vector column ready for future sqlite-vec integration."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `knowledge.db` — SQLite database file (derived artifact, rebuilt from entry files)
      - SQL schema: `entries` table (all frontmatter fields + NULL vector column), `edges` table (relates_to + supersedes relationships), `scope_tags` table (normalized tag-to-entry mapping)
      - `scripts/knowledge/lib/graph-db.sh` — SQLite connection library (query helper, DB path resolution, error handling)
      - Updated `scripts/knowledge/rebuild-index.sh` — populates SQLite DB from knowledge entry file frontmatter alongside existing flat index rebuild
    - Consumes:
      - Knowledge entry files `knowledge/{category}/MEM###.md` (from [M002](../../milestones/M002/index.md))
      - Content hashes (from [M005](../../milestones/M005/index.md) P01)

- [x] **P02**: Multi-Hop Context Retrieval — "The context recipe declares `graph_hops: 3` and `traverse-graph.sh` retrieves entries up to 3 relationship hops away using a recursive CTE, ranked by effective_confidence weighted by path distance — replacing the 172-line Bash BFS with a ~10-line SQL query."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - Updated `scripts/knowledge/traverse-graph.sh` — rewritten from Bash BFS to `sqlite3` recursive CTE, configurable hop depth (`--hops N`), path-distance ranking
      - Updated `scripts/dispatch/scope-filter.sh` — SQLite query-based filtering replacing grep/sed parsing, supports `--graph` mode
      - Recipe section source type `source: graph` integration in context-recipe.yaml schema
      - Path-distance ranking formula: `effective_confidence * (1 / hop_distance)`
    - Consumes:
      - `knowledge.db` and `scripts/knowledge/lib/graph-db.sh` (from P01)
      - Recipe system and context-recipe.yaml schema (from [M004](../../milestones/M004/index.md))

- [x] **P03**: Provenance Chains — "Running `traverse-graph.sh --provenance MEM042` shows the full supersession chain from the current entry back to the original, displaying each entry ID, confidence, and creation date along the path."
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces:
      - `traverse-graph.sh --provenance` mode — recursive CTE following supersedes/superseded_by chains to origin entry
      - Structured provenance output: chain path with entry metadata (id, confidence, created_at, description) at each node
    - Consumes:
      - `scripts/knowledge/traverse-graph.sh` (rewritten version from P02)
      - `knowledge.db` (from P01)

- [x] **P04**: Graph-Aware Diagnostics — "Running `run-doctor.sh` reports graph health: disconnected components, orphaned entries with no relationships, broken supersession chains, and graph statistics (node count, edge count, average degree) — all computed via SQL queries against knowledge.db."
  - Risk: low
  - Depends: P03
  - Boundary Map:
    - Produces:
      - `scripts/diagnostics/check-graph-health.sh` — disconnected component detection, orphan identification, supersession chain integrity checks, graph statistics
      - Updated `scripts/diagnostics/run-doctor.sh` — includes graph health checks in diagnostic suite
      - Graph statistics output: node count, edge count, avg degree, largest connected component size
    - Consumes:
      - `knowledge.db` and `scripts/knowledge/lib/graph-db.sh` (from P01)
      - `traverse-graph.sh --provenance` (from P03, for chain integrity validation)

## Cross-Cutting Concerns

- **sqlite3 CLI calling convention** — P01, P02, P03, P04. P01 establishes the pattern in `graph-db.sh` (query helper, error handling, DB path resolution); P02–P04 must use this library rather than calling `sqlite3` directly.
- **Structured output format** — P01, P02, P03, P04. All scripts continue to emit prefixed lines (`CREATED:`, `UPDATED:`, `TRAVERSED:`, etc.) to stdout. SQL output is parsed into this format by wrapper functions in `graph-db.sh`.
- **Bash 3.2 compatibility** — P01, P02, P03, P04. All SQL is passed to `sqlite3` via heredoc or `-cmd` flag. No associative arrays, no mapfile/readarray. P01 establishes the portable calling pattern.
- **Atomic file operations** — P01, P02. The `knowledge.db` file is rebuilt using the existing temp-file-then-mv pattern (write to `.tmp.$$`, then `mv`). SQLite's own journaling handles mid-query safety, but the full-rebuild pattern avoids partial DB states.

## Dependency Graph

```
P01 (SQLite Backend)
 └──→ P02 (Multi-Hop Retrieval)
       └──→ P03 (Provenance Chains)
             └──→ P04 (Graph Diagnostics)
```

Linear chain — no concurrent execution opportunities. Each phase modifies or extends artifacts produced by the prior phase.

## Execution Order

1. **P01** (SQLite Graph Backend) — foundation. Creates the database, schema, and library that all subsequent phases depend on. Medium risk due to schema design decisions.
2. **P02** (Multi-Hop Context Retrieval) — rewrites traverse-graph.sh and scope-filter.sh. Medium risk due to recursive CTE correctness and ranking logic. Must complete before P03 adds --provenance to the rewritten script.
3. **P03** (Provenance Chains) — adds --provenance flag to traverse-graph.sh. Low risk — single recursive CTE on supersedes column. Must complete before P04 validates chain integrity.
4. **P04** (Graph-Aware Diagnostics) — final phase, adds health checks. Low risk — SQL queries for diagnostics, no novel algorithms.

## Validation

- **No conflicting producers**: PASS — P02 and P03 both modify traverse-graph.sh, but P03 depends on P02 (sequential, not conflicting). No other shared artifacts.
- **All consumed items have producers**: PASS — all consumed items traced to upstream produces entries. External dependencies (M002 entry files, M004 recipe system, M005 content hashes) are documented.
- **DAG is acyclic**: PASS — linear chain P01 → P02 → P03 → P04, trivially acyclic.
- **Demo sentence coverage**: PASS — all four phases have concrete, observable demo sentences describing specific commands and their expected output.

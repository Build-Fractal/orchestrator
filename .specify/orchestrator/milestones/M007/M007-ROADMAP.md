---
schema_version: "1.0"
type: roadmap
milestone: "M007"
feature_ref: "007-graph-enhanced-knowledge"
feature_spec: "specs/007-graph-enhanced-knowledge/spec.md"
vision: "Enable multi-hop graph traversal, semantic similarity search, and provenance chain queries on the knowledge base via an optional graph database backend — transforming context retrieval from conservative 1-hop grep to intelligent graph-powered discovery while maintaining graceful degradation to flat-file operations."
tier: "C"
created_at: "2026-04-10T23:45:00Z"
updated_at: "2026-04-10T23:45:00Z"
---

## Phases

- [ ] **P01**: Graph DB Backend — "A developer runs `rebuild-index.sh --graph` and the knowledge base is populated into a graph database with nodes for each entry and edges for relates_to, supersedes, and scope_tag co-occurrence — with automatic fallback to flat-file operations when the graph DB is unavailable."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - Graph DB selection decision (Memgraph, Neo4j, SQLite recursive CTEs, or NetworkX)
      - Graph schema definition (node labels, edge types, property mapping from frontmatter)
      - Updated `scripts/knowledge/rebuild-index.sh` — `--graph` mode populates graph alongside flat index
      - `scripts/knowledge/lib/graph-backend.sh` — connection management, query execution, fallback detection
      - Graph connection config in `orchestrator-config.yml`
    - Consumes:
      - Knowledge entry files (from M002)
      - Content hashes (from M005 P01)

- [ ] **P02**: Multi-Hop Context Retrieval — "The context recipe declares `graph_hops: 3` and `scope-filter.sh` retrieves entries up to 3 relationship hops away, ranked by effective_confidence weighted by path distance — producing richer context payloads than the current 1-hop/5-max limit."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces:
      - Updated `scripts/knowledge/scope-filter.sh` — graph-powered mode with configurable hop depth
      - Updated `scripts/knowledge/traverse-graph.sh` — delegates to graph DB when available, falls back to current 1-hop implementation
      - Recipe section source type `source: graph` in context-recipe.yaml schema
      - Path-distance ranking: `effective_confidence × (1 / hop_distance)`
    - Consumes:
      - Graph backend (from P01)
      - Recipe system (from M004 P04)

- [ ] **P03**: Vector Embeddings and Semantic Search — "A developer configures `filter: semantic` in a recipe section and the context builder retrieves the 5 knowledge entries most semantically similar to the current task description — without requiring explicit scope tag matching."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - Embedding computation script — generates vector embeddings for knowledge entry bodies
      - Vector index creation on graph DB
      - `filter: semantic` support in recipe parser and scope-filter.sh
      - Embedding API configuration in orchestrator-config.yml (provider, model, dimension)
    - Consumes:
      - Graph backend (from P01)
      - Embedding API (OpenAI, local model, or graph DB built-in)

- [ ] **P04**: Provenance and Impact Graphs — "Running `scripts/knowledge/traverse-graph.sh --provenance MEM042` shows the full supersession chain; `scripts/diagnostics/check-impact.sh` identifies which knowledge entries correlate with successful dispatches — enabling evidence-based context optimization."
  - Risk: medium
  - Depends: P01, P02
  - Boundary Map:
    - Produces:
      - `traverse-graph.sh --provenance` mode — follows supersession chains to origin
      - `scripts/diagnostics/check-impact.sh` — joins knowledge hit_count + graph relationships with execution-log.jsonl outcomes
      - Impact report: entries ranked by (hit_count × success_rate_of_dispatches_that_included_them)
    - Consumes:
      - Graph backend (from P01)
      - Multi-hop traversal (from P02)
      - execution-log.jsonl (from M001/M004)

- [ ] **P05**: Graph-Aware Diagnostics — "run-doctor.sh reports graph health: disconnected components, orphaned clusters, supersession chain integrity, and graph statistics (nodes, edges, avg degree) — with Cypher query output for visual exploration in Memgraph Lab."
  - Risk: low
  - Depends: P01, P02, P03, P04
  - Boundary Map:
    - Produces:
      - `scripts/diagnostics/check-graph-health.sh` — component analysis, orphan detection, chain integrity
      - Updated `scripts/diagnostics/run-doctor.sh` — includes graph checks when graph DB available
      - Cypher query output for visual exploration
      - Graph statistics in telemetry aggregation
    - Consumes: all prior phases

## Dependency Graph

```
P01 (Graph Backend)
 │
 ├──→ P02 (Multi-Hop Retrieval)
 │     │
 │     └──→ P04 (Provenance & Impact)
 │
 └──→ P03 (Vector Embeddings)
                │
P02, P03, P04 ──→ P05 (Graph Diagnostics)
```

## Execution Order

1. **P01** (Graph Backend) — high risk, foundation. Must complete first.
2. **P02** (Multi-Hop) and **P03** (Embeddings) — can execute concurrently after P01.
3. **P04** (Provenance) — depends on P01 + P02.
4. **P05** (Diagnostics) — depends on all prior. Low risk, final.

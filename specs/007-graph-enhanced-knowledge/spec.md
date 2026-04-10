# Spec 007: Graph-Enhanced Knowledge Retrieval

## Summary

Add an optional graph database backend (Memgraph or equivalent) behind the knowledge system to enable multi-hop traversal, semantic similarity search, provenance chain queries, and cluster detection — unlocking context retrieval capabilities that flat-file grep cannot provide while maintaining graceful degradation when no graph DB is available.

## Motivation

The orchestrator's knowledge system (M002) stores structured entries with explicit relationships (`relates_to`, `superseded_by`, `scope_tags`, `source_unit`). The current retrieval is limited to 1-hop traversal with a 5-entry cap because recursive graph traversal in Bash is expensive and fragile. A graph database removes this ceiling, enabling:

- **Multi-hop traversal** (2-3 hops): "Find all knowledge connected to this phase's decisions within 3 relationship hops" — a single Cypher query vs impossible recursive shell scripting
- **Semantic similarity**: "Find entries similar to this task's description" via vector embeddings — not possible with grep
- **Provenance chains**: "Where did this knowledge originate?" via directed supersession path queries
- **Cluster detection**: "These 5 entries form a concept group" via community detection algorithms
- **Impact analysis**: "What knowledge contributed to the most successful phases?" by joining knowledge hit_count with execution-log outcomes

### Prior Art

Evaluated `memgraph/ai-toolkit/unstructured2graph` (v0.1.4). It's a thin glue layer (~300 lines) using Unstructured (doc parsing) + LightRAG (LLM-powered entity extraction) + Memgraph (graph storage). The orchestrator does NOT need LLM-powered entity extraction — our entities are already explicit in frontmatter. What we'd borrow:

- **Graph schema pattern**: Nodes with properties, typed edges, Cypher queries for traversal
- **Vector search integration**: `CREATE VECTOR INDEX` + `vector_search.search()` for semantic retrieval
- **BFS traversal from seed nodes**: `MATCH (node)-[r*bfs]-(dst)` for multi-hop context gathering
- **Chunk→Entity linking pattern**: Adapted as Entry→Entry and Entry→Decision relationships

We would NOT use: Unstructured library (our content is already structured), LightRAG entity extraction (our entities are explicit), their generic doc→graph pipeline (we have domain-specific structure).

## Status

Spec stub — full user stories and functional requirements to be written when M004-M006 are complete. This milestone depends on the M004 engine and YAML recipe system being in place (graph search becomes a recipe section source type).

## Planned Scope (Draft)

### P01: Graph DB Backend
- Optional Memgraph (or Neo4j/SQLite with recursive CTEs) behind knowledge index
- `rebuild-index.sh --graph` populates graph from knowledge entry files
- Graph schema: nodes = entries, edges = relates_to + supersedes + same_scope_tag + same_source_unit + same_category
- Graceful degradation: falls back to flat-file grep when graph DB unavailable (constitution constraint)
- Connection config in orchestrator-config.yml

### P02: Multi-Hop Context Retrieval
- `scope-filter.sh` gains graph-powered mode
- Configurable in context-recipe.yaml: `graph_hops: 3` (currently hardcoded at 1), `graph_max_entries: 15`
- Cypher query: `MATCH (entry)-[*1..N]-(related) WHERE entry.scope_tags CONTAINS $tag`
- Results ranked by `effective_confidence × (1 / path_distance)`
- Recipe section source type: `source: graph` (designed in M004, implemented here)

### P03: Vector Embeddings and Semantic Search
- Compute embeddings for knowledge entry bodies (requires embedding API — OpenAI, local model, or Memgraph built-in)
- Enable semantic search: "find entries most relevant to this task description"
- Vector index on entry body text, queryable via `vector_search.search()`
- Recipe section filter: `filter: semantic` alongside existing `filter: scope`
- Optional — system works without embeddings, just loses semantic retrieval

### P04: Provenance and Impact Graphs
- Supersession chain queries: `MATCH path = (entry)-[:SUPERSEDES*]-(origin) RETURN path`
- Impact analysis: join knowledge graph with execution-log.jsonl outcomes
- "What knowledge was included in dispatches that succeeded vs failed?"
- "What decision clusters are most referenced by high-confidence knowledge?"
- Powers diagnostics doctor enhancements and engine context optimization

### P05: Graph-Aware Diagnostics
- `run-doctor.sh` gains graph health checks: disconnected components, orphaned clusters, supersession chain integrity
- Visualization output: Cypher queries that can be pasted into Memgraph Lab for visual exploration
- Graph statistics in telemetry: node count, edge count, avg degree, largest component

## Dependencies

- **M004** (Engine Architecture): Recipe system must exist — graph search is a `source: graph` section type in context-recipe.yaml
- **M005** (Hardening): Content hashing must exist — graph nodes use content_hash for change detection during rebuild
- **M006** (Documentation): Architecture docs must cover graph integration points

## Technology Evaluation Notes

### Memgraph
- In-memory graph DB, Cypher-compatible, MIT licensed
- Built-in vector search (`CREATE VECTOR INDEX`), BFS support, community detection (MAGE library)
- Python driver via `memgraph-toolbox`, also has bolt protocol for other languages
- Lightweight: single binary, Docker-friendly, ~50MB memory for small graphs
- Trade-off: requires running process (not file-based like SQLite)

### Alternatives to Evaluate
- **Neo4j Community**: More mature, larger ecosystem, but heavier (JVM-based)
- **SQLite with recursive CTEs**: No external process, but no vector search or graph algorithms
- **DuckDB**: Columnar analytics, has recursive CTEs, no native graph algorithms
- **NetworkX (Python)**: In-memory graph library, no persistence, but perfect for small knowledge bases (<1000 entries)
- **Plain file upgrade**: Extend current traverse-graph.sh to support 2-3 hops with memoization — no new dependency, but O(n²) at scale

Decision deferred to M007 discuss phase. The right choice depends on: knowledge base size at that point, whether the orchestrator has gained a Python component by then (via Conversus integration), and whether the vector search capability justifies the operational overhead.

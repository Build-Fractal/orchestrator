# Spec 007: Graph-Enhanced Knowledge Retrieval

## Summary

Add a SQLite graph backend to the knowledge system to enable multi-hop traversal, provenance chain queries, and graph-aware diagnostics — upgrading context retrieval from 1-hop grep to recursive CTE-powered graph queries with no additional runtime dependencies.

## Motivation

The orchestrator's knowledge system (M002) stores structured entries with explicit relationships (`relates_to`, `superseded_by`, `scope_tags`, `source_unit`). The current retrieval is limited to 1-hop traversal with a 5-entry cap because recursive graph traversal in Bash is expensive and fragile. A SQLite graph backend removes this ceiling using recursive CTEs, enabling:

- **Multi-hop traversal** (2-3 hops): "Find all knowledge connected to this phase's decisions within 3 relationship hops" — a single recursive CTE vs impossible recursive shell scripting
- **Provenance chains**: "Where did this knowledge originate?" via directed supersession path queries
- **Graph-aware diagnostics**: Disconnected components, orphaned entries, chain integrity checks
- **Forward-compatible schema**: Vector column (NULL) ready for future `sqlite-vec` semantic search integration

### Technology Decision: SQLite

Evaluated Memgraph, Neo4j, SQLite recursive CTEs, NetworkX, and DuckDB. SQLite selected because:

- `sqlite3` CLI ships with macOS — zero new dependencies
- File-based — no running process, no Docker, "just works"
- Shell scripts call `sqlite3` directly — preserves pure-Bash architecture
- Recursive CTEs handle multi-hop traversal efficiently for <1000 entries
- `sqlite-vec` extension available for future vector search (schema-ready, pipeline deferred)

Trade-offs accepted: no Cypher query language, no native graph algorithms (PageRank, community detection), no visual explorer. These capabilities are not needed at current scale (~150 entries, single user/project).

### Prior Art

Evaluated `memgraph/ai-toolkit/unstructured2graph` (v0.1.4). The orchestrator does NOT need LLM-powered entity extraction — our entities are already explicit in frontmatter. What we borrow conceptually:

- **Graph schema pattern**: Nodes with properties, typed edges, traversal queries
- **BFS traversal from seed nodes**: Adapted as recursive CTEs
- **Chunk-Entity linking pattern**: Adapted as Entry-Entry and Entry-Decision relationships

## Status

Technology decision finalized (SQLite). Scope reduced from original 5-phase plan: vector embeddings (P03) and impact analysis deferred to future milestones. No graceful degradation — SQLite is always available, making fallback architecturally unnecessary.

## Planned Scope

### P01: SQLite Graph Backend
- SQLite database (`knowledge.db`) as derived artifact from knowledge entry files
- `rebuild-index.sh` populates SQLite DB from knowledge entry file frontmatter
- Graph schema: `entries` table (all frontmatter fields + NULL vector column), `edges` table (relates_to + supersedes), `scope_tags` table
- No graceful degradation — SQLite is the required backend (always available, ships with macOS)
- Knowledge entry markdown files remain the source of truth; DB is rebuilt, not mutated
- Connection/query library in `scripts/knowledge/lib/graph-db.sh`

### P02: Multi-Hop Context Retrieval
- `scope-filter.sh` rewritten to use SQLite queries instead of grep/sed parsing
- `traverse-graph.sh` rewritten: 172-line Bash BFS replaced by recursive CTE (~10 lines of SQL)
- Configurable in context-recipe.yaml: `graph_hops: 3` (currently hardcoded at 1), `graph_max_entries: 15`
- Results ranked by `effective_confidence * (1 / path_distance)`
- Recipe section source type: `source: graph` (designed in M004, implemented here)

### P03: Provenance Chains
- Supersession chain queries: `WITH RECURSIVE` on the supersedes relationship
- `traverse-graph.sh --provenance` mode — follows supersession chains to origin entry
- Simple, high-value feature — one recursive CTE, rich output

### P04: Graph-Aware Diagnostics
- `run-doctor.sh` gains graph health checks: disconnected components, orphaned entries, supersession chain integrity
- Graph statistics: node count, edge count, avg degree, largest component
- SQL queries for each diagnostic (no external graph algorithm library)

## Deferred to Future Milestones

- **Vector embeddings / semantic search**: Schema includes vector column (NULL) for forward compatibility with `sqlite-vec`. Full pipeline (embedding provider, computation script, `filter: semantic`) deferred — requires Python for embedding computation, not justified at current knowledge base size
- **Impact analysis**: Correlating knowledge graph with execution-log.jsonl dispatch outcomes. Deferred until sufficient execution history exists for statistical significance
- **Community detection / clustering**: Not meaningful at <1000 entries. Available via Python (NetworkX) if needed later
- **Visual graph exploration**: No built-in explorer. Can export to DOT format if needed

## Dependencies

- **M004** (Engine Architecture): Recipe system must exist — graph search is a `source: graph` section type in context-recipe.yaml
- **M005** (Hardening): Content hashing must exist — graph nodes use content_hash for change detection during rebuild
- **M006** (Documentation): Architecture docs must cover graph integration points

## Design Constraints

- **Bash 3.2 compatibility**: All scripts must work on macOS default bash. No associative arrays, no mapfile/readarray.
- **`sqlite3` CLI only**: No compiled extensions in M007. Standard SQLite features only (recursive CTEs, window functions, JSON functions if needed).
- **Three-temperature architecture preserved**: Hot (KNOWLEDGE-INDEX.md) + warm (knowledge/{category}/MEM###.md) + cold (knowledge/archive/). SQLite DB is a parallel index, not a replacement for file-based entry storage.
- **Knowledge entry files are source of truth**: The SQLite DB is a derived artifact. Entry CRUD still writes to markdown files. The DB is rebuilt (not mutated) by `rebuild-index.sh`.
- **Atomic operations**: DB rebuild uses temp-file-then-mv pattern consistent with existing scripts.

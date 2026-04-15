---
schema_version: "1.0"
type: context-draft
milestone: "M007"
status: finalized
created_at: "2026-04-14T12:00:00Z"
finalized_at: "2026-04-14T12:00:00Z"
---

## Architectural Decisions

### AD-1: SQLite with Recursive CTEs as Graph Backend

**Decision:** Use SQLite (via `sqlite3` CLI) as the graph storage backend instead of Memgraph, Neo4j, or NetworkX.

**Rationale:**
- `sqlite3` ships with macOS — zero new runtime dependencies
- File-based — no process management, no Docker, no port configuration
- Shell scripts call `sqlite3` directly — preserves the pure-Bash architecture (no Python boundary)
- Recursive CTEs handle multi-hop traversal (2-3 hops) efficiently for <1000 entries
- Eliminates the graceful degradation question entirely — SQLite is always available, so there is nothing to fall back from
- Forward-compatible: `sqlite-vec` extension can be added later for vector search without schema migration

**Schema design includes a vector column (NULL initially)** for future sqlite-vec integration. This is a schema-only decision — no embedding pipeline is built in M007.

**Trade-offs accepted:**
- No Cypher query language (recursive CTEs are less expressive for complex graph patterns)
- No native graph algorithms (PageRank, community detection, Louvain)
- No built-in visual explorer (Memgraph Lab)
- These capabilities are not needed at current scale (~150 entries, single user)

### AD-2: No Graceful Degradation — Single Code Path

**Decision:** Hard-require the SQLite graph backend. No flat-file fallback, no dual code paths.

**Rationale:**
- Single user on one project — no deployment diversity to accommodate
- SQLite is always available (ships with macOS, no setup required), making fallback architecturally unnecessary
- Eliminates the complexity factor the original Tier C classification cited as "doubles the code paths"
- Existing flat-file scripts (traverse-graph.sh BFS, grep-based scope-filter.sh) are replaced, not wrapped

### AD-3: Pure-Bash Architecture Preserved

**Decision:** No Python introduced in M007. All graph operations use `sqlite3` CLI called from shell scripts.

**Rationale:**
- The codebase is 2,000+ lines of Bash 3.2-compatible scripts with established patterns (structured stdout, atomic file writes, portable sed)
- `sqlite3` takes SQL on stdin, emits results on stdout — fits the existing pipe-and-parse architecture
- traverse-graph.sh's 172-line Bash BFS becomes a ~10-line `sqlite3` call with a recursive CTE
- Python is only needed when/if the embedding pipeline (vector search) is added in a future milestone

## Scope Boundaries

### In Scope

- **P01: SQLite Graph Backend** — schema design (entries, edges, scope_tags tables + vector column stub), `rebuild-index.sh` populates SQLite DB from knowledge entry files, graph connection library for shell scripts
- **P02: Multi-Hop Context Retrieval** — `scope-filter.sh` and `traverse-graph.sh` rewritten to use recursive CTEs, configurable hop depth, path-distance ranking, `source: graph` recipe section type
- **P03: Provenance Chains** — supersession chain queries via recursive CTEs on the supersedes relationship, `traverse-graph.sh --provenance` mode
- **P04: Graph-Aware Diagnostics** — `run-doctor.sh` gains graph health checks (disconnected components, orphaned entries, chain integrity), graph statistics

### Out of Scope (Deferred)

- **Vector embeddings / semantic search** — deferred to future milestone. Schema includes vector column (NULL) for forward compatibility. Requires embedding provider (API or local model) which introduces Python — not justified at current knowledge base size (~150 entries) where structural retrieval covers all use cases
- **Impact analysis** (knowledge hits correlated with dispatch success rates) — deferred. Requires sufficient execution history for statistical significance. The join between knowledge graph and execution-log.jsonl is straightforward to add when data volume justifies it
- **Graceful degradation / flat-file fallback** — eliminated by technology choice (SQLite is always available)
- **Community detection / clustering algorithms** — not meaningful at <1000 entries
- **Visual graph exploration** — no Memgraph Lab equivalent; can export to DOT format if needed later

## Design Constraints

- **Bash 3.2 compatibility** — all scripts must work on macOS default bash. No associative arrays, no mapfile/readarray. Use indexed variables.
- **Atomic file operations** — SQLite DB writes use the existing temp-file-then-mv pattern for the `.db` file rebuild. SQLite's own ACID handles concurrent read safety.
- **Structured output convention** — all scripts continue to emit prefixed lines (`CREATED:`, `UPDATED:`, etc.) to stdout. `sqlite3` output is parsed into this format by wrapper scripts.
- **`sqlite3` CLI only** — no compiled SQLite extensions in M007. The `sqlite-vec` extension is a future addition. Standard SQLite features only.
- **Three-temperature architecture preserved** — hot (KNOWLEDGE-INDEX.md), warm (knowledge/{category}/MEM###.md), cold (knowledge/archive/). SQLite DB is a parallel index alongside the existing flat index, not a replacement for the file-based entry storage.
- **Knowledge entry files remain the source of truth** — the SQLite DB is a derived artifact rebuilt from entry files. Entry CRUD still writes to markdown files. The DB is rebuilt (not mutated) by `rebuild-index.sh`.

## Open Questions

None — all major decisions resolved during discussion. Minor implementation details (exact SQL schema, index strategy, error messages) to be resolved during phase planning.

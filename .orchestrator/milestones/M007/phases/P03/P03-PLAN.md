---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M007"
goal: "Add --provenance mode to traverse-graph.sh for supersession chain queries"
demo_sentence: "Running `traverse-graph.sh --provenance MEM042` shows the full supersession chain from the current entry back to the original, displaying each entry ID, confidence, and creation date along the path."
risk: "low"
depends_on: ["P02"]
---

<!--
  P03 -- Provenance Chains
  ==========================

  Context: P02 rewrote traverse-graph.sh to use SQLite recursive CTEs for
  multi-hop traversal of relates_to edges. The script sources graph-db.sh
  and uses db_query() for all SQLite access. P01 established the schema
  with `supersedes` and `superseded_by` TEXT columns on the `entries` table,
  plus `edge_type = 'supersedes'` rows in the `edges` table.

  This phase adds a `--provenance` flag to traverse-graph.sh that follows
  supersession chains instead of relates_to edges. Given an entry ID, it
  walks the supersedes column backward to find the origin entry, and walks
  superseded_by forward to find the latest entry, producing the full
  supersession chain with metadata at each node.

  Supersession chains model knowledge evolution:
    - Entry A (original, superseded_by = B)
    - Entry B (supersedes A, superseded_by = C)
    - Entry C (supersedes B, current)

  Given any entry in the chain, --provenance reconstructs the full chain
  from origin to current, marking the queried entry's position.

  Architectural decisions:
    AD-1  Two recursive CTEs: one walks backward via the `supersedes` column,
          one walks forward via `superseded_by`. Combined with UNION to produce
          the full chain.
    AD-2  Output format is structured text with depth indicators, not
          pipe-delimited. Provenance is human-readable diagnostic output,
          not machine-consumed pipeline data.
    AD-3  The --provenance flag is mutually exclusive with --ranked and
          --max-depth/--hops. Provenance always walks the full chain.

  Cross-phase dependencies:
    - P01 delivered graph-db.sh (get_db_path, db_query) and the entries table
      with supersedes/superseded_by columns.
    - P02 rewrote traverse-graph.sh to source graph-db.sh and use db_query().
-->

## Must-Haves

### Truths

- traverse-graph.sh supports --provenance flag for supersession chain queries.
  - Check: `bash scripts/verify/m007-p03-provenance-flag.sh`
- --provenance mode uses a recursive CTE on supersedes/superseded_by columns.
  - Check: `bash scripts/verify/m007-p03-provenance-cte.sh`
- --provenance output shows the full chain with entry metadata at each node.
  - Check: `bash scripts/verify/m007-p03-provenance-output-format.sh`
- --provenance correctly traverses a 3-entry supersession chain from any position.
  - Check: `bash scripts/verify/m007-p03-provenance-chain-traversal.sh`

### Artifacts

- scripts/knowledge/traverse-graph.sh (min 80 lines, contains "--provenance" and "supersedes" and "WITH RECURSIVE")
- scripts/verify/m007-p03-provenance-flag.sh (min 10 lines, contains "--provenance")
- scripts/verify/m007-p03-provenance-cte.sh (min 10 lines, contains "supersedes")
- scripts/verify/m007-p03-provenance-output-format.sh (min 10 lines, contains "PROVENANCE")
- scripts/verify/m007-p03-provenance-chain-traversal.sh (min 30 lines, contains "supersedes" and "knowledge.db")

### Key Links

- scripts/knowledge/lib/graph-db.sh -> scripts/knowledge/traverse-graph.sh
- knowledge.db (entries.supersedes, entries.superseded_by) -> scripts/knowledge/traverse-graph.sh

## Tasks

### T01: Add --provenance flag and CTE to traverse-graph.sh + create verification scripts

Adds a `--provenance` flag to `scripts/knowledge/traverse-graph.sh` that
triggers a supersession chain query instead of the normal relates_to
traversal. The provenance query uses two recursive CTEs: one walks backward
via the `supersedes` column to find the chain origin, and one walks forward
via `superseded_by` to find the chain tip. The results are combined and
ordered by depth to display the full chain. Output format is structured
text with a header line and indented chain entries showing ID, confidence,
created_at, description, and position label (origin/superseded/current).
Creates three static verification scripts that check file content patterns.

Full plan: `tasks/T01-PLAN.md`

### T02: Integration testing with fixture supersession chain

Creates a temporary fixture directory with a 3-entry supersession chain
(MEM010 -> MEM020 -> MEM030) in knowledge.db, then tests --provenance
from each position in the chain. Verifies: full chain is reconstructed
from any entry, output format matches specification, chain length is
correct, origin and current labels are correct. Creates one runtime
verification script that exercises the full provenance pipeline against
fixture data. Cleans up fixtures.

Full plan: `tasks/T02-PLAN.md`

## Task Dependencies

```
T01 (--provenance flag + CTE + 3 static verification scripts)
  |
  +---> T02 (integration tests + 1 runtime verification script)
```

T01 is the entry point -- it modifies traverse-graph.sh to add the
--provenance mode. T02 depends on T01 because it tests the --provenance
flag against fixture data.

## Files Likely Touched

- scripts/knowledge/traverse-graph.sh (modify -- add --provenance flag and CTE)
- scripts/verify/m007-p03-provenance-flag.sh (create)
- scripts/verify/m007-p03-provenance-cte.sh (create)
- scripts/verify/m007-p03-provenance-output-format.sh (create)
- scripts/verify/m007-p03-provenance-chain-traversal.sh (create)

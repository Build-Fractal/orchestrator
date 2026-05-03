---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M036"
goal: "Extend graph schema to traverse 3 new edge types (cites / derived_from / applies_to_field) and the [source:<cite_id>] tag namespace, additively over the existing relates_to/supersedes layer (CON-5)."
demo_sentence: "An operator authors a fixture spec chunk with cites: [REF-cms-rule-§483-20] plus a fixture reference chunk; runs `bash scripts/knowledge/traverse-graph.sh --id SPEC-requirement-FR-7 --max-depth 1`, sees the reference chunk in the output with edge label `cites`; runs `bash scripts/dispatch/scope-filter.sh knowledge/KNOWLEDGE-INDEX.md M036/P05 --tag '[source:cms-pbj-2024-q3]'` and gets matching chunks across spec/memory/reference categories."
risk: "high"
depends_on: ["P00"]
---

# Phase P05 — Graph Schema Extension

## Phase Summary

P05 closes the "additive over existing knowledge layer" gap declared by P00. P00 shipped the **declarative substrate** for the new edge types (`references/reference-edge-types.md` SSOT) and scope-tag namespace (`source:<cite_id>` row in `references/file-formats.md`) but deliberately did **not** modify any executable script (T02 P00 SUMMARY: "the traverser at `scripts/knowledge/traverse-graph.sh` was deliberately NOT modified — refactoring it to read from this SSOT is P05's contract"). P05 lands the **runtime extension** — the four scripts that actually walk graph edges and filter by scope tags now recognize the three new edge types and the `[source:...]` tag namespace.

Three runtime sites are extended additively:

1. **SQLite schema (`scripts/knowledge/lib/graph-db.sh`)** — the `edges` table currently has `CHECK(edge_type IN ('relates_to', 'supersedes'))`. Extend to the closed enum of 5 edge types declared in the P00 SSOT. Migration is required for any existing `knowledge.db` (SQLite cannot ALTER a CHECK constraint; the safe path is rebuild-from-source via `rebuild-index.sh` since the index is regenerable).
2. **Indexer (`scripts/knowledge/rebuild-index.sh`)** — currently reads only `relates_to` and `supersedes` frontmatter fields. Extend to read `cites`, `derived_from`, `applies_to_field` and insert corresponding edge rows. Without this, `traverse-graph.sh` has no edges to walk.
3. **Traverser (`scripts/knowledge/traverse-graph.sh`)** — currently the recursive CTE hardcodes `edge_type = 'relates_to'`. Extend to accept arbitrary edge types via a default-preserving `--edge-types <comma-list>` flag and to render the matching edge label for typed-edge results.
4. **Scope-filter (`scripts/dispatch/scope-filter.sh`)** — three sites need the new tag namespace: (a) the file-based `filter_knowledge` regex (line 155) matches `\[[a-z]+:[A-Za-z0-9/]+\]` which **does not** match `cms-pbj-2024-q3` (the `-` and digit-prefixed segments break the character class); (b) the index-mode `filter_knowledge_index` reuses the same matching logic; (c) the SQLite `filter_knowledge_graph` mode builds a `scope_clause` that has no `source:` branch. Add a top-level `--tag '<tag-literal>'` flag for the demo invocation and ensure it composes with the existing scope context.

CON-5 (the load-bearing invariant) requires that pre-P05 traversal of `relates_to`/`supersedes` and pre-P05 scope-filter behavior on existing tag namespaces remain **byte-identical**. P05 ships a regression guard test that asserts this — without the guard, a CHECK-constraint widening or a regex-character-class edit could silently shift output for in-scope chunks.

## Must-Haves

### Truths

- Graph DB schema accepts `cites` / `derived_from` / `applies_to_field` edge inserts without CHECK violation
  - Check: `bash tools/verify/m036-p05-edges-schema-accepts-new.sh`

- Pre-existing `relates_to` and `supersedes` edge inserts continue to succeed
  - Check: `bash tools/verify/m036-p05-edges-schema-accepts-old.sh`

- `rebuild-index.sh` populates edges from `cites` / `derived_from` / `applies_to_field` frontmatter
  - Check: `bash tools/verify/m036-p05-rebuild-emits-new-edges.sh`

- `traverse-graph.sh` walks `cites` edges and emits the edge label in `--ranked` / labeled output
  - Check: `bash tools/verify/m036-p05-traverse-cites.sh`

- `traverse-graph.sh` default invocation (no `--edge-types` flag) is byte-identical to pre-P05 for a relates_to fixture (CON-5 regression guard)
  - Check: `bash tools/verify/m036-p05-traverse-relates-to-baseline.sh`

- `scope-filter.sh` accepts `--tag '[source:<cite_id>]'` and returns chunks bearing that tag
  - Check: `bash tools/verify/m036-p05-scope-filter-source-tag.sh`

- `scope-filter.sh` invoked without `--tag` produces output byte-identical to pre-P05 for a fixture KNOWLEDGE-INDEX.md (CON-5 regression guard)
  - Check: `bash tools/verify/m036-p05-scope-filter-baseline.sh`

- `tests/test-reference-graph-edges.sh` exists, exercises SC-4 end-to-end (fixture spec + reference + traverse + grep), and exits 0
  - Check: `bash tools/verify/m036-p05-sc4-test-exists-and-passes.sh`

- Phase-suite aggregator runs all 8 sub-gates with `pass=8 fail=0`
  - Check: `bash tools/verify/m036-p05-phase-suite.sh`

### Artifacts

- `scripts/knowledge/lib/graph-db.sh` (modify; min 200 lines, contains `cites`)
- `scripts/knowledge/rebuild-index.sh` (modify; min 200 lines, contains `cites`)
- `scripts/knowledge/traverse-graph.sh` (modify; min 300 lines, contains `--edge-types`)
- `scripts/dispatch/scope-filter.sh` (modify; min 700 lines, contains `source:`)
- `tests/test-reference-graph-edges.sh` (create; min 50 lines, contains `SC-4`)
- `tools/verify/m036-p05-edges-schema-accepts-new.sh` (create; min 20 lines, contains `cites`)
- `tools/verify/m036-p05-edges-schema-accepts-old.sh` (create; min 20 lines, contains `relates_to`)
- `tools/verify/m036-p05-rebuild-emits-new-edges.sh` (create; min 30 lines, contains `cites`)
- `tools/verify/m036-p05-traverse-cites.sh` (create; min 30 lines, contains `cites`)
- `tools/verify/m036-p05-traverse-relates-to-baseline.sh` (create; min 30 lines, contains `CON-5`)
- `tools/verify/m036-p05-scope-filter-source-tag.sh` (create; min 30 lines, contains `source:`)
- `tools/verify/m036-p05-scope-filter-baseline.sh` (create; min 30 lines, contains `CON-5`)
- `tools/verify/m036-p05-sc4-test-exists-and-passes.sh` (create; min 15 lines, contains `test-reference-graph-edges`)
- `tools/verify/m036-p05-phase-suite.sh` (create; min 40 lines, contains `pass=`)

### Key Links

- `scripts/knowledge/traverse-graph.sh` → `references/reference-edge-types.md` (Principle XI: edge-type list read from SSOT, not hardcoded; via comment reference)
- `scripts/knowledge/lib/graph-db.sh` → `references/reference-edge-types.md` (CHECK constraint enum cross-references the SSOT)
- `tools/verify/m036-p05-phase-suite.sh` → `tools/verify/m036-p05-traverse-cites.sh` (aggregator wires sub-gate)
- `tests/test-reference-graph-edges.sh` → `scripts/knowledge/traverse-graph.sh` (test invokes traverser with new edge type)

## Tasks

### T01: Schema + indexer extension (graph-db + rebuild-index)

See `tasks/T01-schema-and-indexer-PLAN.md`.

### T02: Traverser extension (traverse-graph.sh recognizes new edge types)

See `tasks/T02-traverser-extension-PLAN.md`.

### T03: Scope-filter extension (`--tag '[source:...]'`)

See `tasks/T03-scope-filter-source-tag-PLAN.md`.

### T04: SC-4 fixture test + CON-5 regression guards + verifier suite

See `tasks/T04-sc4-test-and-verifiers-PLAN.md`.

## Task Dependencies

```
T01 ─┐
     ├─→ T04
T02 ─┤
     │
T03 ─┘
```

T02 depends on T01 (the CHECK constraint must accept new edge types before the traverser CTE walks them; the indexer-emitted edges are what the traverser reads). T03 is independent of T01/T02 (scope-filter reads frontmatter / pipe-delimited index, not the edges table). T04 depends on all three (its fixture exercises end-to-end).

## Files Likely Touched

- `scripts/knowledge/lib/graph-db.sh` (modify) — extend CHECK constraint enum
- `scripts/knowledge/rebuild-index.sh` (modify) — read 3 new frontmatter fields, insert edges
- `scripts/knowledge/traverse-graph.sh` (modify) — `--edge-types` flag + label-bearing output
- `scripts/dispatch/scope-filter.sh` (modify) — `--tag` flag + 3 regex / scope-clause sites
- `tests/test-reference-graph-edges.sh` (create) — SC-4 end-to-end fixture test
- `tools/verify/m036-p05-edges-schema-accepts-new.sh` (create)
- `tools/verify/m036-p05-edges-schema-accepts-old.sh` (create)
- `tools/verify/m036-p05-rebuild-emits-new-edges.sh` (create)
- `tools/verify/m036-p05-traverse-cites.sh` (create)
- `tools/verify/m036-p05-traverse-relates-to-baseline.sh` (create)
- `tools/verify/m036-p05-scope-filter-source-tag.sh` (create)
- `tools/verify/m036-p05-scope-filter-baseline.sh` (create)
- `tools/verify/m036-p05-sc4-test-exists-and-passes.sh` (create)
- `tools/verify/m036-p05-phase-suite.sh` (create)

## Path-Collision Check (Plan-Time Discipline rule 6)

Verified at plan-authoring time (2026-05-01):

- `tests/test-reference-graph-edges.sh` — does NOT exist. Safe to `create`.
- `tools/verify/m036-p05-*.sh` (all 9 verifiers) — do NOT exist. Safe to `create`.
- `tools/verify/p05-*.sh` (8 files) — exist but belong to **M030** (per filename conventions and `m030-classifier-corpus/README.md` references). M036 deliberately uses `m036-p05-*` slugs to avoid the M031→M036 collision class P00 surfaced. No collision.

## Notes — Plan-Time Discipline Rule 5 (real-DB verification)

This phase introduces SQL schema changes and SQL-bound code (CHECK constraint widening + new edge inserts via `rebuild-index.sh`). Per rule 5, the verification section satisfies condition (a) — the verifiers under `tools/verify/m036-p05-*.sh` operate against a real (mktemp-staged, freshly-`db_init`'d) SQLite database, not a mock. Each schema-touching verifier asserts the post-insert edge row exists in the real `edges` table by `SELECT COUNT(*)` against the staged DB. No "smoke test pending" callout is needed because the real-DB verification is in-loop.

The mock-vs-real-schema risk that motivated rule 5 is the **column-name drift** between planner spec vocabulary and persistence-layer schema names. P05's load-bearing names — `cites`, `derived_from`, `applies_to_field` — flow from the P00 SSOT (`references/reference-edge-types.md`) into the CHECK constraint enum unchanged. The verifiers grep for these literal names in both the SSOT and the schema source so any future drift fails the gate. There are no separate "spec vocabulary" and "persistence vocabulary" namespaces here; P05 deliberately holds them in lockstep.

## Notes — CON-5 Invariant Enforcement

The phase ships **two regression guards** explicitly named in the boundary map:

1. `tools/verify/m036-p05-traverse-relates-to-baseline.sh` — ingests a fixture corpus containing only `relates_to` and `supersedes` edges, runs the traverser with default flags, and `diff`s the output against a checked-in baseline. Any change to the `relates_to` CTE, the row formatting, or the WARNING emission causes a regression-guard failure.

2. `tools/verify/m036-p05-scope-filter-baseline.sh` — runs scope-filter against a fixture KNOWLEDGE-INDEX.md fragment that contains only pre-P05 tag namespaces (`[project]`, `[milestone:M001]`, `[phase:M001/P02]`), and `diff`s the output against a checked-in baseline. Any change to the scope-tag regex, the include logic, or the pass-through behavior causes a regression-guard failure.

Both guards live under `tests/fixtures/m036-p05-baseline/` (fixture corpus + expected-output baseline files); the path discipline matches the existing fixture convention (`tests/fixtures/state-executing`, `tests/fixtures/m030-classifier-corpus`).

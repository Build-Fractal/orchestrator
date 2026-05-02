---
schema_version: "1.0"
type: reference-edge-types
milestone: "M036"
phase: "P00"
created_at: "2026-05-01"
---

# Reference Knowledge Graph Edge Types (M036 SSOT)

The orchestrator's knowledge graph (`scripts/knowledge/traverse-graph.sh`)
walks typed edges declared in chunk frontmatter. M036 introduces three
new edge types alongside the two pre-existing edges. This file is the
single source of truth (Principle XI) for the edge-type list and each
edge's directionality.

Consumers:
- `scripts/knowledge/traverse-graph.sh` (P05) — additively extended to
  recognize the three new edge types alongside `relates_to` /
  `supersedes`.
- `references/reference-frontmatter-contract.md` (P00 T01) — declares
  the chunk-frontmatter fields whose values these edges traverse.
- `scripts/dispatch/scope-filter.sh` (P07) — uses `applies_to_field`
  edge to scope reference chunks for dispatch injection (FR-7).

## Edge Types

### cites (new in M036)

**Directionality**: directional, from citing chunk → cited reference.

**Frontmatter field**: `cites: [<chunk_id>, ...]`.

**Semantics**: the source chunk asserts that its content cites or
relies upon the target chunk's content. BFS traversal from a spec
chunk to its `cites:` targets surfaces authoritative reference
material in dispatch payloads.

**Example**: `SPEC-requirement-FR-7` declares `cites: [REF-cms-rule-483-20]`.

### derived_from (new in M036)

**Directionality**: directional, from downstream chunk → upstream
source.

**Frontmatter field**: `derived_from: [<chunk_id>, ...]`.

**Semantics**: the source chunk's content is derived from
(paraphrased, summarized, or extracted from) the target chunk.
Reverse-BFS from a regulatory rule surfaces the training material
derived from it.

**Example**: `REF-training-pbj-circle-2024-08` declares
`derived_from: [REF-cms-rule-483-20]`.

### applies_to_field (new in M036)

**Directionality**: directional, from chunk → field-name.

**Frontmatter field**: `applies_to_field: [<field-name>, ...]`.

**Semantics**: the chunk's content authoritatively governs one or
more named fields in the consumer project's domain model. Dispatch
injection (FR-7) walks this edge to surface field-scoped reference
excerpts when a task plan declares `applies_to_field: <name>`.

**Note**: `applies_to_field` is BOTH a frontmatter field name AND
an edge type — the field is interpreted as an edge by the graph
layer.

**Example**: `REF-cms-rule-483-20` declares
`applies_to_field: [staffing_hours_per_resident_day]`.

### relates_to (pre-existing — M011/M020)

**Directionality**: bidirectional.

**Frontmatter field**: `relates_to: [<chunk_id>, ...]`.

**Semantics**: undirected affinity. Pre-existing; declared here for
completeness. M036 does not modify `relates_to` semantics or the
traversal layer's handling thereof (CON-5).

### supersedes (pre-existing — M011/M020)

**Directionality**: directional, from newer chunk → older chunk.

**Frontmatter field**: `supersedes: [<chunk_id>]` (typically singleton).

**Semantics**: chain-walk to find the latest version. Pre-existing;
M036 reuses this edge for the reference-corpus supersede chain
(FR-10) without modification (CON-5).

## Adding a New Edge Type

New edge types require an M036 (or follow-on milestone) D-row in
`.orchestrator/DECISIONS.md` plus a coordinated update to:

- this file (declaration);
- `references/reference-frontmatter-contract.md` (frontmatter field
  declaration);
- `scripts/knowledge/traverse-graph.sh` (traversal logic).

No script shall hardcode the edge-type list (Principle XI).

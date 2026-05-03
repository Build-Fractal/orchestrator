---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P05"
milestone: "M036"
provides:
  - "edges.edge_type CHECK enum widened from 2 to 5 values (cites, derived_from, applies_to_field added); rebuild-index.sh extended with three new frontmatter-field reads (cites/derived_from/applies_to_field) and three corresponding edge-insert loops; three new shape verifiers under tools/verify/"
requires:
  - "from:M036/P00/T01 what:references/reference-frontmatter-contract.md (graph-edge field declarations); from:M036/P00/T02 what:references/reference-edge-types.md (5-edge SSOT); from:M020 what:scripts/knowledge/lib/graph-db.sh + scripts/knowledge/rebuild-index.sh"
affects:
  - "M036/P05/T02 (traverse-graph.sh --edge-types extension consumes the widened CHECK + populated edge rows); M036/P05/T03 (scope-filter.sh --tag flag); M036/P05/T04 (sc4-end-to-end test); M036/P07 (dispatch injection consuming edge rows)"
key_files:
  - "scripts/knowledge/lib/graph-db.sh; scripts/knowledge/rebuild-index.sh; tools/verify/m036-p05-edges-schema-accepts-new.sh; tools/verify/m036-p05-edges-schema-accepts-old.sh; tools/verify/m036-p05-rebuild-emits-new-edges.sh"
key_decisions:
  - "none"
patterns_established:
  - "SQLite CHECK-enum widening migration via rebuild-from-source (rebuild-index.sh always stages a fresh tmp_db before atomic mv promotion, so CHECK constraint upgrade requires no destructive migration step); per-frontmatter-field edge-loop pattern verbatim-replicated from relates_to canonical sample (locally-scoped *_target variable names avoid shadowing across loops); single-script-file verifier shape (AD-19) using mktemp staging + PROJECT_ROOT env override for fixture-driven rebuild testing without polluting live knowledge.db"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P05/tasks/T01-schema-and-indexer-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-05-02T03:30:20Z"
---

T01 of M036/P05 lands the schema + indexer half of the reference-corpus graph extension. Two surgical edits + three shape verifiers, all green.

**What changed**:

1. scripts/knowledge/lib/graph-db.sh line 73 (now line 84): edge_type CHECK enum widened from ('relates_to', 'supersedes') to ('relates_to', 'supersedes', 'cites', 'derived_from', 'applies_to_field'). Inline comment added pointing readers at the SSOT (references/reference-edge-types.md, M036/P00/T02) and listing the four-step extension protocol for future edge types. Top-of-file header comment added documenting the schema-evolution note: SQLite cannot ALTER a CHECK constraint, so rebuild-from-source via rebuild-index.sh is the migration path; rebuild always stages a fresh tmp_db before atomic mv promotion, so no destructive migration is needed for the orchestrators own knowledge.db.

2. scripts/knowledge/rebuild-index.sh: three new fm_field calls (cites_raw, derived_from_raw, applies_to_field_raw) added immediately after relates_to_raw at line ~102. Three new edge-insertion blocks added after the supersedes block (~line 140), each verbatim-adapted from the canonical relates_to loop with locally-scoped target-variable names (cite_target / derived_target / field_target) to avoid shadowing. The applies_to_field edges target field-name strings (opaque to the edge layer); the traverser in T02 will decide dereference policy.

3. Three new shape verifiers under tools/verify/:
   - m036-p05-edges-schema-accepts-new.sh: stages mktemp DB, db_init, three db_insert_edge calls (cites/derived_from/applies_to_field), asserts COUNT=3.
   - m036-p05-edges-schema-accepts-old.sh: same shape, asserts pre-existing relates_to + supersedes still work (CON-5 regression guard at the schema layer).
   - m036-p05-rebuild-emits-new-edges.sh: stages mktemp knowledge/spec/requirement/SPEC-A.md fixture with all three new edge fields, invokes rebuild-index.sh via PROJECT_ROOT override, asserts each expected edge row present.

**Verification result**: 3/3 PASS. All three verifiers exit 0 with PASS: lines.

- bash tools/verify/m036-p05-edges-schema-accepts-new.sh -> PASS: m036-p05-edges-schema-accepts-new (3 new-edge rows)
- bash tools/verify/m036-p05-edges-schema-accepts-old.sh -> PASS: m036-p05-edges-schema-accepts-old (2 legacy-edge rows)
- bash tools/verify/m036-p05-rebuild-emits-new-edges.sh -> PASS: m036-p05-rebuild-emits-new-edges (cites=1 derived_from=1 applies_to_field=1)

**CON-5 posture**: pre-feature behavior is byte-identical. No live chunk in knowledge/ today declares the new fields, so the live rebuild emits the same edge count as pre-T01. The schema CHECK is purely additive (relates_to + supersedes never removed); the rebuild loop only fires when the new fields are non-empty.

**Forward-pointing notes**:
- T02 (traverse-graph.sh --edge-types) consumes the widened CHECK and populated edges; the traverser default invocation (no --edge-types flag) must remain byte-identical for relates_to fixtures (M036/P05 must-have).
- T03 (scope-filter.sh --tag flag) is independent of the edge layer.
- T04 (SC-4 end-to-end fixture test under tests/) wires the full pipeline (frontmatter -> rebuild -> traverse) through one fixture.

**Phase-suite aggregator**: not authored by T01; M036/P05 phase-suite aggregator (tools/verify/m036-p05-phase-suite.sh) is a later-task / phase-close deliverable per the P00 precedent (T03 of P00 owned the m036-p00-phase-suite.sh aggregator).

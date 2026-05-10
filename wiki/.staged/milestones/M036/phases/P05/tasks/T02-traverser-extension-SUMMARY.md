---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M036"
provides:
  - "scripts/knowledge/traverse-graph.sh extended with --edge-types <comma-list> + --reverse flags; typed-edge SQL CTE branch (single-direction by default; --reverse swaps source/target roles); applies_to_field LEFT JOIN handling for field-name targets; output lines suffixed with |<edge_type> label in typed mode; tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt baseline file (7 bytes); two new shape verifiers under tools/verify/"
requires:
  - "from:M036/P00/T02 what:references/reference-edge-types.md (5-edge SSOT + directionality); from:M036/P05/T01 what:scripts/knowledge/rebuild-index.sh (populates new edge rows) + scripts/knowledge/lib/graph-db.sh (widened CHECK enum)"
affects:
  - "M036/P05/T03 (independent — unblocked); M036/P05/T04 (consumes --edge-types extension for SC-4 end-to-end fixture test); M036/P07 (dispatch injection consuming labeled traverser output)"
key_files:
  - "scripts/knowledge/traverse-graph.sh; tools/verify/m036-p05-traverse-cites.sh; tools/verify/m036-p05-traverse-relates-to-baseline.sh; tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt"
key_decisions:
  - "none"
patterns_established:
  - "guarded-branch CTE extension (typed-edge branch sits BEFORE legacy CTE with early exit 0; legacy SQL string untouched character-for-character; CON-5 byte-equality enforced mechanically via cmp -s against pre-edit baseline); LEFT JOIN + COALESCE pattern for asymmetric edge target types (applies_to_field targets field-name strings not chunk IDs; INNER JOIN would silently drop rows; comment-block at join site cites SSOT directionality table); pre-edit-baseline-capture sequencing (capture stdout BEFORE first edit; baseline-after-edit defeats the regression guard); IFS=',' subshell-bracketed comma-list parsing (matches scope-filter.sh --depends pattern; bash 3.2 / POSIX-sh safe; no read -ra); positionally-ordered output suffix (|<edge_type> appended only when --edge-types active so consumers can grep without disturbing default shape)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P05/tasks/T02-traverser-extension-PAYLOAD.md; .orchestrator/milestones/M036/phases/P05/tasks/T02-traverser-extension-PLAN.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-02T03:38:07Z"
---

T02 of M036/P05 lands the traverser-extension half of the reference-corpus graph extension. Three artifact deliverables + two verifiers, all green, with the legacy default-mode code path bytewise unchanged.

**What changed**:

1. scripts/knowledge/traverse-graph.sh: two new flags (--edge-types <comma-list>, --reverse) added to the existing argument-parsing block. A NEW typed-edge CTE branch was inserted BEFORE the legacy CTE block, guarded by `if [ -n "$edge_types" ]; then ... exit 0; fi`. When --edge-types is empty (sentinel), control falls through to the unchanged legacy CTE — bytewise byte-equality with pre-T02 for default-mode invocations (CON-5 contract). The typed-edge branch builds a SQL IN-clause from the comma-list using IFS=',' parsing wrapped in old_ifs save/restore (matches the scope-filter.sh --depends pattern; bash 3.2 / POSIX-sh safe; no read -ra). Each token escapes single quotes via the same `sed "s/'/''/g"` shape used by safe_id at line 74. Output lines are suffixed with `|<edge_type>` so consumers can grep the label. Forward direction by default; --reverse swaps source_id/target_id roles in the WHERE clauses (BFS walks targets-first, needed for the "BFS from cms-rule chunk in reverse, training chunk reachable via derived_from" SSOT acceptance scenario).

2. applies_to_field special case: target_id of an applies_to_field edge is a field-name string (e.g., `staff_count`), not a chunk ID, so no entries row exists for it. The typed-edge SELECT uses `LEFT JOIN entries` + `COALESCE(e.id, r.id)` so field-name targets surface as `<field-name>|applies_to_field` instead of being silently dropped by an INNER JOIN miss. An inline comment block at the join site explains the asymmetry and cites references/reference-edge-types.md (M036/P00/T02). The --ranked variant uses an INNER JOIN because it needs e.confidence (a NULL value would break the printf format string); applies_to_field + --ranked is documented as out-of-scope behavior.

3. Two new shape verifiers under tools/verify/:
   - m036-p05-traverse-cites.sh: stages a fixture spec chunk (SPEC-FR-7) declaring `cites: [REF-cms-rule-483-20]` + the corresponding reference chunk; rebuilds the staged DB; sanity-checks the cites edge row exists; runs traverse-graph.sh --id SPEC-FR-7 --edge-types cites --max-depth 1; asserts stdout contains `REF-cms-rule-483-20|cites`.
   - m036-p05-traverse-relates-to-baseline.sh: CON-5 regression guard. Stages two MEM entries (MEM001 with `relates_to: [MEM002]`); rebuilds the staged DB; runs default-mode traverse-graph.sh; byte-compares stdout against tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt (`cmp -s`).

4. tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt: NEW baseline file (7 bytes: `MEM002\n`). Captured BEFORE any edits to traverse-graph.sh by running the unmodified traverser against the same fixture corpus the verifier stages. Sequencing matters: baseline-after-edit defeats the guard.

**Verification result**: 2/2 PASS for T02 deliverables; 5/5 PASS across all P05 verifiers (T01 + T02 combined; no regression).

- bash tools/verify/m036-p05-traverse-cites.sh -> PASS: m036-p05-traverse-cites (cites edge surfaced with label)
- bash tools/verify/m036-p05-traverse-relates-to-baseline.sh -> PASS: m036-p05-traverse-relates-to-baseline (CON-5 byte-identical)
- bash tools/verify/m036-p05-edges-schema-accepts-new.sh -> PASS (T01, re-run; no regression)
- bash tools/verify/m036-p05-edges-schema-accepts-old.sh -> PASS (T01, re-run; no regression)
- bash tools/verify/m036-p05-rebuild-emits-new-edges.sh -> PASS (T01, re-run; no regression)

Sanity-check sweep (out-of-band, not part of must-haves but exercises the new branch end-to-end):
- `--edge-types applies_to_field` from a chunk with `applies_to_field: [staff_count]` emits `staff_count|applies_to_field` (LEFT JOIN preserves field-name targets).
- `--edge-types applies_to_field --reverse` from `staff_count` emits `SPEC-X|applies_to_field` (BFS targets-first).
- Default-mode against the same applies_to_field-only fixture emits empty output (legacy relates_to-only semantics preserved when no relates_to edges exist).

**CON-5 posture**: confirmed bytewise. The default code path is structurally separated from the typed-edge branch by a guard clause + early `exit 0`; the legacy CTE source SQL string is untouched character-for-character. The verifier mechanically enforces this contract via cmp(1) against a baseline captured before any traverser edits — any future change that perturbs default-mode output will fail this verifier loudly.

**Pre-existing fragility surfaced (not in T02 scope)**: rebuild-index.sh (modified by T01) inherits a pipefail-grep failure mode: when fm_field is called against a chunk file LACKING any of the new edge fields (cites / derived_from / applies_to_field), the inner `grep '^cites:'` returns nonzero, pipefail propagates, and `set -e` exits the script silently. This means today the live `bash scripts/knowledge/rebuild-index.sh` invocation against the live `knowledge/` tree exits 1 (because no live MEM file declares the new fields). T02's fixtures work around this by always declaring the three new fields with empty `[]` values so fm_field's grep finds the line. **Recommendation for T03 / T04 / phase close**: harden `fm_field()` in rebuild-index.sh to tolerate missing fields (e.g., `|| true` after the grep, or use `awk` instead of `grep`). This is a T01 paper-cut, surfaced by T02's investigation but not its responsibility to fix. The work-around is documented inline in the m036-p05-traverse-relates-to-baseline.sh verifier.

**Forward-pointing notes**:
- T03 (scope-filter.sh --tag) is independent of the traverser layer and unblocked.
- T04 (SC-4 end-to-end fixture test) consumes the `--edge-types` extension this task lands. The demo invocation from the phase plan's `demo_sentence` (`bash scripts/knowledge/traverse-graph.sh --id SPEC-requirement-FR-7 --edge-types cites --max-depth 1`) is now functional given the appropriate fixture corpus.
- The phase-suite aggregator (tools/verify/m036-p05-phase-suite.sh) is a phase-close deliverable per the P00 precedent; not authored by T02.
- The fm_field-pipefail fragility (above) should be folded into T03's plan or surface as a P05 phase-close paper-cut.

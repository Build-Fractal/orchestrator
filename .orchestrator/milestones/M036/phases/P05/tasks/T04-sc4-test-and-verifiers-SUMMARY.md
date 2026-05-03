---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P05"
milestone: "M036"
provides:
  - "SC-4 end-to-end fixture test (tests/test-reference-graph-edges.sh) + SC-4 truth-check wrapper (tools/verify/m036-p05-sc4-test-exists-and-passes.sh) + 8-gate phase-suite aggregator (tools/verify/m036-p05-phase-suite.sh)"
requires:
  - "from:T01 what:m036-p05-edges-schema-accepts-new.sh + m036-p05-edges-schema-accepts-old.sh + m036-p05-rebuild-emits-new-edges.sh; from:T02 what:m036-p05-traverse-cites.sh + m036-p05-traverse-relates-to-baseline.sh; from:T03 what:m036-p05-scope-filter-source-tag.sh + m036-p05-scope-filter-baseline.sh"
affects:
  - "P05 close (gates the M036/P05 SUMMARY for milestone-suite consumption)"
key_files:
  - "tests/test-reference-graph-edges.sh,tools/verify/m036-p05-sc4-test-exists-and-passes.sh,tools/verify/m036-p05-phase-suite.sh"
key_decisions:
  - "none"
patterns_established:
  - "phase-suite aggregator slot uses milestone-prefixed slug (m036-p05-phase-suite.sh) per plan-phase.md Plan-Time Discipline rule 6; SUB-FAIL diagnostic to stderr (debug surface) while stdout is reserved for the canonical SUMMARY line consumed by check-must-haves.sh; SC-4 test wrapped in tools/verify shape so the aggregator can consume it alongside shape verifiers (aggregator only knows tools/verify shape); fixture frontmatter mirrors the production chunk shape used by T01/T02 verifiers (full chunk-frontmatter contract: scope_tags, source_unit, content_hash, all 5 graph-edge fields) rather than the minimal payload-skeleton form, so the SC-4 test exercises the same code path real chunks travel"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P05/tasks/T04-sc4-test-and-verifiers-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-02T03:49:55Z"
---

T04 closes M036/P05 by landing the SC-4 acceptance test end-to-end and the phase-suite aggregator that gates the P05 SUMMARY. Three artifacts shipped:

1. tests/test-reference-graph-edges.sh -- SC-4 end-to-end integration test. Stages a fixture spec chunk (SPEC-requirement-FR-7) under PROJECT_ROOT=tmpdir/knowledge/spec/requirement/ declaring cites: [REF-cms-rule-483-20] with the full production frontmatter contract (scope_tags, source_unit, content_hash, all 5 graph-edge fields), plus the corresponding reference chunk under reference/cms-rule/. Runs scripts/knowledge/rebuild-index.sh against the staged tree (no live knowledge/ mutation), then traverses with --edge-types cites --max-depth 1 and asserts the literal substring REF-cms-rule-483-20|cites appears in the labeled output. MEM001/MEM002 conventions: pass_count/fail_count scalars (bash 3.2 safe), prefixed PASS/FAIL lines, mktemp + trap teardown, TEST summary line.

2. tools/verify/m036-p05-sc4-test-exists-and-passes.sh -- AD-19 single-script-file Truth Check wrapper. Asserts (a) the test file exists, (b) running it exits 0. Wraps the integration test in tools/verify shape so the phase-suite aggregator can consume it alongside the 7 sub-gate shape verifiers from T01/T02/T03 (the aggregator only knows tools/verify shape).

3. tools/verify/m036-p05-phase-suite.sh -- 8-gate phase-suite aggregator. Mirrors tools/verify/m036-p00-phase-suite.sh shape (run helper, single canonical SUMMARY line on stdout, SUB-FAIL diagnostics to stderr, exit 1 on any sub-gate fail). Wires all 8 P05 sub-gates: 3 from T01 (edges-schema-accepts-new, edges-schema-accepts-old, rebuild-emits-new-edges) + 2 from T02 (traverse-cites, traverse-relates-to-baseline) + 2 from T03 (scope-filter-source-tag, scope-filter-baseline) + 1 from T04 (sc4-test-exists-and-passes). Filename uses the milestone-prefixed slug per the post-M030/M031/M036 P00 collision discipline (commands/plan-phase.md Plan-Time Discipline rule 6).

Verification result: PASS at every gate.
- bash tools/verify/m036-p05-sc4-test-exists-and-passes.sh -> PASS: m036-p05-sc4-test-exists-and-passes (SC-4), exit 0.
- bash tools/verify/m036-p05-phase-suite.sh -> SUMMARY: m036-p05-phase-suite.sh pass=8 fail=0, exit 0.
- Direct test invocation bash tests/test-reference-graph-edges.sh -> PASS: SC-4: cites edge surfaced with label (REF-cms-rule-483-20|cites); TEST: pass=1 fail=0, exit 0.

Real-DB verification posture preserved: Every sub-gate the aggregator runs exercises real SQLite (T01: real db_init + INSERT; T02: real rebuild + recursive-CTE traverse; T03: real fixture + scope-filter; T04 SC-4: full path frontmatter -> real rebuild -> real DB -> real traverse -> grep label). No mocks; the rule-5 column-drift risk cannot apply because (a) edge-type names lockstep with the SSOT via grep checks in T01 verifiers, (b) the SC-4 test exercises the full path against real SQLite.

No path collisions: All three new artifacts use milestone-prefixed slugs (m036-p05-*.sh); none of them existed on disk before T04 dispatch (verified at task-execution time). The T01 paper-cut hardening to scripts/knowledge/rebuild-index.sh (fm_field() appending || true) is consumed transparently by the SC-4 test path -- rebuild-index exits 0 against the staged fixture without leaking the per-field grep failures.

---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P03"
milestone: "M020"
provides:
  - "tests/test-graduate-workflow.sh — SC-2 end-to-end integration test for the P03 graduate.sh extension; exercises four operational modes (three-entry cluster graduate, single-entry cluster graduate, cluster reject, cluster-membership-drift abort) using tempdir+PROJECT_ROOT+ORCH_ROOT fixture isolation; 31 assertions covering status flips, archived_into back-references, decision_history block presence, rationale text propagation, JSONL record counts (knowledge_graduate + knowledge_archive), drift-abort exit code + diagnostic + atomic byte-equivalence + zero-JSONL invariant"
requires:
  - "from:M020/P03/T01 what:scripts/knowledge/lib/decision-history.sh (dh_emit_jsonl writes JSONL records to ORCH_ROOT/execution-log.jsonl that the test asserts via grep -c). from:M020/P03/T02 what:scripts/knowledge/graduate.sh (full FR-3 cluster surface — --cluster id rationale text canonical-plus-siblings + --reject every-archived + cluster-membership-drift gate). from:M020/P01 what:scripts/knowledge/lib/frontmatter.sh (fm_append_decision_history shape: decision_history: YAML list whose records are flow-style maps with rationale + timestamp + operator + cluster_id; the test reads via grep, not full YAML parse)"
affects:
  - "M020/P03 phase-level verification (this is the SC-2 end-to-end smoke for the entire P03 graduate.sh surface). Future M020 phase verification ladders consume the same tempdir+PROJECT_ROOT+ORCH_ROOT fixture pattern."
key_files:
  - "tests/test-graduate-workflow.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "grep -c X file safe-counter — the grep -c pattern returns rc=1 when count is 0 AND prints 0 itself; the common '|| echo 0' fallback DOUBLES the count line and breaks subsequent integer comparisons. Wrap in a count_event helper that suppresses rc with '|| true' and defaults empty to 0. Single-script Verification Check shape (bash tests/test-graduate-workflow.sh) where the test file ITSELF uses heredocs + pipes + process redirections internally — AD-19 / AP-009 govern Bash tool-call shapes, not script internals; the harness shape-guard inspects only the directly-invoked command. Tempdir + trap-EXIT-rm-rf + PROJECT_ROOT + ORCH_ROOT env-override fixture isolation pattern (CON-1 / FR-8 read-only-during-dispatch) — every fixture lives under mktemp -d, and the live knowledge/** + .orchestrator/execution-log.jsonl are never touched. Portable md5 (macOS md5 -q vs linux md5sum) via 'command -v md5sum' fallback for byte-equivalence assertions on drift-abort. JSONL structural assertion via 'grep -c "event":"X"' instead of jq parsing — keeps jq optional per MEM001. fm_get awk frontmatter reader inlined in the test (reads first --- block, supports keys with single-line scalar values, strips wrapping quotes) — no source dependency on lib/frontmatter.sh because the test asserts the post-mutation file contract, not the helper's behavior."
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P03/tasks/T04-integration-test-PAYLOAD.md, .orchestrator/milestones/M020/phases/P03/tasks/T04-integration-test-PLAN.md, tests/test-graduate-workflow.sh"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-25T14:42:48Z"
---

## What was built

A single integration test, tests/test-graduate-workflow.sh, with 31 assertions across four cases:

1. **Three-entry cluster graduate** — fixture MEM700/MEM701/MEM702 candidates; graduate.sh --cluster Cint flips MEM700 (canonical, lex-first) to graduated, MEM701/MEM702 to archived with archived_into: MEM700; all three gain a decision_history block carrying the rationale text 'merge - same assertion'; .orchestrator/execution-log.jsonl gains exactly 1 knowledge_graduate + 2 knowledge_archive records.

2. **Single-entry cluster graduate** — fixture MEM710 candidate; graduate.sh --cluster Csingle flips MEM710 to graduated, NO archived_into (canonical never archives itself), decision_history written, JSONL log gains 1 knowledge_graduate + 0 knowledge_archive.

3. **Cluster reject** — fixture MEM720/MEM721 candidates; graduate.sh --reject --cluster Crej flips BOTH to archived, NEITHER gains archived_into (rejection has no canonical), both gain decision_history with the rejection rationale, JSONL log gains 0 knowledge_graduate + 2 knowledge_archive.

4. **Cluster-membership-drift abort** — fixture MEM730 (candidate) + MEM731 (already graduated). graduate.sh --cluster Cdrift exits non-zero, stderr carries cluster-membership-drift diagnostic, both files are byte-identical pre/post (md5 unchanged), and zero JSONL records reference Cdrift.

All test fixtures live under $tmpdir created by mktemp -d, with trap 'rm -rf $tmpdir' EXIT cleanup. The test exports PROJECT_ROOT (consumed by lib/index-utils.sh::get_project_root, which detail-utils.sh::find_detail_file honors) and ORCH_ROOT (consumed by decision-history.sh::dh_emit_jsonl as the JSONL log's parent). The live knowledge/** and .orchestrator/execution-log.jsonl are NEVER touched.

## Key decisions

- **count_event helper instead of grep -c with || echo 0 fallback.** Initial draft used 'grep -c PATTERN file || echo 0', which DOUBLES the count output line when grep finds 0 matches: grep -c emits '0', returns rc=1, then the fallback emits another '0', producing the literal two-line string '0\n0' — breaking all integer comparisons. Replaced with a count_event helper that suppresses rc with '|| true' and treats empty output as 0. This is a generally useful pattern for any test asserting absence of grep matches.
- **fm_get inlined as a private awk reader rather than sourcing lib/frontmatter.sh.** The integration test asserts the post-mutation file contract (what the file LOOKS like after graduate.sh runs), not the helper's internal behavior. Inlining keeps the test self-contained and makes failure diagnostics directly readable.
- **JSONL assertion via grep -c rather than jq parsing.** Per MEM001 jq-optional convention, the test does not require jq. Structural assertions use grep against canonical key strings ("event":"knowledge_graduate", "event":"knowledge_archive", Cdrift). When jq is desired for shape-of-record assertions in a future P05 phase test, it will gate behind 'command -v jq' with a soft-skip fall-through.
- **Portable md5 fallback for byte-equivalence.** macOS ships md5 -q (BSD), linux ships md5sum (GNU). The md5_of helper detects md5sum first via 'command -v', falls back to 'md5 -q'. Used only on case 4 to assert atomic-abort byte-equivalence.

## Patterns established

- **count_event helper for safe grep -c counting.** See Key decisions above; reusable across any future integration test asserting absence/presence of pattern lines.
- **Single-script Verification Check + internal heredocs/pipes.** AD-19 / AP-009 govern Bash *tool-call* shapes, not script internals — the harness shape-guard inspects only the directly-invoked command. The test file uses heredocs, pipes, and process redirections internally; the Check command is a single 'bash tests/test-graduate-workflow.sh' invocation.
- **Tempdir + PROJECT_ROOT + ORCH_ROOT triple isolation.** CON-1 / FR-8 read-only-during-dispatch is enforced by combining mktemp -d for the file tree, PROJECT_ROOT for find_detail_file resolution, and ORCH_ROOT for dh_emit_jsonl's log path. This is the canonical pattern for any future graduate.sh / dh_emit_jsonl tests.
- **MEM002 pass()/fail() with parallel-indexed scalars.** No declare -A; pass_count + fail_count + fail_msgs as parallel scalars; PASS: / FAIL: prefixed lines per MEM001; summary count at end with non-zero exit on any fail.

## Verification results

bash tests/test-graduate-workflow.sh — 31/31 assertions PASS, exit 0. Final line: 'SC-2 + drift abort: all 31 cases PASS'.

git status knowledge/ — only the pre-existing hit_count touchups from the dispatch starting state; no new modifications attributable to T04.

git status .orchestrator/execution-log.jsonl — unchanged (the test's JSONL writes land at $tmpdir/orch-state/execution-log.jsonl via the ORCH_ROOT override).

## Demo sentence

> Running 'bash tests/test-graduate-workflow.sh' exercises graduate.sh end-to-end across the three-entry cluster graduate, single-entry cluster graduate, cluster reject, and cluster-membership-drift abort modes against tempdir fixtures, asserts 31 invariants (status flips, archived_into back-references, decision_history block + rationale, JSONL record counts, drift atomic byte-equivalence), and exits 0 with 'SC-2 + drift abort: all 31 cases PASS'.

## Plan deviations

- **count_event helper added beyond the inline 'grep -c || echo 0' shape printed in the task plan's Step 1 source.** The plan's literal source double-counts on zero-match cases; replaced with a small helper that suppresses rc and normalizes empty to 0. Behavioral contract identical to the plan's intent (assert N graduate + M archive records); only the implementation correctness improved.

## Downstream impact

- **M020 phase-level verification** rolls this test into the P03 must-have ledger as the SC-2 end-to-end gate. Tier-1 per-truth verifiers (T01/T02/T03 contract scripts) cover unit-level shape; this test covers full-stack workflow.
- **Future P05 (clustering) tests** can reuse the count_event helper and the tempdir+PROJECT_ROOT+ORCH_ROOT triple-isolation pattern. The P05 test will additionally exercise cluster boundary detection (jaccard.sh threshold) before invoking graduate.sh; T04 deliberately scopes only post-cluster-detection workflow.

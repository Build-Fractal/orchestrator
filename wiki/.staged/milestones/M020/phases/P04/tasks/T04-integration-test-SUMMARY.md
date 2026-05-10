---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P04"
milestone: "M020"
provides:
  - "tests/test-status-review-queue.sh — SC-3 end-to-end integration test for the P04 status.sh Review-Queue section; nine assertions across three scenarios (five-candidate/two-cluster, empty queue, stale-flag) plus FR-8/CON-1 read-only invariants; shadow-repo + helper-wrapper pattern pins fixture knowledge_root so the live cluster.sh + jaccard.sh + frontmatter.sh + staleness.sh pipeline runs end-to-end against tempdir fixtures while leaving live knowledge/ and .orchestrator/execution-log.jsonl untouched"
requires:
  - "from:M020/P04/T01 what:scripts/knowledge/compute-staleness.sh --review-queue [--knowledge-root <path>]; from:M020/P04/T02 what:scripts/orchestrator/status.sh Review-Queue section rendering"
affects:
  - "P04 phase verification rollup; SC-3 end-to-end coverage"
key_files:
  - "tests/test-status-review-queue.sh"
key_decisions:
  - "none-new,AD-19"
patterns_established:
  - "shadow-repo + wrapper helper pattern (T03 verifier carry-forward) — copies status.sh + state/ deps into a shadow scripts/ tree and stages a wrapper compute-staleness.sh that exec-pipes to the live helper with --knowledge-root pinned to the fixture; lets the real cluster.sh + jaccard.sh pipeline run end-to-end without touching live knowledge/. Distinct-vocabulary fixture pattern (P05/T04 carry-forward) — alpha/bravo/charlie disjoint single-token bodies with 6x repetition force deterministic clustering at 0.7 default threshold. tempdir + trap-EXIT-rm-rf + cd-into-fixture + minimal orch root with EVALUATION/ROADMAP/PLAN trio so derive-phase finds enough state to emit MILESTONE/STATE/PHASE lines. set -u (not -e) + MEM002 pass()/fail() parallel-indexed scalars + summary count + non-zero exit on any failure."
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P04/tasks/T04-integration-test-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-25T16:12:01Z"
---

DEVIATION from payload's literal test code: status.sh on main does not propagate --knowledge-root to its compute-staleness.sh helper invocation (the helper resolves knowledge_root from its own SCRIPT_DIR/../../knowledge), so the payload-supplied test (which simply invokes status.sh --root <fixture-orch>) cannot reach the fixture knowledge tree — it always reads the live (empty-of-candidates) knowledge/ and reports 'Review Queue: empty' for every scenario. T04 resolved this without modifying status.sh or compute-staleness.sh (CON-4) by adopting the shadow-repo pattern from T03 verifiers: a build_shadow_repo helper stages copies of status.sh + state/resolve-root.sh + state/derive-phase.sh into a per-scenario shadow tree, and stages a wrapper compute-staleness.sh that 'exec bash <real-helper> --knowledge-root <fixture-knowledge>'. status.sh resolves its helper from REPO_ROOT-relative-to-SCRIPT_DIR and lands on the wrapper; the wrapper exec-pipes to the live helper with the fixture knowledge_root pinned. Result: the real cluster.sh + jaccard.sh + frontmatter.sh + staleness.sh + detail-utils.sh + index-utils.sh pipeline executes end-to-end against tempdir fixtures, exercising the same code path as a non-test invocation but with isolated input. Test exits 0 with 9 PASS / 0 FAIL; auto-loop --step=V emits AUTO:VERIFY_PASS phase=P04 task=T04-integration-test checks_passed=1. Three scenarios cover SC-3: (1) two clusters with three+two candidates respectively asserts header line and per-cluster count=3 (alpha) / count=2 (bravo) lines, (2) zero candidates asserts 'Review Queue: empty' single-line and absence of indented cluster lines, (3) one candidate with created_at=2024-01-01 asserts trailing ' (stale)' marker. FR-8/CON-1 read-only assertions verify no execution-log.jsonl created under any fixture orch root and no live .orchestrator/ test-marker. Bash 3.2 safe; AD-19 single-script-file Check shape on the directly-invoked 'bash tests/test-status-review-queue.sh' (test internals use heredocs/pipes/case-glob freely per P03/T04 + P05/T04 harness shape-guard scope clarification).

---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M020"
provides:
  - "six per-truth verifiers under scripts/verify/m020-p04-*.sh covering compute-staleness.sh --review-queue stdout shape, stale-flag flip, status.sh Review-Queue section rendering, (stale) marker, read-only invariant, and prefix preservation"
requires:
  - "from:M020/P04/T01 what:scripts/knowledge/compute-staleness.sh --review-queue; from:M020/P04/T02 what:scripts/orchestrator/status.sh Review-Queue section"
affects:
  - "P04 phase verification rollup"
key_files:
  - "scripts/verify/m020-p04-compute-staleness-review-queue.sh,scripts/verify/m020-p04-compute-staleness-stale-flag.sh,scripts/verify/m020-p04-status-review-queue-section.sh,scripts/verify/m020-p04-status-stale-marker.sh,scripts/verify/m020-p04-status-review-queue-readonly.sh,scripts/verify/m020-p04-status-prefix-preserved.sh"
key_decisions:
  - "AD-19"
patterns_established:
  - "tempdir + trap EXIT rm -rf isolation; distinct-vocabulary fixture pattern (P05/T04 carry-forward); grep -qE safe-counter (P03/T03 carry-forward)"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P04/tasks/T03-truth-verifiers-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-25T16:06:45Z"
---

REDUCED SCOPE due to T01/T02 plan deviations: auto-loop --step=V requires per-task verifiers to exist at task close, so T01 and T02 inlined five of the six verifiers as part of their own task closures. T03's deliverable was therefore reduced to authoring the single missing verifier and confirming the full set runs green.

Pre-existing verifiers (authored in T01/T02):
- m020-p04-compute-staleness-review-queue.sh (T01)
- m020-p04-status-review-queue-section.sh (T02)
- m020-p04-status-stale-marker.sh (T02)
- m020-p04-status-review-queue-readonly.sh (T02)
- m020-p04-status-prefix-preserved.sh (T02)

New in T03:
- m020-p04-compute-staleness-stale-flag.sh — exercises the per-cluster stale=true|false flag flip against the configured staleness_threshold (default 14 days). Two-fixture design: (1) two MEM entries with created_at=2024-01-01 sharing zebra vocabulary cluster -> asserts stale=true and absence of stale=false; (2) two MEM entries with created_at=TODAY sharing walrus vocabulary cluster -> asserts stale=false and absence of stale=true. AD-19 single-script-file shape, set -u (not -e), tempdir + trap EXIT rm -rf, read-only against live knowledge/**.

Verification: all 6 verifiers PASS individually; auto-loop --step=V emits AUTO:VERIFY_PASS phase=P04 task=T03-truth-verifiers checks_passed=6. Bash 3.2 safe throughout; CON-1/FR-8 read-only invariants honored (no live knowledge/** touched, no .orchestrator/execution-log.jsonl written by any verifier).

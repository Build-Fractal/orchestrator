---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P00"
milestone: "M027"
provides:
  - "14 per-contract verifier scripts under scripts/verify/m027-p00-*.sh covering FR-1/FR-2 (rollup-cli-contract), FR-1/FR-4/SC-1 (live-m019-row), FR-4/SC-12 (goodhart-pairing), FR-3/SC-6 (source-filter), FR-18/AD-1/SC-14 (aggregation-precedence), FR-12/SC-9 (read-only via git diff --quiet), FR-21/CON-6 (zero-llm-token grep), FR-14/SC-5 (corrupt-line WARN line N), FR-17 (input-schema WARN), FR-11 (pricing-warning N missing cell suffix), FR-13/FR-19/AD-3/SC-19 (fs-race copy-then-aggregate), CON-12/AD-2/SC-13 (perf-bound 5s/10MB with RELAX-CANDIDATE diagnostic), SC-10 (pre-m019-additivity silent skip), CON-7/SC-11 (bash32-compat). Each verifier emits PASS:/FAIL: per repo convention, exit 0/1/2."
requires:
  - "from:P00/T01 what:scripts/diagnostics/metrics-rollup.sh CLI surface and library functions; from:P00/T02 what:tests/fixtures/m027-p00/*.jsonl + perf-10mb.jsonl.gen.sh; from:scripts/verify/m019-p01-*.sh what:verifier-shape convention"
affects:
  - "P00/T04"
key_files:
  - "scripts/verify/m027-p00-aggregation-precedence.sh,scripts/verify/m027-p00-bash32-compat.sh,scripts/verify/m027-p00-corrupt-line.sh,scripts/verify/m027-p00-fs-race.sh,scripts/verify/m027-p00-goodhart-pairing.sh,scripts/verify/m027-p00-input-schema.sh,scripts/verify/m027-p00-live-m019-row.sh,scripts/verify/m027-p00-perf-bound.sh,scripts/verify/m027-p00-pre-m019-additivity.sh,scripts/verify/m027-p00-pricing-warning.sh,scripts/verify/m027-p00-read-only.sh,scripts/verify/m027-p00-rollup-cli-contract.sh,scripts/verify/m027-p00-source-filter.sh,scripts/verify/m027-p00-zero-llm-token.sh,scripts/diagnostics/metrics-rollup.sh"
key_decisions:
  - "AD-1,AD-2,AD-3,AD-19"
patterns_established:
  - "One-verifier-per-contract scaffolding mirrors scripts/verify/m019-p01-*.sh (PROJECT_ROOT via BASH_SOURCE; PASS/FAIL stdout/stderr; exit 0/1/2); MEM004 emitter-internal carve-out applied so each verifier may use pipes/awk/dollar-paren internally while AD-19 single-script-file shape rule binds only the Check: invocations from PLAN.md; perf-bound RELAX-CANDIDATE diagnostic pattern for bound-relaxation evidence (mirrors planning-brief 'perf may be revisited'); driving the engine fix into T01 — pure-bash while-read normalize was forking O(7) subprocesses per JSONL line and bubble sort over per-bucket cost arrays was O(n^2), both rewritten as awk passes (single normalize pass + qsort) to satisfy CON-12; engine is now ~2.5s on 10MB / 36k records vs ~3min45s before."
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P00/tasks/T03-per-contract-verifiers-PAYLOAD.md,.orchestrator/milestones/M027/phases/P00/tasks/T03-per-contract-verifiers-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-27T01:18:38Z"
---

Created 14 per-contract verifier scripts under scripts/verify/m027-p00-*.sh exercising every FR/SC contract listed in T03's Steps 1-14. Each verifier follows the repo convention from m019-p01-*.sh (PROJECT_ROOT via BASH_SOURCE, PASS/FAIL emit, 0/1/2 exit codes). Initial T03 verifier run reported 13/14 PASS — perf-bound failed because the rollup engine from T01 timed out at ~3:55 wall-clock against the 10MB / 36200-record fixture. Diagnosis: T01's metrics_rollup_normalize was a pure-bash while-read loop forking sed+grep+head subprocesses per field per record (~7 subprocess invocations × 36k records = quarter-million forks), and metrics_rollup_aggregate used a bubble sort O(n^2) over per-bucket cost arrays (1.3 billion comparisons at n=36k). The T01 plan explicitly anticipated this (its Constraints called out 'switch normalizer to awk, replace per-record grep calls in bash loops with single awk pass' as the candidate fix when the perf bound was missed). Rewrote metrics_rollup_normalize as a single awk pass with inline match()-based field extraction (mirroring the sed semantics), and replaced the bubble sort with a qsort (Hoare partition with mid-pivot, O(n log n)). Rollup now completes the 10MB fixture in ~2.5 s wall-clock — well under the 5s CON-12 / SC-13 bound. All 14 verifiers PASS post-fix. The engine fix touches T01's deliverable but was driven into existence by T03's perf-bound verifier — the perf surface was T03's contract to enforce.

---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P00"
milestone: "M027"
provides:
  - "scripts/verify/m027-rollup-schema.sh phase-suite orchestrator: runs all 14 m027-p00-*.sh verifiers in stable order (cheapest first, perf-bound last), aggregates results, prints PASS: m027-rollup-schema.sh 14 gates on green and FAIL list to stderr on red; surfaces RELAX-CANDIDATE annotations from perf-bound on stdout for downstream tooling; live-M019 demo invocation (bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019) confirmed green and emits one paired cost+quality milestone row"
requires:
  - "from:P00/T01 what:scripts/diagnostics/metrics-rollup.sh engine; from:P00/T02 what:tests/fixtures/m027-p00/ fixtures; from:P00/T03 what:14 per-contract verifiers under scripts/verify/m027-p00-*.sh; from:scripts/verify/m019-p01-phase-suite.sh what:phase-suite shape convention"
affects:
  - "P00"
key_files:
  - "scripts/verify/m027-rollup-schema.sh"
key_decisions:
  - "AD-19,FR-15,SC-2"
patterns_established:
  - "phase-suite orchestrator at M027/P00 scale (14 gates) follows m019-p01-phase-suite.sh shape verbatim — parallel-string GATES list, per-gate exit-code capture, PASS/FAIL emission, single-script-file Check shape externally with internal carve-out for the for-loop; RELAX-CANDIDATE forwarding pattern: capture per-gate stdout, grep for the structured annotation, print on suite stdout so plan-phase / consolidate can act on it without scraping; soft-failure semantics: a RELAX-CANDIDATE on perf still counts as gate failure (suite exits 1) but the diagnostic is preserved"
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P00/tasks/T04-phase-suite-and-demo-PAYLOAD.md,.orchestrator/milestones/M027/phases/P00/tasks/T04-phase-suite-and-demo-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-27T01:22:07Z"
---

Created scripts/verify/m027-rollup-schema.sh (109 lines, executable, bash 3.2 compatible). Suite invokes all 14 m027-p00-*.sh verifiers in dependency-friendly order: bash32-compat, zero-llm-token, rollup-cli-contract, input-schema, corrupt-line, pricing-warning, source-filter, aggregation-precedence, goodhart-pairing, pre-m019-additivity, fs-race, read-only, live-m019-row, perf-bound. Suite passes 14/14 against the T01 engine + T02 fixtures + T03 verifier set. Live-M019 demo invocation green: emits one milestone row with both cost block (EST_COST_USD, TOKENS_EST, P50_COST, P95_COST) and quality block (PASS_RATE, DEVIATIONS, RETRIES) on the same row. Phase-level check-must-haves.sh reports 3 unrelated failures owned by other tasks: (1) m027-p00-read-only.sh missing literal 'git diff --quiet' substring [T03 scope]; (2) m027-p00-input-schema.sh missing literal 'estimated_cost_usd' substring [T03 scope]; (3) two key-link absent-references in scripts/diagnostics/metrics-rollup.sh (pricing.sh, m019-schema.sh) [T01 scope]. Per the T04 dispatch payload's explicit constraint ('T04 does not edit the engine, the fixtures, or the per-contract verifiers — those are owned by T01, T02, and T03 respectively'), these are left visible for the orchestrator to route. The T04 deliverable itself is green: phase-suite runs all 14 per-contract verifiers cleanly, and the live-row demo emits the paired row.

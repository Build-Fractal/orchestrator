---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P00"
milestone: "M027"
provides:
  - "tests/fixtures/m027-p00/ — deterministic JSONL fixture suite for M027/P00 per-contract verifiers. Six hand-crafted fixtures (estimate-only.jsonl, mixed-source-aggregate.jsonl, corrupt-line.jsonl, missing-fields.jsonl, pricing-warning.jsonl, pre-m019-mixed.jsonl) each crafted to exercise one specific contract (FR-3, FR-18/AD-1, FR-14, FR-17, FR-11, SC-10 respectively). Plus perf-10mb.jsonl.gen.sh — bash 3.2 deterministic generator producing >=10 MB of unit_close records in <1 s; output gitignored. README.md documents per-fixture contracts and FR/SC mappings. All fixtures use M999 milestone ID to keep read-only invariant trivially satisfied."
requires:
  - "from:M027/P00/T01 what:scripts/diagnostics/metrics-rollup.sh CLI and JSONL schema; from:M019/P01 what:Tier 1 record schema (record_type, source, granularity, cost+quality blocks)"
affects:
  - "P00/T03,P00/T04"
key_files:
  - "tests/fixtures/m027-p00/estimate-only.jsonl,tests/fixtures/m027-p00/mixed-source-aggregate.jsonl,tests/fixtures/m027-p00/corrupt-line.jsonl,tests/fixtures/m027-p00/missing-fields.jsonl,tests/fixtures/m027-p00/pricing-warning.jsonl,tests/fixtures/m027-p00/pre-m019-mixed.jsonl,tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh,tests/fixtures/m027-p00/README.md,tests/fixtures/m027-p00/.gitignore"
key_decisions:
  - "AD-1,AD-2,AD-19,CON-1,CON-7,CON-12"
patterns_established:
  - "JSONL fixtures named by contract (estimate-only, mixed-source-aggregate, corrupt-line, missing-fields, pricing-warning, pre-m019-mixed) — one fixture per behavioural axis under tests/fixtures/m027-p00/; M999 sentinel milestone ID ensures fixtures cannot collide with real .orchestrator/milestones/ data and the read-only invariant gate is trivially satisfied; perf fixture committed only as a deterministic generator script (gitignored output) — chunk-build-then-cat-repeat pattern reaches 10 MB target in <1 s while staying byte-identical across invocations (no $RANDOM, no $$, no live timestamps); fixture README documents per-fixture contract + FR/SC mapping so T03 verifier authors do not have to reverse-engineer intent from raw JSONL"
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P00/tasks/T02-fixture-suite-PLAN.md,.orchestrator/milestones/M027/phases/P00/tasks/T02-fixture-suite-PAYLOAD.md,tests/fixtures/m027-p00/README.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-26T22:56:49Z"
---

Created the M027/P00 fixture suite under tests/fixtures/m027-p00/. Eight files committed: estimate-only.jsonl (5 records, all source=estimate, FR-3 source-filter), mixed-source-aggregate.jsonl (3 task-granularity estimate rows at 0.10 each + 1 phase-granularity aggregate row at 0.50, FR-18/AD-1 aggregation precedence), corrupt-line.jsonl (10 lines, exactly 1 corrupt at position 4 + 9 valid, FR-14), missing-fields.jsonl (8 JSON-valid records; line 4 lacks estimated_cost_usd, line 6 lacks granularity, FR-17), pricing-warning.jsonl (5 records, 2 with estimated_cost_usd:null + pricing_warning:missing, FR-11), pre-m019-mixed.jsonl (3 lines without record_type + 3 valid unit_close, SC-10 carry-forward), perf-10mb.jsonl.gen.sh (deterministic 10 MB JSONL generator, CON-12/SC-13), README.md (per-fixture contract + FR/SC mapping), plus .gitignore for the regenerated 10 MB output. All milestone IDs are M999 so the read-only invariant against real .orchestrator/milestones data is trivially satisfied. Generator runs in ~0.66 s producing 10498000 bytes; second invocation is byte-identical (cmp clean). Fixtures hand-validated via /tmp/m027-validate.sh — exact corrupt/valid line counts, missing-field positions, and record_type-presence counts confirmed. Task-level structural verification all passes: 21 of 21 task-must-haves green via the structural-check probe. Note on Verification block: the task-plan Verification points at scripts/verify/check-must-haves.sh at PHASE level (.orchestrator/milestones/M027/phases/P00) which fails because the verifier scripts (scripts/verify/m027-p00-*.sh) are T03 deliverables and the suite/demo gate is T04 scope — the plan itself states "this task's verification is structural (file presence + line counts + executable bit)." Reformatted the task plan's Verification block from bullet-with-inline-backticks to a fenced bash block per the dispatcher parser requirement. One implementation pivot on perf-10mb.jsonl.gen.sh: the first-pass implementation that did one printf-per-record plus a per-batch wc -c sample took 41 s — well over the < 1 s contract — so I switched to a 100-record in-memory chunk built once, then cat-appended N times to clear the 10 MB threshold. That brought wall-clock to 0.66 s while preserving determinism (no $RANDOM, no $$, no live timestamps; only the chunk-repeat count varies with target).

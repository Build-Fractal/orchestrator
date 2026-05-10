---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M027"
goal: "Ship the rollup engine + verifier — a sourceable bash library and CLI (scripts/diagnostics/metrics-rollup.sh) that aggregates M019 Tier 1 JSONL into paired cost+quality rows at task/phase/milestone/project granularity, plus a verifier (scripts/verify/m027-rollup-schema.sh) covering FR-3, FR-4, FR-11, FR-12, FR-13, FR-14, FR-17, FR-18, FR-19, CON-12/SC-13 perf, SC-3/SC-17 byte-identity placeholders, zero-LLM-token, and bash 3.2 compat."
demo_sentence: "A developer runs `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` against this repo and stdout shows exactly one milestone row with paired cost (estimated_cost_usd, payload_tokens_estimate, mean/p50/p95 dispatch cost) AND quality (verification_pass_rate, deviation_count, retry_count) columns; `git diff --quiet` after the run is exit 0; running `bash scripts/verify/m027-rollup-schema.sh` exits 0 over a fixture suite covering FR-18 aggregation precedence (aggregate-row sums match aggregate-row, not aggregate+children), FR-3 source-filter (—source runtime against estimate-only fixture prints 'no records match filter' + exit 0), FR-4 Goodhart pairing (cost-without-quality fixture rejected), FR-14 corrupt-line tolerance (1 corrupt + 9 valid records → 9 aggregated, 1 stderr line-number diagnostic, exit 0), FR-19 FS-race (concurrent truncation does not crash the rollup), FR-12 read-only invariant (`git diff --quiet` after rollup pass), CON-6/FR-21 zero-LLM-token grep against the M027 script set, and CON-12/SC-13 perf bound (rollup against a synthesized 10MB JSONL completes in <5s wall-clock on a 2024-era laptop)."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M027/P00 verification logic lives inside the
     scripts/verify/m027-p00-*.sh files; the Check commands here invoke them. -->

- `scripts/diagnostics/metrics-rollup.sh` exists, is executable, sourceable as a library (no load-time side effects) and runnable as a CLI; CLI accepts `--granularity task|phase|milestone|project`, scope flags `--milestone`, `--phase`, `--task`, the `--source estimate|runtime|aggregate|all` filter (FR-3), and a JSONL path override (FR-1, FR-2).
  - Check: `bash scripts/verify/m027-p00-rollup-cli-contract.sh`

- Running the rollup CLI with `--granularity milestone --milestone [M019](../../../../milestones/M019/index.md)` against this repo's live `.orchestrator/milestones/M019/execution-log.jsonl` exits 0 and stdout contains exactly one milestone row carrying both a cost block (`estimated_cost_usd`, `payload_tokens_estimate`, mean/p50/p95 dispatch cost) AND a quality block (`verification_pass_rate`, `deviation_count`, `retry_count`) on the same row (FR-1, FR-4, SC-1).
  - Check: `bash scripts/verify/m027-p00-live-m019-row.sh`

- Goodhart output pairing — every rollup row that contains a cost cell also contains a quality cell on the same row; the verifier rejects any rollup configuration that produces a cost column without a quality column (FR-4, SC-12).
  - Check: `bash scripts/verify/m027-p00-goodhart-pairing.sh`

- Source-filter contract — `--source runtime` against an estimate-only fixture log produces an empty rollup with a "no records match filter" annotation on stdout and exit code 0; `--source estimate` against the same log produces a non-empty row; `--source all` (default) merges per FR-18 precedence (FR-3, SC-6).
  - Check: `bash scripts/verify/m027-p00-source-filter.sh`

- Aggregation precedence — when a fixture log contains both a `source: aggregate` phase record and its constituent `source: estimate` task records at granularity G, the rollup at granularity G sums the aggregate row only (children at G are not double-counted); precedence is `aggregate > runtime > estimate` at every granularity (FR-18, AD-1, SC-14).
  - Check: `bash scripts/verify/m027-p00-aggregation-precedence.sh`

- Read-only invariant — `git diff --quiet` against the project tree after running the rollup CLI on a fixture is exit 0; the rollup never appends to or rewrites `execution-log.jsonl` (FR-12, CON-1, SC-9).
  - Check: `bash scripts/verify/m027-p00-read-only.sh`

- Zero-LLM-token contract — grepping the M027 script set under `scripts/diagnostics/metrics-rollup.sh`, `scripts/verify/m027-*.sh`, and any P00-introduced helper for forbidden LLM-invocation patterns (`claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`) returns no matches (FR-21, CON-6, SC-16 carry-forward into P00 surface).
  - Check: `bash scripts/verify/m027-p00-zero-llm-token.sh`

- Corrupt-line tolerance — running the rollup against a fixture log containing 1 corrupted JSONL line + 9 valid records exits 0, emits exactly 1 stderr diagnostic naming the corrupted line number, and aggregates the 9 valid records correctly (FR-14, SC-5).
  - Check: `bash scripts/verify/m027-p00-corrupt-line.sh`

- Input-schema validation — records missing required fields (`estimated_cost_usd`, `record_type`, `granularity`) or with the wrong type are excluded from totals with a stderr line-number diagnostic; never crashes the rollup (FR-17, AD-6).
  - Check: `bash scripts/verify/m027-p00-input-schema.sh`

- Pricing-warning surface — rollup output contains a `(N missing)` suffix on cost cells whose underlying records carried a `pricing_warning` (or had `estimated_cost_usd: null`); records are tagged, never silently dropped (FR-11, SC-1 AS-6 carry-forward).
  - Check: `bash scripts/verify/m027-p00-pricing-warning.sh`

- FS-race / copy-then-aggregate — rollup engine reads the JSONL via `mktemp` + `cp` snapshot at start; in-flight writes after the snapshot are not double-counted; concurrent truncation of the source log mid-rollup does not crash the engine (FR-13, FR-19, AD-3, SC-19).
  - Check: `bash scripts/verify/m027-p00-fs-race.sh`

- Performance bound — running the rollup CLI against a synthesized 10 MB fixture JSONL completes in under 5 s wall-clock on a 2024-era laptop (CON-12, AD-2, SC-13).
  - Check: `bash scripts/verify/m027-p00-perf-bound.sh`

- Pre-M019 records (lacking `record_type`) are silently ignored by the rollup; running rollup against a fixture log that mixes pre-M019 and Tier 1 records does not double-count or crash (SC-10 carry-forward, M019 additivity).
  - Check: `bash scripts/verify/m027-p00-pre-m019-additivity.sh`

- All M027/P00 shell scripts pass bash 3.2 compat — no `declare -A`, no `mapfile`, no `<<<` herestrings, no `${var^^}`, no `<(...)` process substitution, no `&>` (CON-7, SC-11 carry-forward).
  - Check: `bash scripts/verify/m027-p00-bash32-compat.sh`

- `bash scripts/verify/m027-rollup-schema.sh` orchestrates the full P00 verifier suite (the named per-contract checks above) and exits 0 on green; this is the SC-2 / FR-15 entry point (FR-15, SC-2).
  - Check: `bash scripts/verify/m027-rollup-schema.sh`

### Artifacts

- `scripts/diagnostics/metrics-rollup.sh` (min 400 lines, contains "metrics-rollup")
- `scripts/verify/m027-rollup-schema.sh` (min 30 lines, contains "m027-p00")
- `scripts/verify/m027-p00-rollup-cli-contract.sh` (min 30 lines, contains "granularity")
- `scripts/verify/m027-p00-live-m019-row.sh` (min 30 lines, contains "M019")
- `scripts/verify/m027-p00-goodhart-pairing.sh` (min 40 lines, contains "Goodhart")
- `scripts/verify/m027-p00-source-filter.sh` (min 40 lines, contains "no records match filter")
- `scripts/verify/m027-p00-aggregation-precedence.sh` (min 50 lines, contains "aggregate")
- `scripts/verify/m027-p00-read-only.sh` (min 30 lines, contains "git diff --quiet")
- `scripts/verify/m027-p00-zero-llm-token.sh` (min 40 lines, contains "anthropic")
- `scripts/verify/m027-p00-corrupt-line.sh` (min 40 lines, contains "line number")
- `scripts/verify/m027-p00-input-schema.sh` (min 40 lines, contains "estimated_cost_usd")
- `scripts/verify/m027-p00-pricing-warning.sh` (min 30 lines, contains "pricing_warning")
- `scripts/verify/m027-p00-fs-race.sh` (min 50 lines, contains "mktemp")
- `scripts/verify/m027-p00-perf-bound.sh` (min 40 lines, contains "10")
- `scripts/verify/m027-p00-pre-m019-additivity.sh` (min 30 lines, contains "pre-M019")
- `scripts/verify/m027-p00-bash32-compat.sh` (min 40 lines, contains "declare -A")
- `tests/fixtures/m027-p00/` (directory with at least: estimate-only.jsonl, mixed-source-aggregate.jsonl, corrupt-line.jsonl, missing-fields.jsonl, pricing-warning.jsonl, pre-m019-mixed.jsonl, perf-10mb.jsonl.gen.sh)

### Key Links

- `scripts/diagnostics/metrics-rollup.sh` → `scripts/lib/pricing.sh` (rollup sources the pricing helper for stale detection + warning surface)
- `scripts/diagnostics/metrics-rollup.sh` → `scripts/verify/m019-schema.sh` (input contract validated upstream of aggregation; rollup composes against the M019 schema validator)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-rollup-cli-contract.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-live-m019-row.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-goodhart-pairing.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-source-filter.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-aggregation-precedence.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-read-only.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-zero-llm-token.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-corrupt-line.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-input-schema.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-pricing-warning.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-fs-race.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-perf-bound.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-pre-m019-additivity.sh` (orchestrated gate)
- `scripts/verify/m027-rollup-schema.sh` → `scripts/verify/m027-p00-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: rollup engine — sourceable lib + CLI in metrics-rollup.sh

See `.orchestrator/milestones/M027/phases/P00/tasks/T01-rollup-engine-PLAN.md`.

### T02: P00 fixture suite under tests/fixtures/m027-p00/

See `.orchestrator/milestones/M027/phases/P00/tasks/T02-fixture-suite-PLAN.md`.

### T03: per-contract verifier scripts (m027-p00-*.sh)

See `.orchestrator/milestones/M027/phases/P00/tasks/T03-per-contract-verifiers-PLAN.md`.

### T04: phase-suite orchestrator (m027-rollup-schema.sh) + bash32 compat gate + live-row demo wiring

See `.orchestrator/milestones/M027/phases/P00/tasks/T04-phase-suite-and-demo-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04
```

Strictly sequential. T02 (fixtures) consumes T01's CLI contract for invocation shape. T03 (per-contract verifiers) consumes both T01's engine and T02's fixtures. T04 (phase-suite + demo) consumes T03's verifier set.

T01 and T02 cannot parallelize cleanly: T02's fixture-generator script (perf-10mb.jsonl.gen.sh) and the assertions inside individual fixtures are designed against the CLI shape produced by T01.

## Files Likely Touched

- scripts/diagnostics/metrics-rollup.sh (create)
- scripts/verify/m027-rollup-schema.sh (create)
- scripts/verify/m027-p00-rollup-cli-contract.sh (create)
- scripts/verify/m027-p00-live-m019-row.sh (create)
- scripts/verify/m027-p00-goodhart-pairing.sh (create)
- scripts/verify/m027-p00-source-filter.sh (create)
- scripts/verify/m027-p00-aggregation-precedence.sh (create)
- scripts/verify/m027-p00-read-only.sh (create)
- scripts/verify/m027-p00-zero-llm-token.sh (create)
- scripts/verify/m027-p00-corrupt-line.sh (create)
- scripts/verify/m027-p00-input-schema.sh (create)
- scripts/verify/m027-p00-pricing-warning.sh (create)
- scripts/verify/m027-p00-fs-race.sh (create)
- scripts/verify/m027-p00-perf-bound.sh (create)
- scripts/verify/m027-p00-pre-m019-additivity.sh (create)
- scripts/verify/m027-p00-bash32-compat.sh (create)
- tests/fixtures/m027-p00/estimate-only.jsonl (create)
- tests/fixtures/m027-p00/mixed-source-aggregate.jsonl (create)
- tests/fixtures/m027-p00/corrupt-line.jsonl (create)
- tests/fixtures/m027-p00/missing-fields.jsonl (create)
- tests/fixtures/m027-p00/pricing-warning.jsonl (create)
- tests/fixtures/m027-p00/pre-m019-mixed.jsonl (create)
- tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh (create)
- tests/fixtures/m027-p00/README.md (create)

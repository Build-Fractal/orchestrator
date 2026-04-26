# M027/P00 fixture suite

This directory holds deterministic JSONL fixtures consumed by the M027/P00
per-contract verifier scripts (`scripts/verify/m027-p00-*.sh`) that exercise
`scripts/diagnostics/metrics-rollup.sh` (the rollup engine, T01) against the
contracts laid out in the M027 spec.

All milestone IDs in these fixtures are `M999` (or M998/M997 for variants in
future fixtures) so they cannot collide with real `.orchestrator/milestones/`
data and the read-only invariant (FR-12, `git diff --quiet` after a rollup
run) is trivially satisfied.

Every `*.jsonl` fixture below is committed to git. The synthesized 10 MB perf
fixture (`perf-10mb.jsonl`) is **not** committed — it is regenerated on demand
by `perf-10mb.jsonl.gen.sh` from a deterministic template before each perf
verifier invocation.

## Schema invariants

Each `unit_close` record carries the full M019 Tier 1 schema unless the
fixture is explicitly testing a degraded shape:

```
record_type: "unit_close"
ts: "<ISO 8601 UTC>"
milestone: "M999"
phase: "P00"
task: "T0X"
granularity: "task" | "phase" | "milestone"
source: "estimate" | "runtime" | "aggregate"
estimated_cost_usd: <number | null>
pricing_version: "v1"
payload_tokens_estimate: <integer>
verification_pass_rate: <0..1>
deviation_count: <integer>
retry_count: <integer>
pricing_warning: "missing"     # only when estimated_cost_usd: null (FR-11)
```

Cost block: `estimated_cost_usd`, `pricing_version`, `payload_tokens_estimate`.
Quality block: `verification_pass_rate`, `deviation_count`, `retry_count`.
The Goodhart pairing contract (FR-4) requires both blocks on every row that
contributes to a cost cell.

## Fixtures

### `estimate-only.jsonl` (FR-3 source-filter)

5 `unit_close` records, all with `source: "estimate"`, mixed across two tasks
under one phase under M999. Records carry valid cost+quality blocks.

T03 verifier behaviour:

- `--source runtime` against this fixture asserts an empty rollup with a
  "no records match filter" annotation on stdout and exit 0.
- `--source estimate` asserts a non-empty rollup.
- `--source all` (default) yields the same as `--source estimate` because the
  fixture contains no aggregate or runtime records.

Maps to: FR-3, SC-6.

### `mixed-source-aggregate.jsonl` (FR-18 / AD-1 aggregation precedence)

4 records covering M999/P00:

- 3 task-granularity `source: estimate` rows at `estimated_cost_usd: 0.10`
  each (naive sum = 0.30).
- 1 phase-granularity `source: aggregate` row at `estimated_cost_usd: 0.50`
  covering the same M999/P00 scope.

T03 verifier behaviour:

- `--granularity phase --milestone M999` yields total cost **0.50** (the
  aggregate row), NOT 0.80 (aggregate + children) — `aggregate > runtime >
  estimate` precedence at the matching granularity.
- `--granularity task` yields the three task rows summed at 0.30 (children
  remain visible at their own granularity, never double-counted at the
  coarser one).

Maps to: FR-18, AD-1, SC-14.

### `corrupt-line.jsonl` (FR-14 corrupt-line tolerance)

10 lines total — 9 valid `unit_close` records plus exactly 1 corrupt line in
position 4 containing the literal text `{"record_type": "unit_close", BROKEN
JSON HERE`.

T03 verifier behaviour:

- Rollup exits 0.
- Stderr contains exactly one `WARN` line that names line number `4`.
- The 9 valid records aggregate normally.

Maps to: FR-14, SC-5.

### `missing-fields.jsonl` (FR-17 input-schema validation)

8 lines that all parse as JSON. 6 are valid `unit_close` records; 2 lack
required fields:

- Line 4 lacks `estimated_cost_usd`.
- Line 6 lacks `granularity`.

T03 verifier behaviour:

- Stderr emits `WARN: input-schema line 4` and `WARN: input-schema line 6`.
- Only the 6 valid records contribute to totals.
- Exit 0 (never abort on degraded input — CON-5).

Maps to: FR-17, AD-6.

### `pricing-warning.jsonl` (FR-11 pricing-warning surface)

5 `unit_close` records — 3 with valid `estimated_cost_usd`, 2 with
`estimated_cost_usd: null` and `pricing_warning: "missing"`.

T03 verifier behaviour:

- The rollup output for the relevant scope contains a `(2 missing)` suffix on
  the cost cell.
- The 2 null-cost records are tagged, never silently dropped.

Maps to: FR-11, SC-1 AS-6 carry-forward.

### `pre-m019-mixed.jsonl` (SC-10 pre-M019 carry-forward)

6 lines — 3 lines that lack `record_type` entirely (legacy pre-M019 log
shapes such as `{"event": "lock_acquired", ...}`) plus 3 valid M019
`unit_close` records.

T03 verifier behaviour:

- Rollup ignores the 3 pre-M019 lines silently (no stderr WARN).
- Aggregates only the 3 M019 records.
- Exit 0.

Maps to: SC-10, M019 additivity invariant.

### `perf-10mb.jsonl.gen.sh` (CON-12 / SC-13 perf bound)

Bash 3.2 generator that synthesizes a deterministic ≥10 MB JSONL of
`unit_close` records by composing a small in-memory chunk and appending it
the appropriate number of times to clear the 10 MB threshold. Runs in well
under 1 s. Produces byte-identical output across invocations with the same
arguments (no `$RANDOM`, no `$$`, no live timestamps).

The generator's first argument is the output path; the default is
`perf-10mb.jsonl` next to the script. The generator emits exactly one stdout
line: the resolved output path.

The 10 MB output file itself is gitignored (see `.gitignore`); only the
generator script is committed.

Maps to: CON-12, SC-13, AD-2.

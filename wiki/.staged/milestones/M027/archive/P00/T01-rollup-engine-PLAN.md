---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M027"
name: "rollup engine — sourceable lib + CLI in metrics-rollup.sh"
depends_on: []
---

## Prerequisites

- The repo's `.orchestrator/milestones/M019/execution-log.jsonl` already contains [M019](../../../../milestones/M019/index.md) Tier 1 records emitted under the schema enforced by `scripts/verify/m019-schema.sh`. M019 Tier 1 closed 2026-04-18.
- `scripts/lib/pricing.sh` is sourceable per its load-time `_PRICING_SH_SOURCED` guard. It exposes:
  - `pricing_file_path` — prints the resolved `pricing.yml` path (respects `ORCH_PRICING_FILE`).
  - `pricing_file_present` — exit 0 if resolvable + readable, 1 otherwise.
  - `pricing_is_stale` — exit 0 if missing or age > 90 days.
  - `pricing_warning_reason` — prints `missing | stale:<N>d | no-rate:<MODEL>` after a failed `pricing_estimate_cost_usd`.
- `scripts/verify/m019-schema.sh` exists and validates JSONL line-by-line; record-level enums:
  - `record_type ∈ {payload_breakdown, dispatch_usage, unit_close}`
  - `source ∈ {estimate, runtime, aggregate}`
  - `granularity ∈ {task, phase, milestone}` on `unit_close`
  - `unit_close` records carry both a cost block (`estimated_cost_usd`, `pricing_version`) and a quality block (`verification_pass_rate`, `deviation_count`, `retry_count`).
- Pre-M019 lines (no `record_type`) are NOT rejected by the M019 validator and MUST be silently ignored by the rollup (M019 SC-10 carry-forward).

## Description

Create `scripts/diagnostics/metrics-rollup.sh` — the M027 P00 rollup engine. It is BOTH a sourceable bash library (functions only on import; no load-time output) AND a CLI. It reads M019 Tier 1 JSONL, applies copy-then-aggregate FS-race semantics (FR-19 / AD-3), validates input schema (FR-17), tolerates corrupt lines (FR-14), enforces aggregation precedence `aggregate > runtime > estimate` at every granularity (FR-18 / AD-1), supports a `--source` filter (FR-3), surfaces pricing warnings as `(N missing)` cell suffixes (FR-11), and prints paired cost+quality rows (FR-4) at task / phase / milestone / project granularity (FR-1, FR-2). The engine is read-only (FR-12 / CON-1); it never appends to or rewrites JSONL. Bash 3.2 only (CON-7) — no `declare -A`, no `<<<`, no `mapfile`, no `<(...)`. The engine never invokes an LLM (FR-21 / CON-6) — bash + `awk` + `grep` + `sed` only. The MEM004 carve-out permits pipes / `$()` / `awk` *inside* this emitter-internal library; only `Check:` commands at task and phase plan level are restricted to single-script-file shape (AD-19).

## Steps

1. **Create the file** `scripts/diagnostics/metrics-rollup.sh`. Add `#!/usr/bin/env bash` header, `set -u`, and a re-source guard (`[ -n "${_METRICS_ROLLUP_SH_SOURCED:-}" ] && return 0; _METRICS_ROLLUP_SH_SOURCED=1`).

2. **CLI argument surface** — when invoked as a CLI (i.e. `${BASH_SOURCE[0]} == ${0}`), parse:
   - `--granularity task|phase|milestone|project` (default: `milestone`)
   - `--milestone <Mxxx>` (scope filter; default: active milestone if resolvable, else first under `.orchestrator/milestones/`)
   - `--phase <Pxx>` (scope filter)
   - `--task <id>` (scope filter)
   - `--source estimate|runtime|aggregate|all` (default: `all`)
   - `--log <path>` (override JSONL path; default: derived from `--milestone`)
   - `--help` / `-h` (usage)
   - On unknown flag → exit 2 with usage to stderr.

3. **Snapshot via mktemp + cp** (FR-19 / AD-3):
   - Resolve target JSONL path (CLI override > derived from milestone).
   - If path missing → print "no Tier 1 records yet" to stdout, exit 0.
   - `tmpfile=$(mktemp)`. Trap EXIT to `rm -f "$tmpfile"`.
   - `cp "$resolved_path" "$tmpfile"`. From here on, all reads use `$tmpfile`.
   - This snapshot semantic is what tolerates concurrent writes / truncation by Tier 1 emitters.

4. **Streaming line classification** — single pass over `$tmpfile` with `awk` (or bash while-read; bash 3.2 safe). For each line:
   - If line is empty → skip.
   - If JSON parse fails → emit `WARN: corrupt JSONL line <N> in <path>` to stderr, increment `corrupt_count`, continue (FR-14).
   - If line lacks `record_type` field → silently skip (pre-M019 record; SC-10 carry-forward).
   - If line is malformed Tier 1 (missing `granularity`, missing `estimated_cost_usd`, wrong type) → emit `WARN: input-schema line <N>: <reason>` to stderr, increment `validation_skip_count`, continue (FR-17).
   - Else → emit a normalized one-line projection containing: `record_type | source | granularity | milestone | phase | task | estimated_cost_usd | payload_tokens_estimate | verification_pass_rate | deviation_count | retry_count | pricing_warning`.

5. **Aggregation precedence (FR-18, AD-1)** — operating on the normalized projection:
   - **Indexing.** Group records by `(granularity, milestone, phase, task)` scope key. Within each group, partition by `source` ∈ {`aggregate`, `runtime`, `estimate`}.
   - **Per-group selection.** For each group, take the highest-priority partition that has at least one record: `aggregate` > `runtime` > `estimate`. The other partitions for that group are discarded — children that already fed an aggregate at granularity G are not double-counted at G.
   - **Source-filter (FR-3) interaction.** When `--source` is not `all`, restrict the per-group partition choice to the requested source. If the requested partition is empty for a group, the group contributes no row. If no group has a row, output is "no records match filter" + exit 0.
   - **Roll-up to higher granularity.** When the requested CLI granularity is coarser than the per-record granularity (e.g. `--granularity milestone` with `task`-level records), prefer an `aggregate` record at the coarser granularity if present; else sum the per-group rows (each already resolved per the rule above).

6. **Output formatting (FR-4 Goodhart pairing)** — every row that contains a cost cell MUST contain a quality cell on the same row. Emit a fixed-column table with at minimum:
   ```
   GRANULARITY  SCOPE      DISPATCHES  EST_COST_USD  TOKENS_EST  P50_COST  P95_COST  PASS_RATE  DEVIATIONS  RETRIES  WARNINGS
   ```
   - Cost cells whose underlying records carried a `pricing_warning` field (or had `estimated_cost_usd: null`) MUST display the value followed by ` (N missing)` where N is the count of records contributing the warning (FR-11).
   - Pricing-warning records are tagged in the row, never silently dropped.
   - Goodhart pairing is structural: the printer MUST refuse to emit a cost column if the corresponding quality columns are absent. If the upstream group has no quality data (degenerate case), emit `quality=unknown` rather than dropping the cost column.
   - Stderr summary line at end: `corrupt=<N> validation_skipped=<N> warnings=<N>`.

7. **Sourceable library shape.** Expose these top-level functions for downstream P01 callers (do not couple to the CLI parser):
   - `metrics_rollup_snapshot SOURCE_LOG TMP_OUT` — snapshot via mktemp+cp; sets `$?` to 0 on success.
   - `metrics_rollup_normalize TMP_LOG NORMALIZED_OUT` — emits the one-line projection; returns counts via stderr.
   - `metrics_rollup_aggregate NORMALIZED FILTER_SOURCE FILTER_GRANULARITY FILTER_MILESTONE FILTER_PHASE FILTER_TASK` — applies AD-1 precedence + filters; prints rolled-up rows to stdout.
   - `metrics_rollup_render ROWS` — applies FR-4 Goodhart pairing + FR-11 pricing-warning suffixes; prints the human-readable table.
   - `metrics_rollup_main "$@"` — CLI entry; the bottom of the file calls this only when `${BASH_SOURCE[0]}` equals `$0` (so a `source` import does NOT run main).

8. **Zero-LLM-token discipline (FR-21 / CON-6).** The script MUST NOT contain any of: `claude_chat`, `anthropic`, `dispatch-interface.sh`, `dispatch_task`, `subagent`. No backend calls. Any LLM call is a verifier failure.

9. **bash 3.2 compat (CON-7).** No `declare -A` / associative arrays. Use parallel indexed-array lookups (MEM001 pattern; `arr_k_0`, `arr_v_0`, etc.). No `<<<` herestrings; use `printf '%s\n' "$x" | cmd` instead. No `mapfile` / `readarray`; use `while IFS= read -r line` loops. No `${var^^}`; use `printf '%s' "$x" | tr '[:lower:]' '[:upper:]'` if uppercasing is needed. No `<(...)` process substitution.

10. **`chmod +x scripts/diagnostics/metrics-rollup.sh`.**

## Must-Haves

- File `scripts/diagnostics/metrics-rollup.sh` exists, is executable, ≥ 400 lines, contains the literal string `metrics-rollup`.
- Sourcing the file produces no stdout / stderr; all behavior gated behind `${BASH_SOURCE[0]} == ${0}`.
- CLI accepts every flag listed in step 2; unknown flag → exit 2.
- Live invocation against `.orchestrator/milestones/M019/execution-log.jsonl` exits 0 and emits a single milestone row carrying both cost and quality columns (validates SC-1 in this task; the verifier under T03 re-asserts it mechanically).
- File contains the load-time guard `_METRICS_ROLLUP_SH_SOURCED`.
- Zero-LLM-token: file does not match `(claude_chat|anthropic|dispatch-interface\.sh|dispatch_task|subagent)`.
- bash 3.2 compat: file does not match `(declare -A|mapfile|readarray|<<<|<\(|>\(|&>|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^})`.

## Verification

```bash
bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019
```

The above must exit 0 and print one paired cost+quality row to stdout. The remaining contract verifiers (Goodhart pairing, source-filter, aggregation precedence, corrupt-line, FS-race, perf bound, etc.) live in T03 and are wired into `scripts/verify/m027-rollup-schema.sh` in T04. The phase-level `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M027/phases/P00` runs at the phase boundary, not at T01 task verification.

## Inputs

### From Previous Tasks

None — T01 is the dependency root.

### From Disk (Pre-existing)

- `scripts/lib/pricing.sh` — source for `pricing_file_path`, `pricing_file_present`, `pricing_is_stale`, `pricing_warning_reason`. No new functions are added to this file; this task consumes only.
- `scripts/verify/m019-schema.sh` — defines the input contract this task aggregates against. The validator does line-by-line schema checks; the rollup engine adopts the same field names but is independent of the validator at runtime (it does not invoke `m019-schema.sh` per record — that would explode the cost; instead it does its own minimal field extraction and skips/tags malformed lines).
- `.orchestrator/milestones/M019/execution-log.jsonl` — live demo target. This file is read-only for this task.
- M019 P01 SUMMARY at [`.orchestrator/milestones/M019/phases/P01/P01-SUMMARY.md`](../../../../milestones/M019/phases/P01/P01-SUMMARY.md) — reference for record schema field names. Not read at runtime.

## Constraints

- **CON-1 / FR-12 (read-only)**: This task MUST NOT write to or rewrite any `execution-log.jsonl`. The mktemp snapshot is the ONLY write, and it lives in `${TMPDIR:-/tmp}`. EXIT trap removes it. T03's read-only verifier will run `git diff --quiet` after invocation and fail the task if it is non-zero.
- **CON-6 / FR-21 (zero-token)**: bash + awk + grep + sed only. T03's zero-LLM-token verifier will grep this file.
- **CON-7 (bash 3.2)**: T03's bash32-compat verifier will grep this file for forbidden constructs.
- **CON-12 / SC-13 (perf)**: This task does not implement perf optimization beyond single-pass streaming + lookup-table aggregation. T03's perf-bound verifier asserts < 5 s on a 10 MB synthesized JSONL. If the bound is missed, T01 must be revisited (likely candidates: switch the normalizer to `awk`, replace per-record `grep` calls in bash loops with a single awk pass).
- **MEM004 carve-out applies here**: this is emitter-internal code, so pipes / `$()` / `awk` are permitted *inside* the script. The AD-19 single-script-file shape rule applies only to `Check:` commands at task and phase plan level.
- **No new fields on Tier 1 records (CON-2)**: This task does not extend the M019 schema; it only consumes existing fields.

## Expected Output

After this task:

1. `scripts/diagnostics/metrics-rollup.sh` exists, ≥ 400 lines, executable, sourceable.
2. Running `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` against this repo prints exactly one milestone row with paired cost + quality columns, exit 0.
3. Running `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone NONEXISTENT` prints a "no Tier 1 records yet" annotation, exit 0 (graceful degradation per CON-5).
4. Sourcing the file (e.g., `. scripts/diagnostics/metrics-rollup.sh`) produces no stdout / stderr; functions `metrics_rollup_snapshot`, `metrics_rollup_normalize`, `metrics_rollup_aggregate`, `metrics_rollup_render`, `metrics_rollup_main` are defined.
5. `git diff --quiet` after running the CLI on a fixture or on the live M019 log returns exit 0.

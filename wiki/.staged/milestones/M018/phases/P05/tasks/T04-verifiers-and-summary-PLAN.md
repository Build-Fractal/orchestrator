---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M018"
name: "P05 verifiers, fixtures, fixture-staging helper, P05-SUMMARY + CLAUDE.md/AGENTS.md dual-write"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped the four additive savings fields on `dispatch_usage` and `unit_close` JSONL records.
- T02 has shipped the cost-rollup column extension, efficiency-footer compression line, and doctor compression-regression flag.
- T03 has shipped `scripts/diagnostics/compression-eval.sh` with cohort segmentation + outcome-rate delta + `--tier <N>` filter.
- `scripts/verify/_helpers/m018-p04-build-fixture.sh` is the canonical fixture-staging helper shape T04 mirrors. Read it once for shape (config-override scaffolding, fixture path resolution, capture-file staging) before authoring `m018-p05-build-fixture.sh`. P03's helper is also valid reference; either one works.
- `scripts/util/dual-write-runtime-md.sh` is the canonical dual-write helper used by every prior phase (M011/P07, [M013](../../../../../milestones/M013/index.md), [M015](../../../../../milestones/M015/index.md), [M016](../../../../../milestones/M016/index.md), [M019](../../../../../milestones/M019/index.md), [M020](../../../../../milestones/M020/index.md), [M021](../../../../../milestones/M021/index.md), [M025](../../../../../milestones/M025/index.md), [M027](../../../../../milestones/M027/index.md), M018/P02, M018/P03, M018/P04). Invocation pattern: `bash scripts/util/dual-write-runtime-md.sh <orchestrator:recent-changes block content>` — writes the block to both `CLAUDE.md` and `AGENTS.md` between the `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<` sentinels. The verifier `m018-p05-dual-write-recent.sh` only checks that both files contain "M018/P05" in their recent-changes block.
- AD-19 single-script-file `Check:` contract: every verifier exposes its truth via a single bash invocation. The verifier may shell out to subordinate helpers (e.g., `_helpers/m018-p05-build-fixture.sh`) but `check-must-haves.sh` invokes ONE bash file per truth.
- AP-009 applies to verifier scripts. No compound chains > 2; no plain subshells; no `$(...|...)`. Verifier scripts use `pass()` / `fail()` per MEM002 and the typical `printf 'PASS:' / printf 'FAIL:'` line-prefix convention.
- `scripts/knowledge/write-summary.sh` is the canonical phase-summary writer. T04 invokes it via `bash scripts/knowledge/write-summary.sh phase ... --provides ... --requires ... ...`; the script appends a `unit_close` JSONL record (now carrying T01's additive fields, exercising the fields end-to-end as the phase closes).
- Bash 3.2 — verifiers use parallel indexed arrays (no `declare -A`).

## Description

T04 ships eight verifier scripts under `scripts/verify/m018-p05-*.sh`, two fixture trees under `tests/fixtures/m018-p05-*/`, one fixture-staging helper under `scripts/verify/_helpers/m018-p05-build-fixture.sh`, the P05-SUMMARY, and the CLAUDE.md/AGENTS.md `orchestrator:recent-changes` dual-write.

The eight verifiers map 1:1 to the P05 truths:

1. `m018-p05-dispatch-usage-additivity.sh` — exercise T01's dispatch_usage emit. Drive `_di_emit_dispatch_usage` against a fixture log carrying a known `payload_breakdown` record with `tier1_savings_tokens=200`, `filter_dropped_tokens=300`, `tier2_savings_tokens=100`, `tier1_invocations=1`. Assert the emitted `dispatch_usage` JSONL line:
   - is valid JSON (parses via `python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]'` if python3 available, else via a minimal awk/sed sanity check),
   - carries the four additive fields with the expected integer values,
   - is back-compat: a checked-in pre-P05 dispatch_usage record (e.g., from `tests/fixtures/m018-p02-baseline-payload.golden.txt` if present, or a hand-curated sample inside the fixture) parses cleanly under the same JSON validator.
2. `m018-p05-unit-close-additivity.sh` — exercise T01's unit_close emit. Drive `_ws_emit_unit_close` (or `bash scripts/knowledge/write-summary.sh task ...`) against a fixture log carrying multiple `payload_breakdown` records on the same task scope. Assert the emitted `unit_close` JSONL line:
   - carries the four additive fields with values matching the SUM of the in-scope payload_breakdown records (not just one record),
   - back-compat per the pre-P05 record check.
3. `m018-p05-cost-rollup-savings-columns.sh` — invoke `bash scripts/diagnostics/metrics-rollup.sh --milestone <fixture-id>`. Assert:
   - the header line contains `FILTER_DROPPED`, `TIER1_SAVINGS`, `TIER2_SAVINGS`, `TIER1_INVOCS`,
   - the data row contains integer values for those columns,
   - the existing column indices (cost / pass_rate / retries) are unchanged (CON-5 carry-forward).
4. `m018-p05-efficiency-footer-compression.sh` — two assertions:
   - `bash scripts/diagnostics/efficiency-footer.sh --milestone <savings-fixture>` emits a line containing `compression:` and a percent reduction value,
   - `bash scripts/diagnostics/efficiency-footer.sh --milestone <no-savings-fixture>` does NOT emit a `compression:` line,
   - `bash scripts/diagnostics/efficiency-footer.sh --milestone <savings-fixture> --quiet` emits zero stdout (CON-3 byte-identity contract preserved).
5. `m018-p05-doctor-compression-regression.sh` — invoke `bash scripts/diagnostics/check-anomalies.sh --milestone <regression-fixture> --sample-floor 1`. Assert:
   - the output contains a `compression-regression` reason on at least one flagged row,
   - the row carries a `savings_ratio=` token,
   - invocation under `ORCHESTRATOR_AUTO=1` produces zero stdout (suppression matrix preserved).
6. `m018-p05-compression-eval.sh` — invoke `bash scripts/diagnostics/compression-eval.sh --milestone <fixture-id> --tier 1 --sample-floor 2`. Assert:
   - the output contains `COHORT`, `compressed`, `uncompressed`, `delta`, and `regression_flag:` rows,
   - invocation with `--sample-floor 1000` produces an `insufficient sample` line and exits 0,
   - invocation with `--tier 3` produces the P06-reservation stub line and exits 0.
7. `m018-p05-compression-eval-shape.sh` — assertions on the script body of `scripts/diagnostics/compression-eval.sh`:
   - the script is executable (`-x` test),
   - the script declares a sourceable guard (`_COMPRESSION_EVAL_SH_SOURCED`),
   - the script CLI block exists (`if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]`),
   - the body declares the MEM004 carve-out comment,
   - `--help` exits 0 and emits a usage block,
   - all CLI paths exit 0 (FR-12 read-only / CON-5 never-abort) — invoke with several malformed arg combos and assert exit 0.
8. `m018-p05-dual-write-recent.sh` — assert both `CLAUDE.md` and `AGENTS.md` contain a `# >>> orchestrator:recent-changes >>>`-delimited block whose body names "M018/P05" or "compression-eval".

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p05-build-fixture.sh`

Mirror the P04 helper. Job: stage two fixture milestone directories (savings-bearing log + no-savings log) under `$TMPDIR_BUILD/_p05_fixture/<slug>/`, each containing:

- `.orchestrator/milestones/M-FIXTURE/execution-log.jsonl` — synthesized JSONL with the appropriate record mix.
- (Optionally) a stub `.orchestrator/config.yml` for tests that exercise config-driven knobs (e.g., the efficiency-footer disable knob).

Returns 0 on successful staging, prints the staged fixture root on stdout. Idempotent (clean staging dir on re-invocation).

### Step 2 — Author `tests/fixtures/m018-p05-savings-log/execution-log.jsonl`

Hand-craft a JSONL log with:

- 5 `payload_breakdown` records (tasks T01–T05) carrying:
  - T01: `tier1_savings_tokens=200`, `filter_dropped_tokens=100`, `tier2_savings_tokens=0`, `tier1_invocations=1`, `payload_tokens_estimate=1000`.
  - T02: same shape, different numeric values.
  - T03: zero savings (uncompressed cohort representative).
  - T04: high savings (compressed cohort representative; ratio > 34.7%).
  - T05: high savings.
- 5 corresponding `unit_close` records (granularity=task), each pre-T01 for back-compat (no savings fields). T04's verifiers stage the post-T01 versions by invoking `_ws_emit_unit_close` directly, OR by manually appending a synthetic post-T01 unit_close record with the savings fields populated.
- Mixed `verification_pass_rate` values (some 1.0, some 0.8, some "unknown") to exercise the cohort outcome-rate computation.

Plus `tests/fixtures/m018-p05-savings-log/README.md` documenting the fixture's record mix and which truth/verifier each record exercises.

### Step 3 — Author `tests/fixtures/m018-p05-no-savings-log/execution-log.jsonl`

Hand-craft a JSONL log with:

- 3 `payload_breakdown` records carrying ZERO savings fields (i.e., no `tier1_savings_tokens`, no `tier2_savings_tokens`, no `filter_dropped_tokens`). These are pre-P02 records — what an old log looks like.
- 3 corresponding pre-T01 `unit_close` records.

Plus a README documenting "this fixture asserts the M018/P05 surfaces stay quiet on legacy logs (no compression line, no savings columns surfaced)."

### Step 4 — Author the eight verifiers

Each verifier follows the standard P03/P04 verifier pattern:

```bash
#!/usr/bin/env bash
# scripts/verify/m018-p05-<truth>.sh — Phase P05 verifier.
set -u
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$PROJECT_ROOT/scripts/verify/_helpers/m018-p05-build-fixture.sh"
# Use pass()/fail() per MEM002.
PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1"; }
# ... assertions per the verifier's truth ...
if [ "$FAIL_COUNT" -eq 0 ]; then exit 0; else exit 1; fi
```

For shim-style invocations of `_di_emit_dispatch_usage` and `_ws_emit_unit_close`, source the host script and override the env vars (`UNIT_ID`, `MILESTONE_ID`, `PHASE_ID`, `TASK_ID`, `BACKEND`, `PAYLOAD`, `ORCH_ROOT`) to point at the fixture milestone — this is the same pattern the P03/P04 shim verifiers used for `_bc_apply_tier1` / `_bc_apply_tier2`.

### Step 5 — Run the post-T01 emitters end-to-end

For each verifier that needs a post-T01 emit (truths #1, #2, #3, #4, #5, #6), the fixture-staging helper invokes the appropriate emitter on the fixture milestone, then the verifier reads the appended JSONL line and asserts on it. This exercises T01 + T02 + T03 end-to-end, not just the production-code static checks.

### Step 6 — Author [`.orchestrator/milestones/M018/phases/P05/P05-SUMMARY.md`](../../../../../milestones/M018/phases/P05/P05-SUMMARY.md)

Use `bash scripts/knowledge/write-summary.sh phase ...` per the canonical pattern. The summary frontmatter:

```yaml
---
schema_version: "1.0"
type: phase-summary
id: P05
parent: M018
milestone: M018
provides: "additive integer fields filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations on dispatch_usage (scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage) and unit_close (scripts/knowledge/write-summary.sh:_ws_emit_unit_close) JSONL records — rolled up from in-scope payload_breakdown records at emit-time (CON-5); cost-rollup column extension (FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS appended after existing 12 columns); efficiency-footer 'compression: <pct>% reduction over baseline' tail line (configurable via compression.efficiency_footer.enabled); doctor anomaly compression-regression reason (configurable via compression.regression_floor, default 0.347 per SC-9 P00 calibration); scripts/diagnostics/compression-eval.sh sourceable+CLI cohort-segmentation diagnostic with --tier <N> filter (1 and 2 supported in P05; tier 3 stub for P06); eight P05-private truth verifiers under scripts/verify/m018-p05-*.sh; two fixture trees under tests/fixtures/m018-p05-{savings-log,no-savings-log}/; scripts/verify/_helpers/m018-p05-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P02 payload_filter + filter_dropped_tokens additive field on payload_breakdown; P03 tier1_savings_tokens + tier1_invocations additive fields on payload_breakdown; P04 tier2_savings_tokens additive field on payload_breakdown; SC-9 calibrated 34.7% floor (P00); M027 metrics-rollup.sh + efficiency-footer.sh + check-anomalies.sh as extension targets (DEP-2)"
affects: "P06 (Tier 3 auto-compact — extends compression-eval.sh tier=3 stub to a real cohort against tier3_savings_tokens; extends dispatch_usage / unit_close additive fields with tier3_compression_savings_tokens and tier3_invocations; reuses the rollup-helper shape T01 established for the dispatch-internal emitter side; doctor compression-regression flag composes with tier3-quality regression once tier3 ships); M027 future surfaces consume the additive fields with no further changes required (rollup column-index contract is now pinned)"
verification_result: pass
---
```

The body of the summary follows the P02/P03/P04 narrative shape: closure summary, risk-mitigation traceability, followups, verification result.

### Step 7 — Dual-write CLAUDE.md / AGENTS.md `orchestrator:recent-changes`

Update the `# >>> orchestrator:recent-changes >>>` block to add a new bullet:

```
- 030-context-compression-layer / M018/P05: schema extensions on dispatch_usage + unit_close (additive filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations integer fields rolled up from payload_breakdown at emit-time, CON-5); cost-rollup column extension; efficiency-footer 'compression:' tail; doctor compression-regression flag (SC-9 0.347 floor); scripts/diagnostics/compression-eval.sh sourceable+CLI cohort-segmentation diagnostic with --tier <N> filter.
```

Invoke `bash scripts/util/dual-write-runtime-md.sh <new block content>` to apply to both files.

### Step 8 — Run the phase-level verification

`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P05/`. Expect all eight truths PASS, all artifacts present, all key links resolve.

## Verification

The phase-level verification is the gate:

- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P05/`

Expected output: all truths and artifacts PASS.

## Must-Haves (subset addressed by this task)

- **Truth #8**: dual-write recent-changes. Wholly addressed by Step 7.
- All other truths are EXERCISED here (Step 4) but the production code lives in T01 / T02 / T03.

## Notes

- The fixture-staging helper writes hand-crafted JSONL — no live build-context.sh dispatch is needed for T04's verifiers. This isolates T04 from any timing / locking issues against the active execution-log.jsonl.
- The `m018-p05-compression-eval.sh` verifier exercises both happy-path and below-floor paths; the `--tier 3` stub assertion is the load-bearing P06 contract.
- The compression-regression doctor flag should fire on the savings-log fixture only when the fixture's payload_breakdown records collectively show a savings ratio < 0.347 — the fixture must include at least one task whose ratio is below the floor for truth #5 to PASS. Author the savings-log fixture with this in mind: T03 is high-savings (above floor), T04/T05 are mid (above floor), but include a synthetic milestone-level aggregate that brings the average below the floor. (Or, simpler: include one fixture task whose tokens are large but savings are zero, dragging the milestone-level ratio below 0.347.)
- Bash 3.2 throughout. Verifier scripts use parallel scalars + indexed arrays only.
- The eight verifier filenames are exactly:
  1. `m018-p05-dispatch-usage-additivity.sh`
  2. `m018-p05-unit-close-additivity.sh`
  3. `m018-p05-cost-rollup-savings-columns.sh`
  4. `m018-p05-efficiency-footer-compression.sh`
  5. `m018-p05-doctor-compression-regression.sh`
  6. `m018-p05-compression-eval.sh`
  7. `m018-p05-compression-eval-shape.sh`
  8. `m018-p05-dual-write-recent.sh`

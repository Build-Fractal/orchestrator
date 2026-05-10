---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M030"
name: "metrics-rollup --by-model + efficiency-footer model_mix: line + co-authored verifiers + references doc amendment"
depends_on: ["T01"]
---

## Prerequisites

- T01 deliverables on disk and green:
  - `tests/fixtures/m030-p05/live-routed-corpus.jsonl` — 23 records (14 fast / 7 balanced / 2 smart).
  - `tests/fixtures/m030-p05/no-cost-rates-routing.yml` — routing-table copy without `cost_rates:`.
  - `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` — golden baseline of unflagged rollup.
  - `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt` — golden baseline of footer against pre-M030 corpus.
  - `tests/fixtures/m030-p05/synthesize-corpus.sh` — corpus synthesizer.
  - `tools/verify/p05-sc11-rollup-byte-equality.sh` — exits 0.
  - `tools/verify/p05-sc11-footer-byte-equality.sh` — exits 0.
  - `tools/verify/p05-doctor-config-check.sh` — exits 0.
- `scripts/diagnostics/metrics-rollup.sh` is in its post-M027/[M018](../../../../../milestones/M018/index.md) form. Key surface T02 will amend:
  - `metrics_rollup_main` argparse loop (lines ~702-770) — extend with `--by-model` and (optionally) `--routing-table` flags.
  - The CLI dispatch path after argparse (lines ~790-849) — branch on the new `--by-model` flag to take a different output path that suppresses the existing tabular emission and emits the per-tier dispatch-count + cost lines instead.
  - `metrics_rollup_normalize` projection (lines ~140-315) — extend the column set to include `model_routed` (currently column shape stops at column 18 with tier3 fields; T02 appends `model_routed` as column 19 to preserve the M018/P06 carry-forward convention, OR T02 extracts `model_routed` directly via a separate awk pass for the `--by-model` code-path so the normalize projection stays untouched and SC-11 byte-equality is trivially preserved). Recommended: separate awk pass — simpler invariant.
- `scripts/diagnostics/efficiency-footer.sh` is in its post-M018/P05 form. Key surface T02 will amend:
  - `efficiency_footer_render` body (lines ~44-157) — after the existing `compression:` line block (lines ~115-155), add a `model_mix:` block that invokes `metrics-rollup.sh --by-model` and parses the per-tier counts.
  - The `model_mix:` line is suppressed when the underlying corpus has zero shadow-on records (zero `model_routed` fields present). This is the SC-11 byte-equality preservation mechanism for pre-M030 fixtures.
- `templates/model-routing.yml` carries the shipped `cost_rates:` section (3 tiers × {input_per_mtok, output_per_mtok}).
- `references/model-routing.md` exists with the existing P01–P04 sections (`## Operator Overrides`, `## Live Routing`, etc.). T02 appends a `## Cost Rollup Surfaces` section.

Plan-time prerequisite-existence verification: every path above is asserted by T01 close. T02 entry runs `bash tools/verify/p05-sc11-rollup-byte-equality.sh && echo $?` (logical equivalent — actually run as a single script `bash <path>` and check `$?`) to confirm T01 is green before any amendment.

## Description

T02 lands the additive `--by-model` flag on `metrics-rollup.sh` and the additive `model_mix:` line on `efficiency-footer.sh`. Five deliverable groups:

1. **`metrics-rollup.sh --by-model` flag implementation.**
2. **`efficiency-footer.sh model_mix:` line implementation.**
3. **Co-authored scenario-specific verifiers** (4 new gates).
4. **`references/model-routing.md` amendment** — `## Cost Rollup Surfaces` section.
5. **Re-run T01's SC-11 gates** against the post-amendment surfaces to confirm byte-equality holds.

### `metrics-rollup.sh --by-model` shape

The amendment introduces:

- A new `--by-model` flag in `metrics_rollup_main`. When set, `by_model_mode=1`; the rollup takes a different code-path after argparse.
- A new optional `--routing-table <path>` flag. When set, `routing_table_path=<path>`; otherwise defaults to `M030_ROUTING_TABLE_PATH` env var, then `<project-root>/templates/model-routing.yml`. (Mirrors the doctor surface's pattern.)
- A new internal function `_metrics_rollup_by_model_emit` that:
  1. Reads the JSONL log line-by-line via awk, counting records by `model_routed` value (`fast | balanced | smart`). Records without `model_routed` (pre-M030) are skipped; they don't contribute to counts.
  2. Computes the total dispatch count `N = fast + balanced + smart`.
  3. Emits the per-tier dispatch-count line:
     ```
     N dispatches: <fast> fast / <balanced> balanced / <smart> smart
     ```
     (Exact label format documented; the SC-8 verifier matches this regex.)
  4. Reads `cost_rates:` from the routing-table file via an awk section-walker (same shape as P01/T03's routing-table parsing).
  5. If `cost_rates:` is present AND each tier's `input_per_mtok` + `output_per_mtok` are numeric, computes:
     - `aggregated_cost_usd` = sum over records of `(input_tokens_estimate / 1_000_000) * cost_rates.<tier-of-record>.input_per_mtok + (output_tokens_estimate / 1_000_000) * cost_rates.<tier-of-record>.output_per_mtok`.
     - `counterfactual_all_smart_cost_usd` = same sum but every record's tier replaced with `smart` (use `cost_rates.smart.input_per_mtok` + `cost_rates.smart.output_per_mtok` for every record's token counts).
     - Emits two additional lines:
       ```
       aggregated_cost_usd: 0.00012345
       counterfactual_all_smart_cost_usd: 0.00067890
       ```
     - (8-decimal precision; same precision as the existing tabular `EST_COST_USD` cell.)
  6. If `cost_rates:` is absent OR a tier entry is missing OR a rate value is non-numeric, emits:
     ```
     cost rates not configured
     aggregated_cost_usd: 0
     counterfactual_all_smart_cost_usd: 0
     ```
     (Warning, not hard failure. Exit 0 still.)
  7. Returns 0.

The new code-path is gated by `if [ "$by_model_mode" -eq 1 ]; then _metrics_rollup_by_model_emit ...; return 0; fi` placed AFTER the snapshot/normalize steps but BEFORE the existing `metrics_rollup_aggregate` + `metrics_rollup_render` invocations. This way the `--by-model` path reads from the same `$snapshot` (FR-19 / AD-3 atomicity) but emits a different shape.

**Critical invariant**: when `--by-model` is ABSENT, the `by_model_mode=0` default skips the new code-path entirely; the existing rollup emission is byte-identical to pre-T02. The SC-11 rollup gate (`p05-sc11-rollup-byte-equality.sh`) is the mechanical contract for this.

### `efficiency-footer.sh model_mix:` shape

The amendment introduces a new block in `efficiency_footer_render` AFTER the compression-line block (after line ~155 in the current source) and BEFORE the `return 0`:

```bash
# M030/P05/T02 — model_mix: line. Invokes metrics-rollup.sh --by-model
# against the same milestone/log path the parent footer is rendering.
# Suppressed when the corpus has zero shadow-on records (zero
# `model_routed` fields). This is the SC-11 byte-equality preservation
# mechanism — pre-M030 fixtures emit zero new bytes through the footer.
cfg_model_mix_footer="${ORCH_MODEL_MIX_FOOTER:-}"
if [ -z "$cfg_model_mix_footer" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
  cfg_model_mix_footer="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" model_routing.efficiency_footer.enabled 2>/dev/null || true)"
fi
case "$cfg_model_mix_footer" in
  false|FALSE|False|0|no|NO|No)
    : # suppressed by config
    ;;
  *)
    by_model_out=""
    if [ -n "$milestone" ]; then
      by_model_out="$(bash "$_EFF_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
        --by-model --milestone "$milestone" 2>/dev/null || true)"
    fi
    # Parse the per-tier dispatch-count line.
    mm_line="$(printf '%s\n' "$by_model_out" | grep -E '^[0-9]+ dispatches:' | head -n 1)"
    if [ -n "$mm_line" ]; then
      mm_total="$(printf '%s\n' "$mm_line" | awk '{print $1}')"
      mm_fast="$(printf '%s\n' "$mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="fast") print $(i-1)}' | head -n 1)"
      mm_bal="$(printf '%s\n' "$mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="balanced") print $(i-1)}' | head -n 1)"
      mm_smart="$(printf '%s\n' "$mm_line" | awk -F'[: /]+' '{for(i=1;i<=NF;i++) if($i=="smart") print $(i-1)}' | head -n 1)"
      # Suppress if total == 0 (no shadow-on records — SC-11 contract).
      if [ -n "$mm_total" ] && [ "$mm_total" -gt 0 ] 2>/dev/null; then
        printf '  model_mix: fast=%s balanced=%s smart=%s\n' "${mm_fast:-0}" "${mm_bal:-0}" "${mm_smart:-0}"
      fi
    fi
    ;;
esac
```

The block:

- Respects an `ORCH_MODEL_MIX_FOOTER` env var override (matches the existing `ORCH_EFFICIENCY_FOOTER` / `ORCH_COMPRESSION_FOOTER` convention).
- Falls through to `read-config.sh model_routing.efficiency_footer.enabled` for project/local/defaults config layers.
- Invokes `metrics-rollup.sh --by-model --milestone "$milestone"` and parses stdout for the per-tier line.
- Suppresses the line when total dispatches == 0 (the load-bearing SC-11 mechanism).
- Emits `  model_mix: fast=<N> balanced=<M> smart=<K>` with the standard 2-space indent.

Optional savings suffix: when `cost_rates:` is present (the rollup output additionally carries the `aggregated_cost_usd:` and `counterfactual_all_smart_cost_usd:` lines), T02 may compute `savings_usd = counterfactual - aggregated` and append ` savings: <USD>` to the model_mix: line. This is OPTIONAL — T02 documents whether it ships in P05 or defers to a later phase. The phase-suite verifier `p05-model-mix-footer-line.sh` accepts EITHER shape (with or without savings suffix); T02 commits to one and updates the verifier accordingly.

### Co-authored verifiers

Four new verifiers under `tools/verify/`:

1. **`p05-by-model-dispatch-counts.sh`** — invokes the rollup against the live-routed corpus and asserts the per-tier dispatch-count line has the expected exact integer counts.

   ```bash
   #!/usr/bin/env bash
   set -u
   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   FIXTURE="$PROJECT_ROOT/tests/fixtures/m030-p05/live-routed-corpus.jsonl"

   pass=0; fail=0

   ACTUAL="$(mktemp -t p05-by-model-disp.XXXXXX)"
   trap 'rm -f "$ACTUAL"' EXIT

   bash "$PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
     --by-model --log "$FIXTURE" \
     > "$ACTUAL" 2>/dev/null
   rc=$?

   if [ "$rc" -ne 0 ]; then
     fail=$((fail + 1))
     echo "FAIL: rollup --by-model exited $rc"
   fi

   # Assert the dispatch-count line is present.
   if grep -qE '^[0-9]+ dispatches: [0-9]+ fast / [0-9]+ balanced / [0-9]+ smart' "$ACTUAL"; then
     pass=$((pass + 1))
     echo "OK: dispatch-count line present"
   else
     fail=$((fail + 1))
     echo "FAIL: dispatch-count line missing or malformed"
   fi

   # Assert the exact counts (14 fast / 7 balanced / 2 smart over 23 total).
   if grep -qE '^23 dispatches: 14 fast / 7 balanced / 2 smart' "$ACTUAL"; then
     pass=$((pass + 1))
     echo "OK: counts match expected (14/7/2 over 23)"
   else
     fail=$((fail + 1))
     echo "FAIL: counts diverge from expected (14/7/2 over 23)"
     echo "Actual stdout:"
     cat "$ACTUAL"
   fi

   echo "SUMMARY: p05-by-model-dispatch-counts.sh pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

2. **`p05-by-model-cost-rates-present.sh`** — invokes the rollup with the shipped `templates/model-routing.yml` and asserts both the aggregated-cost line and counterfactual-cost line are present. Hand-computed expected values:

   - 14 records × 1024 input + 512 output @ fast (1.00/Mtok input, 5.00/Mtok output): 14 × (1024/1e6 × 1.00 + 512/1e6 × 5.00) = 14 × (0.001024 + 0.002560) = 14 × 0.003584 = 0.050176
   - 7 records × @ balanced (3.00/15.00): 7 × (0.003072 + 0.007680) = 7 × 0.010752 = 0.075264
   - 2 records × @ smart (15.00/75.00): 2 × (0.015360 + 0.038400) = 2 × 0.053760 = 0.107520
   - Aggregated: 0.050176 + 0.075264 + 0.107520 = 0.232960
   - Counterfactual (all 23 at smart): 23 × 0.053760 = 1.236480
   - Savings: 1.236480 − 0.232960 = 1.003520

   The verifier asserts the rollup emits these values to within 8-decimal precision (allow `0.232960` to render as `0.23296000` per the existing rollup's printf format).

3. **`p05-by-model-cost-rates-absent.sh`** — invokes the rollup with `--routing-table tests/fixtures/m030-p05/no-cost-rates-routing.yml` (or `M030_ROUTING_TABLE_PATH=...`) and asserts:

   - `cost rates not configured` line present.
   - `aggregated_cost_usd: 0` line present (or the documented zero-savings shape).
   - `counterfactual_all_smart_cost_usd: 0` line present.
   - Exit 0 (warning, not failure).
   - Per-tier dispatch-count line still present (fall-through from the rollup amendment).

4. **`p05-model-mix-footer-line.sh`** — invokes the footer against the live-routed corpus via an `ORCHESTRATOR_ROOT=tmp_root` carve-out. Stages `tmp_root/milestones/M999/execution-log.jsonl` as a copy of the fixture, then:

   ```bash
   ORCHESTRATOR_ROOT="$tmp_root" bash scripts/diagnostics/efficiency-footer.sh \
     --milestone M999 \
     > "$ACTUAL" 2>/dev/null
   ```

   Asserts the footer body contains `  model_mix: fast=14 balanced=7 smart=2` (with the expected counts). If T02 ships the optional savings suffix, the verifier additionally asserts ` savings: <numeric>` is present.

### `references/model-routing.md` amendment

Append a new `## Cost Rollup Surfaces` section after the existing `## Live Routing` section. Section content:

```markdown
## Cost Rollup Surfaces

`scripts/diagnostics/metrics-rollup.sh --by-model` emits per-tier
dispatch counts, aggregated cost, and the all-`smart` counterfactual
for any milestone with shadow-on or live-routed `dispatch_usage`
records. Output shape:

```text
N dispatches: <fast> fast / <balanced> balanced / <smart> smart
aggregated_cost_usd: <USD>
counterfactual_all_smart_cost_usd: <USD>
```

When `cost_rates:` is absent from `templates/model-routing.yml` (or
the path passed via `--routing-table`/`M030_ROUTING_TABLE_PATH`), the
output substitutes:

```text
N dispatches: <fast> fast / <balanced> balanced / <smart> smart
cost rates not configured
aggregated_cost_usd: 0
counterfactual_all_smart_cost_usd: 0
```

`scripts/diagnostics/efficiency-footer.sh` emits an additional
`model_mix:` line at the close of an `orchestrator:auto` run when
the milestone's `dispatch_usage` records contain `model_routed`
fields. Line shape: `  model_mix: fast=<N> balanced=<M> smart=<K>`.
The line is suppressed when the corpus has zero shadow-on records
(byte-equality with pre-M030 footer output).

### Operator obligation

Update `cost_rates:` in `templates/model-routing.yml` when provider
pricing changes. The `--by-model` counterfactual relies on these
values being current. The doctor's `--config-check` validates the
SECTION shape (closure invariants) but does NOT validate that the
RATES are current — staleness is an operator-noticed fact, not a
mechanical gate.
```

### SC-11 re-confirmation

Post-amendment, T02 re-runs the T01 SC-11 gates:

```bash
bash tools/verify/p05-sc11-rollup-byte-equality.sh
bash tools/verify/p05-sc11-footer-byte-equality.sh
```

Both must continue to exit 0. If either fails, T02's amendment has broken byte-equality and must be reworked. Common breakage modes:

- The rollup amendment accidentally emits a new line on the unflagged code-path (e.g., a debug `printf` left in). Fix: gate every new emission on `by_model_mode=1`.
- The footer amendment accidentally emits the `model_mix:` line when the corpus has zero shadow-on records (e.g., the suppression check is skipped or the `mm_total` parse is empty-string-vs-zero confused). Fix: tighten the `[ "$mm_total" -gt 0 ] 2>/dev/null` guard or add an explicit `[ -n "$mm_total" ] && [ "$mm_total" != "0" ]` check.

## Steps

1. **Confirm T01 deliverables are green**:

   ```bash
   bash tools/verify/p05-sc11-rollup-byte-equality.sh
   bash tools/verify/p05-sc11-footer-byte-equality.sh
   bash tools/verify/p05-doctor-config-check.sh
   ```

   Expected: all three exit 0. If any fail, halt T02 and re-open T01.

2. **Read `scripts/diagnostics/metrics-rollup.sh`** in full to confirm the line numbers and surface shape match the prerequisite description. Identify the argparse loop's insertion point (after `--source` case block) and the post-argparse CLI dispatch (after `_metrics_rollup_default_milestone` resolution).

3. **Read `scripts/diagnostics/efficiency-footer.sh`** in full to confirm the insertion point for the `model_mix:` block (after the compression-line block, before the `return 0`).

4. **Amend `scripts/diagnostics/metrics-rollup.sh`** per the Description:

   - Add `--by-model` and `--routing-table` flags to the argparse loop.
   - Add the `_metrics_rollup_by_model_emit` function near the other internal functions (e.g., after `metrics_rollup_render`).
   - Add the `if [ "$by_model_mode" -eq 1 ]; then _metrics_rollup_by_model_emit ...; return 0; fi` branch after the snapshot+normalize but before aggregate+render.
   - Bash 3.2 compatible. MEM004 emitter-internal carve-out applies — pipes / `$(...)` / awk allowed inside the function body.

5. **Author `tools/verify/p05-by-model-dispatch-counts.sh`** per the shape in the Description. Make executable.

6. **Author `tools/verify/p05-by-model-cost-rates-present.sh`** with the hand-computed expected values. Make executable.

7. **Author `tools/verify/p05-by-model-cost-rates-absent.sh`** with the cost-rates-absent fixture. Make executable.

8. **Run all three rollup verifiers** to confirm the rollup amendment is green:

   ```bash
   bash tools/verify/p05-by-model-dispatch-counts.sh
   bash tools/verify/p05-by-model-cost-rates-present.sh
   bash tools/verify/p05-by-model-cost-rates-absent.sh
   ```

   Expected: all three exit 0 with `SUMMARY: ... pass=N fail=0`.

9. **Re-run the SC-11 rollup gate** to confirm byte-equality is preserved:

   ```bash
   bash tools/verify/p05-sc11-rollup-byte-equality.sh
   ```

   Expected: exit 0. If fail, the rollup amendment has broken unflagged byte-equality — investigate and fix before proceeding.

10. **Amend `scripts/diagnostics/efficiency-footer.sh`** per the Description — add the `model_mix:` block after the compression-line block.

11. **Author `tools/verify/p05-model-mix-footer-line.sh`** with the carve-out staging and per-tier-count assertion. Make executable.

12. **Run the footer verifier**:

    ```bash
    bash tools/verify/p05-model-mix-footer-line.sh
    ```

    Expected: exit 0.

13. **Re-run the SC-11 footer gate** to confirm byte-equality is preserved on pre-M030 corpora:

    ```bash
    bash tools/verify/p05-sc11-footer-byte-equality.sh
    ```

    Expected: exit 0. If fail, the footer amendment has accidentally emitted a `model_mix:` line for a corpus with zero shadow-on records — investigate the suppression guard.

14. **Amend `references/model-routing.md`** by appending the `## Cost Rollup Surfaces` section per the Description.

15. **Run the full T01+T02 verifier set** as a self-check:

    ```bash
    bash tools/verify/p05-sc11-rollup-byte-equality.sh
    bash tools/verify/p05-sc11-footer-byte-equality.sh
    bash tools/verify/p05-doctor-config-check.sh
    bash tools/verify/p05-by-model-dispatch-counts.sh
    bash tools/verify/p05-by-model-cost-rates-present.sh
    bash tools/verify/p05-by-model-cost-rates-absent.sh
    bash tools/verify/p05-model-mix-footer-line.sh
    ```

    Expected: all seven exit 0.

## Must-Haves

T02 satisfies the following phase truths:

- "`bash scripts/diagnostics/metrics-rollup.sh --by-model --log <fixture>` emits a per-tier dispatch-count line" — gated by `bash tools/verify/p05-by-model-dispatch-counts.sh`.
- "With `cost_rates:` present, additionally emits aggregated cost + counterfactual lines" — gated by `bash tools/verify/p05-by-model-cost-rates-present.sh`.
- "With `cost_rates:` absent, emits warning + zero-savings lines, exit 0" — gated by `bash tools/verify/p05-by-model-cost-rates-absent.sh`.
- "`efficiency-footer.sh` emits `model_mix: fast=<N> balanced=<M> smart=<K>` when corpus has shadow-on records" — gated by `bash tools/verify/p05-model-mix-footer-line.sh`.
- SC-11 gates from T01 continue to pass post-amendment — gated by `bash tools/verify/p05-sc11-rollup-byte-equality.sh` and `bash tools/verify/p05-sc11-footer-byte-equality.sh`.

## Verification

```bash
bash tools/verify/p05-by-model-dispatch-counts.sh
bash tools/verify/p05-by-model-cost-rates-present.sh
bash tools/verify/p05-by-model-cost-rates-absent.sh
bash tools/verify/p05-model-mix-footer-line.sh
bash tools/verify/p05-sc11-rollup-byte-equality.sh
bash tools/verify/p05-sc11-footer-byte-equality.sh
bash tools/verify/p05-doctor-config-check.sh
```

Each command uses single-script-file shape per AD-19. All seven must exit 0 before T02 closes. Each emits `SUMMARY: <verifier-name> pass=N fail=0` on success.

## Inputs

### From Previous Tasks (T01)

- `tests/fixtures/m030-p05/live-routed-corpus.jsonl` — Key API: 23-record JSONL fixture; 14 fast / 7 balanced / 2 smart distribution; deterministic per-record token counts (1024 input / 512 output). Consumed by the rollup verifiers and the footer verifier.
- `tests/fixtures/m030-p05/no-cost-rates-routing.yml` — Key API: routing-table YAML without `cost_rates:` section; otherwise structurally valid. Consumed by `p05-by-model-cost-rates-absent.sh`.
- `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` + `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt` — Key API: golden stdout snapshots of pre-amendment rollup + footer against pre-M030 fixture. Consumed by SC-11 gates.
- `tools/verify/p05-sc11-rollup-byte-equality.sh` + `tools/verify/p05-sc11-footer-byte-equality.sh` + `tools/verify/p05-doctor-config-check.sh` — Key API: each `bash <path>` exits 0 on green; emits `SUMMARY:` line with pass-count.

### From Disk (Pre-existing)

- `scripts/diagnostics/metrics-rollup.sh` — Key API: sourceable + CLI; `bash <path> [flags]` emits cost+quality table to stdout; flags include `--granularity`, `--milestone`, `--phase`, `--task`, `--source`, `--log`, `--help`. T02 extends with `--by-model` and `--routing-table`.
- `scripts/diagnostics/efficiency-footer.sh` — Key API: sourceable function `efficiency_footer_render <milestone> <quiet-flag>` + CLI `bash <path> [--milestone <id>] [--project] [--quiet]`. Emits multi-line footer body to stdout. T02 amends to additionally emit `model_mix:` line.
- `templates/model-routing.yml` — Key API: 3 top-level sections (`routing:`, `resolution:`, `cost_rates:`); per-tier `cost_rates.<tier>.{input_per_mtok,output_per_mtok}` keys. SSOT for cost computation.
- `references/model-routing.md` — operator-facing routing-table documentation. T02 appends `## Cost Rollup Surfaces` section.
- `scripts/state/read-config.sh` — Key API: `bash <path> <key>` reads `<key>` from the `.orchestrator/config.yml` overlay layers. Used by the footer's config-knob resolution.

## Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p05-*` is invoked as a single `bash <path>`. The amendments themselves are emitter-internal (MEM004 carve-out applies — pipes / `$(...)` / awk allowed inside `metrics-rollup.sh` and `efficiency-footer.sh` bodies).
- **AP-008 heredoc-with-expansion**: not introduced — T02 ships only code amendments + verifiers. T03 handles the commit.
- **AP-009 compound-chain-gt2**: verifier scripts use straight-line shape (per-command `bash <path>` then `$?` capture); no `cmd1 && cmd2 && cmd3` chains.
- **Bash 3.2 compatibility**: amendments use parallel scalars, plain `case`, `while [ ... ]; do` loops. No `declare -A`, no `mapfile`, no process substitution.
- **CON-2 / FR-19 / SC-11 (additive schema)**: every amendment is strictly additive. Default rollup output (no `--by-model`) is byte-identical to pre-T02. Footer output on pre-M030 corpus is byte-identical to pre-T02 (suppress the `model_mix:` line entirely when no `model_routed` records present). The SC-11 gates from T01 are the mechanical contract.
- **CON-3 closure preserved**: T02 introduces zero new hardcoded model IDs. The `_metrics_rollup_by_model_emit` function reads model IDs ONLY from `templates/model-routing.yml resolution:` (and even then, only indirectly via `model_routed` symbolic-tier values from JSONL records — the cost computation uses `cost_rates.<tier>` not `cost_rates.<model-id>`). Verified by visual inspection of the diff (no `claude-haiku-*` / `claude-sonnet-*` / `claude-opus-*` literals introduced).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T02 introduces no SQL — N/A.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T02 invokes verifiers under `tools/verify/` and `scripts/diagnostics/` directly via `bash <path>`. No `run-probe.sh` invocations.
- **Project-owned-verifier-paths discipline ([M032](../../../../../milestones/M032/index.md) Finding A)**: every new verifier lives under `tools/verify/p05-*`; none under `scripts/verify/`.

## Expected Output

- `scripts/diagnostics/metrics-rollup.sh` — amended with `--by-model` flag handler + per-tier aggregation + cost_rates-present and cost_rates-absent branches. Default behavior byte-identical to pre-T02.
- `scripts/diagnostics/efficiency-footer.sh` — amended with `model_mix:` line block. Suppression on no-shadow-on-records preserves SC-11 byte-equality.
- `references/model-routing.md` — extended with `## Cost Rollup Surfaces` section.
- `tools/verify/p05-by-model-dispatch-counts.sh` + `p05-by-model-cost-rates-present.sh` + `p05-by-model-cost-rates-absent.sh` + `p05-model-mix-footer-line.sh` — four new verifiers; each exits 0 against post-T02 surfaces.
- T01 SC-11 gates continue to exit 0.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p05-by-model-dispatch-counts.sh` → `SUMMARY: p05-by-model-dispatch-counts.sh pass=2 fail=0`, exit 0.
- `bash tools/verify/p05-by-model-cost-rates-present.sh` → `SUMMARY: p05-by-model-cost-rates-present.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p05-by-model-cost-rates-absent.sh` → `SUMMARY: p05-by-model-cost-rates-absent.sh pass=N fail=0`, exit 0.
- `bash tools/verify/p05-model-mix-footer-line.sh` → `SUMMARY: p05-model-mix-footer-line.sh pass=N fail=0`, exit 0.
- `bash scripts/diagnostics/metrics-rollup.sh --by-model --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` (rough sample) →
  ```
  23 dispatches: 14 fast / 7 balanced / 2 smart
  aggregated_cost_usd: 0.23296000
  counterfactual_all_smart_cost_usd: 1.23648000
  ```
- `bash scripts/diagnostics/efficiency-footer.sh --milestone M999` (with carve-out → live-routed corpus) — appends `  model_mix: fast=14 balanced=7 smart=2` to the existing footer body.

The label tokens `aggregated_cost_usd:` and `counterfactual_all_smart_cost_usd:` are stable contract — the SC-8 verifier locks them. If T02 chooses different label tokens (e.g., `total_cost_usd:` and `counterfactual_smart_only_usd:`), the label change must be reflected in BOTH the rollup amendment AND the verifier scripts authored in T02 — the labels are a coupled commit. Recommended: use the labels documented above for consistency with the spec's prose-level mention of "an aggregated cost line + an all-`smart` counterfactual line".

The `--routing-table` flag is OPTIONAL plumbing — T02 may instead expose only the `M030_ROUTING_TABLE_PATH` env var (matches the doctor surface's `ROUTING_TABLE_PATH` env-only convention). The verifier `p05-by-model-cost-rates-absent.sh` should use whichever mechanism T02 ships; the choice is documented in the rollup amendment's inline comments.

If the rollup-shape verifier `tools/verify/p01-routing-table-shape.sh` rejected the cost-rates-absent fixture in T01 step 5, T01 should have already amended the verifier to relax the cost_rates: presence requirement. T02 inherits that amendment and assumes the routing-table-shape verifier accepts cost_rates: as optional. If T01 did not make that amendment (because the verifier already accepted absence), no T02 action is needed.

The savings-suffix on the `model_mix:` line is a stylistic choice — both forms (`model_mix: fast=14 balanced=7 smart=2` and `model_mix: fast=14 balanced=7 smart=2 savings: 1.00352000`) are acceptable. T02 ships ONE form; the verifier `p05-model-mix-footer-line.sh` asserts the chosen form. If T02 ships only the per-tier counts (no savings suffix), the verifier asserts only the per-tier counts; if T02 ships the savings suffix, the verifier additionally asserts the suffix is present with a numeric value.

If `efficiency-footer.sh` cannot resolve the active milestone in the carve-out (because `find-active-milestone.sh` returns empty under the staged ORCHESTRATOR_ROOT), pass `--milestone M999` explicitly to short-circuit the resolver. The verifier should always pass `--milestone` explicitly to keep the carve-out predictable.

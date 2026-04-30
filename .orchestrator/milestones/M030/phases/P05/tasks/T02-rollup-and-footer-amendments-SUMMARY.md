---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M030"
provides:
  - "scripts/diagnostics/metrics-rollup.sh --by-model flag (additive; per-tier dispatch counts + cost_rates-present aggregated_cost_usd + counterfactual_all_smart_cost_usd; cost_rates-absent warning + zero-savings fallback),scripts/diagnostics/efficiency-footer.sh model_mix: line (additive; suppressed on zero shadow-on records — SC-11 mechanism),tools/verify/p05-by-model-dispatch-counts.sh,tools/verify/p05-by-model-cost-rates-present.sh,tools/verify/p05-by-model-cost-rates-absent.sh,tools/verify/p05-model-mix-footer-line.sh,references/model-routing.md ## Cost Rollup Surfaces section"
requires:
  - "from:P05/T01 what:tests/fixtures/m030-p05/live-routed-corpus.jsonl + no-cost-rates-routing.yml + rollup-pre-m030-baseline.txt + footer-pre-m030-baseline.txt + p05-sc11-rollup-byte-equality.sh + p05-sc11-footer-byte-equality.sh + p05-doctor-config-check.sh,from:P02/T01 what:tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl,from:HEAD what:scripts/diagnostics/metrics-rollup.sh + scripts/diagnostics/efficiency-footer.sh + templates/model-routing.yml + references/model-routing.md"
affects:
  - "P05/T03"
key_files:
  - "scripts/diagnostics/metrics-rollup.sh,scripts/diagnostics/efficiency-footer.sh,references/model-routing.md,tools/verify/p05-by-model-dispatch-counts.sh,tools/verify/p05-by-model-cost-rates-present.sh,tools/verify/p05-by-model-cost-rates-absent.sh,tools/verify/p05-model-mix-footer-line.sh"
key_decisions:
  - "snapshot-shared dual-emission (rollup branches AFTER snapshot before normalize/aggregate/render — same snapshot reused so FR-19/AD-3 atomicity preserved + SC-11 byte-equality of unflagged path mechanically guaranteed); awk section-walker for cost_rates parsing (2-pass; indent-depth-aware; emits RATES tuple or NO_RATES sentinel); explicit 8-decimal expected values in the cost-rates-present verifier (asserts exact 0.23296000 / 1.23648000 not regex — future drift trips the gate immediately); routing-table path-resolution priority --routing-table flag > M030_ROUTING_TABLE_PATH env > templates/model-routing.yml default; cost_rates-absent is warning-class (exit 0) not hard failure — rollup remains useful as dispatch-count surface; ORCHESTRATOR_ROOT carve-out reuse for model-mix footer gate (mktemp -d + cp + trap-cleanup mirrors T01 SC-11 footer baseline-capture)"
patterns_established:
  - "snapshot-shared dual-emission branch (shared snapshot + by_model_mode=0/1 fork before normalize/aggregate/render),awk-section-walker-for-cost_rates (indent-depth-aware top/2-space-tier/4-space-key parse + RATES tuple or NO_RATES sentinel),footer-side-rollup-internal-invocation (footer invokes metrics-rollup.sh --by-model as subshell + parses dispatch-count line + emits derived footer line),hand-computed-cost-expectations-in-verifier (verifier asserts exact 8-decimal values not regex; verifier header names the formula),ORCHESTRATOR_ROOT-carve-out-reuse-across-T01-and-T02-footer-gates"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P05/tasks/T02-rollup-and-footer-amendments-PAYLOAD.md,.orchestrator/milestones/M030/phases/P05/tasks/T02-rollup-and-footer-amendments-PLAN.md"
duration: "80m"
verification_result: "pass"
completed_at: "2026-04-30T19:21:40Z"
---

T02 lands the additive `--by-model` flag on `scripts/diagnostics/metrics-rollup.sh` and the additive `model_mix:` line on `scripts/diagnostics/efficiency-footer.sh`, plus four co-authored scenario-specific verifiers and the `## Cost Rollup Surfaces` operator-doc section. All amendments are strictly additive (CON-2 / FR-19 / SC-11): pre-M030 fixtures round-trip byte-identically through both surfaces, mechanically enforced by the T01 byte-strict gates (which remain green post-amendment).

## What was built

1. `scripts/diagnostics/metrics-rollup.sh` — added `--by-model` flag + `--routing-table <path>` flag to `metrics_rollup_main` argparse, plus the new internal function `_metrics_rollup_by_model_emit` that walks the snapshot JSONL via awk, counts `model_routed` per tier (fast/balanced/smart), parses `cost_rates:` from the routing-table via a 2-pass awk section-walker, and emits the three-line shape (dispatch-count + aggregated-cost + counterfactual) when rates are present, or the warning + zero-savings shape when rates are absent. Routing-table resolution: `--routing-table <path>` flag → `M030_ROUTING_TABLE_PATH` env → `templates/model-routing.yml` default. The branch is gated on `by_model_mode=1` AFTER the snapshot but BEFORE normalize/aggregate/render — same snapshot reused so FR-19/AD-3 atomicity is preserved. Default unflagged path is mechanically byte-identical to pre-T02 (SC-11 contract).

2. `scripts/diagnostics/efficiency-footer.sh` — added a new `model_mix:` block in `efficiency_footer_render` AFTER the compression-line block and BEFORE the closing `return 0`. The block invokes `metrics-rollup.sh --by-model --milestone "$milestone"` against the same milestone the parent footer is rendering, parses the per-tier dispatch-count line via awk, and emits `  model_mix: fast=<N> balanced=<M> smart=<K>` with the standard 2-space indent. The line is suppressed entirely when total == 0 (no shadow-on records — the load-bearing SC-11 mechanism). Config knob discipline matches the compression line: `ORCH_MODEL_MIX_FOOTER` env var → `model_routing.efficiency_footer.enabled` config, falsy values suppress.

3. `references/model-routing.md` — appended a `## Cost Rollup Surfaces` section between `## Live Routing` and `## See Also`, documenting the `--by-model` output shape, the cost_rates-present vs cost_rates-absent branches, the routing-table path-resolution priority, the `model_mix:` line shape, the suppression-on-zero-records mechanism, the config-knob discipline, and the operator obligation to update `cost_rates:` when provider pricing changes (with explicit clarification that the doctor's `--config-check` validates SHAPE, not currency).

4. Four new verifiers under `tools/verify/`:
   - `p05-by-model-dispatch-counts.sh` (3 sub-gates: rc==0; dispatch-count line shape; exact 14/7/2 over 23 counts) — FR-15 sentence 1.
   - `p05-by-model-cost-rates-present.sh` (5 sub-gates: rc==0; aggregated_cost_usd matches 0.23296000 to 8-decimal precision; counterfactual_all_smart_cost_usd matches 1.23648000; dispatch-count line still emitted; "cost rates not configured" line absent) — FR-15 sentence 2 + counterfactual.
   - `p05-by-model-cost-rates-absent.sh` (5 sub-gates: rc==0 under cost_rates-absent — warning not hard failure; dispatch-count still emitted; "cost rates not configured" warning present; aggregated_cost_usd: 0; counterfactual_all_smart_cost_usd: 0) — FR-15 sentence 3 fallback.
   - `p05-model-mix-footer-line.sh` (3 sub-gates: rc==0; `model_mix:` line shape with 2-space indent; exact 14/7/2 counts) — FR-16. Uses the same ORCHESTRATOR_ROOT carve-out (mktemp -d + cp + trap-cleanup) the SC-11 footer gate established.

## Verification

- `bash tools/verify/p05-sc11-rollup-byte-equality.sh` — `pass=1 fail=0` (unflagged rollup byte-identical to pre-amendment baseline).
- `bash tools/verify/p05-sc11-footer-byte-equality.sh` — `pass=1 fail=0` (footer suppresses model_mix: line on pre-M030 corpus).
- `bash tools/verify/p05-doctor-config-check.sh` — `pass=1 fail=0` (SC-9 wrapper green via P01 delegate).
- `bash tools/verify/p05-by-model-dispatch-counts.sh` — `pass=3 fail=0`.
- `bash tools/verify/p05-by-model-cost-rates-present.sh` — `pass=5 fail=0`.
- `bash tools/verify/p05-by-model-cost-rates-absent.sh` — `pass=5 fail=0`.
- `bash tools/verify/p05-model-mix-footer-line.sh` — `pass=3 fail=0`.
- All 7 T01+T02 verifiers green: SELF-CHECK pass=7 fail=0.
- Earlier phase suites unaffected: P01 pass=7, P02 pass=9, P03 pass=8, P04 pass=12.

## Hand-computed cost-rate expectations (asserted by the cost-rates-present verifier)

Per-record token shape: 1024 input + 512 output. Tier rates: fast 1.00/5.00, balanced 3.00/15.00, smart 15.00/75.00 (per-Mtok input/output).

- fast per-record:     1024/1e6 * 1.00 + 512/1e6 * 5.00 = 0.003584
- balanced per-record: 1024/1e6 * 3.00 + 512/1e6 * 15.00 = 0.010752
- smart per-record:    1024/1e6 * 15.00 + 512/1e6 * 75.00 = 0.053760
- aggregated     = 14 * 0.003584 + 7 * 0.010752 + 2 * 0.053760 = 0.232960
- counterfactual = 23 * 0.053760 = 1.236480

Both values land at 8-decimal precision (`0.23296000` and `1.23648000`).

## Patterns established

- Snapshot-shared dual-emission branch: the `--by-model` code-path reads from the SAME snapshot the unflagged path uses, branching AFTER the snapshot but BEFORE normalize/aggregate/render. FR-19/AD-3 atomicity preserved without re-snapshotting; SC-11 byte-equality of the unflagged path mechanically guaranteed because zero new code runs on `by_model_mode=0`.
- Awk section-walker for cost_rates parsing: 2-pass awk (one for the section parse emitting "RATES <fi> <fo> <bi> <bo> <si> <so>" or "NO_RATES"; one for the JSONL walk consuming that line). Indent-depth-aware (top-level vs 2-space tier vs 4-space key). Tolerates whitespace and comments. Robust to per-tier missing entries (any missing → NO_RATES).
- Footer-side rollup-internal invocation pattern: the `model_mix:` block invokes `metrics-rollup.sh --by-model` as a subshell, parses the resulting per-tier dispatch-count line via awk, and emits a derived footer line. Same shape the compression-line block uses (rollup as the SSOT, footer as a thin presenter). Suppression-on-zero is the load-bearing SC-11 mechanism.
- Hand-computed cost-rate expectations baked into the verifier: the cost-rates-present gate asserts the EXACT 8-decimal value rather than a regex, so future drift in either the rollup arithmetic OR the routing-table rates trips the gate immediately. Verifier names the formula in its header so operators can re-derive when rates change.
- ORCHESTRATOR_ROOT carve-out reuse: the model-mix footer gate uses the identical mktemp -d + cp + trap-cleanup carve-out the T01 SC-11 footer baseline-capture established. Same shape across both gates means a single staging-pattern bug fix lands once.

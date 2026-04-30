---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M030"
goal: "Land the M027 surface integration for adaptive model selection — additive `--by-model` flag on `scripts/diagnostics/metrics-rollup.sh` (FR-15 / SC-8), additive `model_mix:` line on `scripts/diagnostics/efficiency-footer.sh` (FR-16), and verifier coverage for the existing `scripts/diagnostics/run-doctor.sh --config-check` malformed-yaml file:line path (FR-17 / SC-9, surface already shipped P01/T04). All amendments are strictly additive: pre-M030 JSONL fixtures must round-trip byte-identically through unflagged `metrics-rollup.sh` and through `efficiency-footer.sh` whose footer body has zero shadow-on records to summarize (CON-2 / FR-19 / SC-11). When `templates/model-routing.yml cost_rates:` is present, `--by-model` prints `<N> dispatches: <a> fast / <b> balanced / <c> smart` plus an aggregated cost line plus an all-`smart` counterfactual line; when absent, the same per-tier dispatch-count line plus a `cost rates not configured` warning plus a zero-savings line — both branches exit 0. The `model_mix:` line on `efficiency-footer.sh` is emitted only when the active milestone's execution-log contains shadow-on dispatch_usage records carrying `model_routed`; pre-M030 fixtures (no `model_routed` field) suppress the line entirely so byte-equality holds. Phase-suite ships as a straight-line aggregator over the P05 sub-gates, mirroring P01–P04 shape."
demo_sentence: "An operator runs three commands against fixture corpora. (a) `bash scripts/diagnostics/metrics-rollup.sh --by-model --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` (10+ live-routed records spanning fast/balanced/smart) emits to stdout a line matching `^[0-9]+ dispatches: [0-9]+ fast / [0-9]+ balanced / [0-9]+ smart`, plus an aggregated cost line, plus an all-`smart` counterfactual cost line — exit 0. (b) The same command against `tests/fixtures/m030-p05/live-routed-corpus.jsonl` with a copy of `templates/model-routing.yml` whose `cost_rates:` section has been stripped emits the per-tier dispatch-count line plus `cost rates not configured` plus a zero-savings line — still exit 0. (c) `bash scripts/diagnostics/efficiency-footer.sh --milestone M999 --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` (or equivalent fixture-routed invocation) appends a `model_mix:` line to the existing efficiency footer; running the same command against `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (no `model_routed` field) emits the legacy footer byte-identically — no `model_mix:` line. (d) `bash scripts/diagnostics/run-doctor.sh --config-check` against a malformed `templates/model-routing.yml` (undefined symbolic-tier reference) exits 1 with stdout containing the offending file path and a `:<lineno>` suffix (existing P01/T04 surface; P05 inherits via `tools/verify/p05-doctor-config-check.sh` wrapper). (e) `bash tools/verify/p05-phase-suite.sh` emits `SUMMARY: p05-phase-suite.sh pass=N fail=0` with N>=8 and exits 0."
risk: "low"
depends_on: ["P02"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p05-*) so install-clobber risk is contained
     (M032 Finding A discipline).

     P05 is low-risk and surface-only: three additive amendments + a
     verifier wrapper. Three tasks total:
       T01 — fixtures + cost_rates-absent malformed routing.yml +
             tolerant pre-amendment SC-11 byte-equality gate.
       T02 — amend metrics-rollup.sh (--by-model) + amend
             efficiency-footer.sh (model_mix: line) + co-authored
             SC-8 and SC-9 verifiers + SC-11 confirmation against
             pre-M030 fixtures + doctor-config-check wrapper for SC-9.
       T03 — phase-suite aggregator + recent-changes dual-write +
             commit.

     T02 deliberately combines the rollup and footer amendments because
     they share a fixture corpus, share the cost_rates-present /
     cost_rates-absent branch logic, and the footer reads rollup output
     internally — splitting them adds context-bridge cost without a
     clean separation. T03 is a thin close. -->

### Truths

- `bash scripts/diagnostics/metrics-rollup.sh --by-model --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` against the live-routed fixture corpus (10+ shadow-on `dispatch_usage` records spanning all three tiers) emits to stdout a line matching `^[0-9]+ dispatches: [0-9]+ fast / [0-9]+ balanced / [0-9]+ smart`. The fixture commits to a known per-tier distribution (e.g., 14 fast / 7 balanced / 2 smart over 23 total records) so the verifier asserts the exact integer counts. The dispatch-count line is the contract whether `cost_rates:` is present or absent. (FR-15 / SC-8 first sentence.)
  - Check: `bash tools/verify/p05-by-model-dispatch-counts.sh`

- With `templates/model-routing.yml` declaring a `cost_rates:` section (the shipped default), `bash scripts/diagnostics/metrics-rollup.sh --by-model --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` additionally emits an aggregated cost line and an all-`smart` counterfactual line. Both lines carry numeric USD values computed from the per-record `input_tokens_estimate` + `output_tokens_estimate` fields (already in shadow-on records) multiplied by the per-tier `cost_rates:` rates. The verifier asserts both lines are present with the `^aggregated_cost_usd:` and `^counterfactual_all_smart_cost_usd:` prefixes (or equivalent stable label tokens documented in `references/model-routing.md`); exact USD value verified to 8-decimal precision against a hand-computed expectation derived from the fixture's known token distribution. Exit 0. (FR-15 / SC-8 second sentence.)
  - Check: `bash tools/verify/p05-by-model-cost-rates-present.sh`

- With `cost_rates:` ABSENT from the routing-table at the path passed to `metrics-rollup.sh` (the verifier stages a copy of `templates/model-routing.yml` at `/tmp/p05-no-cost-rates-routing.yml` with the `cost_rates:` section deleted, then invokes the rollup with `M030_ROUTING_TABLE_PATH=<that-path>` env or equivalent override mechanism documented in T02), the same `--by-model` command emits the per-tier dispatch-count line plus a `cost rates not configured` warning line (case-insensitive match permitted; the verifier asserts the exact label declared in the rollup amendment) plus a zero-savings line (`counterfactual_all_smart_cost_usd: 0` or `savings_usd: 0` — the verifier documents the stable token). Exit 0 (warning, not hard failure). (FR-15 / SC-8 third sentence.)
  - Check: `bash tools/verify/p05-by-model-cost-rates-absent.sh`

- `bash scripts/diagnostics/efficiency-footer.sh --milestone <fixture-milestone> --log tests/fixtures/m030-p05/live-routed-corpus.jsonl` (or equivalent shape — T02 documents the fixture-routing override; recommended shape is to pre-stage an `ORCHESTRATOR_ROOT=tmp_root` carve-out where `tmp_root/milestones/M999/execution-log.jsonl` IS the fixture corpus, mirroring the P02 round-trip pattern) appends a `model_mix:` line to the existing footer body. The line shape is `model_mix: fast=<N> balanced=<M> smart=<K>` with the same per-tier counts the rollup emits for the same corpus; T02 documents whether the line additionally carries a `savings: <USD>` suffix when `cost_rates:` is present. The line is suppressed entirely when the underlying corpus has zero shadow-on records (no `model_routed` field present). (FR-16 / SC-8-paired with SC-11 below.)
  - Check: `bash tools/verify/p05-model-mix-footer-line.sh`

- SC-11 byte-equality through unflagged `metrics-rollup.sh`: against the pre-M030 fixture at `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (5 records, no `model_routed` field, the P02 graduation fixture), running `bash scripts/diagnostics/metrics-rollup.sh --log tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (no `--by-model` flag) emits stdout that is byte-identical to the same command's output captured BEFORE T02's amendments land. The verifier captures a HEAD-baseline output via `git stash` + run + `git stash pop` workflow, OR (preferred shape) compares against a committed golden-output fixture at `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` that T01 captures from `git show HEAD:scripts/diagnostics/metrics-rollup.sh` execution. Implementation is straightforward: T01 stages the golden baseline by running the pre-amendment rollup once before T02 amends; T02's gate diffs post-amendment output against the golden. (CON-2 / FR-19 / SC-11.)
  - Check: `bash tools/verify/p05-sc11-rollup-byte-equality.sh`

- SC-11 byte-equality through unflagged `efficiency-footer.sh`: against the same pre-M030 fixture, running `bash scripts/diagnostics/efficiency-footer.sh` (no special flags; falls through to the legacy rollup-driven path with no shadow-on records) emits stdout that is byte-identical to the same command captured BEFORE T02's amendments. Same golden-baseline pattern as the rollup gate above. The footer's `model_mix:` line MUST be suppressed when no `model_routed` field is present in the underlying corpus — this is the load-bearing gate for FR-19 additive schema. (CON-2 / FR-19 / SC-11.)
  - Check: `bash tools/verify/p05-sc11-footer-byte-equality.sh`

- SC-9 doctor `--config-check` continues to exit 1 with file+lineno on a malformed `templates/model-routing.yml`. The surface already exists (P01/T04 deliverable: `scripts/diagnostics/run-doctor.sh` reads `--config-check`, invokes `tools/verify/p01-routing-table-shape.sh`, and propagates the verifier's `<file>:<lineno>` diagnostic to stdout with exit 1). P05's contribution is a thin wrapper `tools/verify/p05-doctor-config-check.sh` that delegates to the existing `tools/verify/p01-doctor-config-check.sh` Scenarios A+B and asserts exit 0 — guaranteeing the SC-9 contract still holds at P05 close even though no P05 task amends the doctor surface. The wrapper shape mirrors `tools/verify/p04-additive-schema.sh` (delegate-and-pass-through). (FR-17 / SC-9.)
  - Check: `bash tools/verify/p05-doctor-config-check.sh`

- `bash tools/verify/p05-phase-suite.sh` invokes all seven P05 sub-gates (by-model-dispatch-counts, by-model-cost-rates-present, by-model-cost-rates-absent, model-mix-footer-line, sc11-rollup-byte-equality, sc11-footer-byte-equality, doctor-config-check) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p05-phase-suite.sh pass=N fail=M` on a single line before exit. Same straight-line shape as `p02-phase-suite.sh`, `p03-phase-suite.sh`, `p04-phase-suite.sh`. (Phase-close aggregator.)
  - Check: `bash tools/verify/p05-phase-suite.sh`

### Artifacts

- tests/fixtures/m030-p05/live-routed-corpus.jsonl (min 23 lines, contains "model_routed", contains "fast", contains "balanced", contains "smart") — create
- tests/fixtures/m030-p05/no-cost-rates-routing.yml (min 50 lines, contains "routing:", contains "resolution:") — create
- tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt (min 1 lines) — create
- tests/fixtures/m030-p05/footer-pre-m030-baseline.txt (min 1 lines) — create
- tests/fixtures/m030-p05/synthesize-corpus.sh (min 30 lines, contains "model_routed", contains "fast", contains "balanced", contains "smart") — create
- scripts/diagnostics/metrics-rollup.sh (modify — add --by-model flag handler + per-tier aggregation + cost_rates-present + cost_rates-absent branches; preserve unflagged byte-equality) — modify
- scripts/diagnostics/efficiency-footer.sh (modify — add model_mix: line emission gated on shadow-on records present in corpus; preserve byte-equality when no shadow-on records) — modify
- references/model-routing.md (modify — add `## Cost Rollup Surfaces` section documenting the --by-model output shape, the cost_rates-absent fallback, the model_mix: line shape, and the cost_rates: operator update obligation) — modify
- tools/verify/p05-by-model-dispatch-counts.sh (min 60 lines, contains "live-routed-corpus.jsonl", contains "dispatches:", contains "fast", contains "balanced", contains "smart", contains "SUMMARY:") — create
- tools/verify/p05-by-model-cost-rates-present.sh (min 70 lines, contains "cost_rates", contains "aggregated_cost_usd", contains "counterfactual_all_smart", contains "SUMMARY:") — create
- tools/verify/p05-by-model-cost-rates-absent.sh (min 70 lines, contains "cost rates not configured", contains "no-cost-rates-routing.yml", contains "SUMMARY:") — create
- tools/verify/p05-model-mix-footer-line.sh (min 80 lines, contains "model_mix:", contains "fast=", contains "balanced=", contains "smart=", contains "live-routed-corpus.jsonl", contains "SUMMARY:") — create
- tools/verify/p05-sc11-rollup-byte-equality.sh (min 50 lines, contains "pre-m030-dispatch-usage.jsonl", contains "rollup-pre-m030-baseline.txt", contains "diff", contains "SUMMARY:") — create
- tools/verify/p05-sc11-footer-byte-equality.sh (min 50 lines, contains "pre-m030-dispatch-usage.jsonl", contains "footer-pre-m030-baseline.txt", contains "diff", contains "SUMMARY:") — create
- tools/verify/p05-doctor-config-check.sh (min 20 lines, contains "p01-doctor-config-check.sh", contains "SUMMARY:") — create
- tools/verify/p05-phase-suite.sh (min 80 lines, contains "p05-by-model-dispatch-counts", contains "p05-by-model-cost-rates-present", contains "p05-by-model-cost-rates-absent", contains "p05-model-mix-footer-line", contains "p05-sc11-rollup-byte-equality", contains "p05-sc11-footer-byte-equality", contains "p05-doctor-config-check", contains "SUMMARY:") — create
- CLAUDE.md (modify — recent-changes region) — modify
- AGENTS.md (modify if present — recent-changes region dual-write) — modify

### Key Links

- specs/032-adaptive-model-selection/spec.md → scripts/diagnostics/metrics-rollup.sh (FR-15 names the additive `--by-model` flag; SC-8 names the dispatch-count line + cost line + counterfactual + cost_rates-absent fallback)
- specs/032-adaptive-model-selection/spec.md → scripts/diagnostics/efficiency-footer.sh (FR-16 names the additive `model_mix:` line)
- specs/032-adaptive-model-selection/spec.md → scripts/diagnostics/doctor.sh (FR-17 / SC-9 names the `--config-check` flag and the file:line diagnostic on the M027 doctor surface; on-disk file is `run-doctor.sh`, the spec uses the conceptual name `doctor.sh`; surface ships P01/T04, P05 inherits via wrapper)
- specs/032-adaptive-model-selection/spec.md → references/model-routing.md (FR-15 / FR-16 — operator-facing rollup + footer + cost_rates-update documentation)
- scripts/diagnostics/metrics-rollup.sh → templates/model-routing.yml (cost_rates: SSOT consumed by --by-model; CON-3 closure preserved — no new model-ID literals)
- scripts/diagnostics/efficiency-footer.sh → scripts/diagnostics/metrics-rollup.sh (footer reads rollup output; model_mix: line consumes the per-tier counts)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-by-model-dispatch-counts.sh (suite invokes the SC-8 dispatch-count gate)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-by-model-cost-rates-present.sh (suite invokes the SC-8 cost-line gate)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-by-model-cost-rates-absent.sh (suite invokes the SC-8 fallback gate)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-model-mix-footer-line.sh (suite invokes the FR-16 footer gate)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-sc11-rollup-byte-equality.sh (suite invokes the SC-11 rollup byte-equality gate)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-sc11-footer-byte-equality.sh (suite invokes the SC-11 footer byte-equality gate)
- tools/verify/p05-phase-suite.sh → tools/verify/p05-doctor-config-check.sh (suite invokes the SC-9 doctor wrapper)

## Tasks

### T01: P05 fixtures + golden baselines + tolerant SC-11 pre-amendment gates (preflight)

See tasks/T01-fixtures-and-baselines-PLAN.md.

T01 ships before any work on `scripts/diagnostics/metrics-rollup.sh` or `scripts/diagnostics/efficiency-footer.sh` so the SC-11 byte-equality contract has a mechanical gate at the moment T02's diff lands. Mirrors the P02/T01 + P03/T01 + P04/T01 graduation pattern (verifier-before-deliverable, AKA D-A4 timeline-graduation discipline at sub-phase scope).

Five deliverable groups:

(a) **Live-routed corpus** at `tests/fixtures/m030-p05/live-routed-corpus.jsonl` — ≥10 (recommended 23) shadow-on `dispatch_usage` records spanning all three symbolic tiers. Recommended distribution: 14 fast / 7 balanced / 2 smart so the per-tier counts are non-trivial and the per-tier-cost computation has variance. Each record uses the post-P04 schema (the same fields P02-P04 emit + `escalation_count=0` + `escalation_reason=""`). Synthesized via `tests/fixtures/m030-p05/synthesize-corpus.sh` (idempotent — re-running produces identical output).

(b) **Cost-rates-absent routing-table fixture** at `tests/fixtures/m030-p05/no-cost-rates-routing.yml` — a copy of `templates/model-routing.yml` with the `cost_rates:` section deleted. T02's verifiers point the rollup at this path via the override mechanism T02 documents (recommended: a `M030_ROUTING_TABLE_PATH` env var that defaults to `templates/model-routing.yml` — same shape as the existing `ROUTING_TABLE_PATH` env var the doctor reads at run-doctor.sh line ~45).

(c) **Pre-amendment golden baselines** at `tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt` and `tests/fixtures/m030-p05/footer-pre-m030-baseline.txt`. T01 captures these by running the pre-amendment `metrics-rollup.sh` and `efficiency-footer.sh` against `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` and committing the captured stdout to disk. The SC-11 gates compare post-T02 output against these goldens via `diff`.

(d) **Tolerant SC-11 gates** at `tools/verify/p05-sc11-rollup-byte-equality.sh` and `tools/verify/p05-sc11-footer-byte-equality.sh`. T01 ships these as fully-strict gates (NOT pre-amendment-tolerant — the goldens are captured before T02 amends, so the gate must be byte-strict from the start; if it passes pre-T02 it MUST also pass post-T02, otherwise T02 has broken byte-equality). This is the inversion of the P04/T01 tolerant pattern: P05's gate is naturally a true regression gate because the goldens are the contract.

(e) **Doctor-config-check wrapper** at `tools/verify/p05-doctor-config-check.sh` — a thin pass-through wrapper that invokes `tools/verify/p01-doctor-config-check.sh` and asserts exit 0. Mirrors the `p04-additive-schema.sh` shape. T01 ships this wrapper because the doctor surface ships P01/T04 — the P05 phase-suite simply re-runs the existing P01 gate to confirm SC-9 still holds at P05 close.

T01 ends green: all artifacts on disk, the SC-11 gates pass against HEAD's pre-amendment `metrics-rollup.sh` + `efficiency-footer.sh` (the goldens were captured FROM that HEAD), and the doctor-config-check wrapper passes (delegates to the green P01 gate).

### T02: metrics-rollup --by-model + efficiency-footer model_mix: line + co-authored verifiers

See tasks/T02-rollup-and-footer-amendments-PLAN.md.

T02 is the surface-amendment task. Reads the current `scripts/diagnostics/metrics-rollup.sh` (post-M027/M018 — the awk-based rollup engine ~860 lines) and `scripts/diagnostics/efficiency-footer.sh` (post-M018/P05 — the compression-line-bearing footer ~225 lines) and amends each:

1. **`metrics-rollup.sh --by-model` flag**:
   - Add `--by-model` to the `metrics_rollup_main` argparse loop (after `--source` / before `--log`). When set, the CLI takes a different output code-path: the existing tabular cost+quality table is suppressed, and the rollup instead emits the per-tier dispatch-count line + (cost_rates-present) aggregated cost line + counterfactual line OR (cost_rates-absent) warning line + zero-savings line.
   - Per-tier aggregation reads the input JSONL line-by-line (reusing the existing `metrics_rollup_normalize` awk pass — extend its projection to include `model_routed` if not already present in the column set; if the column shape needs to grow, append at the END to preserve back-compat indices per the M018/P06 carry-forward convention) and counts records by `model_routed` value (`fast | balanced | smart`). Records without `model_routed` (pre-M030) are skipped — they don't contribute to the count.
   - Cost computation reads `templates/model-routing.yml cost_rates:` via an awk section-walker (same pattern P01/T03's `p01-routing-table-shape.sh` uses; same pattern P02/T02's dispatch-interface awk extraction uses). Per-record cost = `(input_tokens_estimate / 1_000_000) * cost_rates.<tier>.input_per_mtok + (output_tokens_estimate / 1_000_000) * cost_rates.<tier>.output_per_mtok`. Aggregated cost = sum per record. Counterfactual = same sum but every record's tier replaced with `smart`.
   - Routing-table path resolution: `--routing-table <path>` flag (preferred) OR `M030_ROUTING_TABLE_PATH` env var OR default `templates/model-routing.yml`. Mirrors run-doctor.sh's pattern.
   - cost_rates-absent fallback: when the routing-table file lacks a `cost_rates:` section OR a per-tier entry is missing, emit `cost rates not configured` to stdout (exact label fixed at this line so the SC-8 verifier asserts it), emit `aggregated_cost_usd: 0` and `counterfactual_all_smart_cost_usd: 0` (or the equivalent stable label tokens T02 commits to), exit 0. NOT a hard failure — the rollup remains useful for dispatch-count surfacing.
   - **Default behavior preservation**: when `--by-model` is ABSENT, the rollup's existing tabular shape is byte-identical to pre-T02. The new flag's code path is a pure addition; the default code-path's emission set is unchanged. Verified by the SC-11 gate (golden-baseline `diff`).

2. **`efficiency-footer.sh model_mix:` line**:
   - Inside `efficiency_footer_render` after the existing compression-line block (lines ~115-155), add a `model_mix:` block. Read the same rollup output the function already invokes (`bash scripts/diagnostics/metrics-rollup.sh --by-model --milestone "$milestone" 2>/dev/null || true`). If the rollup output contains a line matching `^[0-9]+ dispatches: ... fast / ... balanced / ... smart`, parse the per-tier counts via awk, format as `model_mix: fast=<N> balanced=<M> smart=<K>`, and emit with the standard 2-space indent the rest of the footer uses.
   - When `cost_rates:` is present, optionally append `savings: <USD>` to the line (T02 documents the chosen shape). When `cost_rates:` is absent, the line carries only the per-tier counts.
   - **Suppression on no-shadow-on-records**: when the rollup output's per-tier line shows `0 dispatches: 0 fast / 0 balanced / 0 smart` (the corpus has zero shadow-on records — every dispatch_usage record lacks a `model_routed` field), the `model_mix:` line is suppressed entirely. This is the SC-11 byte-equality preservation mechanism — pre-M030 fixtures emit zero new bytes through the footer.
   - Same config knob discipline as the compression line: `ORCH_MODEL_MIX_FOOTER` env var / `model_routing.efficiency_footer.enabled` config (recommended) gates the line independently of the parent footer suppressor; the footer `--quiet` flag still wins.

3. **Co-authored verifiers** (all under `tools/verify/`):
   - `p05-by-model-dispatch-counts.sh` — invokes the rollup against the live-routed corpus and asserts the per-tier dispatch-count line is present with the expected exact integer counts (fixture-known: 14 fast / 7 balanced / 2 smart over 23 records).
   - `p05-by-model-cost-rates-present.sh` — invokes the rollup with the shipped `templates/model-routing.yml` and asserts both the aggregated-cost-line and counterfactual-cost-line are present with the documented label tokens. Hand-computed expected USD values asserted to 8-decimal precision.
   - `p05-by-model-cost-rates-absent.sh` — invokes the rollup with `M030_ROUTING_TABLE_PATH=tests/fixtures/m030-p05/no-cost-rates-routing.yml` and asserts the `cost rates not configured` warning line + the zero-savings line. Exit 0.
   - `p05-model-mix-footer-line.sh` — invokes the footer against the live-routed corpus (via an `ORCHESTRATOR_ROOT=tmp_root` carve-out where `tmp_root/milestones/M999/execution-log.jsonl` IS the fixture corpus, mirroring the P02 round-trip pattern) and asserts the `model_mix: fast=<N> balanced=<M> smart=<K>` line is emitted with the expected counts.

4. **`references/model-routing.md` amendment** — add `## Cost Rollup Surfaces` section documenting the `--by-model` output shape, the cost_rates-absent fallback, the `model_mix:` line shape, and the operator obligation to update `cost_rates:` when provider pricing changes. T02 commits this in the same diff that lands the rollup + footer amendments.

5. **Re-run T01's gates** post-amendment to confirm the byte-equality contract holds:
   - `bash tools/verify/p05-sc11-rollup-byte-equality.sh` — must continue to pass (unflagged rollup output unchanged).
   - `bash tools/verify/p05-sc11-footer-byte-equality.sh` — must continue to pass (footer output against pre-M030 corpus unchanged because the model_mix: line is suppressed when no shadow-on records present).

T02 ends green when all six new T02 verifiers (the four scenario-specific gates above + the two SC-11 gates carried over from T01) pass on a clean checkout.

### T03: P05 phase-suite aggregator + recent-changes dual-write + commit

See tasks/T03-phase-suite-and-close-PLAN.md.

T03 closes P05 with three deliverables:

1. **`tools/verify/p05-phase-suite.sh`** — straight-line aggregator over all seven P05 sub-gates (by-model-dispatch-counts + by-model-cost-rates-present + by-model-cost-rates-absent + model-mix-footer-line + sc11-rollup-byte-equality + sc11-footer-byte-equality + doctor-config-check). Same straight-line shape as `p02-phase-suite.sh` / `p03-phase-suite.sh` / `p04-phase-suite.sh` — literal `bash <path>` invocations + per-gate rc capture + pass/fail accumulators + SUMMARY line. Exit 0 iff `fail == 0`.

2. **CLAUDE.md + AGENTS.md recent-changes dual-write** via `scripts/util/dual-write-runtime-md.sh --append-entry` with the standard single-line P05-close entry summarizing the rollup `--by-model` flag + footer `model_mix:` line + SC-11 byte-equality preservation + doctor-config-check wrapper deliverables.

3. **Stage + commit P05 close** as a single coherent commit covering the phase-suite verifier, the CLAUDE.md+AGENTS.md edits, and any plan-side amendments needed to satisfy `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05`. Plan-amendments-not-task-reopen pattern (per P02/T04 + P03/T04 + P04/T04 precedent) when the must-haves grep fails on artifact-grep or key-link-direction. Use `git commit -F /tmp/p05-t03-commit-msg.txt` (multi-line message; AP-008 heredoc-with-expansion forbids the inline-HEREDOC form).

After T03 commits, P05 is closed and the orchestrator state machine transitions to `summarized` for P05 (phase-summary still authored by `orchestrator:verify` + `orchestrator:consolidate` downstream).

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03
```

Strict linear chain. T01 ships the fixture corpus + cost-rates-absent routing-table copy + golden baselines + SC-11 gates + doctor wrapper BEFORE T02 amends `metrics-rollup.sh` + `efficiency-footer.sh`, so the byte-equality contract has a mechanical gate at the moment the diff lands. T02 ships the rollup + footer amendments + co-authored scenario-specific verifiers + references/model-routing.md doc amendment. T03 closes the phase with the suite + commit.

T01 and T02 cannot be parallelized: T01 IS the SC-11 gate that T02 must continue to pass; the goldens must be captured pre-amendment. T02 and T03 cannot be parallelized: T03's phase-suite invokes T02's verifiers.

T02 deliberately combines the rollup `--by-model` flag and the footer `model_mix:` line into a single task because (a) they share the same fixture corpus, (b) the footer reads rollup output internally so the dependency would force T02-rollup → T02-footer sequencing anyway, (c) cost_rates-present / cost_rates-absent branch logic is shared, and (d) splitting the rollup and footer changes adds context-bridge cost (re-reading the same files, re-staging the same fixtures) without a clean separation. P05's risk classification is `low` per the roadmap row; one combined T02 fits comfortably in a single context window.

## Files Likely Touched

- scripts/diagnostics/metrics-rollup.sh (modify — add --by-model flag + per-tier aggregation + cost_rates branches; preserve unflagged byte-equality)
- scripts/diagnostics/efficiency-footer.sh (modify — add model_mix: line; preserve byte-equality on no-shadow-on-records)
- references/model-routing.md (modify — add `## Cost Rollup Surfaces` section)
- tests/fixtures/m030-p05/live-routed-corpus.jsonl (create)
- tests/fixtures/m030-p05/no-cost-rates-routing.yml (create)
- tests/fixtures/m030-p05/rollup-pre-m030-baseline.txt (create)
- tests/fixtures/m030-p05/footer-pre-m030-baseline.txt (create)
- tests/fixtures/m030-p05/synthesize-corpus.sh (create)
- tools/verify/p05-by-model-dispatch-counts.sh (create)
- tools/verify/p05-by-model-cost-rates-present.sh (create)
- tools/verify/p05-by-model-cost-rates-absent.sh (create)
- tools/verify/p05-model-mix-footer-line.sh (create)
- tools/verify/p05-sc11-rollup-byte-equality.sh (create)
- tools/verify/p05-sc11-footer-byte-equality.sh (create)
- tools/verify/p05-doctor-config-check.sh (create)
- tools/verify/p05-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify if present — recent-changes region dual-write)

<!-- Phase plan and task plan files (this file + tasks/T0[1-3]-*-PLAN.md)
     are written by the planner, not by the executor — not listed here. -->

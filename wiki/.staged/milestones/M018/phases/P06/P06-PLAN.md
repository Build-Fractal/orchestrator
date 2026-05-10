---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M018"
goal: "Tier 3 auto-compact: LLM-routed section summarization in build-context.sh, intensity-gated, failure-passthrough; payload_breakdown / dispatch_usage / unit_close additive tier3 fields (CON-5); compression-eval.sh --tier 3 cohort logic replaces P05 stub; RISK-3 gate (no statistically significant outcome-rate regression vs uncompressed cohort) gates P06 close."
demo_sentence: "At Standard intensity, an oversized section gets routed through `dispatch-interface.sh` with `templates/compression-tier3-prompt.md`; the original persists to `.orchestrator/cache/tier3-originals/`; `tier3_compression_savings_tokens` and `tier3_invocations` appear in `payload_breakdown`. An LLM-call failure passes Tier 2's output through unchanged and emits a `tier3_failed` JSONL record (never crashes the dispatch). T3's `unit_close: pass` is gated by `compression-eval.sh` showing no statistically significant outcome-rate regression vs the uncompressed cohort."
risk: "high"
depends_on: ["P05"]
---

## Boundary Map

**Produces:**
- T3 implementation in `scripts/dispatch/build-context.sh` (`_bc_apply_tier3` — `dispatch-interface.sh`-routed summarization with intensity gate, failure-passthrough, MIT-08 density pre-check, in-band marker emit, originals persistence).
- `templates/compression-tier3-prompt.md` (new) — summarization prompt template.
- `.orchestrator/cache/tier3-originals/` directory tree (lazily created at first T3 fire).
- Additive `tier3_compression_savings_tokens` + `tier3_invocations` fields on `payload_breakdown` (CON-5); same fields rolled-up onto `dispatch_usage` (co-located emit) and `unit_close` (granularity-aware rollup) following the P05 schema-extension pattern.
- Additive `tier3_failed` + `tier3_skipped` JSONL record schemas (additive — pre-M018 readers ignore unknown record_type values).
- Intensity-gate wiring in `build-context.sh` (Quick skips T3; Standard / Full enable T3 gated on `compression.tier3.intensity_floor`).
- `compression-eval.sh` `--tier 3` real cohort logic (replaces the P05 reservation stub).
- Four P06-private truth verifiers under `scripts/verify/m018-p06-*.sh`.
- Two fixture trees under `tests/fixtures/m018-p06-{tier3-fired,tier3-failed}/`.
- One fixture-staging helper under `scripts/verify/_helpers/m018-p06-build-fixture.sh`.
- `P06-SUMMARY.md` (via `bash scripts/lifecycle/phase-transition.sh --write`).
- CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write for M018/P06.

**Consumes:**
- `references/compression-grammar.md` Tier 3 rules (P01).
- `scripts/dispatch/dispatch-interface.sh` (DEP-7) — Tier 3 summarization routes through this for runtime portability (FR-13).
- `scripts/engine/intensity-gate.sh` (DEP-5) — resolves `intensity_floor` gate (FR-14).
- `scripts/util/cache-prune.sh` (P03) — prune retention surface; tier3-originals/ co-tenants are already untouched by the single-level walk shopt-glob.
- `scripts/diagnostics/compression-eval.sh` (P05) — extends the `--tier 3` recognized-but-no-op stub into a real cohort against `tier3_compression_savings_tokens`.
- `scripts/dispatch/build-context.sh` `_bc_apply_tier1` / `_bc_apply_tier2` (P03/P04) — the tier3 helper installs after `_bc_apply_tier2` and before `_bc_emit_payload_breakdown`, mirroring the existing tier1→tier2 wiring.
- `scripts/lib/knowledge-filter.sh` `kf_get_*` config helpers (P02/P03/P04 pattern) — extends with `kf_get_tier3_*` accessors (`enabled`, `intensity_floor`, `section_budget_tokens`, `originals_dir`, `output_max_ratio`, `density_floor`).
- `scripts/lib/preservation-check.sh` `pres_check_section` / `pres_emit_violation` (P02) — Tier 3 uses these for post-summarization preservation self-check (FR-2).
- `scripts/dispatch/dispatch-interface.sh` `_di_emit_dispatch_usage` (P05/T01) — extends with `tier3_compression_savings_tokens` + `tier3_invocations` rollup from in-flight payload_breakdown rows.
- `scripts/knowledge/write-summary.sh` `_ws_emit_unit_close` (P05/T01) — extends with the same two additive fields under granularity-aware rollup.
- `scripts/diagnostics/metrics-rollup.sh` (P05/T02) — extends column projection with `TIER3_SAVINGS` + `TIER3_INVOCS` (appended after the four P05 columns to preserve column-index contract).
- `scripts/diagnostics/efficiency-footer.sh` (P05/T02) — compression-line denominator already covers tier-totals via additive sum; extends to fold tier3_savings into the percent.
- `scripts/diagnostics/check-anomalies.sh` (P05/T02) — compression-regression flag composes additively with tier3 once tier3 ships (no new reasons; tier3_savings folds into sav_total denominator).

## Must-Haves

### Truths

<!-- Every truth's Check is a single-script-file invocation per AD-19.
     bash -n self-checks are used as a fallback when the canonical
     verifier ships in T04 (the closing task), so each task always has
     at least one extractable Check at task-plan parse time. -->

- The `_bc_apply_tier3` helper exists in `scripts/dispatch/build-context.sh` and routes summarization through `dispatch-interface.sh` with `templates/compression-tier3-prompt.md`.
  - Check: `bash scripts/verify/m018-p06-tier3-helper-shape.sh`
- `templates/compression-tier3-prompt.md` exists with a versioned frontmatter and a body that names input contract (section header + body bytes) and output contract (in-band marker + summary body).
  - Check: `bash scripts/verify/m018-p06-tier3-prompt-template.sh`
- `payload_breakdown` records carry additive `tier3_compression_savings_tokens` and `tier3_invocations` integer fields; `dispatch_usage` and `unit_close` records carry the same two fields rolled up from in-scope `payload_breakdown` rows; pre-M018 records remain valid JSON (CON-5 absent-as-zero).
  - Check: `bash scripts/verify/m018-p06-tier3-additivity.sh`
- `compression-eval.sh --tier 3` replaces the P05 reservation stub with real cohort logic against `tier3_compression_savings_tokens`; reports per-cohort + delta means with 95% CIs; emits `regression_flag:` advisory; below-floor emits `insufficient sample` and exits 0; sourceable + CLI shape preserved (FR-12 always-exit-0; AD-19 single-script-file Check shape).
  - Check: `bash scripts/verify/m018-p06-compression-eval-tier3.sh`
- CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name "M018/P06" and "tier3" / "compression-tier3-prompt".
  - Check: `bash scripts/verify/m018-p06-dual-write-recent.sh`

<!-- Tier-3 behavioral truths (non-mechanical; verified manually at
     phase-transition time per gate RISK-3): -->

- **RISK-3 gate** (Tier 3 behavior): `compression-eval.sh --milestone M018 --tier 3` shows no statistically significant outcome-rate regression vs the uncompressed cohort before P06 marks `unit_close: pass`. (No mechanical Check — the gate is a phase-close manual review of the compression-eval report; below-sample-floor counts as a non-regression for P06 close because the diagnostic exits with `insufficient sample`. The truth is declared "behavioral" per the Truths-without-Check carve-out in `commands/plan-phase.md` Gotchas.)

### Artifacts

- `scripts/dispatch/build-context.sh` (min 2100 lines, contains "_bc_apply_tier3")
- `templates/compression-tier3-prompt.md` (min 25 lines, contains "compressed:tier3")
- `scripts/verify/m018-p06-tier3-helper-shape.sh` (min 20 lines, contains "_bc_apply_tier3")
- `scripts/verify/m018-p06-tier3-prompt-template.sh` (min 15 lines, contains "compression-tier3-prompt.md")
- `scripts/verify/m018-p06-tier3-additivity.sh` (min 30 lines, contains "tier3_compression_savings_tokens")
- `scripts/verify/m018-p06-compression-eval-tier3.sh` (min 30 lines, contains "--tier 3")
- `scripts/verify/m018-p06-dual-write-recent.sh` (min 10 lines, contains "M018/P06")
- `scripts/verify/_helpers/m018-p06-build-fixture.sh` (min 30 lines, contains "execution-log.jsonl")
- `tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl` (min 10 lines, contains "tier3_compression_savings_tokens")
- `tests/fixtures/m018-p06-tier3-failed-log/execution-log.jsonl` (min 5 lines, contains "tier3_failed")
- [`.orchestrator/milestones/M018/phases/P06/P06-SUMMARY.md`](../../../../milestones/M018/phases/P06/P06-SUMMARY.md) (min 50 lines, contains "tier3")

### Key Links

- `scripts/dispatch/build-context.sh` → `templates/compression-tier3-prompt.md` (T3 helper sources the prompt)
- `scripts/dispatch/build-context.sh` → `scripts/dispatch/dispatch-interface.sh` (T3 routes summarization through it)
- `scripts/dispatch/build-context.sh` → `scripts/engine/intensity-gate.sh` (T3 honors intensity_floor)
- `scripts/diagnostics/compression-eval.sh` → `scripts/dispatch/build-context.sh` (compression-eval reads tier3_compression_savings_tokens written by build-context)
- `scripts/dispatch/dispatch-interface.sh` → `scripts/dispatch/build-context.sh` (dispatch_usage rollup reads tier3 fields the payload_breakdown emitter wrote)
- `scripts/knowledge/write-summary.sh` → `scripts/dispatch/build-context.sh` (unit_close rollup reads tier3 fields the payload_breakdown emitter wrote)
- `CLAUDE.md` → `compression-tier3-prompt.md` (recent-changes dual-write names the new template)
- `AGENTS.md` → `compression-tier3-prompt.md` (recent-changes dual-write names the new template)

## Tasks

### T01: Tier 3 helper in build-context.sh + prompt template + intensity gate + failure-passthrough

See [`.orchestrator/milestones/M018/phases/P06/tasks/T01-tier3-helper-PLAN.md`](../../../../milestones/M018/phases/P06/tasks/T01-tier3-helper-PLAN.md).

### T02: Schema extensions — additive `tier3_compression_savings_tokens` + `tier3_invocations` on payload_breakdown / dispatch_usage / unit_close + new `tier3_failed` / `tier3_skipped` records

See [`.orchestrator/milestones/M018/phases/P06/tasks/T02-schema-extensions-PLAN.md`](../../../../milestones/M018/phases/P06/tasks/T02-schema-extensions-PLAN.md).

### T03: compression-eval.sh `--tier 3` real cohort logic replaces P05 stub

See [`.orchestrator/milestones/M018/phases/P06/tasks/T03-compression-eval-tier3-PLAN.md`](../../../../milestones/M018/phases/P06/tasks/T03-compression-eval-tier3-PLAN.md).

### T04: Verifiers + fixtures + helper + P06-SUMMARY (via phase-transition.sh --write) + dual-write

See [`.orchestrator/milestones/M018/phases/P06/tasks/T04-verifiers-and-summary-PLAN.md`](../../../../milestones/M018/phases/P06/tasks/T04-verifiers-and-summary-PLAN.md).

## Task Dependencies

```
T01 ──┐
      ├─→ T03 ─→ T04
T02 ──┘
```

- T01 (helper + template) and T02 (schema fields) are mechanically independent (T01 writes the helper; T02 widens the JSONL emitter shape). Both must land before T03 reads the new field, and before T04 verifies the joined behavior. Either ordering of T01 / T02 works; the canonical execution order in this plan is T01 → T02 → T03 → T04 to mirror the P05 ordering and to give T02 the option to inspect T01's stats-file shape.
- T03 (compression-eval `--tier 3` cohort) depends on T02 (the field T03 cohort-classifies on must exist in the JSONL emitter shape).
- T04 (verifiers + summary) depends on T01 + T02 + T03; the eight-truth verifier fan-out exercises every prior task's surface.

## Files Likely Touched

- scripts/dispatch/build-context.sh (modify) — add `_bc_apply_tier3` helper, extend `_bc_emit_payload_breakdown` with the two additive fields, wire intensity-gate + failure-passthrough.
- scripts/lib/knowledge-filter.sh (modify) — add `kf_get_tier3_*` config accessors.
- scripts/dispatch/dispatch-interface.sh (modify) — extend `_di_emit_dispatch_usage` with tier3 rollup.
- scripts/knowledge/write-summary.sh (modify) — extend `_ws_emit_unit_close` with tier3 rollup (granularity-aware).
- scripts/diagnostics/metrics-rollup.sh (modify) — append `TIER3_SAVINGS` + `TIER3_INVOCS` columns after the four P05 columns.
- scripts/diagnostics/efficiency-footer.sh (modify) — fold tier3_savings into the compression-line numerator.
- scripts/diagnostics/check-anomalies.sh (modify) — fold tier3_savings into sav_total denominator.
- scripts/diagnostics/compression-eval.sh (modify) — replace `--tier 3` reservation stub with real cohort logic.
- templates/compression-tier3-prompt.md (create).
- scripts/verify/m018-p06-tier3-helper-shape.sh (create).
- scripts/verify/m018-p06-tier3-prompt-template.sh (create).
- scripts/verify/m018-p06-tier3-additivity.sh (create).
- scripts/verify/m018-p06-compression-eval-tier3.sh (create).
- scripts/verify/m018-p06-dual-write-recent.sh (create).
- scripts/verify/_helpers/m018-p06-build-fixture.sh (create).
- tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl (create).
- tests/fixtures/m018-p06-tier3-fired-log/README.md (create).
- tests/fixtures/m018-p06-tier3-failed-log/execution-log.jsonl (create).
- tests/fixtures/m018-p06-tier3-failed-log/README.md (create).
- [.orchestrator/milestones/M018/phases/P06/P06-SUMMARY.md](../../../../milestones/M018/phases/P06/P06-SUMMARY.md) (create).
- CLAUDE.md (modify) — `orchestrator:recent-changes` block.
- AGENTS.md (modify) — `orchestrator:recent-changes` block (dual-write mirror).

## Notes

- **AD-19 / AP-009 single-script-file Check shape**: every truth's Check is a single bash invocation. Verifier scripts use pass()/fail() per MEM002 and printf-prefixed lines per MEM001. The four canonical verifiers ship in T04; T01-T03 each carry a `bash -n` self-check as their task-local extractable Check (the auto-loop verify parser refuses zero-Check plans).
- **MEM004 emitter-internal carve-out**: applies inside `_bc_apply_tier3`, `_bc_emit_payload_breakdown`, `_di_emit_dispatch_usage`, `_ws_emit_unit_close`, `metrics-rollup.sh`, and `compression-eval.sh` bodies (single-pass awk + pipes permitted). The AD-19 single-script-file shape rule applies only to Check: lines at task / phase plan level.
- **CON-5 (additive emitters)**: `tier3_compression_savings_tokens` + `tier3_invocations` are additive integer fields on `payload_breakdown`, `dispatch_usage`, `unit_close`. Pre-P06 records remain valid JSON; downstream consumers (rollup, footer, doctor, compression-eval) treat absent fields as zero.
- **FR-9 (tier3 failure-passthrough)**: an LLM call failure (timeout, rate-limit, error response, dispatch-interface non-zero exit) leaves the Tier 2 output intact and emits a `tier3_failed` JSONL record naming the error reason. Never crashes the dispatch. The `_bc_apply_tier3` helper is bail-safe — every error path returns 0 after writing a stats file with `savings_tokens=0 invocations=0` so the emitter records no false savings.
- **FR-14 (intensity-gating)**: Quick → T3 skipped + `tier3_skipped` JSONL record with `{reason: "intensity=quick"}`. Standard / Full → T3 active. Resolution honors `compression.tier3.intensity_floor` config knob (default `standard`).
- **Edge case (Tier 3 produces a summary larger than the input)**: per spec edge-cases, T3 measures output size and discards summaries that exceed `compression.tier3.output_max_ratio` (default 0.80) of the input size; passes through Tier 2's output instead and emits a `tier3_no_savings` JSONL record. Folds into the FR-9 failure-passthrough path mechanically.
- **MIT-08 density pre-check**: the helper computes a pre-call density estimate (input tokens / output budget); below the configured `compression.tier3.density_floor` (default 1.5) the helper short-circuits and passes Tier 2 output through unchanged. Avoids paying LLM cost on sections that cannot meaningfully compress.
- **Originals persistence**: the original section bytes (post-Tier 2 input to T3) are written to `.orchestrator/cache/tier3-originals/<sha256>.txt` using the same SHA-256 (section-name + 0x1F + body) pattern as Tier 1's tool-result cache. `cache-prune.sh` (P03) does not recurse into sub-directories under cache_dir, so tier3-originals/ co-tenants are untouched by tier1 prune passes; a future T-row will add tier3-originals retention if disk-pressure surfaces.
- **RISK-3 gate**: P06's `unit_close: pass` is gated by `compression-eval.sh --milestone M018 --tier 3` showing no statistically significant outcome-rate regression vs the uncompressed cohort. Below the sample floor, the diagnostic emits `insufficient sample` and exits 0 — that is treated as a non-regression for P06 close (M018 may need additional milestones of telemetry before the regression check has statistical power; the diagnostic stays operational so subsequent milestones close the gap).
- **`phase-transition.sh --write` (NOT `write-summary.sh phase`)**: T04's closing step invokes `bash scripts/lifecycle/phase-transition.sh <milestone-dir> P06 --write --body-file=<path> --observability_surfaces=<text>` so the roadmap and disk transition atomically. P05/T04 wrote the summary directly via `write-summary.sh phase` and triggered `SYNC:MISMATCH` that needed `sync-roadmap.sh --fix`; P06 avoids the regression.
- **Bash 3.2** (MEM001): no `declare -A`, no process substitution, no merged stdout-stderr shorthand. Parallel scalars / indexed arrays only; awk inside helper bodies is permitted by the MEM004 carve-out.
- **No conversus gate at P06** (per CON-6, only P01 grammar contract requires `--strict` conversus). The RISK-3 manual review is the only non-mechanical phase-close gate.

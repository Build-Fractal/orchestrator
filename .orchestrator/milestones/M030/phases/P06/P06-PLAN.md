---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M030"
goal: "Land FR-18 anomaly-driven regression detection — extend `scripts/diagnostics/check-anomalies.sh` with a rolling-window per-class verifier-fail-rate check that emits a `model_routing_regression` anomaly record (text + JSONL) when a class crosses the configured threshold; surface the anomaly through `orchestrator:doctor` per existing M027 conventions; preserve SC-11 byte-equality of every existing anomaly check when no `model_routing_regression` records are present. Pick the threshold default per #Q-4 deferred-to-plan-phase: fixed pass-rate floor (default 0.5, min-class-sample 10), configurable via `.orchestrator/config.yml model_routing_regression.{pass_rate_threshold,min_class_sample}`. Add `character` as an additive field on shadow-on `dispatch_usage` emits so per-class grouping survives operator-overlaid routing tables (additive — SC-11-preserving)."
demo_sentence: "An operator runs five commands. (a) `bash scripts/diagnostics/check-anomalies.sh --milestone M999` against `tests/fixtures/m030-p06/regression-mechanical.jsonl` (20 mechanical-class shadow-on records with engineered pass_rate=0.4 over the rolling window) emits to stdout a line matching `^FLAGGED model_routing_regression class=mechanical class_pass_rate=0\\.40 sample=20 threshold=0\\.50` AND appends a JSONL record `{\"record_type\":\"anomaly\",\"kind\":\"model_routing_regression\",\"class\":\"mechanical\",\"class_pass_rate\":0.4,\"class_sample\":20,\"threshold\":0.5,\"milestone\":\"M999\",\"timestamp\":\"...\"}` to `.orchestrator/anomalies.jsonl` (or the path passed via `M030_ANOMALIES_JSONL_PATH` env). (b) The same command against `tests/fixtures/m030-p06/regression-standard.jsonl` and `tests/fixtures/m030-p06/regression-novel.jsonl` produces equivalent output for `class=standard` and `class=novel`. (c) The same command against `tests/fixtures/m030-p06/no-regression.jsonl` (60 records, all classes pass_rate >= 0.8) emits NO `model_routing_regression` line and appends NO JSONL record. (d) `bash scripts/diagnostics/run-doctor.sh` (full doctor run) against the engineered corpus surfaces the `model_routing_regression class=mechanical` line in its `Anomaly Detection (Tier 1 baseline)` block — the existing doctor surface picks up the new line via the existing `check-anomalies.sh` invocation, no `run-doctor.sh` amendment required. (e) `bash scripts/diagnostics/check-anomalies.sh` against `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (5 records, no `model_used` field, the P02 graduation fixture) emits stdout byte-identical to a pre-amendment golden captured at T01. (f) `bash tools/verify/p06-phase-suite.sh` emits `SUMMARY: p06-phase-suite.sh pass=N fail=0` with N>=8 and exits 0."
risk: "low"
depends_on: ["P02", "P04"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p06-*) so install-clobber risk is contained
     (M032 Finding A discipline).

     P06 is low-risk and surface-extending: one additive field on
     dispatch-interface.sh + one rolling-window check on check-anomalies.sh
     + a JSONL emit + a docs amendment. Three tasks total:
       T01 — fixtures + golden baseline + pre-amendment-tolerant SC-11 gate
             (mirrors P02/T01, P03/T01, P04/T01, P05/T01 graduation pattern).
       T02 — dispatch-interface.sh character-emit + check-anomalies.sh
             rolling-window check + JSONL emit + co-authored verifiers
             + references/model-routing.md amendment + SC-11 confirmation.
       T03 — phase-suite aggregator + recent-changes dual-write + commit.

     T02 deliberately combines the dispatch-interface character emit with
     the check-anomalies amendment because they ship as a coupled pair —
     the new field is the input the new check consumes; splitting them
     creates a fragile intermediate state where the field is emitted but
     no consumer reads it (and SC-11 still has to hold across the split).
     T03 is a thin close. -->

### Truths

- `bash scripts/diagnostics/check-anomalies.sh --milestone M999` against `tests/fixtures/m030-p06/regression-mechanical.jsonl` (20 shadow-on records with `character=mechanical` and engineered `escalation_count` distribution producing class_pass_rate=0.4) emits to stdout a line matching `^FLAGGED model_routing_regression class=mechanical class_pass_rate=0\.40 sample=20 threshold=0\.50` AND appends exactly one record `{"record_type":"anomaly","kind":"model_routing_regression","class":"mechanical",...}` to the path given by `M030_ANOMALIES_JSONL_PATH` env (default `.orchestrator/anomalies.jsonl`). Exit 0. The verifier injects a tmp `M030_ANOMALIES_JSONL_PATH` so the project's real anomalies log is never touched. (FR-18, US-6 AS-1.)
  - Check: `bash tools/verify/p06-mechanical-regression.sh`

- The same command against `tests/fixtures/m030-p06/regression-standard.jsonl` (20 records `character=standard`, engineered class_pass_rate=0.4) emits the equivalent stdout line with `class=standard` and appends the equivalent JSONL record with `"class":"standard"`. Exit 0. (FR-18, US-6 AS-1.)
  - Check: `bash tools/verify/p06-standard-regression.sh`

- The same command against `tests/fixtures/m030-p06/regression-novel.jsonl` (20 records `character=novel`, engineered class_pass_rate=0.4) emits the equivalent stdout line with `class=novel` and appends the equivalent JSONL record with `"class":"novel"`. Exit 0. (FR-18, US-6 AS-1.)
  - Check: `bash tools/verify/p06-novel-regression.sh`

- `bash scripts/diagnostics/check-anomalies.sh --milestone M999` against `tests/fixtures/m030-p06/no-regression.jsonl` (60 records, 20 per class, all classes class_pass_rate >= 0.8) emits NO line matching `model_routing_regression` and appends NO record matching `"kind":"model_routing_regression"` to the JSONL emit path. Exit 0. The existing legacy anomaly text-block (`FLAGGED <scope> ... reasons=<csv>` lines from M027/P03) is unaffected. (FR-18 negative case.)
  - Check: `bash tools/verify/p06-no-regression.sh`

- `bash scripts/diagnostics/check-anomalies.sh --milestone M999` against `tests/fixtures/m030-p06/below-min-sample.jsonl` (5 mechanical records with class_pass_rate=0.4 — below the min_class_sample=10 floor) emits NO `model_routing_regression` line and appends NO JSONL record. The class is silently skipped because the rolling-window sample size is below the configured floor. Exit 0. (FR-18 sample-floor guard, mirrors existing `insufficient sample` pattern from M027/P03.)
  - Check: `bash tools/verify/p06-below-min-sample.sh`

- `bash scripts/diagnostics/run-doctor.sh --root <staged-root>` against an engineered ORCHESTRATOR_ROOT carve-out (`tmp_root/milestones/M999/execution-log.jsonl` = `tests/fixtures/m030-p06/regression-mechanical.jsonl`) surfaces the `model_routing_regression class=mechanical` line in its `Anomaly Detection (Tier 1 baseline)` advisory block. The doctor surfaces the new line because `run-doctor.sh` already invokes `check-anomalies.sh` (line 156-158 of `scripts/diagnostics/run-doctor.sh`) and renders its stdout — no `run-doctor.sh` amendment required. Exit code follows existing doctor semantics (advisory; never blocks). (Acceptance roadmap line 57: "the anomaly surfaces through `orchestrator:doctor` per existing M027 conventions".)
  - Check: `bash tools/verify/p06-doctor-surfaces-anomaly.sh`

- SC-11 byte-equality through `check-anomalies.sh`: against the pre-M030 fixture at `tests/fixtures/m030-p02/pre-m030-dispatch-usage.jsonl` (5 records, no `model_used` field, no `character` field — the P02 graduation fixture), running `bash scripts/diagnostics/check-anomalies.sh --milestone M001 --root <staged-root>` emits stdout byte-identical to a pre-amendment golden captured at T01 (HEAD-baseline shape). The verifier compares post-amendment stdout against `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt`. (CON-2 / FR-19 / SC-11. Mirrors P05's `p05-sc11-rollup-byte-equality.sh` shape.)
  - Check: `bash tools/verify/p06-sc11-byte-equality.sh`

- SC-11 byte-equality through unflagged dispatch-interface.sh shadow-OFF emit path: against the P02 round-trip stage, running the dispatch-interface emit branch with `M030_SHADOW_MODE=0` produces a `dispatch_usage` JSONL line byte-identical to its pre-T02 HEAD output. The new `character` field MUST be emitted ONLY on the shadow-on branch (gated by `M030_SHADOW_MODE=1 && CLAUDECODE=1`). The shadow-off printf format is byte-untouched. Verifier reuses the P02 round-trip stage at `tests/fixtures/m030-p02/round-trip-stage/` and the existing `tools/verify/p02-additive-schema.sh` shape — P06's gate is a thin pass-through that re-runs P02's SC-11 byte-equality contract post-T02 amendment. (CON-2 / FR-19 / SC-11.)
  - Check: `bash tools/verify/p06-shadow-off-byte-equality.sh`

- `bash tools/verify/p06-phase-suite.sh` invokes all eight P06 sub-gates (mechanical-regression, standard-regression, novel-regression, no-regression, below-min-sample, doctor-surfaces-anomaly, sc11-byte-equality, shadow-off-byte-equality) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p06-phase-suite.sh pass=N fail=M` on a single line before exit. Same straight-line shape as `p02-phase-suite.sh` / `p03-phase-suite.sh` / `p04-phase-suite.sh` / `p05-phase-suite.sh`. (Phase-close aggregator.)
  - Check: `bash tools/verify/p06-phase-suite.sh`

### Artifacts

- tests/fixtures/m030-p06/synthesize-corpus.sh (min 60 lines, contains "regression-mechanical.jsonl", contains "regression-standard.jsonl", contains "regression-novel.jsonl", contains "no-regression.jsonl", contains "below-min-sample.jsonl", contains "character", contains "escalation_count") — create
- tests/fixtures/m030-p06/regression-mechanical.jsonl (min 20 lines, contains "character", contains "mechanical", contains "escalation_count") — create
- tests/fixtures/m030-p06/regression-standard.jsonl (min 20 lines, contains "character", contains "standard", contains "escalation_count") — create
- tests/fixtures/m030-p06/regression-novel.jsonl (min 20 lines, contains "character", contains "novel", contains "escalation_count") — create
- tests/fixtures/m030-p06/no-regression.jsonl (min 60 lines, contains "character", contains "mechanical", contains "standard", contains "novel") — create
- tests/fixtures/m030-p06/below-min-sample.jsonl (min 5 lines, contains "character", contains "mechanical") — create
- tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt (min 1 lines) — create
- scripts/dispatch/dispatch-interface.sh (modify — additive `character=` field on the shadow-on emit branch only; shadow-off branch byte-untouched) — modify
- scripts/diagnostics/check-anomalies.sh (modify — add per-class verifier-fail-rate check + JSONL emit + stdout text-render line; preserve unchanged output when no `model_routing_regression` fires) — modify
- references/model-routing.md (modify — add `## Anomaly Records` section documenting the `model_routing_regression` record shape, threshold defaults, JSONL emit path, and doctor surfacing) — modify
- tools/verify/p06-mechanical-regression.sh (min 60 lines, contains "regression-mechanical.jsonl", contains "model_routing_regression", contains "class=mechanical", contains "SUMMARY:") — create
- tools/verify/p06-standard-regression.sh (min 50 lines, contains "regression-standard.jsonl", contains "model_routing_regression", contains "class=standard", contains "SUMMARY:") — create
- tools/verify/p06-novel-regression.sh (min 50 lines, contains "regression-novel.jsonl", contains "model_routing_regression", contains "class=novel", contains "SUMMARY:") — create
- tools/verify/p06-no-regression.sh (min 50 lines, contains "no-regression.jsonl", contains "model_routing_regression", contains "SUMMARY:") — create
- tools/verify/p06-below-min-sample.sh (min 50 lines, contains "below-min-sample.jsonl", contains "min_class_sample", contains "SUMMARY:") — create
- tools/verify/p06-doctor-surfaces-anomaly.sh (min 60 lines, contains "run-doctor.sh", contains "model_routing_regression", contains "Anomaly Detection", contains "SUMMARY:") — create
- tools/verify/p06-sc11-byte-equality.sh (min 50 lines, contains "pre-m030-dispatch-usage.jsonl", contains "check-anomalies-pre-m030-baseline.txt", contains "diff", contains "SUMMARY:") — create
- tools/verify/p06-shadow-off-byte-equality.sh (min 25 lines, contains "p02-additive-schema.sh", contains "SUMMARY:") — create
- tools/verify/p06-phase-suite.sh (min 80 lines, contains "p06-mechanical-regression", contains "p06-standard-regression", contains "p06-novel-regression", contains "p06-no-regression", contains "p06-below-min-sample", contains "p06-doctor-surfaces-anomaly", contains "p06-sc11-byte-equality", contains "p06-shadow-off-byte-equality", contains "SUMMARY:") — create
- CLAUDE.md (modify — recent-changes region) — modify
- AGENTS.md (modify — recent-changes region) — modify

### Key Links

- specs/032-adaptive-model-selection/spec.md → scripts/diagnostics/check-anomalies.sh (FR-18 anomaly-detection-extension; US-6 AS-1; spec line 150)
- specs/032-adaptive-model-selection/spec.md → scripts/dispatch/dispatch-interface.sh (FR-19 jsonl-schema-additive — `character` field added to shadow-on emit; spec line 151)
- .orchestrator/milestones/M030/M030-CONTEXT.md → references/model-routing.md (D-A9 anomaly-JSONL snapshot convention documented; spec amendment 9; #Q-4 threshold-default decision)
- references/model-routing.md → scripts/diagnostics/check-anomalies.sh (Anomaly Records section documents the `model_routing_regression` record shape and operator threshold-tuning obligation)
- .orchestrator/milestones/M030/phases/P02/P02-SUMMARY.md → scripts/dispatch/dispatch-interface.sh (P02 established the shadow-on emit branch; P06 extends it additively)
- .orchestrator/milestones/M030/phases/P04/P04-SUMMARY.md → scripts/dispatch/dispatch-interface.sh (P04 established `escalation_count` + `escalation_reason` fields P06 consumes for the verifier-fail signal)

## Tasks

### T01: P06 fixtures + golden baseline + SC-11 gates (preflight)

See `.orchestrator/milestones/M030/phases/P06/tasks/T01-fixtures-and-baseline-PLAN.md`.

### T02: dispatch-interface character emit + check-anomalies amendment + co-authored verifiers + references doc

See `.orchestrator/milestones/M030/phases/P06/tasks/T02-anomaly-check-and-emit-PLAN.md`.

### T03: phase-suite aggregator + recent-changes dual-write + close

See `.orchestrator/milestones/M030/phases/P06/tasks/T03-phase-suite-and-close-PLAN.md`.

## Task Dependencies

T01 → T02 → T03 (linear chain — same shape as P02, P03, P04, P05).

T01 ships preflight scaffolding (fixtures + goldens + SC-11 gate). T02 amends `dispatch-interface.sh` shadow-on emit + `check-anomalies.sh` and authors the regression verifiers. T03 ships the phase-suite aggregator + close.

## Files Likely Touched

- tests/fixtures/m030-p06/synthesize-corpus.sh (create)
- tests/fixtures/m030-p06/regression-mechanical.jsonl (create)
- tests/fixtures/m030-p06/regression-standard.jsonl (create)
- tests/fixtures/m030-p06/regression-novel.jsonl (create)
- tests/fixtures/m030-p06/no-regression.jsonl (create)
- tests/fixtures/m030-p06/below-min-sample.jsonl (create)
- tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt (create)
- scripts/dispatch/dispatch-interface.sh (modify — additive `character=` field on shadow-on emit branch only)
- scripts/diagnostics/check-anomalies.sh (modify — add `_ca_model_routing_regression_check` function + integrate into CLI dispatch path; preserve byte-equality on no-regression input)
- references/model-routing.md (modify — append `## Anomaly Records` section)
- tools/verify/p06-mechanical-regression.sh (create)
- tools/verify/p06-standard-regression.sh (create)
- tools/verify/p06-novel-regression.sh (create)
- tools/verify/p06-no-regression.sh (create)
- tools/verify/p06-below-min-sample.sh (create)
- tools/verify/p06-doctor-surfaces-anomaly.sh (create)
- tools/verify/p06-sc11-byte-equality.sh (create)
- tools/verify/p06-shadow-off-byte-equality.sh (create)
- tools/verify/p06-phase-suite.sh (create)
- CLAUDE.md (modify — recent-changes region)
- AGENTS.md (modify — recent-changes region)
- .orchestrator/milestones/M030/phases/P06/P06-SUMMARY.md (create — T03 close artifact)
- .orchestrator/milestones/M030/execution-log.jsonl (modify — phase-grain unit_close append at T03 close)

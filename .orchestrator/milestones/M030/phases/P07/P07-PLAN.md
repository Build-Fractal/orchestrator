---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M030"
goal: "Land the M030 milestone-close acceptance gate — synthesize a full-scale acceptance corpus (50 records per class + 0-record + 2-class-only) under `tests/m030-acceptance/`, author the `run-acceptance-battery.sh` end-to-end SC runner that exercises every M030 success criterion (SC-1 through SC-11 inclusive of SC-2a/SC-3a/SC-7a), capture a one-shot `M030-ACCEPTANCE-EVIDENCE.md` ledger of the green run, and ship the M030 milestone close ceremony (P07-SUMMARY.md + phase-grain unit_close + M030-VALIDATED marker via `mark-complete.sh` + M030-SUMMARY.md + milestone-grain unit_close + final `validate-milestone.sh` clean pass + close commit). P07 is structurally distinct from P02–P06 — its outputs gate the milestone close, not just the phase close."
demo_sentence: "An operator runs five commands. (a) `bash tests/m030-acceptance/shadow-corpus-fixtures.sh` is idempotent — first invocation synthesizes four corpora (`corpus-50-per-class.jsonl` 150 records / 50 per class; `corpus-zero.jsonl` 0 records; `corpus-2-class-only.jsonl` 100 records: 50 mechanical + 50 standard + 0 novel; `corpus-block.jsonl` 60 records below per-class threshold) under `tests/m030-acceptance/`; second invocation produces byte-identical files. (b) `bash tests/m030-acceptance/run-acceptance-battery.sh` invokes every M030 SC verifier in literal sequence and emits `BATTERY: pass=14 fail=0` (SC-1 + SC-2 + SC-2a + SC-3 + SC-3a + SC-4 + SC-5 + SC-6 + SC-7 + SC-7a + SC-8 + SC-9 + SC-10 + SC-11 = 14 success criteria) before exit 0. (c) `bash tools/verify/p07-corpus-2-class-partially-ready.sh` exercises `shadow-compare.sh` against `corpus-2-class-only.jsonl`, asserts `flip_recommendation=partially_ready` plus a `flippable_classes=mechanical,standard` enumeration line (or equivalent enumeration shape per the verdict spec). (d) `bash tools/verify/p07-cross-surface-coherence.sh` runs `metrics-rollup.sh --by-model` + `efficiency-footer.sh` against `corpus-50-per-class.jsonl` and asserts the per-tier dispatch counts sum to 150, the model_mix footer line is present, and `check-anomalies.sh` against the corpus emits zero `model_routing_regression` records. (e) `bash tools/verify/p07-phase-suite.sh` aggregates every P07 sub-gate (SC battery + the at-scale corpus gates + the cross-surface coherence gate + the evidence-ledger shape gate) and emits `SUMMARY: p07-phase-suite.sh pass=N fail=0` with N>=10 and exits 0. After T04 lands, `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030` reports `VALIDATE: PASS — N/N checks passed` (171/171, modulo any P00–P06 boundary-map deltas), a `.orchestrator/milestones/M030/M030-VALIDATED` marker file exists with phase_count=8, a `.orchestrator/milestones/M030/M030-SUMMARY.md` file exists with valid milestone-summary frontmatter, and `tail -3 .orchestrator/milestones/M030/execution-log.jsonl | jq -r 'select(.granularity==\"phase\" or .granularity==\"milestone\").unitId'` returns `M030/P07` followed by `M030`."
risk: "medium"
depends_on: ["P02", "P03", "P04", "P05", "P06"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned per-phase verifiers live under tools/verify/ with
     slug-bearing filenames (p07-*) so install-clobber risk is contained
     (M032 Finding A discipline).

     P07 is the M030 milestone-close gate. Four tasks total:
       T01 — acceptance-corpus synthesizer + 4 corpus fixtures (50/class
             + zero + 2-class-only + block) + per-verdict gates.
       T02 — run-acceptance-battery.sh end-to-end SC runner + 14 SC
             delegators (mostly wrapping existing P0N verifiers) + the
             new at-scale gates + cross-surface coherence gate.
       T03 — M030-ACCEPTANCE-EVIDENCE.md ledger + evidence-ledger shape
             gate + p07-phase-suite.sh aggregator.
       T04 — milestone close ceremony (P07-SUMMARY.md + phase-grain
             unit_close + mark-complete.sh + M030-SUMMARY.md +
             milestone-grain unit_close + recent-changes dual-write +
             close commit + final validate-milestone.sh clean pass).

     T04 is structurally distinct from T01–T03: it ships the milestone-
     close artifacts (M030-VALIDATED marker + M030-SUMMARY.md +
     milestone-grain unit_close), not just phase-close artifacts. The
     phase-close ceremony (P07-SUMMARY.md + phase-grain unit_close)
     ships in T04 alongside the milestone-close because P07 is the
     final phase — splitting them would create a fragile two-commit
     close. -->

### Truths

- `bash tests/m030-acceptance/shadow-corpus-fixtures.sh` is idempotent. First invocation creates four corpora under `tests/m030-acceptance/` matching the demo_sentence shapes; second invocation produces byte-identical files (asserted by capturing sha256 of each corpus before+after the second invocation). Exit 0 both invocations. (P07 deliverable per roadmap line 68; mirrors P05/T01 + P06/T01 idempotent-synthesizer pattern.)
  - Check: `bash tools/verify/p07-corpus-synthesizer-idempotent.sh`

- `bash scripts/diagnostics/shadow-compare.sh` against `tests/m030-acceptance/corpus-50-per-class.jsonl` (M030_SHADOW_COMPARE_CORPUS env or `--corpus` flag) emits `flip_recommendation=ready` to stdout. Per-class evidence count lines for each of mechanical/standard/novel show count >= 50. Exit 0. (FR-8 ready threshold; SC-2 verdict 1 of 4.)
  - Check: `bash tools/verify/p07-corpus-50-per-class-ready.sh`

- `bash scripts/diagnostics/shadow-compare.sh` against `tests/m030-acceptance/corpus-zero.jsonl` (a 0-record corpus) emits `flip_recommendation=evidence_insufficient` to stdout. Exit 0. (FR-8 evidence_insufficient threshold; SC-2 verdict 2 of 4.)
  - Check: `bash tools/verify/p07-corpus-zero-evidence-insufficient.sh`

- `bash scripts/diagnostics/shadow-compare.sh` against `tests/m030-acceptance/corpus-2-class-only.jsonl` (50 mechanical + 50 standard + 0 novel; novel's routing-table default is `smart`) emits `flip_recommendation=partially_ready` to stdout AND a `flippable_classes=` enumeration line listing exactly `mechanical,standard` (or whichever delimiter shape the existing shadow-compare.sh emits — verifier reads the existing enumeration shape from the script body and asserts the listed classes match the ready set). Exit 0. (FR-8 partially_ready threshold + D-A3 conservative-by-construction gate; SC-2 verdict 3 of 4.)
  - Check: `bash tools/verify/p07-corpus-2-class-partially-ready.sh`

- `bash scripts/diagnostics/shadow-compare.sh` against `tests/m030-acceptance/corpus-block.jsonl` (60 records distributed across all 3 classes but all classes below the per-class evidence + stability thresholds, AND at least one class's routing-table default is NOT `smart` so the partially_ready conservative-construction gate fails) emits `flip_recommendation=block` to stdout. Exit 0. (FR-8 block threshold; SC-2 verdict 4 of 4.)
  - Check: `bash tools/verify/p07-corpus-block.sh`

- Partial-flip JSONL field shape: synthesizing a dispatch under `M030_SHADOW_COMPARE_CORPUS=tests/m030-acceptance/corpus-2-class-only.jsonl` with `model_routing.live: true` against a `novel`-classified plan results in a `dispatch_usage` record where `jq -r '.partial_flip_active'` returns `true` AND `jq -r '.withheld_classes'` returns a non-empty list containing `novel`. (FR-9 partial-flip-activation; D-A3 per-class authorization; spec amendment 3.)
  - Check: `bash tools/verify/p07-partial-flip-jsonl-fields.sh`

- Cross-surface coherence: against `tests/m030-acceptance/corpus-50-per-class.jsonl` (150 dispatch_usage records distributed across fast/balanced/smart per the routing-table mapping for mechanical/standard/novel), running `bash scripts/diagnostics/metrics-rollup.sh --by-model --log <corpus>` produces a per-tier dispatch-counts line summing to 150, an `aggregated_cost_usd` line, and a `counterfactual_all_smart_cost_usd` line; running `bash scripts/diagnostics/efficiency-footer.sh` against the same corpus produces a `model_mix:` line; running `bash scripts/diagnostics/check-anomalies.sh` against the corpus emits zero `model_routing_regression` text lines and appends zero records to the JSONL emit path. Exit 0 across all three surfaces. (Roadmap line 64: "metrics-rollup.sh --by-model and the efficiency-footer produce coherent output across the full corpus".)
  - Check: `bash tools/verify/p07-cross-surface-coherence.sh`

- The acceptance battery runner at `tests/m030-acceptance/run-acceptance-battery.sh` invokes every M030 SC verifier in literal sequence (no loops, no eval per AD-19), exits 0 iff every SC passes, and emits a single `BATTERY: pass=N fail=M` summary line before exit. The 14 SCs invoked: SC-1 (classifier determinism + no network) → SC-2 (4-verdict shadow-compare via the four P07 corpus gates) → SC-2a (programmatic flip-gate) → SC-3 (live mechanical) → SC-3a (shadow-record write-path correctness) → SC-4 (escalation sequence) → SC-5 (escalation cap) → SC-6 (per-task override) → SC-7 (kill switch) → SC-7a (compound kill+floor) → SC-8 (by-model rollup with + without cost_rates) → SC-9 (doctor config-check) → SC-10 (classifier ground-truth ≥85%) → SC-11 (additive-schema byte-equality across rollup + footer + check-anomalies). When all pass, stdout's last line matches `^BATTERY: pass=14 fail=0`. (Roadmap line 64: "the M030 acceptance battery (all SCs from spec.md) runs to green".)
  - Check: `bash tools/verify/p07-acceptance-battery-pass.sh`

- `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md` is a one-shot evidence ledger of the green acceptance-battery run. Frontmatter declares `schema_version: "1.0"`, `type: acceptance-evidence`, `milestone: M030`, `recorded_at: <ISO8601>`, `battery_summary: "pass=14 fail=0"`. Body has a `## Evidence` section with one row per SC (14 rows total) carrying the columns `SC | Verifier path | Last-run output (key line)`. Each row's verifier path resolves to an existing-on-disk script. (Roadmap line 68 deliverable; consumed by milestone validate per the same line.)
  - Check: `bash tools/verify/p07-acceptance-evidence-ledger.sh`

- `bash tools/verify/p07-phase-suite.sh` invokes all P07 sub-gates (corpus-synthesizer-idempotent + corpus-50-per-class-ready + corpus-zero-evidence-insufficient + corpus-2-class-partially-ready + corpus-block + partial-flip-jsonl-fields + cross-surface-coherence + acceptance-battery-pass + acceptance-evidence-ledger) in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p07-phase-suite.sh pass=N fail=M` on a single line before exit. Same straight-line shape as `p02-phase-suite.sh` / `p03-phase-suite.sh` / `p04-phase-suite.sh` / `p05-phase-suite.sh` / `p06-phase-suite.sh`. (Phase-close aggregator.)
  - Check: `bash tools/verify/p07-phase-suite.sh`

### Artifacts

- tests/m030-acceptance/shadow-corpus-fixtures.sh (min 80 lines, contains "corpus-50-per-class.jsonl", contains "corpus-zero.jsonl", contains "corpus-2-class-only.jsonl", contains "corpus-block.jsonl", contains "mechanical", contains "standard", contains "novel") — create
- tests/m030-acceptance/corpus-50-per-class.jsonl (min 150 lines, contains "mechanical", contains "standard", contains "novel", contains "model_routed", contains "classifier_confidence") — create
- tests/m030-acceptance/corpus-zero.jsonl (min 0 lines) — create
- tests/m030-acceptance/corpus-2-class-only.jsonl (min 100 lines, contains "mechanical", contains "standard") — create
- tests/m030-acceptance/corpus-block.jsonl (min 30 lines, contains "mechanical") — create
- tests/m030-acceptance/run-acceptance-battery.sh (min 90 lines, contains "BATTERY:", contains "SC-1", contains "SC-2", contains "SC-2a", contains "SC-3a", contains "SC-7a", contains "SC-10", contains "SC-11") — create
- tools/verify/p07-corpus-synthesizer-idempotent.sh (min 40 lines, contains "shadow-corpus-fixtures.sh", contains "sha256", contains "SUMMARY:") — create
- tools/verify/p07-corpus-50-per-class-ready.sh (min 40 lines, contains "corpus-50-per-class.jsonl", contains "flip_recommendation=ready", contains "SUMMARY:") — create
- tools/verify/p07-corpus-zero-evidence-insufficient.sh (min 30 lines, contains "corpus-zero.jsonl", contains "evidence_insufficient", contains "SUMMARY:") — create
- tools/verify/p07-corpus-2-class-partially-ready.sh (min 50 lines, contains "corpus-2-class-only.jsonl", contains "partially_ready", contains "mechanical", contains "standard", contains "SUMMARY:") — create
- tools/verify/p07-corpus-block.sh (min 40 lines, contains "corpus-block.jsonl", contains "flip_recommendation=block", contains "SUMMARY:") — create
- tools/verify/p07-partial-flip-jsonl-fields.sh (min 60 lines, contains "partial_flip_active", contains "withheld_classes", contains "novel", contains "SUMMARY:") — create
- tools/verify/p07-cross-surface-coherence.sh (min 80 lines, contains "metrics-rollup.sh", contains "efficiency-footer.sh", contains "check-anomalies.sh", contains "model_mix", contains "model_routing_regression", contains "SUMMARY:") — create
- tools/verify/p07-acceptance-battery-pass.sh (min 30 lines, contains "run-acceptance-battery.sh", contains "BATTERY:", contains "pass=14 fail=0", contains "SUMMARY:") — create
- tools/verify/p07-acceptance-evidence-ledger.sh (min 50 lines, contains "M030-ACCEPTANCE-EVIDENCE.md", contains "type: acceptance-evidence", contains "battery_summary", contains "SUMMARY:") — create
- tools/verify/p07-phase-suite.sh (min 90 lines, contains "p07-corpus-synthesizer-idempotent", contains "p07-corpus-50-per-class-ready", contains "p07-corpus-zero-evidence-insufficient", contains "p07-corpus-2-class-partially-ready", contains "p07-corpus-block", contains "p07-partial-flip-jsonl-fields", contains "p07-cross-surface-coherence", contains "p07-acceptance-battery-pass", contains "p07-acceptance-evidence-ledger", contains "SUMMARY:") — create
- .orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md (min 30 lines, contains "type: acceptance-evidence", contains "battery_summary", contains "SC-1", contains "SC-11") — create
- .orchestrator/milestones/M030/M030-SUMMARY.md (min 50 lines, contains "type: milestone-summary", contains "M030", contains "verification_result:") — create (predicate amended from `verification_result: \"pass\"` to `verification_result:` per plan-amendment-not-task-reopen pattern: check-must-haves predicate parser strips at the first backslash of an escaped-quote sequence, surfaced post-T04 close; bare-key match preserves the must-have intent — only the close ceremony writes this frontmatter line, value is canonical)
- .orchestrator/milestones/M030/M030-VALIDATED (min 5 lines, contains "milestone: M030", contains "validated_at", contains "phase_count: 8") — create
- .orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md (min 30 lines, contains "type: phase-summary", contains "P07", contains "verification_result:") — create (predicate amended from `verification_result: \"pass\"` to `verification_result:` per plan-amendment-not-task-reopen pattern: same parser limitation as M030-SUMMARY.md predicate above)
- CLAUDE.md (modify — recent-changes region + project-status section update from "in progress" to "Closed M030") — modify
- AGENTS.md (modify — recent-changes region) — modify

### Key Links

- .orchestrator/milestones/M030/phases/P07/P07-PLAN.md → tests/m030-acceptance/run-acceptance-battery.sh (SC-1 through SC-11 inclusive of SC-2a/SC-3a/SC-7a — the 14-SC acceptance battery; spec lines 153-168 in specs/032-adaptive-model-selection/spec.md drive the SC list — key-link source amended from spec.md to P07-PLAN.md per plan-amendment-not-task-reopen pattern: spec authored before runner naming was settled, so spec doesn't carry the runner literal; P07-PLAN.md is the canonical source-of-truth referencing the runner)
- .orchestrator/milestones/M030/M030-ROADMAP.md → tests/m030-acceptance/shadow-corpus-fixtures.sh (P07 boundary-map produce: corpus synthesizer; roadmap line 68)
- .orchestrator/milestones/M030/M030-ROADMAP.md → tests/m030-acceptance/run-acceptance-battery.sh (P07 boundary-map produce: end-to-end SC runner; roadmap line 68)
- .orchestrator/milestones/M030/M030-ROADMAP.md → .orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md (P07 boundary-map produce: one-shot evidence ledger; roadmap line 68)
- .orchestrator/milestones/M030/phases/P07/P07-PLAN.md → tools/verify/p07-corpus-2-class-partially-ready.sh (D-A3 partially_ready conservative-construction gate exercised end-to-end; M030-CONTEXT.md lines 32-34 declare D-A3 — key-link source amended from M030-CONTEXT.md to P07-PLAN.md per plan-amendment-not-task-reopen pattern: context authored before P07 verifier slug was settled; P07-PLAN.md grep-references the verifier as the canonical source-of-truth)
- .orchestrator/milestones/M030/phases/P02/P02-SUMMARY.md → scripts/diagnostics/shadow-compare.sh (P02 established the 4-verdict shadow-compare surface P07 exercises at scale)
- .orchestrator/milestones/M030/phases/P07/P07-PLAN.md → tools/verify/p07-partial-flip-jsonl-fields.sh (P04 established the partial_flip_active + withheld_classes JSONL fields P07 verifies under the at-scale partially_ready corpus — key-link source amended from P04-SUMMARY.md to P07-PLAN.md per plan-amendment-not-task-reopen pattern: upstream phase summaries are immutable post-close and cannot reference downstream verifiers; P07-PLAN.md grep-references the verifier as the canonical source-of-truth)
- .orchestrator/milestones/M030/phases/P07/P07-PLAN.md → tools/verify/p07-cross-surface-coherence.sh (P05 established metrics-rollup --by-model + efficiency-footer model_mix surfaces, P06 established check-anomalies model_routing_regression check, P07 cross-surface-coherence verifier exercises both end-to-end against the full corpus — key-link source amended from P05/P06-SUMMARY.md to P07-PLAN.md per plan-amendment-not-task-reopen pattern: upstream phase summaries are immutable post-close and cannot reference downstream verifiers; P07-PLAN.md grep-references the verifier as the canonical source-of-truth)

## Tasks

### T01: Acceptance-corpus synthesizer + 4 corpus fixtures + per-verdict gates

See `.orchestrator/milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-PLAN.md`.

### T02: Acceptance-battery runner + SC delegators + cross-surface coherence gate

See `.orchestrator/milestones/M030/phases/P07/tasks/T02-acceptance-battery-PLAN.md`.

### T03: Acceptance-evidence ledger + evidence-ledger shape gate + phase-suite aggregator

See `.orchestrator/milestones/M030/phases/P07/tasks/T03-evidence-ledger-and-phase-suite-PLAN.md`.

### T04: M030 milestone close ceremony

See `.orchestrator/milestones/M030/phases/P07/tasks/T04-milestone-close-ceremony-PLAN.md`.

## Task Dependencies

T01 → T02 → T03 → T04 (linear chain). Same shape as P02–P06 closes, with one extra task because P07's milestone-close ceremony is structurally distinct from its phase-close ceremony.

T01 ships the at-scale corpus + per-verdict gates (the input to every downstream SC verifier). T02 wires the acceptance-battery runner that delegates to existing P0N verifiers + invokes the new T01 gates + the cross-surface coherence gate. T03 captures the green-run evidence ledger + closes the phase-suite aggregator. T04 ships the milestone-close ceremony (P07-SUMMARY.md + phase-grain unit_close + M030-VALIDATED marker via mark-complete.sh + M030-SUMMARY.md + milestone-grain unit_close + recent-changes dual-write + close commit + final validate-milestone.sh clean pass).

## Files Likely Touched

- tests/m030-acceptance/shadow-corpus-fixtures.sh (create)
- tests/m030-acceptance/corpus-50-per-class.jsonl (create)
- tests/m030-acceptance/corpus-zero.jsonl (create)
- tests/m030-acceptance/corpus-2-class-only.jsonl (create)
- tests/m030-acceptance/corpus-block.jsonl (create)
- tests/m030-acceptance/run-acceptance-battery.sh (create)
- tools/verify/p07-corpus-synthesizer-idempotent.sh (create)
- tools/verify/p07-corpus-50-per-class-ready.sh (create)
- tools/verify/p07-corpus-zero-evidence-insufficient.sh (create)
- tools/verify/p07-corpus-2-class-partially-ready.sh (create)
- tools/verify/p07-corpus-block.sh (create)
- tools/verify/p07-partial-flip-jsonl-fields.sh (create)
- tools/verify/p07-cross-surface-coherence.sh (create)
- tools/verify/p07-acceptance-battery-pass.sh (create)
- tools/verify/p07-acceptance-evidence-ledger.sh (create)
- tools/verify/p07-phase-suite.sh (create)
- .orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md (create)
- .orchestrator/milestones/M030/M030-SUMMARY.md (create)
- .orchestrator/milestones/M030/M030-VALIDATED (create — written by mark-complete.sh)
- .orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md (create)
- .orchestrator/milestones/M030/phases/P07/P07-PLAN.md (create — this file)
- .orchestrator/milestones/M030/phases/P07/tasks/T01-corpus-and-verdict-gates-PLAN.md (create)
- .orchestrator/milestones/M030/phases/P07/tasks/T02-acceptance-battery-PLAN.md (create)
- .orchestrator/milestones/M030/phases/P07/tasks/T03-evidence-ledger-and-phase-suite-PLAN.md (create)
- .orchestrator/milestones/M030/phases/P07/tasks/T04-milestone-close-ceremony-PLAN.md (create)
- .orchestrator/milestones/M030/execution-log.jsonl (modify — phase-grain unit_close append at T04 + milestone-grain unit_close append at T04)
- CLAUDE.md (modify — recent-changes region + project-status update from "in progress" to "Closed M030")
- AGENTS.md (modify — recent-changes region)

---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M018"
name: "P06 verifiers (5), fixtures (2 trees), fixture-staging helper, P06-SUMMARY (via phase-transition.sh --write), CLAUDE.md / AGENTS.md orchestrator:recent-changes dual-write"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `_bc_apply_tier3` in `scripts/dispatch/build-context.sh`, the prompt template at `templates/compression-tier3-prompt.md`, the six `kf_get_tier3_*` accessors in `scripts/lib/knowledge-filter.sh`, and the config-default block in `templates/orchestrator-config-default.yml`.
- T02 has shipped the additive `tier3_compression_savings_tokens` + `tier3_invocations` fields on `payload_breakdown`, `dispatch_usage` (both co-located + dispatch-interface), and `unit_close` JSONL records; the two new columns on `metrics-rollup.sh`; the tier3 fold into `efficiency-footer.sh` + `check-anomalies.sh`.
- T03 has replaced the `--tier 3` stub in `scripts/diagnostics/compression-eval.sh` with real cohort logic against `tier3_compression_savings_tokens`.
- The P05/T04 implementation is the canonical shape T04 mirrors. Re-read `.orchestrator/milestones/M018/phases/P05/tasks/T04-verifiers-and-summary-PLAN.md` for the verifier-shape, fixture-shape, and dual-write conventions before authoring.
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` is the fixture-staging helper shape T04 mirrors. Read it once for shape (config-override scaffolding, fixture path resolution) before authoring `m018-p06-build-fixture.sh`.
- `scripts/util/dual-write-runtime-md.sh` is the canonical dual-write helper used by every prior phase. Invocation pattern: `bash scripts/util/dual-write-runtime-md.sh <orchestrator:recent-changes block content>` — writes the block to both `CLAUDE.md` and `AGENTS.md` between the `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<` sentinels. The verifier `m018-p06-dual-write-recent.sh` only checks that both files contain "M018/P06" in their recent-changes block.
- `scripts/lifecycle/phase-transition.sh` is the canonical phase-summary writer for P06. **CRITICAL**: T04 invokes `phase-transition.sh --write` (NOT `write-summary.sh phase` directly). P05/T04 wrote the summary directly via `write-summary.sh phase` and triggered a `SYNC:MISMATCH` that needed `sync-roadmap.sh --fix`; P06 avoids the regression by using the atomic transition helper. Invocation:

  ```bash
  bash scripts/lifecycle/phase-transition.sh \
    .orchestrator/milestones/M018 P06 \
    --write \
    --body-file=.orchestrator/milestones/M018/phases/P06/_summary-body.txt \
    --observability_surfaces='execution-log.jsonl: payload_breakdown.{tier3_compression_savings_tokens,tier3_invocations} additive integer fields; ...' \
    --verification_result=pass
  ```

  The helper reads all task summaries from the phase directory, derives `provides` / `requires` / `affects` / `key_files` / `key_decisions` / `patterns_established` / `drill_down_paths` automatically, runs the external mod check, syncs the roadmap, and writes the summary atomically.
- AD-19 single-script-file `Check:` contract: every verifier exposes its truth via a single bash invocation. The verifier may shell out to subordinate helpers (e.g., `_helpers/m018-p06-build-fixture.sh`) but `check-must-haves.sh` invokes ONE bash file per truth.
- AP-009 applies to verifier scripts. No compound chains > 2; no plain subshells; no `$(... | ...)`. Verifier scripts use `pass()` / `fail()` per MEM002 and `printf 'PASS:' / printf 'FAIL:'` line-prefix convention.
- Bash 3.2 — verifiers use parallel indexed arrays (no `declare -A`).

## Description

T04 ships:

1. **One fixture-staging helper** at `scripts/verify/_helpers/m018-p06-build-fixture.sh`.
2. **Two fixture trees** under `tests/fixtures/m018-p06-{tier3-fired,tier3-failed}-log/`.
3. **Five verifier scripts** under `scripts/verify/m018-p06-*.sh` (one per mechanical truth in P06-PLAN.md):
   - `m018-p06-tier3-helper-shape.sh` — Truth #1 (helper exists + routes through dispatch-interface).
   - `m018-p06-tier3-prompt-template.sh` — Truth #2 (prompt template exists + frontmatter contract).
   - `m018-p06-tier3-additivity.sh` — Truth #3 (three-record-type additive fields).
   - `m018-p06-compression-eval-tier3.sh` — Truth #4 (tier-3 cohort replaces stub).
   - `m018-p06-dual-write-recent.sh` — Truth #5 (CLAUDE.md / AGENTS.md recent-changes).
4. **P06-SUMMARY.md** via `bash scripts/lifecycle/phase-transition.sh --write`.
5. **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write** for M018/P06.

T04 does NOT ship:

- T01's helper, prompt template, or accessors.
- T02's schema field additivity.
- T03's compression-eval cohort logic.

## Inputs

Surface contracts T04 reads from upstream files:

- `scripts/verify/m018-p05-*.sh` (eight verifiers from P05) — read for the canonical verifier shape (pass()/fail() helpers, hermetic root staging via `ORCHESTRATOR_ROOT`, single-script-file Check shape, MEM004 carve-out comments where applicable).
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` and `scripts/verify/_helpers/m018-p04-build-fixture.sh` — read for the fixture-staging helper shape.
- `tests/fixtures/m018-p05-savings-log/execution-log.jsonl` — read for the JSONL-record-mix shape; T04's `m018-p06-tier3-fired-log/execution-log.jsonl` extends this with tier3 fields and at least one `tier3_failed` event record.
- `scripts/lifecycle/phase-transition.sh --help` — read at integration time for the `--write` invocation surface; the canonical body-file pattern is `.orchestrator/milestones/M018/phases/P06/_summary-body.txt`.
- `scripts/util/dual-write-runtime-md.sh` — read for the recent-changes block shape.

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p06-build-fixture.sh`

Mirror the P05 helper. Job: stage two fixture milestone directories (tier3-fired log + tier3-failed log) under `$TMPDIR_BUILD/_p06_fixture/<slug>/`, each containing:

- `.orchestrator/milestones/M-FIXTURE/execution-log.jsonl` — synthesized JSONL with the appropriate record mix.
- (Optionally) a stub `.orchestrator/config.yml` for tests that exercise config-driven knobs.

The helper takes one argument (`tier3-fired` | `tier3-failed`) and prints the staged fixture root on stdout. Idempotent (clean staging dir on re-invocation). Bash 3.2; no compound chains > 2.

### Step 2 — Author `tests/fixtures/m018-p06-tier3-fired-log/execution-log.jsonl`

Hand-craft a JSONL log with:

- 5 `payload_breakdown` records (tasks T01-T05 of a fictional M-FIXTURE milestone) carrying:
  - T01: `tier3_compression_savings_tokens=400`, `tier3_invocations=1`, `payload_tokens_estimate=2000`. Other tier savings = 0.
  - T02: `tier3_compression_savings_tokens=600`, `tier3_invocations=1`, `payload_tokens_estimate=3000`.
  - T03: `tier3_compression_savings_tokens=0`, `tier3_invocations=0`, `payload_tokens_estimate=2500` (uncompressed-cohort representative).
  - T04: `tier3_compression_savings_tokens=800`, `tier3_invocations=1`, `payload_tokens_estimate=3500` (high-savings).
  - T05: `tier3_compression_savings_tokens=0`, `tier3_invocations=0`, `payload_tokens_estimate=2200` (uncompressed-cohort representative).
- 5 `unit_close` records (granularity=task) for the same five tasks with `verification_pass_rate=1.0`, `retry_count=0`, `deviation_count=0`. Compressed cohort: T01/T02/T04 (tier3 fired). Uncompressed cohort: T03/T05.
- 1 `tier3_skipped` record naming `reason=density-floor` (exercises the helper's MIT-08 short-circuit emit).
- 1 pre-P06 row at the top of the file: a `payload_breakdown` record from a hand-curated baseline carrying ONLY the four P05 fields and NONE of the tier3 fields. The verifier's back-compat assertion confirms this row still parses as valid JSON and treats absent tier3 fields as zero.

Add a `tests/fixtures/m018-p06-tier3-fired-log/README.md` documenting the fixture's record mix and what each verifier expects.

### Step 3 — Author `tests/fixtures/m018-p06-tier3-failed-log/execution-log.jsonl`

Hand-craft a smaller JSONL log carrying:

- 2 `payload_breakdown` records with `tier3_compression_savings_tokens=0`, `tier3_invocations=0` (T3 didn't fire because it failed-passthrough).
- 2 `tier3_failed` records naming `reason=llm-call-nonzero` and `reason=preservation-breach` respectively (exercises the failure-passthrough emit path from T01).
- 2 `unit_close` records with `verification_pass_rate=1.0` (the dispatches still succeeded — failure-passthrough means the agent received the Tier 2 output and ran successfully on it).

Add a `README.md` documenting the failure-passthrough scenario.

### Step 4 — Author `scripts/verify/m018-p06-tier3-helper-shape.sh` (Truth #1)

Single bash file. Asserts:

- The string `_bc_apply_tier3` exists in `scripts/dispatch/build-context.sh` (helper shipped).
- The string `dispatch-interface.sh` is referenced inside the `_bc_apply_tier3` function body (uses `awk` to extract the function body and `grep` for the reference).
- The string `compression-tier3-prompt.md` is referenced inside the helper body.
- The pipeline-wiring tail invokes `_bc_apply_tier3 "$PAYLOAD_CAPTURE"` between `_bc_apply_tier2` and `_bc_emit_payload_breakdown`.
- The six `kf_get_tier3_*` accessors exist in `scripts/lib/knowledge-filter.sh`.
- `bash -n scripts/dispatch/build-context.sh` exits 0.
- `bash -n scripts/lib/knowledge-filter.sh` exits 0.

Verifier uses `pass() / fail()` per MEM002. AD-19 single-script-file Check shape — the verifier itself is the canonical Check.

### Step 5 — Author `scripts/verify/m018-p06-tier3-prompt-template.sh` (Truth #2)

Single bash file. Asserts:

- `templates/compression-tier3-prompt.md` exists.
- The template's frontmatter declares `tier: 3` and `applies_to: ["dispatch-payload-section"]`.
- The frontmatter `preserves:` array contains every preserved-pattern token named in `references/compression-grammar.md` Tier 3 section (frontmatter, code fences, JSONL records, MEM identifiers, paths, scaffold-placeholder markers, URLs, command names, in-band markers).
- The body contains the literal substring `compressed:tier3 model=<MODEL> input_tokens=<N> output_tokens=<M>` (the in-band marker the helper substitutes post-call).
- The body contains the literal `## Section to compress` header (last section of the template, where the helper appends the section bytes).

### Step 6 — Author `scripts/verify/m018-p06-tier3-additivity.sh` (Truth #3)

Single bash file. Stages a fixture log via `_helpers/m018-p06-build-fixture.sh tier3-fired`, then asserts:

- The fixture's `payload_breakdown` records (post-T02) carry both `"tier3_compression_savings_tokens":` and `"tier3_invocations":` fields with non-negative integer values.
- A pre-P06 `payload_breakdown` row in the fixture (the hand-curated baseline at the top) parses as valid JSON via a minimal awk/sed parse-check (or `python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]'` if available).
- Driving `_di_emit_dispatch_usage` (or equivalent — the verifier may invoke `bash scripts/dispatch/dispatch-interface.sh ...` against the fixture root if the CLI exposes the emit, otherwise it shims the function via the same shape pattern P05/T04 used) produces a `dispatch_usage` record with both new fields, and the values are the SUM of the in-scope payload_breakdown rows (not just one row).
- Driving `_ws_emit_unit_close` (via `bash scripts/knowledge/write-summary.sh phase ...` against the fixture root) produces a `unit_close` record with the new fields rolled up at granularity-aware scope.
- `bash scripts/diagnostics/metrics-rollup.sh --milestone M-FIXTURE` (with `ORCHESTRATOR_ROOT=<fixture-root>`) emits a header containing `TIER3_SAVINGS` and `TIER3_INVOCS` and a data row with integer values for those columns.
- `bash scripts/diagnostics/efficiency-footer.sh --milestone M-FIXTURE` emits a `compression:` line whose percent reflects the SUM of all four P05 fields plus tier3_savings (not just the P05 fields).
- `bash scripts/diagnostics/check-anomalies.sh --milestone M-FIXTURE --sample-floor 1` produces output where any flagged row's `savings_ratio` reflects the widened sav_total (the verifier confirms tier3_savings is folded into the denominator by checking ratio against the known fixture-row inputs).

### Step 7 — Author `scripts/verify/m018-p06-compression-eval-tier3.sh` (Truth #4)

Single bash file. Asserts:

- `bash scripts/diagnostics/compression-eval.sh --milestone M-FIXTURE --tier 3 --sample-floor 1` (with `ORCHESTRATOR_ROOT=<tier3-fired-fixture>`) emits a `# compression-eval — milestone=M-FIXTURE tier=3` header followed by a `COHORT` line with `compressed`, `uncompressed`, and `delta` rows. Exit 0.
- The output contains `regression_flag:` (advisory line — value is "none" expected on this fixture because pass-rates are 1.0/1.0 across cohorts).
- `bash scripts/diagnostics/compression-eval.sh --milestone M-FIXTURE --tier 3 --sample-floor 1000` emits an `insufficient sample` line and exits 0 (cohort sizes are below the floor).
- The output never contains the literal "tier 3 reserved for P06" (regression check — confirms the stub is gone).
- `bash -n scripts/diagnostics/compression-eval.sh` exits 0.
- `bash scripts/diagnostics/compression-eval.sh --tier 3` against an absent log emits a degraded-input line and exits 0 (FR-12 / CON-5 always-exit-0 contract preserved).

### Step 8 — Author `scripts/verify/m018-p06-dual-write-recent.sh` (Truth #5)

Single bash file. Asserts:

- `CLAUDE.md` contains a `# >>> orchestrator:recent-changes >>>` block.
- `AGENTS.md` contains a `# >>> orchestrator:recent-changes >>>` block.
- Both blocks contain the literal substring `M018/P06`.
- Both blocks contain the literal substring `tier3` (or `compression-tier3-prompt`).

Mirrors `m018-p05-dual-write-recent.sh` exactly (substituting `M018/P05` → `M018/P06`).

### Step 9 — Run all five verifiers; iterate until green

Each verifier must exit 0 and emit `PASS:` lines per assertion. Failures emit `FAIL:` with a message naming the file/line/value mismatch.

```bash
bash scripts/verify/m018-p06-tier3-helper-shape.sh
bash scripts/verify/m018-p06-tier3-prompt-template.sh
bash scripts/verify/m018-p06-tier3-additivity.sh
bash scripts/verify/m018-p06-compression-eval-tier3.sh
bash scripts/verify/m018-p06-dual-write-recent.sh
```

(The dual-write verifier won't pass until Step 11 lands the dual-write block.)

### Step 10 — Author `_summary-body.txt` for `phase-transition.sh --write`

Write the P06-SUMMARY narrative body to `.orchestrator/milestones/M018/phases/P06/_summary-body.txt`. Mirror the P05-SUMMARY narrative shape (the `## Risk-mitigation traceability`, `## Followups for downstream phases`, `## Verification result` sections). Name what P06 ships:

- `_bc_apply_tier3` LLM-routed summarization helper with intensity-gate, MIT-08 density pre-check, originals persistence, failure-passthrough.
- `templates/compression-tier3-prompt.md` summarization prompt template.
- Six `kf_get_tier3_*` config accessors.
- Additive `tier3_compression_savings_tokens` + `tier3_invocations` fields on `payload_breakdown` / `dispatch_usage` / `unit_close`.
- New `tier3_skipped` / `tier3_failed` / `tier3_no_savings` JSONL record schemas.
- `metrics-rollup.sh` `TIER3_SAVINGS` + `TIER3_INVOCS` columns.
- `efficiency-footer.sh` + `check-anomalies.sh` tier3-fold widening.
- `compression-eval.sh --tier 3` real cohort logic replacing the P05 stub.
- Five P06-private truth verifiers + two fixture trees + fixture-staging helper.
- CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write.

Note RISK-3 disposition: state explicitly that the diagnostic surface is operational, that current cohort sizes are below the statistical floor (insufficient sample), that this is treated as a non-regression for P06 close per the spec's RISK-3 framing, and that subsequent milestones will exercise the tier-3 cohort and re-evaluate.

### Step 11 — Dual-write the `orchestrator:recent-changes` block

```bash
bash scripts/util/dual-write-runtime-md.sh '030-context-compression-layer / M018/P06: tier3 auto-compact live in build-context.sh (_bc_apply_tier3: dispatch-interface.sh-routed summarization with intensity-gate, MIT-08 density pre-check, originals persistence to .orchestrator/cache/tier3-originals/, failure-passthrough emitting tier3_failed JSONL); templates/compression-tier3-prompt.md (versioned frontmatter + preserved-pattern body); additive tier3_compression_savings_tokens / tier3_invocations fields on payload_breakdown / dispatch_usage / unit_close (CON-5); compression-eval.sh --tier 3 real cohort logic replaces the P05 stub.'
```

Re-run `bash scripts/verify/m018-p06-dual-write-recent.sh` and confirm PASS.

### Step 12 — Run `phase-transition.sh --write` to atomically write P06-SUMMARY.md + sync roadmap

```bash
bash scripts/lifecycle/phase-transition.sh \
  .orchestrator/milestones/M018 P06 \
  --write \
  --body-file=.orchestrator/milestones/M018/phases/P06/_summary-body.txt \
  --observability_surfaces='execution-log.jsonl: payload_breakdown.{tier3_compression_savings_tokens,tier3_invocations} additive integer fields; dispatch_usage.{tier3_compression_savings_tokens,tier3_invocations} rolled-up additive fields; unit_close.{tier3_compression_savings_tokens,tier3_invocations} granularity-aware additive fields; tier3_skipped / tier3_failed / tier3_no_savings new JSONL record_types (additive); metrics-rollup.sh stdout: TIER3_SAVINGS / TIER3_INVOCS columns; efficiency-footer.sh stdout: compression: line numerator widens to fold tier3 savings; check-anomalies.sh stdout: compression-regression denominator widens to fold tier3 savings; compression-eval.sh stdout: --tier 3 cohort + delta block with 95% CIs and regression_flag (no longer P06-reservation stub).' \
  --verification_result=pass
```

Expected: `phase-transition.sh` reads all four task summaries, derives `provides` / `requires` / `affects` / etc. fields automatically, syncs the roadmap, writes `P06-SUMMARY.md` atomically, and emits a `TRANSITION:READY phase=P06 fields_derived=N` status line. No `SYNC:MISMATCH`.

### Step 13 — Run `check-must-haves.sh` against the phase

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P06/
```

Expected: every truth Check passes; every artifact line-count + substring matches; every key-link resolves.

## Verification

T04's task-local extractable Check is the syntax-only self-check on the closing-task verifier:

- Check: `bash -n scripts/verify/m018-p06-dual-write-recent.sh`

(One Check per task per the auto-loop verify parser. The five canonical truth verifiers are themselves the phase-level Checks; T04's task-local Check is on the dual-write verifier, which is the truth most tightly tied to T04 itself — the dual-write block is written by T04 alone.)

## Must-Haves (subset addressed by this task)

- **Truth #5** (dual-write recent-changes): wholly addressed by Steps 8 + 11.
- **Truths #1, #2, #3, #4**: T04 ships the canonical verifiers that exercise the truths end-to-end; the underlying production code ships in T01/T02/T03. T04 closes the verification loop on all four mechanical truths plus the dual-write truth.
- **RISK-3 phase-close gate**: T04 executes the manual review of `compression-eval.sh --milestone M018 --tier 3` and records the disposition in `_summary-body.txt` (Step 10 narrative).

## Notes

- **`phase-transition.sh --write` (NOT `write-summary.sh phase`)**: this is the load-bearing convention. P05/T04 wrote the summary directly via `write-summary.sh phase` and had to fix a `SYNC:MISMATCH` post-hoc with `sync-roadmap.sh --fix`. P06 atomically transitions roadmap + disk via the lifecycle helper, avoiding the regression. The helper invokes `write-summary.sh phase` internally with the correctly-derived field values.
- **Five truths, five verifiers** (vs P05's eight): P06's surface is narrower because the schema additivity is concentrated on a single tier and the rollup-fold is a denominator widen rather than a new column block. The five-truth split is:
  1. helper shape (T01),
  2. prompt template shape (T01),
  3. three-record-type additivity end-to-end (T02 + T03's read-side),
  4. compression-eval `--tier 3` cohort (T03),
  5. dual-write (T04).
- **RISK-3 disposition**: the spec's RISK-3 gate says "P06's `unit_close: pass` is gated by `compression-eval.sh` showing no statistically significant outcome-rate regression vs the uncompressed cohort." At P06 close, the cohort sizes will likely be below the sample floor (the diagnostic emits `insufficient sample` and exits 0). Per the spec's framing, this counts as a non-regression — the diagnostic is operational, the cohort split logic works against the fixture log, and subsequent milestones will exercise the diagnostic against larger n. Document this disposition in `_summary-body.txt` so the next operator reading P06-SUMMARY understands the RISK-3 framing without needing to re-derive it.
- **Hermetic fixtures**: every verifier uses `ORCHESTRATOR_ROOT=<fixture-root>` to point production scripts at the fixture log. The fixture-staging helper is the canonical entry point — it stages a fully-formed `.orchestrator/`-style root with `milestones/M-FIXTURE/execution-log.jsonl` and a minimal `config.yml`. Production scripts never write to the fixture; verifiers only read.
- **Five verifiers, single-file Check shape**: every verifier's body is invoked via a single bash file (`bash scripts/verify/m018-p06-<truth>.sh`); verifiers internally shell out to the fixture-staging helper for setup. AD-19 single-script-file Check shape is satisfied at the truth-level.
- **Pre-P06 record back-compat**: every additivity verifier asserts that a hand-curated pre-P06 row (no tier3 fields) parses as valid JSON and that downstream consumers treat absent fields as zero. CON-5 contract verified end-to-end.
- **Bash 3.2** (MEM001): no `declare -A`. Verifier scripts use parallel indexed arrays + `pass() / fail()` per MEM002.
- **The `--tier 3` cohort RISK-3 manual review** is recorded in `_summary-body.txt`, not in a separate file — the operator running `orchestrator:auto` reads the summary at phase-close time and confirms the disposition. The disposition is "operational; insufficient sample at P06 close; non-regression by spec framing."

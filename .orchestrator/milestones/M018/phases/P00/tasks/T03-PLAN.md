---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M018"
name: "Calibrate SC-9 threshold and amend spec"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 must be complete: `scripts/verify/m018-p00-emitter-parity.sh` exists and runs; the dispatch_usage emitter fires on every dispatch path that emits payload_breakdown.
- T02 must be complete: `scripts/diagnostics/m018-section-distribution.sh` exists and produces both text and JSON output; `scripts/verify/m018-p00-probe-output.sh` passes.

T03 collects the 20-dispatch parity sample, derives the SC-9 calibrated threshold, applies the spec amendment, and writes P00-SUMMARY.md.

## Description

This is the closing task. T03:

1. Generates a 20-dispatch parity sample (or uses the next 20 real dispatches if they are already accumulating from in-progress orchestrator activity) and asserts ≥ 95% parity via T01's verifier.
2. Runs T02's probe against the historical log, captures the JSON output, extracts the `aggregate_ceiling.low_pct` figure (the empirically-defensible lower-confidence bound on achievable savings).
3. Applies a spec amendment to `specs/030-context-compression-layer/spec.md` SC-9 that replaces the placeholder threshold with the probe-derived value, citing the probe output by reference.
4. Writes `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md` capturing parity result, calibrated threshold, model assumptions, and amendment commit reference.
5. Ships the supporting verifiers `scripts/verify/m018-p00-sc9-calibrated.sh` and `scripts/verify/m018-p00-summary-complete.sh`.

## Steps

1. **Collect the 20-dispatch sample.** Pick the cheapest path that yields 20 fresh dispatches against the patched emitter:
   - **Path A (preferred if 20+ dispatches have accumulated organically since T01 landed):** run `bash scripts/verify/m018-p00-emitter-parity.sh --window 20 --threshold 95`. If it passes, record the parity figure and proceed to step 2.
   - **Path B (if fewer than 20 fresh dispatches exist):** construct a synthetic fixture-replay harness at `scripts/verify/m018-p00-fixture-replay.sh` that invokes `scripts/dispatch/build-context.sh` against a small in-memory fixture (a fake milestone/phase/task triple) 20 times back-to-back, each invocation writing to a scratch execution-log under `.orchestrator/scratch/m018-p00-fixture-log.jsonl`. The harness then runs the parity verifier against that scratch log via a `--log-path` flag added in this step (extend T01's verifier to accept `--log-path PATH` defaulting to the production union scan).
   - Document which path was used in P00-SUMMARY.md.

2. **Run the probe and capture output.** Execute `bash scripts/diagnostics/m018-section-distribution.sh --format json > .orchestrator/scratch/m018-section-distribution-output.json` and `bash scripts/diagnostics/m018-section-distribution.sh --format text > .orchestrator/scratch/m018-section-distribution-output.txt`. Both files become part of the audit trail.

3. **Extract the calibrated threshold.** Parse the JSON output: `THRESHOLD_PCT=$(jq -r '.aggregate_ceiling.low_pct' .orchestrator/scratch/m018-section-distribution-output.json)`. Round to one decimal place. This is the SC-9 calibrated threshold floor — the value below which post-M018 measurement counts as a SC-9 failure. Capture also `aggregate_ceiling.mean_pct` (the expected outcome) and `aggregate_ceiling.high_pct` (the optimistic ceiling) for the summary.

4. **Apply the spec amendment.** Edit `specs/030-context-compression-layer/spec.md` SC-9 (currently around line 241):
   - **Before** (current text): "the post-M018 measured reduction falls below the calibrated threshold's lower confidence bound. *(Per gate finding RISK-2: the prior "≥ 25%" target was unbacked and is replaced by a probe-derived threshold.)*"
   - **After**: replace the parenthetical with: "*(Per gate finding RISK-2 + P00 calibration: SC-9 threshold floor is **<THRESHOLD_PCT>%** mean payload-token reduction, derived from `scripts/diagnostics/m018-section-distribution.sh` aggregate-ceiling 80% CI lower bound across n=169 historical `payload_breakdown` records under per-tier modeling assumptions documented in the probe script. Probe output archived at `.orchestrator/scratch/m018-section-distribution-output.{json,txt}`. Expected mean: <MEAN_PCT>%; optimistic ceiling: <HIGH_PCT>%.)*"
   - Also update the spec frontmatter `Last Revised:` line (line 14) to: "2026-04-27 — applied conversus gate RISK-1/2/3 mitigations: added P00 measurement-prerequisites phase (US-0, FR-0a, FR-0b), promoted US-7 P3→P2, deferred SC-9 threshold to P00 calibration, resolved Q-1/Q-2. **2026-XX-XX (P00 close)**: SC-9 threshold pinned to <THRESHOLD_PCT>% per probe-derived 80% CI lower bound."
   - Use `Edit` (not `Write`) to apply both edits surgically.

5. **Write the SC-9 verifier** at `scripts/verify/m018-p00-sc9-calibrated.sh`:
   - Reads `specs/030-context-compression-layer/spec.md`.
   - Asserts the SC-9 block contains a numeric threshold (regex `[0-9]+\.?[0-9]*%`) AND the literal string `P00 calibration` (proves the amendment landed and is sourced from the probe).
   - Asserts the placeholder string `≥ 25%` does NOT appear anywhere in the SC-9 block (proves the original placeholder was replaced, not annotated).
   - Single-script-file shape (AD-19).
   - Exits 0 on pass, 1 with diagnostic on fail.

6. **Write P00-SUMMARY.md** at `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md` with the following sections:
   - **Closure summary** (one paragraph): what P00 accomplished, parity achieved, threshold calibrated.
   - **Parity result**: which path (A or B), exact dispatch counts, parity percentage, sample window timestamps.
   - **Calibrated threshold**: the value chosen, the underlying probe outputs (low/mean/high CI), the model assumptions cited verbatim from the probe's `model_assumptions` JSON block.
   - **Spec amendment**: line numbers touched, before/after text quoted, commit reference (sha + message).
   - **Risk-mitigation traceability**: explicit links from RISK-1 → MIT-1 → T01 → emitter parity result, RISK-2 → MIT-2 → T02+T03 → SC-9 calibration. This is the audit trail D028 promised would carry the proof.
   - **Followups for downstream phases**: any caveats T01/T02 surfaced that P01–P07 should know about. (For example: if T01 chose Option 1 co-location, P05's surface integration needs to know that some `dispatch_usage` records will carry `emission_point: build-context` instead of `dispatch-interface`.)

7. **Write the summary completeness verifier** at `scripts/verify/m018-p00-summary-complete.sh`:
   - Reads `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`.
   - Asserts the file contains all six required section headings: `Closure summary`, `Parity result`, `Calibrated threshold`, `Spec amendment`, `Risk-mitigation traceability`, `Followups for downstream phases`.
   - Asserts the file contains the literal string `parity` and a numeric percentage matching the calibrated threshold from step 3.
   - Asserts the file is ≥ 40 lines.
   - Single-script-file shape (AD-19); exits 0 on pass, 1 with diagnostic on fail.

8. **Run the full P00 must-haves check.** `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P00/`. All four truths in P00-PLAN.md must report PASS.

9. **Commit** with a message that references D028, the parity figure, the threshold value, and the probe-output audit trail. Include `Phase: M018/P00` and `Closes: US-0, FR-0a, FR-0b`.

## Must-Haves

This task addresses the phase must-haves:

- Truth: "The `dispatch_usage` JSONL emitter fires on real dispatches at parity ≥ 95% with `payload_breakdown` over a 20-dispatch sample." — proved by step 1.
- Truth: "`specs/030-context-compression-layer/spec.md` SC-9 is amended with an empirically-grounded threshold." — implemented by steps 3, 4, 5.
- Truth: "Phase summary records the parity result, the probe-derived threshold value, and the spec amendment commit/diff reference." — implemented by steps 6, 7.
- Artifacts: `scripts/verify/m018-p00-sc9-calibrated.sh`, `scripts/verify/m018-p00-summary-complete.sh`, `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md`.

## Verification

- `bash scripts/verify/m018-p00-emitter-parity.sh --window 20 --threshold 95` — must pass.
- `bash scripts/verify/m018-p00-probe-output.sh` — must pass.
- `bash scripts/verify/m018-p00-sc9-calibrated.sh` — must pass.
- `bash scripts/verify/m018-p00-summary-complete.sh` — must pass.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P00/` — must report all P00 truths PASS.

## Inputs

### From Previous Tasks

- `scripts/verify/m018-p00-emitter-parity.sh` (from T01)
  - Key API: `bash scripts/verify/m018-p00-emitter-parity.sh [--window N] [--threshold P] [--log-path PATH]`
  - Key behavior: exits 0 if parity ≥ threshold over the last N records; exits 1 otherwise.
  - Note: T03 step 1 (Path B) extends this script with `--log-path PATH` if not already supported by T01. If T01 did not add it, T03 adds it as a back-compat additional flag (default behavior unchanged).
- `scripts/dispatch/build-context.sh` and/or `scripts/dispatch/dispatch-interface.sh` (modified by T01)
  - Key behavior: emits `dispatch_usage` JSONL records on every dispatch path that emits `payload_breakdown`.
- `scripts/diagnostics/m018-section-distribution.sh` (from T02)
  - Key API: `bash scripts/diagnostics/m018-section-distribution.sh [--format text|json] [--bootstrap-iterations N] [--seed S]`
  - Key behavior: reads historical log, emits per-section distribution + per-tier savings ceilings with 80% CIs.
  - JSON output keys: `per_section[]`, `per_tier{filter,tier1,tier2,tier3}`, `aggregate_ceiling{low_pct,mean_pct,high_pct,low_tokens,mean_tokens,high_tokens}`, `model_assumptions{}`.
- `scripts/verify/m018-p00-probe-output.sh` (from T02)
  - Key behavior: validates probe JSON output structure.

### From Disk (Pre-existing)

- `specs/030-context-compression-layer/spec.md` — the file T03 amends. SC-9 lives around line 241; spec frontmatter `Last Revised:` lives around line 14.
- `.orchestrator/DECISIONS.md` D028 — the operator gate-resolution row that committed P00 to "carry the proof." T03's summary references D028 explicitly so the audit trail loops closed.
- `.orchestrator/milestones/M018/M018-ROADMAP.md` — phase boundary contract; the demo sentence is the closure criterion T03 must satisfy.

## Constraints

- **Bash 3.2+ / POSIX sh** for any shell helpers. `jq` required for JSON parsing (already a project dependency per the existing probe).
- **AD-19 (script-file shape)** — all verifier internals stay clean; the threshold-extraction step in the harness uses temp-file shape (`bash scripts/.../m018-section-distribution.sh --format json > $TMP; THRESHOLD=$(jq -r '...' $TMP)`) rather than inline `$(... | ...)`.
- **Constitution Principle II (Evidence Before Claims)** — the spec amendment cites the probe output and model assumptions verbatim. The threshold value is not paraphrased or rounded for narrative impact; the rounded number is the one a reader can re-derive from the audit trail.
- **Constitution Principle VI (State on Disk Is Truth)** — probe outputs go to `.orchestrator/scratch/` (durable); the spec amendment is a real edit (not a comment); the summary is committed alongside.
- **Spec amendment is byte-surgical** — use `Edit` to change exactly the SC-9 paragraph and the `Last Revised:` line. Do not reformat surrounding text. Confirm the diff before commit.
- **Idempotency** — running T03 twice should produce identical output. The probe is seed-pinned (T02 step 3); the spec edit is a one-shot replacement of the placeholder block, so re-running detects the already-amended state and is a no-op (the SC-9 verifier in step 5 documents this contract).

## Expected Output

```
$ bash scripts/verify/m018-p00-emitter-parity.sh --window 20 --threshold 95
PASS: dispatch_usage parity over recent 20 payload_breakdown records: 20 dispatch_usage / 20 payload_breakdown = 100%

$ bash scripts/verify/m018-p00-sc9-calibrated.sh
PASS: SC-9 calibrated to 23.1% via P00 probe (placeholder ≥25% removed)

$ bash scripts/verify/m018-p00-summary-complete.sh
PASS: P00-SUMMARY.md complete (six required sections present, parity 100%, threshold 23.1% cited)

$ bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P00/
PASS: P00 must-haves all verified
```

After T03 closes, M018/P00 is complete and the milestone unblocks for P01 grammar-contract work.

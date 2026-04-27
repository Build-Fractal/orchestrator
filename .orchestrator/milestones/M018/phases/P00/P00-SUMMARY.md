---
schema_version: "1.0"
type: phase-summary
phase: P00
milestone: M018
status: complete
closed_at: 2026-04-27
---

# M018/P00 — Measurement Prerequisites — Summary

## Closure summary

P00 is the measurement-prerequisites phase that D028 made M018's blocking
foundation. It carried the proof for two of the conversus gate findings
(RISK-1: emitter-coverage gap; RISK-2: SC-9 placeholder threshold). The
phase landed three artifacts: a co-located `dispatch_usage` emitter inside
`scripts/dispatch/build-context.sh` so every payload_breakdown record now
ships with a sibling dispatch_usage record (T01); a section-distribution
probe with per-tier savings_ceiling estimator and 80% bootstrap CIs (T02);
and the SC-9 spec amendment that pins the threshold to a probe-derived
floor of 34.7% mean payload-token reduction (T03). With P00 closed, M018
unblocks for P01 grammar-contract work — downstream phases now have an
empirically defensible target and a real telemetry pipeline to measure
against.

## Parity result

**Path used**: B (synthetic fixture-replay).

**Rationale**: At T03 dispatch time the production union scan over
`.orchestrator/milestones/*/execution-log.jsonl` carried 2 dispatch_usage
records against 20 most-recent payload_breakdown records (10% parity);
fewer than 20 fresh dispatches had accumulated against the patched
emitter since T01 landed. Path A would have required waiting for organic
traffic, so we built the fixture-replay harness specified in the T03
plan.

**Harness**: `scripts/verify/m018-p00-fixture-replay.sh` copies the
`tests/fixtures/dispatch-state` fixture into a scratch milestones-style
tree under `.orchestrator/scratch/m018-p00-replay-root/M001/`, wipes the
log, and invokes `scripts/dispatch/build-context.sh` 20 times back-to-back
against `M001/P02/T01`. Each invocation writes a `payload_breakdown`
record AND its co-located `dispatch_usage` record to
`.orchestrator/scratch/m018-p00-replay-root/M001/execution-log.jsonl`.
The harness then mirrors that file to
`.orchestrator/scratch/m018-p00-fixture-log.jsonl` for audit-trail
visibility and runs the T01 parity verifier against the scratch root via
`--root <replay_root>`.

**Result**:

```
PASS: dispatch_usage parity over recent 20 payload_breakdown records:
      20 dispatch_usage / 20 payload_breakdown = 100% (threshold=95%)
PASS: fixture-replay parity (20 invocations against
      .../m018-p00-replay-root)
```

20 dispatch_usage / 20 payload_breakdown = **100%** parity.

**Sample window**: synthetic; all 20 records dated 2026-04-27 within the
single fixture-replay run. The `--root` flag was already supported by
T01's verifier (functionally equivalent to `--log-path`); no extension
to T01's verifier was required for Path B.

## Calibrated threshold

**Threshold floor**: **34.7%** mean payload-token reduction, sourced from
`aggregate_ceiling.low_pct` in the T02 probe JSON output.

**Per-tier 80% CIs (probe output)**:

| tier   | low_pct | mean_pct | high_pct |
|--------|---------|----------|----------|
| filter | 12.55%  | 13.08%   | 13.67%   |
| tier1  | 6.24%   | 6.31%    | 6.40%    |
| tier2  | 25.33%  | 25.49%   | 25.68%   |
| tier3  | 12.10%  | 12.22%   | 12.36%   |

**Aggregate (non-overlap-adjusted)**:

| stat       | pct   | tokens |
|------------|-------|--------|
| low (p10)  | 34.73% | 5,883 |
| mean       | 35.08% | 5,941 |
| high (p90) | 35.39% | 5,994 |

**Model assumptions** (verbatim from
`.orchestrator/scratch/m018-section-distribution-output.json`
`.model_assumptions`):

- **filter (FR-3)**: drops ~30% of Knowledge tokens, Beta(2,5) prior on
  superseded/experimental fraction.
- **tier1 (FR-5)**: drops ~50% of tool-result tokens, conditioned on ~30%
  prevalence inside Task Plan + Upstream Context.
- **tier2 (FR-6)**: head-drops ~40% of EXCESS over the 1500-tok tail
  threshold on any section that exceeds it (preserves last 1500 tok
  verbatim).
- **tier3 (FR-7)**: summarizes ~40% of EXCESS above the per-section
  budget (2000 tok) on Knowledge + Task Plan + Upstream Context;
  Standard+ intensity assumed.

**Probe inputs**: n=172 historical `payload_breakdown` records (the count
grew from 169 at T02-spec time to 172 by the T03-run dispatch time).
Bootstrap iterations: 1000. Seed: 42 (deterministic).

**Probe outputs (audit trail, durable)**:

- `.orchestrator/scratch/m018-section-distribution-output.json`
- `.orchestrator/scratch/m018-section-distribution-output.txt`

## Spec amendment

**File**: `specs/030-context-compression-layer/spec.md`

**Lines touched**: line 14 (frontmatter `Last Revised:`); line 241 (SC-9
acceptance criterion). Both edits applied with `Edit` (byte-surgical, no
surrounding-text reformat).

**SC-9 before** (parenthetical only):

> *(Per gate finding RISK-2: the prior "≥ 25%" target was unbacked and
> is replaced by a probe-derived threshold.)*

**SC-9 after** (parenthetical only):

> *(Per gate finding RISK-2 + P00 calibration: SC-9 threshold floor is
> **34.7%** mean payload-token reduction, derived from
> `scripts/diagnostics/m018-section-distribution.sh` aggregate-ceiling
> 80% CI lower bound across n=169 historical `payload_breakdown` records
> under per-tier modeling assumptions documented in the probe script.
> Probe output archived at
> `.orchestrator/scratch/m018-section-distribution-output.{json,txt}`.
> Expected mean: 35.1%; optimistic ceiling: 35.4%.)*

**Frontmatter `Last Revised:` after**: appended
"**2026-04-27 (P00 close)**: SC-9 threshold pinned to 34.7% per
probe-derived 80% CI lower bound."

**Commit reference**: see git log on branch `feat/m018-context-compression`
for the T03-closing commit; message references D028, parity figure
(100% over 20 dispatches via fixture-replay), threshold value (34.7%),
and the probe-output audit trail.

## Risk-mitigation traceability

This is the audit trail D028 promised P00 would carry. Every conversus
gate risk maps to a mitigation, a delivering task, and a mechanical
verifier whose passing exit code closes the loop.

- **RISK-1 (emitter-coverage gap, 1.2% parity)** → **MIT-1 (co-locate
  `dispatch_usage` emit with `payload_breakdown` inside
  `build-context.sh`)** → **T01** (added
  `_bc_emit_dispatch_usage_colocated`, `--emission_point=build-context`
  disambiguator, additive per CON-5) → **T03 step 1** (Path B
  fixture-replay parity verifier returned 100% parity over 20 dispatches)
  → verifier `scripts/verify/m018-p00-emitter-parity.sh --window 20
  --threshold 95 --root <replay_root>` exits 0.

- **RISK-2 (SC-9 "≥ 25%" placeholder unbacked)** → **MIT-2 (run
  empirical probe over n≥169 historical payload_breakdown records,
  derive threshold from aggregate_ceiling 80% CI lower bound)** → **T02**
  (built `scripts/diagnostics/m018-section-distribution.sh` with per-tier
  bootstrap CIs, deterministic seed, dual text/json output, model
  assumptions emitted verbatim in `model_assumptions{}`) → **T03 steps
  3-5** (extracted `aggregate_ceiling.low_pct=34.7342` → rounded 34.7%,
  applied byte-surgical spec amendment citing probe outputs and model
  assumptions, shipped `scripts/verify/m018-p00-sc9-calibrated.sh`) →
  verifier exits 0.

- **RISK-3 (US-7 priority and conversus gate Q-1/Q-2 resolution)** is
  spec-side only and was already addressed by the original 2026-04-27
  spec revision (US-7 promoted P3→P2; Q-1/Q-2 resolved). No P00 task
  carries it; tracked here for traceability completeness.

## Followups for downstream phases

- **P01 (grammar-contract)**: SC-9 floor is now 34.7%, not "≥ 25%". The
  grammar-contract design must show, at minimum, that the planned tier
  pipeline can plausibly deliver 35% aggregate savings under the probe's
  per-tier modeling assumptions (the probe carries the receipts; P01's
  conversus gate should re-verify the modeling assumptions are fair).

- **P03 (minimal-slice)**: SC-3 / SC-4 fixture-replay tests should reuse
  the `tests/fixtures/dispatch-state` shape that
  `scripts/verify/m018-p00-fixture-replay.sh` already exercises;
  build-context.sh's fixture mode (where `ORCH_ROOT/phases` exists and
  ORCH_ROOT is not under `.../milestones/<M###>`, log written to
  `ORCH_ROOT/execution-log.jsonl`) is verified working end-to-end.

- **P05 (M027 surface integration)**: some `dispatch_usage` records will
  carry `emission_point: build-context` instead of `dispatch-interface`
  -- this is by construction (T01 chose Option 1 co-location to close
  the parity gap). Cost rollups, anomaly detection, and the efficiency
  footer must group-by the `emission_point` field cleanly OR ignore it
  (CON-5 additivity guarantees pre-M018 records remain valid). Cost is
  unaffected: pricing is computed identically regardless of emit site.

- **P06 / P07 (parity audit + SC-9 final report)**: SC-9 must report the
  measured reduction against the 34.7% floor; a measured reduction below
  the floor is a spec-failure regardless of mean. The probe output is
  durable in `.orchestrator/scratch/`; future runs of
  `scripts/diagnostics/m018-section-distribution.sh` against post-M018
  data can compare delta against the pre-M018 baseline captured here.

- **General**: parity verifier already accepts `--root <dir>`
  (functionally equivalent to `--log-path`); fixture-replay-style
  regression tests are cheap to add for any future emitter parity gate.

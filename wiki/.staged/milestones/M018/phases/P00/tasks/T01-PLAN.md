---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P00"
milestone: "M018"
name: "Diagnose and patch dispatch_usage emitter coverage gap"
depends_on: []
---

## Prerequisites

None — this is the first task in P00. The empirical evidence of the gap is already on disk:

- Telemetry probe report at `.orchestrator/scratch/m018-telemetry-probe-report.txt` shows `Records found: payload_breakdown=169  dispatch_usage=2` across all milestones — a 1.2% parity ratio where ≥ 95% is required.
- The probe script that produced that report lives at `.orchestrator/scratch/m018-telemetry-probe.sh`.

## Description

Find the structural reason `dispatch_usage` JSONL records fire only ~1% as often as `payload_breakdown` records, and land a fix so that every dispatch path that emits `payload_breakdown` also emits `dispatch_usage`. Ship a parity-verifier script that asserts ≥ 95% parity across a configurable sample window of recent execution-log records.

The current asymmetry: `_bc_emit_payload_breakdown()` lives in `scripts/dispatch/build-context.sh` (line ~1042) and is invoked at the end of every `build-context.sh` run. `_di_emit_dispatch_usage()` lives in `scripts/dispatch/dispatch-interface.sh` (line ~141) and is invoked at the end of every `dispatch-interface.sh` run. The gap exists because most production dispatch paths construct payloads via `build-context.sh` but do NOT route execution through `dispatch-interface.sh` — they hand the payload off to the runtime's native dispatch (e.g., Claude Code's Agent tool) without invoking the dispatch interface wrapper.

Pick the cheapest fix that achieves parity:

1. **Co-locate emission** (likely simplest): emit `dispatch_usage` from `build-context.sh` immediately after `payload_breakdown`, with `output_tokens_estimate=0` and a marker like `"source":"estimate","emission_point":"build-context"` to disambiguate from full-pipeline dispatches that pass through `dispatch-interface.sh`. This guarantees parity by construction.
2. **Wire dispatch-interface.sh into build-context's caller**: identify what calls `build-context.sh` and route the result through `dispatch-interface.sh`. Higher-touch; risks regressing other [M019](../../../../../milestones/M019/index.md) invariants.
3. **Add a third emission point** at whatever common chokepoint exists. Investigate the actual call graph before choosing.

Option 1 is the recommended default unless the investigation reveals a structural reason it would corrupt M019's emitter contract. Document the choice rationale in the commit message and reference it from P00-SUMMARY.md (T03 will pick this up).

## Steps

1. **Trace the dispatch call graph.** Read `scripts/dispatch/build-context.sh` and `scripts/dispatch/dispatch-interface.sh` end-to-end. Identify every caller of each (`grep -rn "build-context.sh\|dispatch-interface.sh" scripts/ commands/ packaging/`). Document in a scratch note where the asymmetry originates.

2. **Read M019/P01 verifiers** (`scripts/verify/m019-p01-emitter-presence.sh`, `scripts/verify/m019-schema.sh`) to confirm what invariants the emitter contract guarantees. The fix must not regress them.

3. **Apply the fix.** If choosing Option 1 (co-location): add a new helper in `build-context.sh` (or call `_di_emit_dispatch_usage` directly if the pricing/sourcing dependencies are reachable from `build-context.sh`) that emits a minimal `dispatch_usage` record after `_bc_emit_payload_breakdown`. The minimal record must satisfy `scripts/verify/m019-schema.sh` — meaning it carries `record_type`, `unitId`, `milestone`, `phase`, `task`, `backend`, `input_tokens_estimate`, `output_tokens_estimate`, `pricing_version`, `model`, `source`, `timestamp` (plus either `estimated_cost_usd` or `pricing_warning`). Use the same `payload_tokens_estimate` value for `input_tokens_estimate` and emit `output_tokens_estimate=0` (real output is unknown at build-context time).

4. **Add an `emission_point` field** (additive; back-compat per CON-5) so downstream rollups can distinguish full-pipeline `dispatch_usage` records from build-context co-located ones. Values: `"dispatch-interface"` (the existing happy/failure paths) or `"build-context"` (the new co-located path). Update `_di_emit_dispatch_usage` to also stamp `"emission_point":"dispatch-interface"`.

5. **Write the parity verifier** at `scripts/verify/m018-p00-emitter-parity.sh`:
   - Reads `.orchestrator/milestones/*/execution-log.jsonl` (the same union the telemetry probe uses).
   - Counts the most recent N `payload_breakdown` records and the most recent N `dispatch_usage` records, where N defaults to 20 and is configurable via `--window N`.
   - Computes parity as `dispatch_usage_count / payload_breakdown_count` over the same time window (use the timestamp of the Nth-from-last `payload_breakdown` as the lower bound for the `dispatch_usage` count).
   - Threshold defaults to 95% and is configurable via `--threshold P` (integer 0–100).
   - Exits 0 when parity ≥ threshold; exits 1 with a diagnostic line otherwise.
   - Single-script-file shape (AD-19): no inline `$(... | ...)`, no plain subshells, no compound chains > 2.

6. **Run the verifier locally** against the historical log to confirm it correctly *fails* before any new dispatches accumulate (sanity check on the failure path), then leave it for T03 to gate the 20-dispatch sample.

7. **Run M019/P01 verifiers** to confirm no regression: `bash scripts/verify/m019-p01-emitter-presence.sh` and `bash scripts/verify/m019-schema.sh`. Both must still pass.

## Must-Haves

This task addresses the phase must-have:

- Truth: "The `dispatch_usage` JSONL emitter fires on real dispatches at parity ≥ 95% with `payload_breakdown` over a 20-dispatch sample." — implemented by the fix in step 3 + verifier in step 5.
- Artifact: `scripts/verify/m018-p00-emitter-parity.sh` — created in step 5.

## Verification

- `bash scripts/verify/m019-p01-emitter-presence.sh` — must pass (no regression).
- `bash scripts/verify/m019-schema.sh` — must pass (additive `emission_point` field accepted; new emission site honors the contract).
- `bash scripts/verify/m018-p00-emitter-parity.sh --window 5 --threshold 0` — must return parity > 0 immediately after a single fresh dispatch (smoke check that the emitter wires up).

The 95% gate against the 20-dispatch sample is T03's verification, not T01's. T01 ships the *machinery*; T03 runs the sample.

## Inputs

### From Previous Tasks

None — first task.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — owns `_bc_emit_payload_breakdown` (line ~1042). Key API: `_bc_emit_payload_breakdown <payload_capture_path>`. Key types: writes a JSON line with `record_type`, `unitId`, `milestone`, `phase`, `task`, `payload_chars`, `payload_tokens_estimate`, `token_estimate_method`, `section_tokens`, `model`, `source`, `timestamp`. Behavioral contract: append-only to `.orchestrator/milestones/<m>/execution-log.jsonl`.
- `scripts/dispatch/dispatch-interface.sh` — owns `_di_emit_dispatch_usage` (line ~141). Key API: `_di_emit_dispatch_usage [reason]` where `reason` is empty for happy path, `"adapter-failed"` / `"adapter-malformed"` for failure paths. Key types: writes a JSON line with `record_type`, `unitId`, `milestone`, `phase`, `task`, `backend`, `input_tokens_estimate`, `output_tokens_estimate`, `estimated_cost_usd` (or `pricing_warning`), `pricing_version`, `model`, `source`, `timestamp`.
- `.orchestrator/scratch/m018-telemetry-probe.sh` — the read-only aggregator that surfaced the gap. Reuse its log-scanning pattern (`for log in .orchestrator/milestones/*/execution-log.jsonl; do … done`) for the parity verifier.
- `.orchestrator/scratch/m018-telemetry-probe-report.txt` — baseline numbers (169 vs 2). Reference these in the commit message and P00-SUMMARY.
- `scripts/verify/m019-schema.sh` — schema gate for emitter records. Read first to understand which fields are required vs optional.
- `scripts/verify/m019-p01-emitter-presence.sh` — presence gate. Read first; the fix must not regress it.

## Constraints

- **Bash 3.2+ / POSIX sh** (NFR-200, MEM001) — no Bash 4 features.
- **AD-19 (script-file shape)** — all `Check:` and verification commands are single-script-file invocations. No inline `(…)`, no `$(... | ...)`, no compound chains > 2.
- **CON-5 (additive emitter schema)** — `emission_point` field is additive; pre-M018 records remain valid (missing field → `null` under jq filters); existing M019 verifiers must accept records both with and without it.
- **Constitution Principle II (Evidence Before Claims)** — the parity verifier asserts a number (the parity ratio); it does not paraphrase intent.
- **Constitution Principle VII (No Hidden State)** — the verifier reads `.orchestrator/milestones/*/execution-log.jsonl` (canonical state) and writes nothing.
- **Pre-bash-shape-guard hook (AP-009)** — the hook will reject scripts that violate shape rules at commit time. Run shape-guard locally before claiming completion: `bash scripts/hooks/pre-bash-shape-guard.sh` if available, or just keep verifier internals clean.

## Expected Output

```
$ bash scripts/verify/m019-p01-emitter-presence.sh
PASS: M019/P01 emitter presence

$ bash scripts/verify/m019-schema.sh
PASS: M019 schema

$ bash scripts/verify/m018-p00-emitter-parity.sh --window 5 --threshold 0
PASS: dispatch_usage parity over recent 5 payload_breakdown records: <N> dispatch_usage / <M> payload_breakdown = <P>%
```

The 95%-over-20-sample run is T03's job; T01 only proves the machinery is in place and not regressing M019 invariants.

---
schema_version: "1.0"
type: acceptance-evidence
milestone: "M030"
recorded_at: "2026-05-01T02:57:14Z"
battery_summary: "pass=22 fail=0"
runner: "tests/m030-acceptance/run-acceptance-battery.sh"
---

# M030 Acceptance Evidence

This file is the one-shot evidence ledger of the M030 acceptance-battery green run captured at `recorded_at`. The battery is the contract; this ledger is the audit trail. Re-running the battery later may produce drift (timestamps, JSONL records); this file freezes the green-run state at milestone close.

## Battery Summary

`BATTERY: pass=22 fail=0` — emitted by `tests/m030-acceptance/run-acceptance-battery.sh` on `2026-05-01T02:57:14Z`.

The battery is a straight-line aggregator over 22 verifier invocations covering 14 M030 success criteria (SC-1 through SC-11 inclusive of SC-2a / SC-3a / SC-7a, with SC-2 / SC-8 / SC-11 each carrying multiple sub-gates). The pass count is informational; the binding contract is `fail=0`.

## Evidence

| SC | Verifier(s) | Canonical key line |
|----|-------------|--------------------|
| SC-1 | `tools/verify/p01-classifier-determinism.sh` + `tools/verify/p01-classifier-perf-and-network.sh` | `SUMMARY: p01-classifier-determinism.sh pass=4 fail=0` / `SUMMARY: p01-classifier-perf-and-network.sh pass=2 fail=0` |
| SC-2 (ready) | `tools/verify/p07-corpus-50-per-class-ready.sh` | `flip_recommendation=ready` (asserted; `SUMMARY: p07-corpus-50-per-class-ready.sh pass=2 fail=0`) |
| SC-2 (evidence_insufficient) | `tools/verify/p07-corpus-zero-evidence-insufficient.sh` | `flip_recommendation=evidence_insufficient` (asserted; `SUMMARY: p07-corpus-zero-evidence-insufficient.sh pass=2 fail=0`) |
| SC-2 (partially_ready) | `tools/verify/p07-corpus-2-class-partially-ready.sh` | `flip_recommendation=partially_ready` + `withheld_classes=novel` enumeration (asserted; `SUMMARY: p07-corpus-2-class-partially-ready.sh pass=3 fail=0`) |
| SC-2 (block) | `tools/verify/p07-corpus-block.sh` | `flip_recommendation=block` (asserted; `SUMMARY: p07-corpus-block.sh pass=2 fail=0`) |
| SC-2a | `tools/verify/p04-sc2a-shadow-gate-block.sh` | `SUMMARY: p04-sc2a-shadow-gate-block.sh pass=3 fail=0` |
| SC-3 | `tools/verify/p04-sc3-live-mechanical.sh` | `SUMMARY: p04-sc3-live-mechanical.sh pass=3 fail=0` |
| SC-3a | `tools/verify/p02-sc3a-roundtrip.sh` | `SUMMARY: p02-sc3a-roundtrip.sh pass=6 fail=0` (6 records: 2 mechanical/fast + 2 standard/balanced + 2 novel/smart all round-trip-correct) |
| SC-4 | `tools/verify/p04-sc4-escalation-sequence.sh` | `SUMMARY: p04-sc4-escalation-sequence.sh pass=6 fail=0` |
| SC-5 | `tools/verify/p04-sc5-escalation-cap.sh` | `SUMMARY: p04-sc5-escalation-cap.sh pass=6 fail=0` |
| SC-6 | `tools/verify/p03-sc6-frontmatter-override.sh` | `SUMMARY: p03-sc6-frontmatter-override.sh pass=4 fail=0` |
| SC-7 | `tools/verify/p03-sc7-kill-switch.sh` | `SUMMARY: p03-sc7-kill-switch.sh pass=2 fail=0` |
| SC-7a | `tools/verify/p03-sc7a-compound.sh` | `SUMMARY: p03-sc7a-compound.sh pass=3 fail=0` |
| SC-8 | `tools/verify/p05-by-model-cost-rates-present.sh` + `tools/verify/p05-by-model-cost-rates-absent.sh` + `tools/verify/p05-by-model-dispatch-counts.sh` | `SUMMARY: p05-by-model-cost-rates-present.sh pass=5 fail=0` / `SUMMARY: p05-by-model-cost-rates-absent.sh pass=5 fail=0` / `SUMMARY: p05-by-model-dispatch-counts.sh pass=3 fail=0` (counts 14/7/2 over 23) |
| SC-9 | `tools/verify/p05-doctor-config-check.sh` | `SUMMARY: p05-doctor-config-check.sh pass=1 fail=0` (delegates to p01-doctor-config-check.sh; well-formed routing.yml passes, malformed fixture fails with file:line diagnostic) |
| SC-10 | `tools/verify/p01-classifier-ground-truth.sh` | `OK: agreement 36/40 (90%) meets >=85% threshold` / `SUMMARY: p01-classifier-ground-truth.sh pass=1 fail=0` |
| SC-11 | `tools/verify/p05-sc11-rollup-byte-equality.sh` + `tools/verify/p05-sc11-footer-byte-equality.sh` + `tools/verify/p06-sc11-byte-equality.sh` | `SUMMARY: p05-sc11-rollup-byte-equality.sh pass=1 fail=0` / `SUMMARY: p05-sc11-footer-byte-equality.sh pass=1 fail=0` / `SUMMARY: p06-sc11-byte-equality.sh pass=1 fail=0` |

## Cross-Surface Coherence

The two phase-suite-only gates that don't appear in the spec.md SC list but verify roadmap-line-64 contracts:

- `tools/verify/p07-partial-flip-jsonl-fields.sh` — partial-flip JSONL field shape verified at acceptance scale (real-dispatch path against `corpus-2-class-only.jsonl` with `model_routing.live: true` against a `novel`-classified plan; asserts `partial_flip_active=true` AND `withheld_classes` containing `novel`). Green: `SUMMARY: p07-partial-flip-jsonl-fields.sh pass=3 fail=0`.
- `tools/verify/p07-cross-surface-coherence.sh` — metrics-rollup `--by-model` + efficiency-footer `model_mix:` + check-anomalies `model_routing_regression` coherent output against the 150-record corpus (50/50/50 over fast/balanced/smart; aggregated_cost_usd + counterfactual_all_smart_cost_usd lines present; zero regression records emitted). Green: `SUMMARY: p07-cross-surface-coherence.sh pass=9 fail=0`.

## Provenance

- Battery runner SHA at recording time: `c628bc4ea40a522d13e4af85c70655f2361afeed` (output of `git rev-parse HEAD:tests/m030-acceptance/run-acceptance-battery.sh`).
- Corpus synthesizer SHA at recording time: `a3cf00affdf61a8e4025e0ef1d997fe4ba2a2ae3` (output of `git rev-parse HEAD:tests/m030-acceptance/shadow-corpus-fixtures.sh`).
- Recording machine: `Darwin 24.6.0 arm64` (output of `uname -srm`; ledger captures runtime context for audit).

## Re-running the Battery

```bash
bash tests/m030-acceptance/shadow-corpus-fixtures.sh
bash tests/m030-acceptance/run-acceptance-battery.sh
```

Idempotent corpus + replay-able battery. Re-running produces a fresh `BATTERY: pass=N fail=0` line; this ledger captures the milestone-close green run.

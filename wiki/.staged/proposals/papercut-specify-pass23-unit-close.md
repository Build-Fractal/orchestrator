---
type: paper-cut
status: open
created: 2026-05-03
source: M032 dogfood — observed during `orchestrator:specify` run for spec 035 (wiki distribution + init integration); observability gap surfaced in routine post-run cleanup.
investigate-by: next M014/M021-style observability tail, or before M032 enters planning if a downstream consumer (e.g., `orchestrator:cost` retrospective rollup) starts depending on Pass-3 records.
---

# Paper-Cut: `orchestrator:specify` emits a Pass-1 `unit_close` only — Pass 2 + Pass 3 never log a follow-up

## Symptom

After running `orchestrator:specify` end-to-end for spec 035 (Pass 1 scaffold + Pass 2 author + Pass 3 conversus gate, all completed; gate verdict PASS; MIT-001..MIT-011 mitigations folded back into spec body), `.orchestrator/execution-log.jsonl` contains only one `unit_close` record for the run:

```jsonl
{"type":"unit_close","ts":"2026-05-03T18:07:20Z","command":"orchestrator:specify","specs_scaffolded":1,"dual_writes":2,"conversus_invocations":0,"adapter_verdicts":"","elapsed_ms":0,"source":"runtime"}
```

This was emitted at 18:07:20 — the moment Pass 1 (scaffold) finished. Subsequent activity is invisible to the execution log:

- 18:41:30 — `spec_complexity_probe` shows `fr_count=22`, `user_story_count=8`, `todo_count=0` (Pass 2 author had clearly run; spec went from 1 FR / 1 US / 19 TODOs at scaffold to 22 FRs / 8 USs / 0 TODOs)
- 20:50:28 — second `spec_complexity_probe` (Pass-3 gate pre-flight); `specs/035-*/conversus/gate-result.md` written with verdict=PASS, surviving_disputes=0
- Spec body amended to fold MIT-001..MIT-011 from `conversus/summary/final.md`

None of this — the author pass running, the gate adapter being invoked, the verdict, the mitigation fold-in — produces any `unit_close` (or follow-up `unit_close`) record.

## Contrast with the documented contract

`commands/specify.md` § Observability:

> At the end of the run:
> - Append one `unit_close` record to `.orchestrator/execution-log.jsonl` with `{command, specs_scaffolded, dual_writes, author_pass_ran, clarify_invocations, conversus_invocations, adapter_verdicts, resolved_intensity, elapsed_ms, source: "runtime"}`.

The doc contracts a *single* end-of-run record carrying full Pass 2/3 metadata. What the runtime emits today is a Pass-1-only record with the Pass-2/3 fields hardcoded to falsy/empty values:

| Documented field | Spec 035's actual value | Reality on disk |
|------------------|-------------------------|------------------|
| `author_pass_ran` | (absent) | true (22 FRs authored) |
| `conversus_invocations` | `0` | 1 (gate-result.md exists) |
| `adapter_verdicts` | `""` | `{"spec-pressure-test": "PASS"}` |
| `resolved_intensity` | (absent) | full (gate ran with arbiter) |
| `surviving_disputes` | (absent) | 0 |
| `findings_appended_to_open_questions` | (absent) | 11 (MIT-001..011 folded) |
| `shape_lint` | (absent) | 10/10 |

Compare to spec 032 ([M030](../milestones/M030/index.md), 2026-04-30) which emitted a Pass-3-aware record:

```jsonl
{"timestamp":"2026-04-30T02:25:51Z","event":"unit_close","command":"orchestrator:specify","specs_scaffolded":1,"spec_path":"specs/032-adaptive-model-selection/spec.md","dual_writes":2,"author_pass_ran":true,"clarify_invocations":0,"conversus_invocations":1,"adapter_verdicts":{"spec-pressure-test":"PASS"},"resolved_intensity":"standard","gate_status":"degraded_pass","gate_note":"...","probe_verdict":"above-threshold","probe_reason":"fr_count>=15","fr_count":19,"user_story_count":6,"shape_lint":"10/10","source":"runtime"}
```

So the rich-record code path exists and was wired correctly at least once. Something — a refactor between 2026-04-30 and 2026-05-03 — bypassed it on the spec 035 run.

## Root cause (hypothesis — needs source-walk)

`scripts/specify/specify.sh` likely emits the Pass-1 `unit_close` unconditionally at the end of scaffold (the early-exit path for Quick intensity / scaffold-only mode), and the Pass 2 + Pass 3 wrappers add to the same JSONL stream but never *replace* or *follow up on* the Pass-1 record. When a single invocation chains all three passes, the consumer sees only Pass 1's bookkeeping.

Two clean fixes:

1. **Defer the `unit_close` emission until the run truly ends.** Pass 1 emits a `specify_pass1_complete` record (or no record at all); the final emission point sits after Pass 3 (or after Pass 2 for Standard, after Pass 1 for Quick) and carries the merged metadata.
2. **Emit a separate `unit_close` per pass with `pass: 1|2|3`** and let downstream consumers reduce. Loses the single-record-per-run contract documented in `commands/specify.md` but is non-destructive of historical records.

(1) matches the documented contract; (2) is mechanically simpler if specify.sh is structured as three independent driver functions today.

## Bug class

**Observability gap, not a behavioral bug.** The spec was authored, gated, and amended correctly on disk. Only the audit trail is missing. Downstream impact:

- `orchestrator:cost` retrospective rollups undercount Pass 2 + Pass 3 work (no tokens / cost / duration recorded for the conversus invocation).
- Future `orchestrator:doctor` checks that look for "specify ran but no gate verdict" cannot distinguish "skipped gate intentionally" from "gate ran but log lost it".
- Knowledge layer's MEM accretion pattern (record-the-call, then mine-the-pattern) misses these calls entirely.

Not blocking [M032](../milestones/M032/index.md) entry into planning — the spec is shippable without this observability fix — but worth catching before M030's adaptive-model selection starts depending on richer per-command cost/quality signals that this gap will hide.

## Reproduction

1. From a clean working tree: `bash scripts/specify/specify.sh --description "<some non-trivial prose>" --intensity full`
2. Run all three passes to completion (Pass 3 should produce a `conversus/gate-result.md` with PASS verdict).
3. `tail -10 .orchestrator/execution-log.jsonl | jq 'select(.command == "orchestrator:specify")'`
4. Observe: a single record from the end of Pass 1 with `conversus_invocations: 0` and `adapter_verdicts: ""`.
5. Diff against spec 032's record (2026-04-30) for the rich shape that the doc contracts.

## Suggested resolution

Lift the `unit_close` emission to a `finally`-style block at the very end of `specify.sh`, with all three pass results aggregated into the record. Add a regression test under `tests/` that runs the three-pass flow against a fixture and asserts the emitted record carries `author_pass_ran:true`, `conversus_invocations:>=1`, and a non-empty `adapter_verdicts` object.

Estimated cost: ≤ 1 hour (single-file edit + test). Demand-driven; ship when M030/[M031](../milestones/M031/index.md) cost-and-quality consumers start reading these records.

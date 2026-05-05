---
type: paper-cut
status: open
created: 2026-05-03
source: M032 + M033 paired roadmap session — observed when authoring `M032-ROADMAP.md` and `M033-ROADMAP.md` after the 2026-05-03 finalize. Sibling paper-cut to `papercut-specify-pass23-unit-close.md` (also from M032 dogfood, same day).
investigate-by: M027/M019 observability tail; or before M029 / M035 enter planning, since both consume per-command cost/quality data and the missing roadmap records will under-count their input.
---

# Paper-Cut: `orchestrator:roadmap` emits no `unit_close` record at all — entire stage is invisible to the execution log

## Symptom

After running `orchestrator:roadmap` end-to-end for milestone M032 (Tier C, with finalized context draft, producing `M032-ROADMAP.md` with 4 phases + cross-cutting concerns + dependency graph + execution order + validation per `templates/roadmap.md`), `.orchestrator/execution-log.jsonl` contains zero records reflecting the run. The same holds for the immediately-following M033 roadmap run.

`grep -E 'orchestrator:roadmap|"command":"roadmap"|roadmap.*unit_close' .orchestrator/execution-log.jsonl` returns nothing — neither in the M030/M031 historical run-up nor in today's M032/M033 sessions.

The skill *did* run successfully — the roadmap files are on disk, the YAML frontmatter is well-formed, `derive-phase.sh` continues to return `planning` (which is correct for "roadmap exists, plan-phase pending" per the documented state-machine collapse). Only the audit trail is missing.

## Contrast with the documented contract

`commands/roadmap.md` documents *no* observability contract:

```
$ grep -nE 'unit_close|execution-log|Observability' commands/roadmap.md
(no matches)
```

There is no `## Observability` section, no `unit_close` mention, no JSONL emission requirement anywhere in the skill instructions. So the runtime is not in *violation* of a documented contract — there is no contract at all.

This is structurally worse than the `specify` Pass-2/3 gap (`papercut-specify-pass23-unit-close.md`): specify at least emits a Pass-1 record and has a documented (if mis-implemented) contract. Roadmap emits nothing and contracts nothing.

Compare to peer skills that *do* emit on completion:

- `orchestrator:specify` — emits one `unit_close` per run (Pass 1 only today; Pass 2/3 enrichment is the sibling paper-cut)
- `orchestrator:dispatch` — emits `unit_close` per dispatched task (Tier 1 observability, M019)
- `orchestrator:verify` — emits `unit_close` per verification run (M027 cost rollup consumer)
- milestone close (validate-milestone.sh) — appends one milestone-grain `unit_close` (SC-14 across M030/M031/M032/M033 specs)

The roadmap stage is the *only* major orchestrator skill that produces no observability emission.

## Bug class

**Observability gap (silent), not a behavioral bug.** Roadmap files are authored correctly on disk. Downstream impact:

- `orchestrator:cost` retrospective rollups under-count roadmap-stage work (no tokens / cost / duration recorded). For M032/M033 paired-launch coordination, the roadmap session is non-trivial — both contexts must be loaded simultaneously, the dependency graph reasoning crosses both milestones — and that work is invisible to the cost ledger.
- M027 efficiency-footer + M030 adaptive-model selection both consume per-command cost/quality signals and have no signal for roadmap stages — they cannot tune intensity, model choice, or budget for a stage they cannot observe.
- M029 (roadmap visibility & CLI UX) is *the* downstream consumer of roadmap state (`orchestrator:where` tree renderer reads the roadmap file). When M029 starts asking "when was this roadmap last regenerated?", `git log` answers that question but the per-run metadata (intensity used, time spent, model invocation count, validation-section pass/fail breakdown) is not recoverable.
- Knowledge-layer MEM accretion pattern (record-the-call → mine-the-pattern) misses every roadmap call. Future MEMs about "when do roadmaps get regenerated and why" have no telemetry to ground in.

## Root cause (hypothesis — needs source-walk)

`commands/roadmap.md` is a markdown skill instruction document; the skill doesn't have a runtime emitter for `unit_close` because the contract was never specified. The sibling specify command went through the M019 Tier 1 observability emitter pass; roadmap was apparently missed in that pass (or was deferred and not picked back up).

The two clean fixes mirror the specify paper-cut's options:

1. **Add an `## Observability` section to `commands/roadmap.md`** documenting the contract, then wire a runtime emission point at the end of the skill execution. Minimum schema:

   ```jsonl
   {"event":"unit_close","ts":"<ISO8601>","command":"orchestrator:roadmap","milestone":"M###","tier":"B|C","phase_count":N,"validation_status":"pass|fail","resolved_intensity":"single-pass|basic-decomp,rationale|basic-decomp,rationale,collaborative-loop","elapsed_ms":N,"source":"runtime"}
   ```

2. **Add a generic stage-completion emitter** that any skill instruction can declare via frontmatter (`emits_unit_close: true`), avoiding per-command bespoke wiring. Aligns with the M019 Tier 1 emitter contract.

(1) is the smaller change and ships fastest; (2) is the architecturally correct fix because the *next* skill that lacks observability — likely `orchestrator:plan-phase`, `orchestrator:consolidate`, or `orchestrator:where` — will benefit too.

## Reproduction

1. From a clean working tree with M032 in `planning` state and a finalized context draft:
   ```
   bash scripts/state/derive-phase.sh .orchestrator/milestones/M032
   # → planning
   ```
2. Invoke `orchestrator:roadmap` for M032 (e.g., via Skill tool with `M032` argument).
3. Confirm the roadmap file is authored: `ls .orchestrator/milestones/M032/M032-ROADMAP.md`.
4. `grep -E 'orchestrator:roadmap|"command":"roadmap"' .orchestrator/execution-log.jsonl` → returns nothing.
5. Diff against `orchestrator:specify`'s emission shape (already on disk for spec 035's Pass-1 record at 2026-05-03T18:07:20Z) — that record exists, the analogous roadmap record does not.

## Suggested resolution

Pair this fix with the specify Pass-2/3 fix (`papercut-specify-pass23-unit-close.md`) under one PR: both are observability gaps in pre-execution skills (specify → discuss → roadmap → plan-phase), and the consuming systems (M027 efficiency-footer, M030 adaptive routing, M029 roadmap-visibility) are the same. The two paper-cuts together close the "specify-through-roadmap visibility hole" before M029 enters planning.

Estimated cost: ≤ 2 hours combined for both paper-cuts (single-file edit per skill + shared test fixture). Demand-driven; ship when M029 enters planning or when an M027/M030 consumer starts reading per-command roadmap signals — whichever comes first.

## Related

- `papercut-specify-pass23-unit-close.md` — sibling paper-cut (M032 dogfood, same day, observability gap class).
- `commands/specify.md` § Observability — the missing-from-roadmap contract this paper-cut suggests adding.
- M019 Tier 1 observability emitter (closed) — establishes the `unit_close` JSONL convention this paper-cut would extend to roadmap.
- M027 (cost+quality observability surfaces, closed 2026-04-27) — primary downstream consumer of `unit_close` records.
- M029 (roadmap visibility & CLI UX, planned pre-launch) — secondary downstream consumer of roadmap state.

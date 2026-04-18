---
schema_version: "1.0"
type: context-draft
milestone: "M019"
status: finalized
created_at: "2026-04-17T23:20:00Z"
finalized_at: "2026-04-17T23:25:00Z"
---

## Architectural Decisions

**AD-1 — Token estimation method (Tier 1): char-quartile heuristic.** The emitter uses pure-bash `chars / 4` token estimation for both `payload_breakdown` and `dispatch_usage` records. Each record carries `token_estimate_method: "char-quartile"` so downstream consumers know the accuracy class (~10–15% off vs. real BPE). No Python or vendored binary dependency in Tier 1. Tier 3 backend adapters write `source: "runtime"` records with real token counts — both representations coexist in the schema from day one.

**AD-2 — Pricing config lives at `.orchestrator/config/pricing.yml`.** Keeps state-tree concerns colocated. `ORCH_PRICING_FILE` env var overrides the path. P00 ships a one-shot populate seeded with current Anthropic public pricing for Opus 4.7 / Sonnet 4.6 / Haiku 4.5 (input + output rates per million tokens, plus `last_updated`). Hand-maintained — refresh cadence acceptable because the model list is small.

**AD-3 — `deviation_count` derived from existing fields, not newly emitted.** The unit-close emitter computes `deviation_count` retroactively from `execution-log.jsonl` (e.g., count of records where `attempt > 1`, count of `outcome != "success"` events for the unit). No new event-emission code required — fits the "additive only" constraint. If the heuristic proves insufficient in Tier 2, the schema reserves the field name; future emissions can fill it directly.

**AD-4 — Three records per dispatch (payload_breakdown + dispatch_usage + unit_close).** Schema-as-contract for Tier 2/3. Granularity = `task | phase | milestone` on `unit_close`. Source enum = `"estimate" | "runtime"`. Both cost AND quality blocks present on every `unit_close` (Goodhart guard, enforced by schema validator).

**AD-5 — Cache-stable section ordering enforced by build-context.sh.** Per Opus 4.7 cache-boundary guidance (P00 / L2): stable sections (constitution excerpt, conventions, phase truths) appear before volatile sections (current git status, task-specific state). Volatile sections wrapped in a `<dispatch-volatile>` marker. The marker itself is the schema lever for future cache-aware optimizations.

**AD-6 — Adaptive thinking, no fixed budgets.** All `thinking_budget:` syntax (or equivalents) removed from templates and intensity-gate prompt nudges. Where thinking-rate guidance is needed, it's expressed as an adaptive nudge ("think carefully; this is harder than it looks" / "prioritize responding quickly"). Constitution XV anti-pattern prohibitions stay negative by design.

**AD-7 — settings.json overwrite bug fixed inside M019/P00.** The `write-permissions.sh` regression that strips the M021 hook on every `evaluate` re-run is folded into P00 as a discrete task. Fix: when `_generated_by: speckit-orchestrator` marker is present AND the file contains hook registrations or allow-list entries beyond the generated set, the writer must merge additively (per AD-13) instead of overwriting. Verify via a regression test that runs `evaluate-preflight` against a fixture file pre-loaded with M021's hook + allow-list and asserts both survive.

**AD-8 — SC-13 regression-safety verified by full pre-existing test suite.** P00's verify gate runs the entire `tests/test-s01.sh`..`tests/test-s07.sh` suite plus `scripts/verify/anti-pattern-lint.sh` against the adapted templates. Spot-checking is insufficient — payload-shape regressions can leak through code paths that aren't obviously dispatch-facing.

## Scope Boundaries

**In scope (P00 — Opus 4.7 baseline adaptation):**
- L1: first-turn completeness block (intent + constraints + acceptance criteria + file paths) assembled from existing plan artifacts in `scripts/dispatch/build-context.sh`
- L2: cache-stable section ordering with `<dispatch-volatile>` marker
- L3: removal of all fixed thinking-budget syntax across `templates/` and `scripts/engine/intensity-gate.sh`
- L4: explicit parallel-fan-out directive when a task recipe declares parallelizable subtasks
- L5: positive-example rewrite of expressive guidance (anti-pattern prohibitions stay negative)
- `write-permissions.sh` additive-merge fix (AD-7)
- One-shot `pricing.yml` populate
- `scripts/verify/m019-p00-payload-shape.sh` gate + P00→P01 ordering check (SC-12)

**In scope (P01 — Tier 1 emitter):**
- `payload_breakdown` JSONL record emitted by `scripts/dispatch/build-context.sh` after payload assembly
- `dispatch_usage` record emitted by the dispatch interface after backend invocation
- `unit_close` records (task, phase, milestone) emitted by the summary writers
- `scripts/lib/pricing.sh` helper resolving rates from `.orchestrator/config/pricing.yml`
- Schema validator (`scripts/verify/m019-schema.sh`) enforcing record types, source enum, cost+quality pairing
- Pricing-degradation path (missing/stale → `estimated_cost_usd: null` + `pricing_warning`, never abort)
- `scripts/verify/m019-*.sh` suite + a fixture-rollup verification asset that demonstrates the records are greppable/aggregatable

**Out of scope (Tier 2, deferred):**
- `orchestrator:cost` command or any new user-facing command
- `scripts/diagnostics/metrics-rollup.sh` or `.orchestrator/metrics/*.jsonl` aggregates
- Log rotation / archive scheme
- Backend-specific runtime-actuals adapters (`adapters/backend/*/report-usage.sh`)

**Out of scope (Tier 3, far-future):**
- `orchestrator:status` efficiency footer
- `orchestrator:doctor` anomaly detection
- Auto-generated `MNNN-METRICS.md` on consolidate
- Multi-runtime parity evals
- Dashboards / charts / any UI

**Explicitly NOT touched in P00:**
- `commands/*.md` user-facing command docs
- `references/*.md`, `docs/*.md`, `README.md`, constitution
- `knowledge/**/MEM*.md` knowledge entries
- Constitution XV anti-pattern prohibitions (negative-by-design)
- Already-dispatched M011 payloads (no backfill)

## Design Constraints

**C1 — Zero-token instrumentation.** The emitter must add zero tokens to dispatch payloads and zero tokens to the orchestrator's own loop. `scripts/dispatch/build-context.sh` emits the `payload_breakdown` record *after* the payload is built, outside the payload. No LLM calls from any emitter code path.

**C2 — Goodhart pairing enforced at emission time.** Every `unit_close` record carries both a cost block (`estimated_cost_usd`, `pricing_version`) and a quality block (`verification_pass_rate`, `deviation_count`, `retry_count`). Schema validator rejects records missing either block. Bolting quality on later would be a schema migration; pairing now is ~10 lines.

**C3 — Pre-M019 log-consumer additivity.** New fields are additive only. Existing fields (`duration_s`, `outcome`, `verification_result`, `attempt`, `unitId`) keep current semantics and positions. `scripts/state/derive-phase.sh` and other existing consumers must not break against either pre-M019 or M019-emitted logs.

**C4 — Pricing degradation never aborts dispatch.** Missing `pricing.yml` or stale rates (>90 days since `last_updated`) → emit the record with `estimated_cost_usd: null` and a `pricing_warning` field naming the missing/stale state. Dispatch continues normally.

**C5 — Bash 3.2 compatibility (Constitution VIII).** No `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. Every new `.sh` file gets a line in `scripts/verify/m019-<phase>-bash32-compat.sh` (or per-phase equivalent) as part of that phase's verify suite.

**C6 — No compound bash in agent-facing content (Constitution XV + M016/M021 anti-pattern linter).** P01 emitter code is verification-script-internal (MEM004 carve-out — pipes/`$()`/awk allowed). P00 template adaptations are agent-facing — must comply with the M021 hook's 10-pattern matrix.

**C7 — P00 strictly dispatch-facing.** P00 touches templates whose output renders into payloads, recipe ordering, and intensity-gate prompt nudges. No drift into `commands/`, `references/`, `docs/`, `README.md`, or constitution edits.

**C8 — P00 must not regress existing behavior.** All `tests/test-s01.sh`..`tests/test-s07.sh` suites and `scripts/verify/anti-pattern-lint.sh` must pass unchanged against adapted templates. Adaptation aligns defaults to documented Opus 4.7 behavior — it does not change what the orchestrator does, only how its dispatches are phrased.

**C9 — P00→P01 ordering is a hard gate (SC-12).** No Tier 1 emitter record may be written to any post-M011 milestone log until P00's verify suite is green. Enforced by an ordering check in the M019 milestone validator. Backfilling adapted records after the fact is impossible — the dispatches already ran.

**C10 — Surgical scope per Constitution XV.** P00 ~5 tasks, P01 ~5–6 tasks. Combined ~2-day unit. Scope creep into Tier 2 surfaces is the documented failure mode (D009) — guard at every phase boundary.

## Open Questions

**Q1 — Token-estimate accuracy validation.** AD-1 picks `chars / 4` as the heuristic. Should P01 ship a one-shot calibration script that compares the heuristic against a reference tokenizer on ~10 sample payloads and reports the actual delta (so the documented "~15%" claim is grounded)? Defer to planner — could be a P01 task or a follow-up note in M019-SUMMARY.

**Q2 — Pricing.yml schema for non-Anthropic models.** Tier 3 backend adapters may bring Codex / Cursor / OpenAI models. Should `pricing.yml` already structure the entries to accept arbitrary model names with a `provider` field, or stay Anthropic-only and refactor at Tier 3? Lean toward the former — costs ~3 lines now, migration later costs more.

**Q3 — `<dispatch-volatile>` marker syntax.** AD-5 picks `<dispatch-volatile>` but this could collide with future XML-ish parsing or confuse cache-key heuristics. Alternative: HTML comment marker (`<!-- volatile-start -->` / `<!-- volatile-end -->`). Planner picks the form during P00/L2 task plan.

**Q4 — `write-permissions.sh` fix reach.** AD-7 scopes the fix to "preserve hooks + allow-list entries beyond the generated set." Open question: should the fix also detect and preserve `defaultMode` overrides, env-var blocks, or other top-level keys the user may have added? Lean conservative — preserve everything outside the script's own generated section, identified by a `// generated:start` / `// generated:end` sentinel pair (additive change to the writer). Planner confirms the sentinel approach is safe with JSON syntax.

**Q5 — Articles-synthesis L1–L5 task granularity.** P00 has 5 documented tactics (L1–L5). Should each be a separate task (5 tasks + write-permissions fix + populate pricing + verify gate = 8 tasks) or grouped (e.g., L1+L4 are both build-context.sh changes)? Planner decides during decomposition — `gsd:plan-phase` will see the actual file deltas.

## Provenance

This context draft was finalized 2026-04-17 after a 6-question pre-planning discussion. All decisions captured here use the `AD-N` prefix to distinguish from milestone-scoped acceptance scenarios. Open questions (`Q-N`) are intentionally left for the planner to resolve during phase decomposition — they are not blockers for roadmap generation.

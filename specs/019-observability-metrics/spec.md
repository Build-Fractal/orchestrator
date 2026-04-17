# Feature Specification: Observability & Efficiency Metrics — Tier 1 (Opus 4.7 baseline adaptation + emitter)

**Feature Branch**: `019-observability-metrics`
**Created**: 2026-04-17
**Updated**: 2026-04-17 — added P00 Opus 4.7 baseline adaptation (see US5 + Problem Statement addendum)
**Status**: Draft
**Input**: User description: "Ship the Tier 1 emitter of M019 (Observability & Efficiency Metrics) as the kickoff unit immediately after M011 closes. Tier 1 is append-only: record payload composition, dispatch usage, and unit-close outcomes to the existing `.orchestrator/milestones/*/execution-log.jsonl` so that M012–M014 dogfooding produces measured data on time/tokens/$/quality across task/phase/milestone/project granularities. No UI, no rollup, no `orchestrator:cost` command — those are Tier 2/3. Pair cost fields with quality fields from day one to avoid Goodhart failure mode. Every record carries `source: \"estimate\" | \"runtime\"`. Pricing table is config-driven so stale rates degrade gracefully." **Scope addendum (2026-04-17)**: M019 also absorbs the Opus 4.7 baseline adaptation sweep (L1–L5 from `.orchestrator/scratch/articles-synthesis-2026-04-17.md`) as a prerequisite phase P00. The adaptation lands *before* the emitter so recorded baselines are taken against adapted dispatch payloads, not against pre-4.7 templates whose behavior the 4.7 release documentation directly modifies (shorter default responses, fewer default tool calls, fewer default subagents, adaptive thinking replacing fixed budgets). Skipping or deferring the adaptation would introduce a pre/post-4.7 discontinuity in every downstream cost and quality comparison (M018 compression, Tier 2/3 rollups), confounding the very decisions M019 exists to enable.

## Problem Statement

The orchestrator's constitution (Principle I — Context Minimization, Principle V — Fresh Context Per Unit) makes strong efficiency claims, but those claims are not currently auditable. `execution-log.jsonl` records `duration_s`, `outcome`, `verification_result`, and `attempt` — enough for timing and pass-rate, nothing for token cost, dollar cost, or payload composition. Decisions like "chunks-first is cheaper than raw-spec fallback" (M011/P05) or "Standard intensity is the right default" (M008) rest on intuition rather than measurement.

M019 exists to close that gap. D009 (`.orchestrator/DECISIONS.md`) frames it as a three-tier build:

- **Tier 1 — Just emit** (this spec, ~1 day). Append-only JSONL records. No UI.
- **Tier 2 — Rollup + `orchestrator:cost` command** (~3 days, deferred until after M014).
- **Tier 3 — Full polished surface** (~7 days, deferred until M014 Tier 1 data reveals what the polished surface should expose).

Tier 1 ships first so M012 (Spec Wiki), M013 (GitHub Native Integration), and M014 (Comment→Workflow Automation) — roughly three milestones of real dogfooding — produce measured baseline data. Waiting until after M014 to start measuring would mean planning Tier 2/3 and M018 (Context Compression) on speculation. Shipping Tier 1 now costs ~1 day and unblocks every downstream efficiency decision.

The scope discipline matters. D009 explicitly calls out the "just emit" framing to prevent Tier 1 from absorbing Tier 2's rollup work or Tier 3's polished-UI work. If Tier 1 grows a `scripts/diagnostics/metrics-rollup.sh` or an `orchestrator:cost` command, the whole measurement loop stalls until those ship. The spec must keep those out of scope.

### Addendum — Why Opus 4.7 Adaptation Rides With Tier 1 (P00)

Opus 4.7 (2026-04 release) shipped documented behavioral deltas vs. 4.6 that directly affect dispatch payload behavior: shorter default responses, fewer default tool calls, fewer spawned subagents, and adaptive thinking replacing fixed thinking budgets. The orchestrator's dispatch templates, context recipes, and intensity-gated guidance were authored against 4.6 defaults. Three concrete exposures:

1. **Parallel subagent fan-out is no longer implicit.** 4.7's guidance is explicit: "spawn multiple subagents in the same turn when fanning out across items or reading multiple files" must be spelled out in-payload, or the model will default to serial tool calls. Orchestrator dispatch payloads do not currently carry this directive.
2. **Fixed thinking budgets are retired.** Any template, recipe, or intensity mapping that assumes a budget knob (`thinking_budget: high`, etc.) is stale. 4.7 uses adaptive thinking; the only levers are prompt-level nudges ("think carefully; this is harder than it looks" / "prioritize responding quickly").
3. **Cache boundary structure now matters more.** 4.7 reasons more after each user turn in interactive sessions. A dispatch payload that interleaves stable context (constitution, conventions) with volatile context (current git status, task-specific state) cache-busts more aggressively under 4.7's behavior than it did under 4.6.

If the emitter ships against unadapted payloads, then L1–L5 land next phase, every M012/M013/M014 dispatch produces baseline data under one payload shape, and every post-adaptation dispatch produces baseline data under a different one. The two are not comparable. M018 compression decisions and Tier 2/3 rollups lose their reference point. Shipping P00 first eliminates the discontinuity at the cost of ~1 additional day.

P00 is scoped narrowly: dispatch-facing templates, payload structure, and intensity-gate prompt nudges. Broader template/recipe rewrites (e.g., rewriting command docs in `commands/`, rewriting reference docs) are explicitly out of scope — they do not affect dispatch payloads and therefore do not affect the baseline.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Dispatch Produces A Record With Estimated Cost And Quality Fields (Priority: P1)

When `orchestrator:dispatch` (or `orchestrator:auto` invoking dispatch) hands a task to a subagent, a single JSONL record is appended to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl` capturing the payload composition and the expected cost. No agent self-reports. No extra LLM tokens consumed for instrumentation.

**Why this priority**: Without the dispatch-time emitter, Tier 1 produces no data. This is the minimum viable Tier 1.

**Independent Test**: Dispatch one Tier-C task via `scripts/dispatch/dispatch-interface.sh` on a fixture milestone. After dispatch returns, `tail -1 .orchestrator/milestones/<Mxxx>/execution-log.jsonl` shows a new record with a `record_type` of `payload_breakdown`, a token estimate, and a pricing-derived dollar estimate.

**Acceptance Scenarios**:

1. **Given** a dispatch is initiated for a task, **When** `scripts/dispatch/build-context.sh` assembles the payload, **Then** a `payload_breakdown` JSONL record is appended with `record_type`, `unitId`, `milestone`, `phase`, `task`, `payload_chars`, `payload_tokens_estimate`, `section_tokens` (per `context-recipe.yaml` section), `model`, `source: "estimate"`, and `timestamp`.
2. **Given** a `payload_breakdown` record is written, **When** the selected backend runs the dispatch, **Then** a `dispatch_usage` record is appended with the same `unitId`, the backend name, an `input_tokens_estimate`, an `output_tokens_estimate` (placeholder — may be zero for Tier 1 if the backend does not expose completion size), an `estimated_cost_usd`, a `pricing_version` pointing to `config/pricing.yml`, and `source: "estimate"`.
3. **Given** pricing is computed, **When** `config/pricing.yml` is missing or stale (last-updated older than 90 days), **Then** the emitter still writes the record with `estimated_cost_usd: null` and a `pricing_warning` field naming the missing/stale state — never aborts the dispatch.
4. **Given** a dispatch runs, **When** instrumentation executes, **Then** it adds zero tokens to the subagent's context and zero tokens to the orchestrator's context (instrumentation is bash-only; it does not call LLMs).

---

### User Story 2 — Unit Close Records Outcome And Quality Fields Next To Cost (Priority: P1)

When a task, phase, or milestone completes (or fails), a `unit_close` JSONL record is appended that pairs timing and cost with quality signals (verification pass rate, deviation rate, attempts) so downstream analysis cannot optimize cost in isolation.

**Why this priority**: Goodhart is the primary failure mode. If Tier 1 emits cost without pairing it to quality, the first rollup spreadsheet will show "cheapest phase is best" and drive toward shortcuts. Pairing the fields at emission time is a ~10-line diff; bolting it on later is a schema migration.

**Independent Test**: Run a phase's existing task + phase summary flow on a fixture. `grep '"record_type":"unit_close"'` returns at least one task-level and one phase-level record, each containing both cost fields and quality fields.

**Acceptance Scenarios**:

1. **Given** a task completes, **When** `scripts/knowledge/write-summary.sh task ...` runs, **Then** a `unit_close` record is appended with `granularity: "task"`, the existing task fields (`unitId`, `duration_s`, `outcome`, `verification_result`, `attempt`), a rolled-up `estimated_cost_usd` summed from the task's `payload_breakdown` + `dispatch_usage` records, and a quality block with `verification_pass_rate` (1.0 or 0.0 for a single task), `deviation_count`, and `retry_count`.
2. **Given** a phase completes, **When** the phase summary writer runs, **Then** a `unit_close` record is appended with `granularity: "phase"`, the phase's task-level rollups, and a `source: "aggregate"` tag distinguishing rolled-up records from leaf emissions.
3. **Given** a milestone completes, **When** `M<xxx>-VALIDATED` is written, **Then** a `unit_close` record is appended with `granularity: "milestone"`.
4. **Given** a `unit_close` record is written at any granularity, **Then** the record contains both a cost block and a quality block — neither may be omitted.

---

### User Story 3 — Runtime Actuals Can Replace Estimates Without Schema Migration (Priority: P2)

When a backend exposes true token counts (Claude Code `SessionEnd` hook, Codex CLI usage reports, Cursor exposed metadata), the emitter writes a parallel `dispatch_usage` record with `source: "runtime"` instead of `"estimate"`. Downstream analysis can distinguish, filter, or compare the two. Tier 1 does not build the backend adapters — it only guarantees the schema supports them so Tier 3's work is additive, not a migration.

**Why this priority**: Tier 3 (`adapters/backend/*/report-usage.sh`) is far-future. But if Tier 1 bakes `source: "estimate"` as the only value, Tier 3 requires a breaking change. Adding the field now costs one line; omitting it costs a migration.

**Independent Test**: Write a record with `source: "runtime"` manually to a fixture `execution-log.jsonl`. The Tier 1 verify scripts must accept both values; the schema validator must not reject `"runtime"`; no code path may assume `source == "estimate"`.

**Acceptance Scenarios**:

1. **Given** a record's `source` field, **When** it is set to `"estimate"` or `"runtime"`, **Then** all Tier 1 verify scripts accept it.
2. **Given** a record's `source` field, **When** it is set to any other value, **Then** the schema validator rejects it.
3. **Given** the schema documents both values, **When** Tier 3 lands backend adapters, **Then** no Tier 1 record-writer needs modification (the adapters become additional emitters).

---

### User Story 4 — Tier 1 Ships Without Blocking On Any Tier 2/3 Surface (Priority: P1)

The Tier 1 emitter is complete and useful when JSONL records are being written. No rollup script, no `orchestrator:cost` command, no `orchestrator:status` efficiency footer, no `orchestrator:doctor` anomaly checks, no auto-generated `MNNN-METRICS.md` are required for Tier 1 to close.

**Why this priority**: This is the scope discipline that D009 explicitly calls out. Scope creep here delays the measurement loop for M012–M014.

**Independent Test**: Read `specs/019-observability-metrics/spec.md` Non-Goals. Every item below must be listed as out-of-scope. Then verify no `commands/cost.md`, no `scripts/diagnostics/metrics-rollup.sh`, and no changes to `commands/status.md` land in the M019 Tier 1 milestone.

**Acceptance Scenarios**:

1. **Given** Tier 1 is declared complete, **When** the orchestrator is inspected, **Then** no new user-facing command (`orchestrator:cost`, `orchestrator:metrics`, etc.) exists.
2. **Given** Tier 1 is declared complete, **When** `orchestrator:status` is run, **Then** its output is byte-identical to pre-M019 output (no efficiency footer).
3. **Given** Tier 1 is declared complete, **When** a milestone closes, **Then** no `MNNN-METRICS.md` is auto-generated.

---

### User Story 5 — Dispatch Payloads Are Adapted For Opus 4.7 Defaults Before Measurement Begins (Priority: P1)

Before the first record from US1/US2 is written in the post-M011 dogfooding period, dispatch-facing templates and payload structure are adapted to Opus 4.7's documented behavioral defaults. The adapted state — not the pre-4.7 state — is what every Tier 1 record measures.

**Why this priority**: Baseline integrity. This is the P0 ordering constraint that makes every other Tier 1 record meaningful. A record written against pre-4.7 payload shape and a record written against post-4.7 payload shape cannot be aggregated into a comparable baseline. Waiting to do the adaptation "later" creates a permanent discontinuity in the measurement record.

**Ordering**: P00 (this story) must ship before P01 (US1–US4 emitter work) begins. No Tier 1 emitter record may be written to a post-M011 milestone log until P00's verify suite is green. Backfilling adapted records after the fact is not possible — the dispatches have already run.

**Independent Test**: Build a dispatch payload via `scripts/dispatch/build-context.sh` on a fixture task before and after the P00 sweep. The post-sweep payload must (a) carry explicit parallel-subagent fan-out guidance when the task recipe declares parallelizable sections, (b) reference no `thinking_budget:` or equivalent fixed-budget knob, (c) place stable sections (constitution excerpt, conventions, phase truths) before volatile sections (current git status, task-specific state), (d) express guidance using positive examples rather than negative prohibitions where the behavior is expressive (distinct from Constitution XV anti-pattern prohibitions, which remain negative by design).

**Acceptance Scenarios**:

1. **Given** a dispatch payload is built for any task, **When** `scripts/dispatch/build-context.sh` renders the payload, **Then** the payload contains an explicit first-turn completeness block covering intent, constraints, acceptance criteria, and relevant file paths — assembled from existing plan artifacts, not added prose (L1).
2. **Given** a dispatch payload is built, **When** the payload is inspected, **Then** stable sections appear before volatile sections, and volatile sections are wrapped in a marker (e.g., `<dispatch-volatile>` or equivalent) distinguishing them from the cache-stable prefix (L2).
3. **Given** any template or recipe in `templates/` or `scripts/engine/intensity-gate.sh`, **When** it is inspected, **Then** no reference to a fixed thinking budget remains; any thinking-rate guidance is expressed as an adaptive-thinking prompt nudge (L3).
4. **Given** a task recipe declares parallelizable subtasks (e.g., fan-out across files, independent verification steps), **When** the payload is built, **Then** an explicit "spawn multiple subagents in the same turn for fan-out" directive appears in the payload (L4).
5. **Given** any dispatch-facing template in `templates/dispatch-prompt.md` or referenced by it, **When** it is inspected for expressive guidance (distinct from anti-pattern prohibitions), **Then** negative-framed instructions ("don't do X") are replaced with positive examples ("do Y") (L5).
6. **Given** P00 is declared complete, **When** P01 (emitter) begins, **Then** the anti-pattern linter, the existing `tests/test-s04-core-commands.sh` suite, and the M011 fixture end-to-end suite all pass against the adapted payloads — adaptation must not regress existing behavior, only align defaults.

---

## Success Criteria

- **SC-1**: Every `orchestrator:dispatch` run appends exactly one `payload_breakdown` and one `dispatch_usage` record to `.orchestrator/milestones/<Mxxx>/execution-log.jsonl`.
- **SC-2**: Every `write-summary.sh task` / phase summary / milestone validation run appends exactly one `unit_close` record at the matching `granularity`.
- **SC-3**: Every `unit_close` record contains both a cost block (`estimated_cost_usd`, `pricing_version`) and a quality block (`verification_pass_rate`, `deviation_count`, `retry_count`).
- **SC-4**: Every emitter-written record carries `source: "estimate"` or `source: "runtime"`; no other values pass schema validation.
- **SC-5**: `config/pricing.yml` exists, lists per-model input/output rates with `last_updated`, and is resolvable by `scripts/lib/pricing.sh` (new helper). Missing or stale (>90 days) pricing degrades to `estimated_cost_usd: null` with a `pricing_warning` — never aborts dispatch.
- **SC-6**: Instrumentation adds zero tokens to the subagent payload and zero tokens to the orchestrator loop. `scripts/dispatch/build-context.sh` emits the record *after* the payload is built, outside the payload.
- **SC-7**: Running M012 kickoff dispatches produces a valid, greppable JSONL stream that a future rollup script can consume without schema changes. (Verified by a fixture-rollup script in the Tier 1 verify suite that parses the records and prints totals — the fixture-rollup is a verification asset, NOT a shipping `orchestrator:cost` surface.)
- **SC-8**: `scripts/verify/m019-*.sh` suite passes: schema validator, emitter presence at each of the three boundaries, pricing-degradation path, source-field enum, zero-payload-token-growth regression, and a fixture end-to-end run that writes and re-reads ~10 records.
- **SC-9**: Bash 3.2 compatible (Constitution VIII). No `declare -A`. No compound bash in agent-facing content (Constitution XV via M016's anti-pattern linter).
- **SC-10**: Pre-M019 `execution-log.jsonl` files remain valid — new fields are additive; existing tools (`scripts/state/derive-phase.sh`, etc.) that consume the log must not break.
- **SC-11 (P00)**: Every dispatch payload built after P00 ships contains an explicit first-turn completeness block (intent, constraints, acceptance criteria, file paths), stable-before-volatile section ordering with a volatile-section marker, explicit parallel-fan-out guidance when applicable, and zero references to fixed thinking budgets. Verified by a new `scripts/verify/m019-p00-payload-shape.sh`.
- **SC-12 (P00)**: No Tier 1 emitter record (US1/US2) is written to any post-M011 milestone log before `scripts/verify/m019-p00-*.sh` is green. Enforced by a P00→P01 ordering check in the M019 validator.
- **SC-13 (P00)**: All pre-existing test suites (`tests/test-s01`–`test-s07`) and the anti-pattern linter pass unchanged against adapted templates. Adaptation must not regress behavior — only align defaults to Opus 4.7.
- **SC-14 (P00)**: No template or recipe retains `thinking_budget:` or equivalent fixed-budget syntax. Replaced with adaptive-thinking prompt nudges where thinking-rate guidance is needed.
- **SC-15 (P00)**: Dispatch-facing expressive guidance is stated as positive examples; Constitution XV anti-pattern prohibitions (which are negative by design) remain negative. A single review pass documents which negatives were retained and why, in the P00 task summary.

## Non-Goals

- **`orchestrator:cost` command or any other new user-facing command.** Tier 2.
- **`scripts/diagnostics/metrics-rollup.sh` or `.orchestrator/metrics/*.jsonl` aggregates.** Tier 2.
- **`orchestrator:status` efficiency footer, `orchestrator:doctor` anomaly checks, auto-generated `MNNN-METRICS.md` on consolidate.** Tier 3.
- **Backend-specific runtime-actual adapters (`adapters/backend/*/report-usage.sh`).** Tier 3. Tier 1 only reserves the `source: "runtime"` schema slot.
- **Multi-runtime parity evals across Claude Code / Codex / Cursor.** Tier 3.
- **Backfilling M011 (or any earlier milestone) with estimated records.** D009 explicitly accepts the ~15–25 unlogged M011/P04–P07 records as a clean boundary.
- **Cost optimization, compression, or model-switching decisions driven by the data.** Tier 1 emits; downstream milestones decide.
- **UI, dashboards, charts, or any visualization.** Every tier.
- **(P00) Rewriting non-dispatch-facing content.** `commands/*.md` user-facing command docs, `references/*.md`, `docs/*.md`, `README.md`, and the constitution are explicitly out of P00 scope. P00 touches only templates and scripts whose output becomes part of a dispatch payload. Broader doc modernization is a separate maintenance effort.
- **(P00) Rewriting knowledge entries (`knowledge/**/MEM*.md`).** Those are consumed by `scripts/knowledge/` tooling and scope-filtered into payloads, but they are not authored as dispatch-facing prompts. Any 4.7 adaptation of their prose is deferred.
- **(P00) Changes to Constitution XV anti-pattern prohibitions.** Those remain negative by design (safety rails, not expressive guidance). L5's "positive examples" rewrite applies only to expressive guidance.
- **(P00) Backfilling already-dispatched M011 payloads.** The adaptation applies from P00 ship forward. The ~15–25 M011/P04–P07 unlogged records noted in D009 stay unlogged; they would not have been adapted records anyway.

## Constraints

- **Must not add tokens to dispatch payloads.** Instrumentation is bash-only and runs outside the agent's context.
- **Must not add tokens to the orchestrator's own loop.** No LLM calls from emitter code paths.
- **Must not break existing `execution-log.jsonl` consumers.** Additive fields only; existing fields (`duration_s`, `outcome`, `verification_result`, `attempt`, `unitId`) keep their current semantics and positions.
- **Must pair cost with quality at every `unit_close` emission.** Goodhart guard; enforced by schema validator.
- **Must degrade gracefully when `config/pricing.yml` is missing or stale.** Emit the record with `estimated_cost_usd: null` and a `pricing_warning`; never abort.
- **Bash 3.2 compatible** (Constitution VIII).
- **No compound bash in agent-facing content** (Constitution XV + M016 anti-pattern linter).
- **Two phases.** P00 (Opus 4.7 baseline adaptation, ~1 day, target 4–5 tasks) ships before P01 (Tier 1 emitter, ~1 day, target 4–6 tasks). P01 must not begin until P00's verify suite is green. D009's "Tier 1 ~1 day" estimate predates the P00 addition; the combined M019 Tier 1 unit is now ~2 days, still a surgical unit per Constitution XV, and still the kickoff unit of M019 before M012 begins.
- **P00 adaptation must not regress existing behavior.** All pre-existing test suites and the anti-pattern linter must pass against adapted templates. Adaptation aligns defaults to Opus 4.7 documented behavior; it does not change what the orchestrator does, only how its dispatches are phrased to the model.
- **P00 scope is strictly dispatch-facing.** Templates that render into payloads, recipe ordering, and intensity-gate prompt guidance only. No drift into `commands/`, `references/`, `docs/`, `README.md`, or constitution edits.

## Out-Of-Scope Open Questions (defer to Tier 2/3)

These are explicitly NOT decisions Tier 1 makes. Capturing them here so Tier 2 planning has a starting list:

- What rollup granularity does `orchestrator:cost` default to? (Tier 2.)
- How does `orchestrator:status` surface efficiency without overwhelming the default output? (Tier 3.)
- What anomaly thresholds does `orchestrator:doctor` use to flag cost regressions? (Tier 3.)
- How are per-runtime actuals reconciled when a milestone spans runtime switches? (Tier 3.)
- Does pricing.yml live in-repo (checked in) or external (user-configured)? Tier 1 assumes in-repo with user-overridable path via env var.

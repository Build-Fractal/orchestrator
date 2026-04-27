---
schema_version: "1.0"
type: feature-spec
feature_slug: "029-m019b-cost-rollup-tier2"
created_at: "2026-04-26"
status: "Draft"
milestone: "M027"
---

# Feature Specification: M027 (M019b) — Cost-Aware Dispatch + Tier 2 Cost Rollup

**Feature Branch**: `029-m019b-cost-rollup-tier2`
**Created**: 2026-04-26
**Last Revised**: 2026-04-26 — context-draft AD-1/2/3 pinned into body; US-5 (predictive cost surface) added per strategic positioning
**Status**: Draft
**Milestone**: M027 (lineage: M019 Tier 2 / "M019b" follow-on)
**Input**: User description: "M019b — Tier 2 observability rollup CLI plus orchestrator:cost user-facing command, efficiency footer, and anomaly detection. Deferred follow-ons from M019 Tier 1 emitter. Reads payload_breakdown, dispatch_usage, and unit_close JSONL records produced by M019 Tier 1 and surfaces them via a rollup CLI and a new orchestrator:cost user-facing command. Provides task/phase/milestone/project granularity rollups, paired cost+quality views (Goodhart-safe), and anomaly detection over the JSONL stream. Backend-actuals (Tier 3) explicitly out of scope." **Scope addendum (2026-04-26 from M027-CONTEXT.md AD-4)**: M027 also ships a *predictive* cost surface — `orchestrator:cost --estimate`, `intensity-recommend.sh` cost annotations, and `orchestrator:dispatch` interactive confirmation — so operators see the recommended intensity tier and the per-tier cost estimate before committing. Strategic positioning: be the one tool for every job by always recommending the ideal intensity for the ask, surfacing the estimated cost, and giving operators one-keystroke override to a cheaper tier. The retrospective and predictive surfaces share the same rollup engine and pricing library; both are zero-LLM-token bash code paths.

## Problem Statement

M019 Tier 1 (closed 2026-04-18) emits `payload_breakdown`, `dispatch_usage`, and `unit_close` JSONL records into `.orchestrator/milestones/<Mxxx>/execution-log.jsonl` at every dispatch and every unit close. The records pair cost with quality fields per the Goodhart guard, and the schema reserves `source: estimate | runtime | aggregate` and `granularity: task | phase | milestone` enums for Tier 2/3 forward compat. Five milestones of post-M019 dogfooding (M012, M013, M014, M021, M024–M026) have produced a populated baseline. **The data exists; nothing reads it.**

Three concrete pain-points follow from that gap. First, no operator can answer "what did this milestone cost in dollars / tokens / wall-time" without piping `cat`/`jq` against raw JSONL — the records are designed to be greppable, but greppable is not the same as surfaced. Second, `orchestrator:status` reports state and progress but says nothing about efficiency, so the most-trafficked operator surface gives no signal when a milestone is burning unusual cost or producing unusual quality. Third, the JSONL stream is now large enough (multi-megabyte across mature milestones) that anomaly detection — "this dispatch cost 5× the moving median for tasks of similar payload size" — needs scripted aggregation; eyeballing it does not scale.

The minimum surface that closes all three pain-points is one rollup engine plus three thin consumers of that engine: a `scripts/diagnostics/metrics-rollup.sh` library that computes paired cost+quality aggregates at task/phase/milestone/project granularity from the existing JSONL, an `orchestrator:cost` user-facing command that prints those aggregates, an opt-in efficiency footer on `orchestrator:status`, and an `orchestrator:doctor`-invoked anomaly check that flags outliers. Tier 3 work — backend-runtime-actuals adapters, multi-runtime parity dashboards, auto-generated `MNNN-METRICS.md` on consolidate, charts/UI — is explicitly deferred so M019b stays scope-disciplined the same way Tier 1 was.

What M019b does **not** attempt: it does not change the Tier 1 emitter schema, does not introduce backend adapters that report runtime-actuals, does not optimize cost or compress payloads (those are M018), and does not produce visualizations beyond plain text. Goodhart pairing is enforced at the *output* surface (every rollup row that shows cost must also show quality); it is already enforced at emission time by Tier 1.

### Strategic Positioning — Cost-Aware Dispatch (added per M027-CONTEXT.md AD-4)

The retrospective surfaces close the data-visibility loop. They do not, on their own, change operator behavior at dispatch time — and changing dispatch-time behavior is where measurable cost wins live. M027 therefore ships a *predictive* surface alongside the retrospective one: when `intensity-recommend.sh` classifies a task, the recommendation is annotated with per-tier cost estimates (Quick / Standard / Full) so the operator sees both the recommended tier and what each tier would cost. When `orchestrator:dispatch` is about to fire interactively at Standard or Full, it surfaces a one-block confirmation showing the estimated cost and a one-keystroke override to a cheaper tier. The framing — "we recommend X, here's what each tier costs, override to cheaper at any time" — is the load-bearing UX. The retrospective rollups answer "what did this cost"; the predictive surface answers "what is this about to cost, and is there a cheaper way."

Both surfaces are zero-LLM-token (CON-6) and read-only (CON-1). The predictive estimate uses the M019 char-quartile token approximation (M019 AD-1) plus `scripts/lib/pricing.sh`. Runtime-actuals calibration (closing the loop with backend-reported actuals) is Tier 3 and remains out of scope.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 + 2 Load-Bearing Scope)

US-1 (rollup engine) is the bottom of the stack — every other story consumes it. US-2 (`orchestrator:cost` command) and US-5 (predictive cost surface) ride on top of the engine in P01; together they make the retrospective Tier 1 data visible *and* surface the predictive cost-aware dispatch decision before the cost is incurred. US-3 (efficiency footer) and US-4 (anomaly detection) are additive surfaces in P02 / P03.

### User Story 1 — Operator Gets Paired Cost+Quality Rollups Across Granularities (Priority: P1)

When an operator runs the rollup CLI against the live `.orchestrator/` tree, a single command produces a paired cost+quality view at any of four granularities (task, phase, milestone, project) without invoking jq, awk, or any LLM. The output is plain text; the underlying engine is sourceable from other scripts.

**Why this priority**: Without the rollup engine, none of the other Tier 2/3 surfaces have anything to call. This is the bottom of the stack — every other story in M019b reuses the same aggregation logic.

**Independent Test**: Run `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` against this repo. The output is a single block containing total `estimated_cost_usd`, total `payload_tokens_estimate`, mean / p50 / p95 dispatch cost, total `verification_pass_rate`, total `deviation_count`, and total `retry_count`. Exit code is 0. No new JSONL records are written by the rollup itself.

**Acceptance Scenarios**:

1. **Given** an `execution-log.jsonl` containing M019 Tier 1 records, **When** `metrics-rollup.sh --granularity task --milestone M019 --phase P01` is run, **Then** stdout shows one row per task with paired cost (sum of `dispatch_usage.estimated_cost_usd`) and quality (`verification_pass_rate`, `deviation_count`, `retry_count`) columns.
2. **Given** the same log, **When** `--granularity phase` is requested, **Then** task-level rows are aggregated into one row per phase with `source: aggregate` semantics, mirroring the Tier 1 `unit_close` aggregate convention.
3. **Given** the same log, **When** `--granularity milestone` is requested, **Then** phase-level rows are aggregated into one row per milestone.
4. **Given** the same log, **When** `--granularity project` is requested, **Then** all milestones across `.orchestrator/milestones/*/execution-log.jsonl` are aggregated into a single project-wide row.
5. **Given** any rollup row that includes a cost block, **Then** the same row also includes a quality block — Goodhart pairing at the output surface is mandatory and enforced by the verifier.
6. **Given** a record with `pricing_warning` set or `estimated_cost_usd: null`, **When** rollup runs, **Then** the warning count is surfaced in the output and the cost cell carries a "(N missing)" suffix rather than silently dropping rows.

---

### User Story 2 — `orchestrator:cost` Surfaces Rollups As A First-Class Command (Priority: P1)

When an operator runs `/orchestrator:cost` (or the runtime-equivalent skill invocation), the command prints a paired cost+quality summary scoped by sensible defaults (current milestone if one is active; project otherwise) and accepts flags to widen or narrow the scope. The command is documented in `commands/cost.md` with the same shape as other orchestrator commands.

**Why this priority**: The rollup engine is necessary but not sufficient. Operators interact with the orchestrator through commands, not loose scripts. Shipping the engine without the command leaves every M019 Tier 1 consumer one indirection away from the data they need, which is exactly the friction Tier 2 was meant to remove.

**Independent Test**: Invoke the command via the runtime adapter (Claude Code skill, Codex CLI command, Cursor command). Output is identical-modulo-formatting to `metrics-rollup.sh` invoked with the same scope. Exit code 0 on success; exit code non-zero with actionable diagnostic on missing `.orchestrator/`.

**Acceptance Scenarios**:

1. **Given** an active milestone, **When** `orchestrator:cost` is invoked with no flags, **Then** output defaults to a milestone-granularity rollup of the active milestone.
2. **Given** no active milestone, **When** `orchestrator:cost` is invoked with no flags, **Then** output defaults to a project-granularity rollup.
3. **Given** any scope flag (`--milestone`, `--phase`, `--task`, `--granularity`, `--source`, `--since <ISO8601>`), **When** the command is invoked, **Then** the scope is honored and the rollup engine is called with the equivalent arguments.
4. **Given** the command runs in a non-orchestrator project, **When** invoked, **Then** it exits with a clear "no .orchestrator/ found; run orchestrator:init first" diagnostic — never crashes.
5. **Given** the command writes to stdout only, **When** the command completes, **Then** no JSONL records are emitted by the rollup pass itself (rollups are read-only consumers — the unit_close record for `orchestrator:cost` itself is the existing dispatch-level one, not a new event surface).

---

### User Story 3 — `orchestrator:status` Surfaces An Efficiency Footer (Priority: P2)

When an operator runs `orchestrator:status`, the existing state/progress output is followed by a short opt-in efficiency footer summarizing milestone-to-date cost and quality. The footer is one block, ≤6 lines, and is suppressed under `--quiet` or via config to keep `status` byte-stable for callers that depend on its current output.

**Why this priority**: This is high-value but not load-bearing. Operators check `status` constantly; surfacing efficiency there is the highest-traffic place to make Tier 1 data visible. Lower than US-1/US-2 because the footer is a nice-to-have on top of an already-shipped command, not a new surface.

**Independent Test**: With efficiency footer enabled (default), run `orchestrator:status` against this repo. The pre-footer output is byte-identical to current `status` output; the footer appears below it. Run again with `--quiet` or `efficiency_footer: false` in `.orchestrator/config.yml`; the footer is absent and output is byte-identical to pre-M019b output.

**Acceptance Scenarios**:

1. **Given** efficiency footer is enabled, **When** `orchestrator:status` is invoked, **Then** the existing output is unchanged and a footer block titled "Efficiency (Tier 1 rollup)" follows it with milestone-to-date cost, quality, and dispatch count.
2. **Given** `--quiet` flag or `efficiency_footer: false` in config, **When** invoked, **Then** the footer is omitted and `status` output is byte-identical to pre-M019b behavior (back-compat with `orchestrator:auto` log scrapers, CI consumers, etc.).
3. **Given** an empty or missing `execution-log.jsonl`, **When** the footer would render, **Then** it prints "Efficiency: no Tier 1 records yet" rather than erroring or showing zeros.

---

### User Story 4 — `orchestrator:doctor` Flags Cost And Quality Anomalies (Priority: P2)

When an operator runs `orchestrator:doctor`, an anomaly-detection pass over the JSONL stream identifies dispatches that cost or under-perform unusually relative to the milestone's moving baseline and surfaces them as advisory diagnostics. Thresholds are config-driven; the pass is read-only and never blocks autonomous mode.

**Why this priority**: Anomaly detection is the loudest "the data is paying off" signal but it is genuinely additive to US-1 through US-3. An operator who has the rollup CLI and the cost command can do anomaly detection by hand; doctor automates the pass.

**Independent Test**: Construct a fixture milestone with one dispatch whose `estimated_cost_usd` is 5× the median of its siblings. Run `orchestrator:doctor`. The output flags that dispatch with the milestone, phase, task, observed cost, baseline, and ratio. Exit code is 0 (advisory); the user-facing diagnostic surface is doctor's existing report block.

**Acceptance Scenarios**:

1. **Given** a milestone with at least 5 dispatches in its log (insufficient sample size below 5), **When** doctor runs, **Then** an anomaly check identifies any dispatch whose cost is ≥ N× the milestone median (N defaults to 3, configurable in `.orchestrator/config.yml`).
2. **Given** the same threshold logic, **When** quality (verification_pass_rate, retry_count) is checked, **Then** dispatches with quality below the configured threshold (e.g., `retry_count > 2`) are also flagged.
3. **Given** anomalies are flagged, **When** doctor's report renders, **Then** each anomaly surfaces both the cost data and the quality data — Goodhart pairing at the alerting surface, never one in isolation.
4. **Given** sample size is below the configured minimum (default 5), **When** doctor runs, **Then** the anomaly check skips that milestone with a "insufficient sample" annotation rather than producing noisy false-positives.

---

### User Story 5 — Operator Sees Recommended Tier And Per-Tier Cost Estimate Before Dispatch (Priority: P1)

When an operator is about to dispatch a task — either explicitly via `orchestrator:cost --estimate <description>`, implicitly via `intensity-recommend.sh` output, or interactively at `orchestrator:dispatch` time — the system surfaces the recommended intensity tier (Quick / Standard / Full) alongside the estimated cost at each tier, with the recommended tier highlighted and a one-keystroke override path to a cheaper tier. The estimate uses zero LLM tokens and completes in under 100 ms.

**Why this priority**: This is the load-bearing positioning surface for M027. Retrospective rollups (US-1 through US-4) tell operators what already happened; the predictive surface lets operators control cost *before* paying it. Without US-5, M027 ships only half the value — visibility into past spend without agency over future spend.

**Independent Test**: Run `bash scripts/engine/intensity-recommend.sh --description "<sample task>"` against the post-M027 codebase. Output includes the recommendation plus a per-tier cost annotation (Quick: $X, Standard: $Y, Full: $Z). Run `orchestrator:cost --estimate "<sample task>"`. Output is the same per-tier table with the recommendation highlighted. Both invocations complete in < 100 ms; neither writes any JSONL record; neither invokes an LLM.

**Acceptance Scenarios**:

1. **Given** any task description, **When** `orchestrator:cost --estimate "<description>"` is invoked, **Then** stdout shows three rows (Quick / Standard / Full) with paired cost (estimated USD, estimated input + output tokens) and quality semantics (Quick = best-effort, Standard = self-review, Full = adversarial gate), with the recommended tier marked.
2. **Given** `intensity-recommend.sh` is invoked with `--format text` (default), **When** it prints its recommendation, **Then** the output appends a per-tier cost annotation block. With `--format json`, the JSON output gains a `cost_estimates` field carrying per-tier USD + token estimates.
3. **Given** an interactive `orchestrator:dispatch` invocation at Standard or Full intensity (not under `--yes`, not under `orchestrator:auto`), **When** the dispatch is about to fire, **Then** a one-block predictive surface displays the estimated cost and a one-keystroke override to a cheaper tier; on accept, the dispatch proceeds at the surfaced tier; on override, the dispatch proceeds at the operator-chosen tier.
4. **Given** `--yes`, `orchestrator:auto`, or `config.predictive_cost_surface: false`, **When** dispatch fires, **Then** the predictive surface is suppressed and dispatch output is byte-identical to pre-M027 behavior — non-interactive callers and CI consumers see no change.
5. **Given** any predictive estimate, **When** the estimate completes, **Then** wall-clock latency is under 100 ms on a 2024-era laptop and zero LLM tokens are spent.
6. **Given** `pricing.yml` is missing or stale, **When** the predictive surface renders, **Then** cost cells show `(unavailable)` with the same `pricing_warning` reason surfaced by the rollup engine; the recommendation still renders; the override flow still works.
7. **Given** the predictive surface displays cost, **Then** the same surface displays the per-tier quality semantics on the same row — Goodhart pairing extends to the predictive output, never showing cost without quality context.

---

## Edge Cases

- **JSONL contains pre-M019 records** (no `record_type`, no `granularity`). Rollup engine ignores any record that lacks a Tier 1 schema marker; back-compat with the historical execution-log format is mandatory (Tier 1 SC-10 carries forward).
- **`pricing.yml` is missing or stale** when rollup runs. The engine surfaces a warning count in the output but never aborts; rows with missing cost data are tagged, not dropped (mirrors Tier 1 C4 never-abort degradation).
- **A milestone has zero `unit_close` records but non-zero `dispatch_usage` records** (in-flight or crashed milestone). Rollups compute over what's present and tag the row as "incomplete (no unit_close)".
- **`source: runtime` records appear alongside `source: estimate` records** (Tier 3 backend adapter has landed for some dispatches but not others). Rollups must distinguish — operators should see "runtime" totals and "estimate" totals separately, never silently merged.
- **Operator runs the rollup against a corrupted JSONL line** (non-parseable JSON). Engine logs the line number on stderr and skips it; never crashes mid-rollup.
- **Concurrency**: rollup runs while a dispatch is mid-flight and writing to the same JSONL. The reader takes a single snapshot at start; in-flight writes after the snapshot are not double-counted.
- **`orchestrator:cost` invoked with mutually-exclusive flags** (e.g., `--task` + `--granularity milestone`). Command exits with a usage error pointing at the conflict; never silently picks one.
- **Predictive estimate with no task description** (`orchestrator:cost --estimate` with no positional arg). Command exits with a usage error showing the required signature; never produces a hallucinated cost figure.
- **Predictive estimate when pricing.yml is missing**. Cost cells render `(unavailable)`, the recommendation still renders, the override flow still works (CON-5 carries to predictive surface).
- **Operator overrides predictive recommendation to a tier the recipe cannot run at** (e.g., recipe requires Full for safety reasons). Dispatch refuses with a clear diagnostic naming the recipe constraint; predictive surface does not silently demote.
- **Concurrent dispatches**: two dispatches firing simultaneously each show their own predictive surface. Surfaces are local to the invocation; no shared state.

---

## Functional Requirements

- **FR-1 (rollup-engine)**: Provide `scripts/diagnostics/metrics-rollup.sh` that aggregates Tier 1 JSONL records into paired cost+quality rows at task / phase / milestone / project granularity. Sourceable as a library by other scripts. Satisfies US-1.
- **FR-2 (granularity-flag)**: Rollup CLI accepts `--granularity task|phase|milestone|project` and the corresponding scope flags (`--milestone`, `--phase`, `--task`). Satisfies US-1 AS-1–AS-4.
- **FR-3 (source-filter)**: Rollup CLI accepts `--source estimate|runtime|aggregate|all` (default `all`) and surfaces estimate-vs-runtime totals separately when both are present. Satisfies Edge Case "source: runtime alongside source: estimate".
- **FR-4 (goodhart-output-pairing)**: Every rollup row that contains a cost column also contains a quality column. The verifier rejects any output schema that drops one without the other. Satisfies US-1 AS-5.
- **FR-5 (cost-command)**: Provide a user-facing `orchestrator:cost` command (skill on Claude Code, command on Codex CLI / Cursor) documented in `commands/cost.md`. Defaults: active milestone if present, project otherwise. Satisfies US-2.
- **FR-6 (efficiency-footer)**: Augment `orchestrator:status` with an opt-in efficiency footer suppressed under `--quiet` or `config.efficiency_footer: false`. The pre-footer output remains byte-identical to current behavior. Satisfies US-3.
- **FR-7 (footer-back-compat)**: Default `efficiency_footer` to `true` for new projects but ship a one-line config knob so existing orchestrator-driven CI flows can opt out without code edits. Satisfies US-3 AS-2.
- **FR-8 (doctor-anomaly-check)**: Add an anomaly-detection pass to `orchestrator:doctor` that flags dispatches whose cost or quality deviates from the milestone moving baseline by ≥ configurable threshold. Read-only; never blocks autonomous mode. Satisfies US-4.
- **FR-9 (anomaly-pairing)**: Doctor's anomaly report surfaces cost and quality together for every flagged dispatch — never one in isolation. Satisfies US-4 AS-3.
- **FR-10 (anomaly-sample-floor)**: Anomaly check skips milestones below a configurable minimum sample size (default 5) with a "insufficient sample" annotation. Satisfies US-4 AS-4.
- **FR-11 (pricing-warning-surface)**: Rollup output includes a `(N missing)` suffix on cost cells whose underlying records carried a `pricing_warning`, never silently dropping rows. Satisfies US-1 AS-6.
- **FR-12 (read-only)**: The rollup engine, `orchestrator:cost` command, efficiency footer, and doctor anomaly check are all read-only consumers of `execution-log.jsonl` — they never append to or rewrite the log. Tier 1 is the sole writer. Satisfies the additivity contract carried over from M019.
- **FR-13 (concurrency-snapshot)**: Rollup engine reads the JSONL via a single-pass snapshot at start; in-flight writes after the snapshot are not double-counted. Satisfies Edge Case "concurrency".
- **FR-14 (corrupt-line-tolerance)**: Rollup skips non-parseable JSONL lines with a stderr line-number diagnostic; never crashes mid-rollup. Satisfies Edge Case "corrupted JSONL line".
- **FR-15 (verifier)**: Provide `scripts/verify/m027-rollup-schema.sh` validating: paired cost+quality output (FR-4), source-enum filter behavior (FR-3), aggregation precedence (FR-18, see below), back-compat byte-identity for `--quiet` status output (FR-6 + FR-7) and dispatch-time predictive surface suppression (FR-23), read-only invariant (FR-12), zero-LLM-token contract (FR-21), latency bound (FR-22).
- **FR-16 (doctor-config-check)**: `orchestrator:doctor --config-check` flags drift in `efficiency_footer` and `predictive_cost_surface` config across team environments. Read-only; advisory.
- **FR-17 (input-schema-validation)**: Rollup engine validates required-field presence (`estimated_cost_usd`, `record_type`, `granularity`) and types before aggregation. Validation failures log the offending line number on stderr; the row is excluded from totals (consistent with FR-14 and CON-5).
- **FR-18 (aggregation-precedence)**: When the rollup engine encounters records at the same granularity G, it applies precedence `aggregate > runtime > estimate`. A `source: aggregate` record at granularity G is authoritative for G and its constituent child records are not double-counted. Verifier (FR-15) enforces with mixed-source fixture logs.
- **FR-19 (fs-race-handling)**: Rollup engine reads JSONL via copy-then-aggregate semantics — `cp` to a `mktemp` path, aggregate against the temp copy, delete the temp copy on completion. Tolerates external log rotation and truncation during rollup.
- **FR-20 (predictive-cost-estimate)**: Provide `orchestrator:cost --estimate <description>` and an annotation hook in `scripts/engine/intensity-recommend.sh` that surface estimated cost at each intensity tier (Quick / Standard / Full) using `scripts/lib/pricing.sh` + char-quartile token approximation (M019 AD-1). Output is paired cost+quality (CON-4 / FR-4 extension to predictive surface). Satisfies US-5 AS-1, AS-2.
- **FR-21 (predictive-zero-token)**: All M027 predictive code paths are bash-only and never invoke an LLM. Estimation reads recipes, applies char-quartile, and consults pricing.sh. Verifier (FR-15) inspects the script set for forbidden LLM-invocation patterns. Satisfies US-5 AS-5 zero-LLM-token clause.
- **FR-22 (predictive-latency-bound)**: Predictive estimate completes in under 100 ms on a 2024-era laptop. Verifier (FR-15) wraps `time` around a fixture invocation and asserts < 100 ms wall-clock. Satisfies US-5 AS-5.
- **FR-23 (dispatch-time-predictive-surface)**: At interactive `orchestrator:dispatch` invocations of intensity Standard or Full, surface a one-block predictive view showing estimated cost, recommended tier, and one-keystroke override. Suppressed under `--yes`, `orchestrator:auto`, or `config.predictive_cost_surface: false`. Suppressed-mode output is byte-identical to pre-M027 dispatch output. Satisfies US-5 AS-3, AS-4.
- **FR-24 (predictive-pricing-degradation)**: When pricing.yml is missing / stale, the predictive surface renders cost cells as `(unavailable)`, the recommendation still renders, and the override flow still works. Mirrors FR-11 / CON-5 retrospective behavior. Satisfies US-5 AS-6.

## Success Criteria

- **SC-1**: `bash scripts/diagnostics/metrics-rollup.sh --granularity milestone --milestone M019` against this repo exits 0 and prints exactly one milestone row containing both cost and quality columns.
- **SC-2**: `bash scripts/verify/m019b-rollup-schema.sh` exits 0; the suite covers FR-3 / FR-4 / FR-6 / FR-7 / FR-12 contracts.
- **SC-3**: Output of `orchestrator:status --quiet` is byte-identical to pre-M019b `orchestrator:status` output (`diff` exits 0). Validates FR-6 + FR-7 back-compat.
- **SC-4**: Output of `orchestrator:cost` with no flags against this repo's active milestone is byte-identical to `metrics-rollup.sh --granularity milestone --milestone <active>` output (modulo a 1-line command header). Validates the command is a thin wrapper, not a divergent surface.
- **SC-5**: Running rollup against a fixture log containing 1 corrupted JSONL line + 9 valid lines exits 0, emits 1 stderr diagnostic naming the corrupted line number, and aggregates the 9 valid lines correctly. Validates FR-14.
- **SC-6**: Running rollup with `--source runtime` against a fixture log containing only `source: estimate` records produces an empty rollup with a "no records match filter" annotation, exit 0. Validates FR-3.
- **SC-7**: `orchestrator:doctor` against a fixture milestone with 1 high-cost outlier among 9 sibling dispatches flags exactly 1 anomaly with paired cost + quality data. Validates FR-8 + FR-9.
- **SC-8**: `orchestrator:doctor` against a fixture milestone with 4 dispatches (below sample floor) skips the anomaly check with the "insufficient sample" annotation. Validates FR-10.
- **SC-9**: No file under `.orchestrator/milestones/*/execution-log.jsonl` is modified by any M019b code path. Validated by `git diff --quiet` after running rollup / cost / status / doctor on a fixture. Validates FR-12.
- **SC-10**: Pre-M019 records (lacking `record_type`) are silently ignored by the rollup; running rollup against a fixture log that mixes pre-M019 and Tier 1 records does not double-count or crash. Validates back-compat with M019 SC-10 carry-forward.
- **SC-11**: All M019b shell scripts pass bash 3.2 compat (no associative arrays, no `<<<` herestrings, no `mapfile`).
- **SC-12**: Goodhart guard at output surface — verifier rejects any rollup configuration that produces a cost column without a quality column on either retrospective or predictive surfaces. Validates FR-4 + FR-20.
- **SC-13**: Performance bound — running the rollup CLI against a 10 MB fixture JSONL completes in under 5 s on a 2024-era laptop. Validates the AD-2 / CON-9-adjacent perf requirement.
- **SC-14**: Aggregation precedence — verifier feeds a fixture log containing both a `source: aggregate` phase record and its constituent `source: estimate` task records; rollup output sums match the aggregate row, not aggregate + children. Validates FR-18.
- **SC-15**: Predictive latency — `time orchestrator:cost --estimate "<sample>"` reports wall-clock under 100 ms on a 2024-era laptop. Validates FR-22.
- **SC-16**: Predictive zero-LLM-token — verifier greps the M027 script set for forbidden LLM-invocation patterns (e.g., `claude_chat`, `anthropic`, dispatch-interface invocations from predictive code paths). No matches. Validates FR-21.
- **SC-17**: Dispatch-time predictive surface back-compat — running a fixture dispatch with `--yes` produces output byte-identical to the same dispatch on a pre-M027 build. Validates FR-23 suppressed-mode invariant.
- **SC-18**: Predictive Goodhart pairing — `orchestrator:cost --estimate "<sample>"` output, parsed mechanically, contains a quality column on every row that contains a cost column. Validates FR-20 + CON-4 extension.
- **SC-19**: FS-race tolerance — verifier fires a rollup against a JSONL while a concurrent process truncates the file mid-aggregation; rollup completes without crashing, tagging the affected snapshot. Validates FR-19.

## Non-Goals

- **Backend runtime-actuals adapters (`scripts/dispatch/adapters/backend/*/report-usage.sh`).** Tier 3. M019b only consumes the `source: runtime` schema slot reserved by Tier 1; it does not produce runtime records.
- **Auto-generated `MNNN-METRICS.md` on `orchestrator:consolidate`.** Tier 3 polished surface. M019b's surfaces are CLI / status footer / doctor diagnostic, all transient.
- **Multi-runtime parity dashboards across Claude Code / Codex / Cursor.** Tier 3.
- **UI, charts, dashboards, plots, or anything beyond plain text.** Every tier of M019.
- **Cost optimization, payload compression, or model-switching decisions driven by the data.** M018 (Context Compression) consumes M019b's data; M019b only surfaces it.
- **Schema changes to Tier 1 records.** M019b is read-only; any new field on `payload_breakdown` / `dispatch_usage` / `unit_close` is a schema migration that lives in a future milestone.
- **Backfilling pre-M019 records.** D009 boundary stands; M019b ignores pre-M019 records.
- **Real-time / streaming rollups.** All rollups are batch (read-the-log-once and aggregate). Streaming is not warranted by the current data volume.
- **Cross-repository rollups.** M019b operates on a single `.orchestrator/` tree. Cross-repo aggregation is a separate effort.
- **Runtime-actuals calibration of the predictive estimate.** M027's predictive surface uses char-quartile token approximation + `pricing.yml` rates. Closing the loop with backend-reported actuals (the predictive estimate learning from observed dispatch_usage records) is Tier 3.
- **Auto-tier-downgrade on cost-budget-exceeded.** M027 surfaces the recommendation and the per-tier cost; the operator (or `orchestrator:auto`'s existing budget guard) decides. Automatic policy-driven tier-downgrade based on aggregate spend is a separate milestone.
- **Confidence bands on the predictive estimate.** M027 ships point estimates with a one-line "estimates ±~20%" disclaimer in `commands/cost.md`. Computed confidence bands wait for runtime-actuals calibration.

## Constraints

- **CON-1 (read-only)**: M019b code paths must not write to or rewrite `execution-log.jsonl`. Tier 1 emitter is the sole writer; M019b is a consumer. (FR-12, SC-9.)
- **CON-2 (additive-only)**: Must not change the Tier 1 schema or the existing `record_type` / `source` / `granularity` enums. Adding new enum values is a future-milestone migration, not a Tier 2 change.
- **CON-3 (back-compat)**: `orchestrator:status` output must remain byte-identical when the efficiency footer is suppressed (`--quiet` or `config.efficiency_footer: false`). CI consumers and `orchestrator:auto` log scrapers depend on this. (FR-6, SC-3.)
- **CON-4 (goodhart-pairing)**: Every output surface that exposes cost must also expose quality on the same row. Never one without the other. (FR-4, FR-9, SC-12.)
- **CON-5 (never-abort)**: Missing / stale `pricing.yml`, corrupt JSONL lines, missing milestones — all degrade gracefully. The rollup never aborts mid-aggregation. (FR-11, FR-14, mirrors M019 C4.)
- **CON-6 (zero-token)**: M019b code paths are bash-only and never invoke an LLM. Reading and aggregating JSONL must add zero tokens to any orchestrator dispatch.
- **CON-7 (bash-3.2)**: All scripts pass bash 3.2 compat per the project constitution. (SC-11.)
- **CON-8 (sample-floor)**: Anomaly detection must define a minimum sample size to avoid false-positive noise on small milestones; default 5, configurable. (FR-10, SC-8.)
- **CON-9 (predictive-latency)**: Predictive estimates must complete in under 100 ms (FR-22, SC-15) so they can ride alongside `intensity-recommend.sh` without perceptible lag. If the bound cannot be met for a given recipe, the surface gracefully degrades to "estimate unavailable" rather than blocking dispatch.
- **CON-10 (operator-override-preserved)**: Every dispatch-time predictive surface preserves a one-keystroke override to a cheaper or more-expensive tier. Strategic positioning: visibility + recommendation + cheap override, never coercion. (FR-23, US-5 AS-3.)
- **CON-11 (evidence-before-claims)**: Every Success Criterion in this spec references behavior whose semantics are pinned in this body or in `M027-CONTEXT.md` (AD-1 aggregation precedence, AD-2 perf bound, AD-3 fs race). No SC depends on a deferred Open Question. Closes the conversus advisory NEW-001 finding.
- **CON-12 (perf-rollup-bound)**: Rollup CLI completes in < 5 s on a 10 MB fixture JSONL on a 2024-era laptop (SC-13). Plan-phase may propose relaxation if measurement shows the bound infeasible without architectural rework.

### Knowledge-Layer Boundary (M019b vs. M025)

M025 (Knowledge Layer Maturation) owns the knowledge-tree write-sites: `MEM*.md`, knowledge index regen, and graph-edge maintenance. M019b does not write knowledge entries during rollup execution — rollups are transient, surfaced to stdout, never persisted. On milestone consolidation, however, M019b's rollup outputs may be summarized into a `MEM*` entry by the consolidate flow (M025 owns the write-site; M019b owns the rollup engine that produces the data). The boundary: M019b produces aggregates on demand; M025 chooses whether and when to durably record them.

## Assumptions

- M019 Tier 1 emitter is shipping Tier 1 records into `.orchestrator/milestones/*/execution-log.jsonl` with the schema documented in `M019/M019-SUMMARY.md`. (Verified — M019 closed 2026-04-18.)
- `.orchestrator/config/pricing.yml` exists and is approximately current; if not, the never-abort path applies. (CON-5.)
- The runtime adapters (Claude Code skill, Codex CLI command, Cursor command) for new user-facing commands follow the conventions established by M015 standalone cutover and M025 installer coexistence. The packaging layer can register a new command without further milestones.
- Operators have a reasonable expectation of cost data in `orchestrator:status` and `orchestrator:cost`. The default-on efficiency footer is the operator-facing UX; CI consumers opt out via `--quiet` or config.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle II — Evidence Before Claims**: M019b is the surface that finally makes M019 Tier 1 data visible. Every other principle and decision in this project that claims an efficiency property (Principle I context minimization, Principle V fresh-context-per-unit) becomes auditable when M019b ships. The spec does not invent new claims; it surfaces existing data.
- **Principle III — Design Before Code**: The rollup engine, command surface, and verifier are designed up-front in this spec. Output schemas (paired cost+quality, source-filter semantics) are pinned before implementation; downstream phases consume the contract, not the code.
- **Principle XV — No Anti-Patterns**: M019b is bash-only with bash 3.2 compat (CON-7), avoids embedding scaffold-placeholder markers in inline code per D020, never aborts on degraded inputs (CON-5, mirrors M019 C4), and defines an output-surface Goodhart guard symmetric to M019's emission-time guard (CON-4).
- **Principle XIV — Knowledge Compounds**: The boundary with M025 is explicit (Knowledge-Layer Boundary section). M019b produces transient surfaces; M025 chooses what to durably record. No double write-site.
- **Principle I — Context Minimization**: M019b adds zero tokens to dispatch payloads (CON-6). All aggregation is bash. No LLM is invoked from any M019b code path.

## Open Questions (defer to planning)

The spec has been amended (Last Revised: 2026-04-26) so that all conversus advisory P0 / P1 / P2 findings are now pinned in the body or in `M027-CONTEXT.md`. The Open Questions list below carries only genuine plan-phase deferrals.

### Resolved during `orchestrator:discuss` (see `M027-CONTEXT.md` for full rationale)

- **Resolved #Q-7 aggregation precedence** → pinned in FR-18 + SC-14 (aggregate > runtime > estimate; aggregates skip already-fed children). Closes conversus THREAT-001 / MIT-002.
- **Resolved #Q-8 performance bound** → pinned in CON-12 + SC-13 (< 5 s on 10 MB JSONL). Closes conversus THREAT-004 / MIT-003.
- **Resolved #Q-9 FS race handling** → pinned in FR-19 (copy-then-aggregate via `mktemp` + `cp`). Closes conversus THREAT-002 / MIT-004.
- **Resolved #Q-12 doctor `--config-check`** → accepted as FR-16. Closes conversus THREAT-008 / MIT-005.
- **Resolved #Q-13 input schema validation** → accepted as FR-17. Closes conversus THREAT-003 / MIT-006.
- **Resolved #Q-3 efficiency footer default** → on for interactive `orchestrator:status`, off under `--quiet` or `config.efficiency_footer: false`. Pinned in FR-7 + AD-5.
- **Resolved #Q-4 / #Q-2 / #Q-6 NEW-001 evidence-before-claims** → CON-11 asserts every SC references pinned semantics. Closes conversus NEW-001.

### Genuine plan-phase deferrals

- **#Q-1 anomaly-threshold-defaults**: Default cost multiplier (proposed: 3× milestone median) and default quality threshold (proposed: `retry_count > 2 OR verification_pass_rate < 0.5`) require sampling existing M012–M026 data to know what "normal" looks like. Plan-phase fires the measurement and pins the defaults in the phase plan. Until then, the proposed defaults are guidance, not contract.
- **#Q-5 doctor-perf**: At what JSONL volume does the anomaly check become slow enough that doctor runs feel laggy? Plan-phase measures against the largest existing milestone log; if the pass exceeds ~1 s, plan-phase adds `--no-anomaly` flag or sample-cap.
- **#Q-10 anomaly-baseline-disclaimer**: Median-based thresholds normalize whatever historical data is present, including systematic errors. Posture at plan-phase: document the baseline-accuracy disclaimer in `commands/doctor.md`; defer corruption-recovery mechanisms.
- **#Q-11 mixed-source-ux**: When both `source: estimate` and `source: runtime` records appear (post-Tier 3), should `commands/cost.md` carry the operator-interpretation guidance, or should the rollup output itself annotate? Plan-phase decision; both options are cheap.
- **#Q-14 predictive surface attachment-format**: Should `intensity-recommend.sh --format json` emit the per-tier `cost_estimates` block as an additional structured field (recommended: yes), or only the human-readable text? Plan-phase decision; default proposed: both — keep text contract byte-stable (CON-3) and add `--format json` opt-in.
- **#Q-15 predictive-confidence-disclaimer-text**: One-line copy for the `commands/cost.md` "estimates ±~20%; runtime-actuals calibration is Tier 3" disclaimer. Trivial; plan-phase pins exact wording.
- **#Q-16 repeat-dispatch-throttling**: Always-on (default proposed: yes, visibility-first) or throttle to once-per-session? Plan-phase pins the default with operator-override flag (`--no-predict`).

## Dependencies

- **M019 Tier 1 emitter** — produces the JSONL records this milestone consumes. Closed 2026-04-18; the schema (record_type / source / granularity enums; cost+quality pairing; pricing_warning field) is the contract.
- **`scripts/lib/pricing.sh`** — sourceable pricing library shipped in M019 P01. M019b's rollup engine sources this lib for pricing-version comparison and stale detection.
- **`scripts/verify/m019-schema.sh`** — Tier 1 schema validator. M019b's verifier composes against it (rollup output references Tier 1 records, so the input contract must hold before output verification fires).
- **Runtime adapters from M015 + M025** — Claude Code skill packaging, Codex CLI command packaging, Cursor command packaging. The packaging layer can register a new user-facing command (`orchestrator:cost`) without code changes to the adapters.
- **`orchestrator:status`** (existing) — efficiency footer attaches to its output (FR-6).
- **`orchestrator:doctor`** (existing) — anomaly check + config-check attach to its diagnostic surface (FR-8, FR-16).
- **`scripts/engine/intensity-recommend.sh`** (existing) — predictive cost annotation hook attaches to its output (FR-20).
- **`orchestrator:dispatch`** (existing, interactive path) — predictive surface attaches at pre-dispatch confirmation (FR-23).

## Downstream Consumers (informational, not binding)

- **M018 (Context Compression)** — consumes M019b rollup data to identify high-cost dispatch patterns worth compressing. M019b surfaces; M018 decides.
- **M019 Tier 3** — backend runtime-actuals adapters. When Tier 3 lands, M019b's rollup engine consumes both `source: estimate` and `source: runtime` records via the existing FR-3 source-filter; no rollup-engine changes needed.
- **M025 (Knowledge Layer Maturation)** — may persist rollup summaries into `MEM*` entries on milestone consolidation. M025 owns the write-site; M019b owns the read-site.
- **`orchestrator:consolidate`** — may invoke the rollup engine on milestone close to surface a one-line efficiency summary in the milestone summary file. Optional; not load-bearing for M019b.

---
schema_version: "1.0"
type: feature-spec
feature_slug: "030-context-compression-layer"
created_at: "2026-04-27"
status: "Draft"
milestone: "M018"
---

# Feature Specification: M018 — Context Compression Layer

**Feature Branch**: `030-context-compression-layer`
**Created**: 2026-04-27
**Last Revised**: 2026-04-27 — applied conversus gate RISK-1/2/3 mitigations: added P00 measurement-prerequisites phase (US-0, FR-0a, FR-0b), promoted US-7 P3→P2, deferred SC-9 threshold to P00 calibration, resolved Q-1/Q-2. **2026-04-27 (P00 close)**: SC-9 threshold pinned to 34.7% per probe-derived 80% CI lower bound.
**Status**: Draft
**Milestone**: M018
**Input**: User description: "M018 — Context Compression Layer. Caveman-style token compression as a pipeline stage with a four-tier compaction ladder per D010: Tier 1 microcompact (cache-reuse + tool-result budgeting, zero LLM cost), Tier 2 snip (head-drop with protected tail, zero LLM cost), Tier 3 auto-compact (LLM-summarization, intensity-gated), Tier 4 collapse (staged multi-phase, feature-flagged off by default). Compression effort biased toward Knowledge injection per telemetry (45.9% of dispatch tokens). Intensity-bound (Quick→T1-T2 only, Standard→through T3, Full→all available). Roundtrip-safe by policy; originals authoritative; compress only at dispatch boundaries. Telemetry-integrated via M019 emitters and M027 efficiency footer/predictive surface so savings are measurable per dispatch. Conversus gate at P01 plan-review for tier-grammar/safety. Multi-runtime parity (Claude Code, Codex CLI, Cursor) per M009 launch gate. Risks: parse-regression in downstream scripts that grep prose; quality regression on summarization tier; emitter coverage gap (only 2 dispatch_usage records vs 169 payload_breakdown)."

**Substrate**: DECISIONS rows D008 (caveman-style sketch) and D010 (four-tier ladder reframing). M019 Tier 1+2/3 emitters and M027 cost+quality observability surfaces are the runtime feedback loop M018 compresses against. M020 review-state model (`status:` field vocabulary) is the substrate for Knowledge-aware filtering.

## Problem Statement

Five milestones of post-M019 telemetry (n=169 `payload_breakdown` records across M012–M027) show that the orchestrator's dispatch payload is large and growing: mean payload is 16,797 tokens; p95 is 24,534 tokens; max observed is 30,358 tokens. Three sections account for 88% of every payload's token spend — Knowledge (45.9%), Task Plan (24.0%), and Upstream Context (18.1%) — while the remaining five sections combined contribute 12%. The cost data is here, the savings target is identified, and **nothing reads or compresses any of it**.

Three concrete pain-points follow from that gap. First, the orchestrator dispatches a fresh-context agent for every unit of work (Constitution Principle V), and every dispatch pays full token cost on a payload whose top three sections are largely re-injected boilerplate from prior dispatches. Second, M020 just shipped a review-state model on knowledge entries (`status:` field vocabulary) that *could* drive a Knowledge-aware injection filter — but no consumer reads it; KNOWLEDGE.md is injected wholesale. Third, M027 just shipped an efficiency footer and predictive cost surface that surface savings to the operator — but with no compression pipeline behind them, the predictive surface forecasts cost the operator cannot reduce except by changing intensity tier.

The minimum surface that closes all three pain-points is a compression pipeline staged at the dispatch boundary plus an injection-time filter that reads M020 review-state. Per D010, the pipeline is a four-tier ladder run cheapest-first: Tier 1 microcompact (cache reuse + tool-result paging, zero LLM cost), Tier 2 snip (head-drop with protected tail, zero LLM cost), Tier 3 auto-compact (LLM summarization, intensity-gated), Tier 4 collapse (staged multi-phase, feature-flagged off). Per the telemetry, **Tier 4 is out of scope for M018** — p95 is 24k tokens, nowhere near context-window runout; the staged-collapse complexity does not earn its cost on this profile and is reframed as a follow-up milestone if/when telemetry shifts.

What M018 does **not** attempt: it does not change the M019 emitter schema, does not introduce backend adapters, does not alter the dispatch loop's state machine, does not compress *originals* (Constitution Principle VI — originals authoritative; compression operates on dispatch-time copies only), and does not ship Tier 4 (deferred). It is read-mostly: the only bytes M018 writes are (a) compressed payload artifacts beside their originals at dispatch time, (b) M019 emitter records describing the savings achieved, and (c) the tier-grammar contract document.

## User Scenarios & Testing *(mandatory)*

### Phase 0 — Measurement Prerequisites (P0, blocking)

Before any tier implementation lands, M018 ships two empirical-grounding artifacts: (a) the `dispatch_usage` emitter coverage fix so the cost-side measurement instrument fires on real dispatches at the same rate as `payload_breakdown` (current observed: 2 vs 169 — fundamentally broken); (b) a section-level distribution probe that measures realistic per-tier savings ceilings against the live telemetry, so the success-criteria thresholds are empirically calibrated rather than guessed. P0 is a hard blocker: no tier code lands until both prerequisites pass. *(See US-0.)*

### Minimal Slice (P1 Load-Bearing Scope, post-P0)

US-1 (tier grammar + safety contract) is the bottom of the stack — every other story consumes the contract it defines. US-2 (Knowledge-aware injection filter) and US-3 (Tier 1 microcompact) are the highest-leverage zero-LLM surfaces because the telemetry shows Knowledge = 45.9% of payload tokens and tool-result/cache reuse is the cheapest possible win. US-1 + US-2 + US-3 together close the dogfood loop: every dispatch after M018/P03 carries less Knowledge boilerplate, paginated tool results, and cached tool-call reuse, with savings measured against the M019 estimator that produced the baseline (now firing reliably per US-0).

US-4 (Tier 2 snip) and US-5 (Tier 3 auto-compact) are P2 — additive on top of the minimal slice once safety boundaries are pinned. US-6 (measurement integration with M027) is P2 because the M027 surfaces already exist; M018 only has to feed them new data. US-7 (eval harness) is **P2 (promoted from P3 per gate finding RISK-3)** — must ship before or alongside Tier 3 deployment so quality regression detection is operational, not retroactive. US-8 (multi-runtime parity) is P3 — gates M009 launch but not M018 close.

### User Story 0 — Emitter Coverage And Threshold Calibration Land Before Any Tier Code (Priority: P0)

When M018 begins implementation, the first deliverable is a P00 phase that resolves two measurement gaps identified in the conversus gate review: (a) the `dispatch_usage` emitter fires on every real dispatch at parity with `payload_breakdown` (telemetry probe shows 2 vs 169 — fundamentally broken); (b) a section-level distribution probe extends the existing telemetry probe to measure realistic compression ceilings per section per tier, producing an empirical baseline against which SC-9's reduction target is calibrated. The phase ships before P01 grammar work begins.

**Why this priority**: Without emitter coverage, M018's primary success criteria (SC-3, SC-9) are unverifiable — the milestone could ship believing it succeeded while delivering negligible value. Without the section-level probe, SC-9's target threshold is a guess. Both are P0 blockers per the gate's RISK-1 + RISK-2 findings.

**Independent Test**: After P00, run a fixture milestone with ≥ 20 dispatches. Each dispatch produces both a `payload_breakdown` and a `dispatch_usage` record (parity ≥ 95%). Run `bash scripts/diagnostics/m018-section-distribution.sh`; output reports per-section size distribution (mean, p50, p95, max) and per-tier achievable-savings estimates with confidence intervals. The SC-9 threshold in this spec is updated (via `--amend`) to the empirically-grounded value.

**Acceptance Scenarios**:

1. **Given** the post-P00 dispatch loop, **When** any dispatch fires, **Then** both `payload_breakdown` and `dispatch_usage` JSONL records are emitted with non-null cost-side fields. Parity gap (record count delta) is < 5% across the test sample.
2. **Given** the section-level distribution probe, **When** it runs against the live telemetry, **Then** output names per-section (mean, p50, p95) token sizes and per-tier achievable-savings ceilings — i.e., "filter at 30% knowledge-drop saves N tokens at p50, M tokens at p95."
3. **Given** the probe results, **When** SC-9 is updated, **Then** the new threshold is grounded in the probe's confidence intervals — either ≥ 25% (if probe confirms) or a different empirically-calibrated value (per the P00 amendment).
4. **Given** P00 acceptance fails (emitter coverage < 95% parity OR probe reveals < 10% achievable savings), **When** the gate re-runs, **Then** M018 scope is re-discussed before P01 starts — possibly downscoping the milestone if savings ceiling is too low to justify the implementation cost.

### User Story 1 — Tier Grammar Contract Defines What Each Tier May Touch (Priority: P1)

When the orchestrator's compression pipeline is invoked, every tier's transformation is bounded by an explicit, versioned grammar contract that names the artifact classes it may modify, the byte patterns it must preserve verbatim (frontmatter, code fences, paths, MEM IDs, command names, URLs, JSONL records, scaffold-placeholder markers), and the failure mode if a contract violation is detected (refuse the tier; pass-through to next tier). The contract lives at `references/compression-grammar.md` and is consumed by tier implementations + the eval harness.

**Why this priority**: Without a grammar contract, every tier's safety boundaries are implicit and per-author — exactly the parse-regression risk D008 originally flagged. The contract is the artifact that makes the conversus gate (D010, locked-in) reviewable: gate reviewers read the contract and dispute it, not free-form intent prose. Bottom of the stack.

**Independent Test**: After P01, `references/compression-grammar.md` exists with versioned contract sections per artifact class (knowledge entry, task plan, dispatch payload section, tool result, JSONL record). `scripts/verify/compression-grammar-lint.sh` (a new verifier) parses the contract, emits one row per (tier, artifact-class, preserved-pattern) triple, and exits 0. Conversus gate (`scripts/dispatch/adapters/tool/conversus.sh gate compression-grammar references/compression-grammar.md ...`) returns PASS or BLOCK; on BLOCK, the contract is revised and the gate re-run before P01 closes.

**Acceptance Scenarios**:

1. **Given** the contract document, **When** the lint verifier runs, **Then** every defined tier has a `preserves:` block listing byte-pattern regexes and an `applies-to:` block listing artifact classes; sections without both blocks fail the lint.
2. **Given** any tier implementation lands in P02–P05, **When** that tier processes a fixture artifact containing a preserved pattern (e.g., a code fence containing scaffold-placeholder markers, a path like `scripts/foo.sh`, a MEM ID like `MEM031`), **Then** the post-tier output contains every preserved pattern byte-identical, verifiable via diff.
3. **Given** the conversus gate is invoked at the end of P01 with `--strict`, **When** the gate returns PASS, **Then** the contract document advances to `Status: Reviewed` (frontmatter); on BLOCK, dispute findings are appended to the contract's Open Questions section and P01 stays open until resolved.

---

### User Story 2 — Knowledge-Aware Injection Filter Drops Low-Priority Entries Before Compression Fires (Priority: P1)

When `scripts/dispatch/build-context.sh` assembles a dispatch payload, the Knowledge section is filtered against M020's `status:` field vocabulary (review-state model) so that entries marked `status: superseded`, `status: experimental`, or below a configured graduation threshold are dropped before any compression tier runs. The filter is the cheapest possible savings (zero compression work; the entry never enters the payload) and is targeted directly at the 45.9% Knowledge-section dominance in the baseline.

**Why this priority**: Tier 1–3 compression is paying compute to compact bytes that should never have been injected. M020 shipped the review-state model exactly so consumers could read it; M018 is the first consumer that actually does. This is the highest-leverage zero-LLM win in the entire milestone.

**Independent Test**: Construct a fixture milestone with 20 knowledge entries, 5 of which carry `status: superseded` and 5 of which carry `status: experimental`. Run `bash scripts/dispatch/build-context.sh` against the fixture. The resulting `payload.md` Knowledge section omits the 10 filtered entries; emits a `payload_filter` JSONL record naming the filter, the dropped count, and the dropped tokens. Compare against the unfiltered baseline: token reduction is reported in the `payload_breakdown` record's `Knowledge` section.

**Acceptance Scenarios**:

1. **Given** a knowledge tree with mixed `status:` field values, **When** `build-context.sh` runs, **Then** entries matching the configured drop-list (`status: superseded`, `status: experimental` by default) are excluded from the Knowledge section of the payload.
2. **Given** the filter ran, **When** the dispatch fires, **Then** the M019 `payload_breakdown` record carries a `filter_dropped_tokens` field naming the tokens omitted, and a new `payload_filter` JSONL record is appended with `{filter, drop_list, dropped_count, dropped_tokens, source: runtime}`.
3. **Given** an entry has no `status:` field at all, **When** the filter runs, **Then** the entry is treated as `status: stable` (never dropped) — back-compat with knowledge entries authored pre-M020.
4. **Given** the operator configures `compression.knowledge_filter.drop_list: []`, **When** dispatch runs, **Then** the filter is a no-op and payload Knowledge bytes are byte-identical to the pre-M018 baseline.
5. **Given** the filter would drop all entries (empty Knowledge section), **When** dispatch runs, **Then** the section emits the literal `(no qualifying knowledge entries)` rather than an empty section, preserving payload structure.

---

### User Story 3 — Tier 1 Microcompact Reuses Cached Tool Results And Pages Oversized Ones (Priority: P1)

When a dispatch's payload contains tool-call result blocks (e.g., previous `Read` outputs, previous `Bash` outputs) that exceed a configured size threshold, Tier 1 microcompact replaces the inline result with a `file_path + preview` reference and persists the full result to `.orchestrator/cache/tool-results/<hash>.txt`. When a subsequent dispatch references the same tool call (identical command + identical inputs), Tier 1 reuses the cached result by reference rather than re-injecting the bytes. Zero LLM cost; pure bash + filesystem.

**Why this priority**: Tool-result inflation is the second highest-leverage zero-LLM win after Knowledge filtering. It's also the canonical "reuse cached tool-call results" pattern from Article 3 (Rohit's Claude Code harness teardown) that originally informed D010 — a production-validated approach with measurable savings.

**Independent Test**: Construct a fixture dispatch payload containing a 12 KB inline `Read` result block. With `compression.tier1.tool_result_budget_bytes: 4096`, run `build-context.sh`. The result block is replaced by `<tool-result file="$ORCH/cache/tool-results/<hash>.txt" preview-bytes="200">…first 200 bytes…</tool-result>` and the 12 KB original is persisted at the named path. Replay the dispatch; the second invocation reuses the cached file by hash without re-paging.

**Acceptance Scenarios**:

1. **Given** a tool-result block exceeds `tier1.tool_result_budget_bytes`, **When** Tier 1 runs, **Then** the inline block is replaced with a `file_path + preview` reference and the original is persisted to `.orchestrator/cache/tool-results/<hash>.txt`.
2. **Given** a tool-call has been cached, **When** a subsequent dispatch contains the same tool-call (matched on command + input hash), **Then** Tier 1 emits the same `file_path + preview` reference without re-running or re-paging the call.
3. **Given** Tier 1 produces compressed output, **When** the dispatch fires, **Then** an M019 `payload_breakdown` record carries a `tier1_savings_tokens` field; the `unit_close` record carries a `tier1_invocations` count.
4. **Given** the cache directory is missing or unwritable, **When** Tier 1 runs, **Then** it logs a one-line warning and passes the payload through unmodified — never crashes the dispatch.
5. **Given** the operator runs `bash scripts/util/cache-prune.sh --max-age 30d`, **When** the script completes, **Then** cache entries older than 30 days are removed; entries referenced by any open milestone's `execution-log.jsonl` in the last 30 days are preserved.

---

### User Story 4 — Tier 2 Snip Head-Drops Section Bodies With A Protected Tail (Priority: P2)

When a payload section exceeds a configured size threshold and Tier 1 alone has not brought it under target, Tier 2 snip head-drops the oldest section body bytes while preserving a configurable protected tail (defaults: last 30% of the section). The transformation is rule-based: section identifier, byte threshold, head-drop ratio, protected-tail ratio. Zero LLM cost; the compressed output names the snip in-band so downstream consumers can detect it.

**Why this priority**: Snip is the lowest-cost mid-budget win after Tier 1. It's lossy (head bytes are dropped) but the protected-tail rule preserves the section's most-recent / load-bearing content. P2 because the minimal slice (US-1 + US-2 + US-3) ships measurable savings without it.

**Independent Test**: Construct a fixture payload with a 30 KB Upstream Context section. With `compression.tier2.section_budget.upstream_context: 12288` and `protected_tail_ratio: 0.3`, run the pipeline. The output section is ≤ 12 KB, contains the literal in-band marker `<!-- compressed:tier2 head-dropped=N bytes -->`, and the trailing 9 KB (30% of 30 KB) is byte-identical to the pre-snip section.

**Acceptance Scenarios**:

1. **Given** a section exceeds its configured budget after Tier 1, **When** Tier 2 runs, **Then** the section is head-dropped to fit the budget while preserving the configured tail ratio byte-identical.
2. **Given** Tier 2 fires, **When** the payload is emitted, **Then** the in-band `<!-- compressed:tier2 head-dropped=N bytes -->` marker appears at the start of the snipped section so downstream consumers (eval harness, debug tools) can detect compression.
3. **Given** the section contains a preserved-pattern byte (per US-1 contract, e.g., a frontmatter block, a code fence, a scaffold-placeholder marker) within the head-drop range, **When** Tier 2 runs, **Then** the snip refuses to cross the preserved pattern: head-drop stops at the boundary, even if the resulting section exceeds budget. A `tier2_preservation_breach` JSONL record names the section and the boundary that prevented full snip.
4. **Given** the operator configures `tier2.protected_tail_ratio: 0.5`, **When** snip runs, **Then** half the section's pre-snip bytes are preserved verbatim at the tail.

---

### User Story 5 — Tier 3 Auto-Compact Summarizes Sections Via LLM, Intensity-Gated (Priority: P2)

When a payload section exceeds budget after Tier 1 + Tier 2 and the resolved intensity is Standard or higher, Tier 3 auto-compact invokes the dispatch interface to summarize the section against a templated summarization prompt (`templates/compression-tier3-prompt.md`). The summary replaces the section in the dispatch payload; the original section is persisted to `.orchestrator/cache/tier3-originals/<hash>.txt` for audit and eval-harness replay. Tier 3 is the only tier that incurs LLM cost; per D010, Quick intensity skips it entirely.

**Why this priority**: Tier 3 is where summarization complexity and quality risk live. P2 (not P1) because the minimal slice ships zero-LLM savings; Tier 3 expands the budget envelope but is gated by the eval harness (US-7) on quality regression.

**Independent Test**: Construct a fixture dispatch with a 25 KB Knowledge section that survives Tier 1 + Tier 2. With `compression.tier3.intensity_floor: standard` and effective intensity Standard, run the pipeline. Tier 3 invokes `dispatch-interface.sh` with the summarization prompt; the resulting payload's Knowledge section is ≤ 8 KB, contains the in-band marker `<!-- compressed:tier3 model=<model> input_tokens=N output_tokens=M -->`, and the original 25 KB is persisted at the named path. With effective intensity Quick, Tier 3 is skipped and the payload exits the pipeline at Tier 2's output.

**Acceptance Scenarios**:

1. **Given** effective intensity Quick, **When** Tier 3 would be invoked, **Then** the tier is skipped and a `tier3_skipped` JSONL record names `{reason: "intensity=quick"}`.
2. **Given** effective intensity Standard or Full and a section over budget after Tier 2, **When** Tier 3 runs, **Then** the dispatch interface is invoked with the summarization prompt, and the summary replaces the section with the in-band marker present.
3. **Given** Tier 3 fires, **When** the dispatch closes, **Then** an M019 `dispatch_usage` record carries the Tier 3 LLM call's `input_tokens_estimate`, `output_tokens_estimate`, `estimated_cost_usd`, and a new `tier3_compression_savings_tokens` field; the `unit_close` record carries `tier3_invocations`.
4. **Given** the LLM call fails (timeout, rate limit, error response), **When** Tier 3 catches the failure, **Then** the tier passes through the Tier 2 output unmodified and emits a `tier3_failed` JSONL record with the error reason — never crashes the dispatch.
5. **Given** the eval harness (US-7) reports a parity-test regression on a Tier 3-compressed section, **When** the operator runs `bash scripts/util/cache-replay.sh <unit-id>`, **Then** the original section is replayed against the same dispatch path so the regression is reproducible.

---

### User Story 6 — Every Tier's Savings Are Visible In M027 Surfaces (Priority: P2)

When M018 tiers fire on a dispatch, the M019 emitters carry per-tier savings fields, and the M027 efficiency footer + predictive cost surface include compression-savings columns. The operator running `orchestrator:status`, `orchestrator:cost`, or `orchestrator:doctor` sees what M018 saved per dispatch / per phase / per milestone without needing to grep JSONL.

**Why this priority**: M027 already shipped the surfaces; M018's burden is feeding the data. The integration is mostly schema (extend `payload_breakdown` and `dispatch_usage` records with tier-savings fields) plus footer/rollup template extensions. P2 because the underlying tiers (US-2 through US-5) carry the load; this story is the consumption surface.

**Independent Test**: Run a dispatch through the full M018 pipeline (US-2 + US-3 + US-4 + US-5 active). The resulting `execution-log.jsonl` records carry `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier3_savings_tokens` fields with non-null values. Run `orchestrator:cost --milestone <active>`; the rollup output includes a "Compression savings" block with per-tier aggregates. Run `orchestrator:status`; the efficiency footer includes a "Compressed: <pct>% reduction over baseline" line.

**Acceptance Scenarios**:

1. **Given** any M018 tier fires, **When** the M019 emitters record the dispatch, **Then** the tier's savings field is populated (zero allowed for no-op runs; null disallowed once the tier is enabled).
2. **Given** `orchestrator:cost` is invoked, **When** the rollup engine reads M019 records, **Then** the output includes a per-tier-savings block alongside the existing cost/quality blocks (Goodhart pairing — savings reported alongside quality metrics so summarization-induced regressions are visible at the same surface).
3. **Given** `orchestrator:status` is invoked with the efficiency footer enabled, **When** any dispatch in the active milestone fired M018 tiers, **Then** the footer includes a one-line compression summary; suppressed under `--quiet` per M027 footer convention.
4. **Given** `orchestrator:doctor`'s anomaly check runs, **When** Tier 3 produces compression savings outside the milestone's moving baseline (e.g., 10× higher LLM cost than median for similar-sized sections), **Then** the anomaly is flagged with both the compression metric and the quality metric (Goodhart pairing at the alerting surface).

---

### User Story 7 — Eval Harness Prevents Quality Regression On Tier 3 (Priority: P2 — promoted from P3 per gate RISK-3)

When a dispatch's Tier 3-compressed section is later judged by behavioral outcomes (verification pass rate, retry count, deviation count from `unit_close` records), the eval harness produces a parity-test report comparing the compressed dispatch's outcomes against a control group of uncompressed-equivalent dispatches. Regressions above a configured threshold trigger an advisory diagnostic; the harness is offline (run on demand against historical telemetry), not in-loop at dispatch time.

**Why this priority**: Promoted to P2 per gate RISK-3: shipping Tier 3 (P2 / P04) without operational quality regression detection creates a deployment window where systematic quality degradation goes undetected. The harness must be operational *before* or *alongside* Tier 3, not retroactively. The harness is offline by design (Constitution Principle II — Evidence Before Claims) so it can run against the full historical telemetry without paying real-time cost; the operational requirement is that it runs as part of every Tier 3-touching dispatch's verification ladder, not as a deferred audit pass.

**Independent Test**: After Tier 3 has fired ≥ 30 times across ≥ 2 milestones, run `bash scripts/diagnostics/compression-eval.sh --milestone <id> --tier 3`. The output is a table with one row per Tier 3-compressed task showing: pre-compression section size, post-compression size, dispatch outcome (pass/fail), retry count, deviation count. A summary block reports the regression delta against an uncompressed control group (same milestone, sections that did not exceed the Tier 3 budget). Exit 0 always; advisory only.

**Acceptance Scenarios**:

1. **Given** a milestone with ≥ 30 Tier 3 invocations and ≥ 30 uncompressed-equivalent dispatches, **When** the harness runs, **Then** the output reports outcome-rate deltas (verification pass rate, retry count, deviation count) between the two cohorts with confidence intervals.
2. **Given** the harness detects a regression beyond the configured threshold (default: pass-rate delta ≥ -5% with p<0.1), **When** the report renders, **Then** the regression is flagged in the summary block and `orchestrator:doctor` surfaces it as an advisory diagnostic (US-6 integration).
3. **Given** sample size is below the configured minimum, **When** the harness runs, **Then** it emits "insufficient sample" and exits 0 — never produces noisy false-positives. Default minimum: 30 per cohort.
4. **Given** a regression is flagged, **When** the operator runs `bash scripts/util/cache-replay.sh --tier 3 --since <date>`, **Then** the originals persisted at `.orchestrator/cache/tier3-originals/` are replayed for manual inspection.

---

### User Story 8 — Multi-Runtime Parity (CC + Codex CLI + Cursor) (Priority: P3)

When the compression pipeline fires under any supported runtime, every tier's behavior is byte-identical-modulo-LLM-output across Claude Code, Codex CLI, and Cursor. The pipeline's bash-only tiers (filter, Tier 1, Tier 2) are byte-identical. Tier 3's LLM call routes through `dispatch-interface.sh` so each runtime calls its native model; output formatting is normalized via the prompt template so downstream consumers see consistent in-band markers.

**Why this priority**: M009 launch gate. P3 because the minimal slice runs in CC alone; multi-runtime parity is necessary for launch but not for M018 close. The work is auditing tier shell-scripts for CC-specific assumptions, extending the dispatch interface to route Tier 3 calls portably, and adding a row to `RUNTIME-ASSUMPTIONS.md` for any unavoidable runtime divergence.

**Independent Test**: Run the full pipeline under each runtime adapter against the same fixture milestone. Diff the resulting compressed payloads. Bash-only tier outputs are byte-identical. Tier 3 outputs vary by model but conform to the same in-band marker schema. `RUNTIME-ASSUMPTIONS.md` carries a row for any documented divergence (e.g., model-pricing differences feeding Tier 3 cost estimates).

**Acceptance Scenarios**:

1. **Given** the same fixture payload, **When** US-2/US-3/US-4 (zero-LLM tiers) run under CC, Codex CLI, and Cursor, **Then** the post-compression payloads are byte-identical across runtimes.
2. **Given** Tier 3 runs under each runtime, **When** the dispatch closes, **Then** each runtime's LLM call routes through `dispatch-interface.sh` with the same template, the in-band marker is present, and `dispatch_usage` records carry the runtime-specific model name + pricing.
3. **Given** any runtime-specific divergence is required, **When** the divergence is documented, **Then** `references/RUNTIME-ASSUMPTIONS.md` carries a row naming the divergence, the rationale, and the M009 audit row that consumes it.

---

## Edge Cases

- **Empty payload section after filter**: US-2 may filter all knowledge entries; the payload still emits the section header with `(no qualifying knowledge entries)` so downstream parsers see a consistent shape.
- **Cache-hash collision**: Tier 1 hashes (command + input) for cache reuse. A collision (astronomically unlikely with SHA-256 but possible with truncated hashes) would replay a different tool result. Mitigation: full SHA-256, not truncated; the `<file_path>` reference includes the original command for visual verification.
- **Tier 3 LLM produces a summary larger than the pre-compression section**: rare but possible. Tier 3 measures output size and discards the summary if it exceeds 80% of input size; passes through Tier 2's output instead, with a `tier3_no_savings` JSONL record naming the discard.
- **Mid-pipeline contract violation discovered post-emit**: a downstream consumer (e.g., the receiving agent) detects a preserved-pattern corruption that the tier's own self-check missed. The eval harness picks this up retroactively (US-7); the immediate dispatch is not retried (Constitution Principle V — fresh context per unit; retry is a planning-layer decision).
- **Pre-existing payload exceeds context window pre-compression**: extreme outlier. M018 does not promise context-window survival; it promises measurable token reduction. If a payload still exceeds the window post-pipeline, the dispatch fails at the runtime layer with the existing error path. T4 collapse is the future answer here; M018 explicitly defers it.
- **Cache directory grows unbounded**: `cache-prune.sh` is the manual answer; the milestone does not auto-prune. Doctor surfaces cache size as an advisory if the directory exceeds a configured threshold.
- **M020 review-state field absent on a knowledge entry (older entry)**: US-2 treats absence as `status: stable` (never dropped) — back-compat with all entries authored before M020.

---

## Functional Requirements

- **FR-0a (dispatch_usage-emitter-coverage)**: P00 closes the emitter-coverage gap so `dispatch_usage` JSONL records fire at parity (≥ 95%) with `payload_breakdown` across a 20-dispatch test sample. Satisfies US-0.
- **FR-0b (section-level-distribution-probe)**: P00 ships `scripts/diagnostics/m018-section-distribution.sh` extending the existing telemetry probe to report per-section size distribution + per-tier achievable-savings ceilings with confidence intervals. SC-9's threshold is calibrated against this probe's output. Satisfies US-0.
- **FR-1 (tier-grammar-document)**: M018 ships `references/compression-grammar.md` as the versioned contract. Lints clean against `scripts/verify/compression-grammar-lint.sh`. Satisfies US-1.
- **FR-2 (preservation-contract)**: Every tier's implementation includes a self-check that rejects any output containing a corrupted preserved-pattern byte. Self-check failure passes payload through unmodified to the next tier and emits a `tier_preservation_violation` JSONL record. Satisfies US-1.
- **FR-3 (knowledge-filter)**: `scripts/dispatch/build-context.sh` reads M020 `status:` field on knowledge entries and excludes entries matching the configured drop-list before payload assembly. Default drop-list: `["superseded", "experimental"]`. Satisfies US-2.
- **FR-4 (filter-emitter)**: When the filter drops entries, a `payload_filter` JSONL record is appended to `execution-log.jsonl`; `payload_breakdown` carries `filter_dropped_tokens`. Satisfies US-2 + US-6.
- **FR-5 (tier1-tool-result-paging)**: Tier 1 replaces oversized inline tool results with `file_path + preview` references and persists originals to `.orchestrator/cache/tool-results/`. Satisfies US-3.
- **FR-6 (tier1-cache-reuse)**: Tier 1 keys cache lookups by SHA-256(command + input) and reuses references across dispatches. Satisfies US-3.
- **FR-7 (tier2-snip)**: Tier 2 head-drops section bodies to a configured budget while preserving a configured tail ratio byte-identical. In-band markers name the snip; preserved-pattern boundaries refuse the snip. Satisfies US-4.
- **FR-8 (tier3-auto-compact)**: Tier 3 routes summarization through `dispatch-interface.sh` with `templates/compression-tier3-prompt.md`. Originals persist to `.orchestrator/cache/tier3-originals/`. Skipped at Quick intensity. Satisfies US-5.
- **FR-9 (tier3-failure-passthrough)**: Tier 3 LLM-call failures pass through Tier 2's output and emit `tier3_failed`; never crash the dispatch. Satisfies US-5 + Constitution Principle II.
- **FR-10 (m019-savings-fields)**: `payload_breakdown`, `dispatch_usage`, and `unit_close` records are extended with `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier3_compression_savings_tokens`, `tier1_invocations`, `tier3_invocations` fields. Schema additions are additive (back-compat). Satisfies US-6.
- **FR-11 (m027-surface-extension)**: `orchestrator:cost` rollup output, `orchestrator:status` efficiency footer, and `orchestrator:doctor` anomaly check all read the new savings fields and surface them. Satisfies US-6.
- **FR-12 (eval-harness)**: `scripts/diagnostics/compression-eval.sh` reads historical telemetry, segments compressed vs uncompressed cohorts, reports outcome-rate deltas with confidence intervals; `--tier <N>` filters by tier. **Operational by Tier 3 ship** (per gate RISK-3) — eval harness participates in Tier 3's verification ladder before Tier 3 dispatches mark `unit_close: pass`. Satisfies US-7.
- **FR-13 (multi-runtime-parity)**: Zero-LLM tiers (filter, T1, T2) are byte-identical across CC / Codex CLI / Cursor; Tier 3 routes through `dispatch-interface.sh`; divergences logged in `references/RUNTIME-ASSUMPTIONS.md`. Satisfies US-8.
- **FR-14 (intensity-gating)**: Quick → filter + T1 + T2 only; Standard → through T3; Full → all available tiers. Implemented via `scripts/engine/intensity-gate.sh` consumption in `build-context.sh`. T4 is out of scope (Non-Goal).
- **FR-15 (config-disable)**: `compression.enabled: false` in `.orchestrator/config.yml` short-circuits the entire pipeline; payload bytes are byte-identical to pre-M018 baseline. Per-tier disable flags exist (`compression.tier1.enabled`, etc.) for surgical opt-out.
- **FR-16 (cache-prune)**: `scripts/util/cache-prune.sh --max-age <duration>` prunes cache entries older than the named age; entries referenced by execution logs in the active retention window are preserved.
- **FR-17 (originals-authoritative)**: M018 never compresses files on disk that are not its own cache artifacts. Knowledge tree, spec files, plan files, and roadmap files remain byte-identical to pre-M018 state at all times. Constitution Principle VI compliance.
- **FR-18 (conversus-gate-p01)**: P01 `references/compression-grammar.md` is gated through `scripts/dispatch/adapters/tool/conversus.sh gate compression-grammar ...` with `--strict` before P01 closes; BLOCK verdicts halt P01.
- **FR-19 (in-band-markers)**: Every tier that modifies a payload section emits an in-band HTML-comment marker (`<!-- compressed:tierN ... -->`) so eval harness, debug tools, and downstream agents can detect compression without parsing JSONL.

## Success Criteria

- **SC-1**: After P01, `bash scripts/verify/compression-grammar-lint.sh` exits 0 against `references/compression-grammar.md`. (FR-1)
- **SC-2**: After P01, `bash scripts/dispatch/adapters/tool/conversus.sh gate compression-grammar references/compression-grammar.md specs/030-context-compression-layer/conversus/grammar-result.md --strict` exits 0 (PASS verdict). (FR-18)
- **SC-3**: After P03 (minimal slice complete), running a control milestone dispatch with the M018 pipeline enabled produces a `payload_breakdown` record where `filter_dropped_tokens + tier1_savings_tokens > 0` for at least one section. (FR-3, FR-5)
- **SC-4**: After P03, a fixture-replay test (`bash tests/integration/test-m018-minimal-slice.sh`) exits 0; the test constructs a fixture with knowledge entries + tool results and verifies filter drop-count + Tier 1 paging match expected. (FR-3, FR-5)
- **SC-5**: After all phases, running the M027 efficiency footer against a milestone with M018 dispatches shows the "Compressed: <pct>% reduction over baseline" line; running `orchestrator:cost` shows the per-tier savings block. (FR-11)
- **SC-6**: After all phases, `bash scripts/diagnostics/compression-eval.sh --tier 3` against a milestone with ≥ 30 Tier 3 invocations exits 0 and reports either "no regression" or a flagged regression with confidence interval. (FR-12)
- **SC-7**: Multi-runtime parity audit: identical fixture payloads dispatched through CC / Codex CLI / Cursor produce byte-identical outputs from zero-LLM tiers; `references/RUNTIME-ASSUMPTIONS.md` carries a row per documented divergence. (FR-13)
- **SC-8**: With `compression.enabled: false`, a sentinel dispatch produces a payload byte-identical to the pre-M018 baseline (regression test against a checked-in golden fixture). (FR-15, FR-17)
- **SC-9**: After M018, a measurable mean-payload reduction is reported in milestone-summary.md against the pre-M018 baseline (mean=16,797 tok). The target threshold is **empirically calibrated in P00** by the section-level distribution probe (US-0); the threshold lands in the spec via `--amend` before P01 closes. SC-9 fails if the post-M018 measured reduction falls below the calibrated threshold's lower confidence bound. *(Per gate finding RISK-2 + P00 calibration: SC-9 threshold floor is **34.7%** mean payload-token reduction, derived from `scripts/diagnostics/m018-section-distribution.sh` aggregate-ceiling 80% CI lower bound across n=169 historical `payload_breakdown` records under per-tier modeling assumptions documented in the probe script. Probe output archived at `.orchestrator/scratch/m018-section-distribution-output.{json,txt}`. Expected mean: 35.1%; optimistic ceiling: 35.4%.)*

## Non-Goals

- **NG-1 (Tier 4 collapse, deferred)**: D010 lists Tier 4 as feature-flagged-off. Per the M018 telemetry probe, p95=24k tokens — context-window pressure does not exist on this profile, so the staged-collapse complexity does not earn its cost. T4 is reframed as a follow-up milestone if and when telemetry shifts. Rationale: per Constitution Principle XV (deliver less, ship sooner), do not over-engineer for problems we don't have.
- **NG-2 (memory-side compression, deferred)**: D008's original P04 contemplated `CLAUDE.compressed.md` / `KNOWLEDGE.compressed.md` opt-in compression of memory files themselves. M018 does not ship this. Rationale: M018's pipeline operates only at dispatch boundaries (Constitution Principle VI — originals authoritative); memory-file compression is a different design problem (round-trip on edit, conflict on merge, reviewability) and would split M018's scope.
- **NG-3 (output-side terseness directive)**: D008's original P05 contemplated injecting a terseness directive into payload prefixes to compact the *agent's output*. M018 does not ship this. Rationale: output-side compaction is an instruction-engineering problem with different evaluation needs; bundle into a future milestone after the input-side pipeline is measured.
- **NG-4 (pre-existing context-window failures)**: M018 does not promise to bring already-too-large payloads under the runtime context window. Promise: measurable token reduction; not: catastrophic-payload survival.
- **NG-5 (knowledge-tree status field schema changes)**: M018 reads M020's `status:` field; it does not extend the vocabulary, change the graduation threshold, or add new field values. Vocabulary changes belong in M020 follow-ups.
- **NG-6 (auto-prune of cache directory)**: `cache-prune.sh` exists; auto-prune does not. Operator-driven only. Rationale: cache eviction policy is a real design problem deserving its own decision; M018 ships the manual surface.
- **NG-7 (compression of dispatched-agent outputs)**: M018 compresses *inputs* (dispatch payloads). It does not compress agent *outputs* (responses, generated artifacts) — those are governed by the receiving runtime, not by orchestrator state.

## Constraints

- **CON-1 (read-mostly)**: M018 modifies only `.orchestrator/cache/` (new directory tree), the M019 emitter schema (additive fields), and `references/compression-grammar.md` + `references/RUNTIME-ASSUMPTIONS.md`. Knowledge tree, spec files, plan files, roadmap files, and existing scripts in non-compression code paths are untouched. Constitution Principle VI compliance.
- **CON-2 (intensity-bound)**: Per D010, every tier's invocation is intensity-gated. Quick = filter + T1 + T2. Standard = through T3. Full = all tiers (where T4 is out of scope per NG-1, Full = same as Standard for this milestone).
- **CON-3 (zero-LLM-default)**: The minimal slice (US-1 + US-2 + US-3) and Tier 2 (US-4) introduce zero LLM cost. Only Tier 3 (US-5) calls a model. Constitution Principle XII compliance — measure first, spend tokens second.
- **CON-4 (in-band marker discoverability)**: Every compressed payload section MUST carry an HTML-comment marker naming the tier and the reduction; tooling depending on this contract reads it without parsing JSONL.
- **CON-5 (back-compat-emitters)**: All M019 schema changes are additive. Pre-M018 records remain readable by post-M018 rollups; post-M018 records are readable by pre-M018 jq filters (missing fields treated as null).
- **CON-6 (conversus-gate-non-negotiable)**: P01 grammar-contract MUST pass conversus gate at `--strict` before P01 closes. Per D010, the parse-regression risk is exactly the subjective-quality territory the conversus adapter earns its cost on.

### Knowledge-Layer Boundary (M018 vs. M020)

M020 owns the knowledge-tree write-sites and the `status:` field vocabulary. M018 owns the dispatch-time *read* of that field for filtering. Specifically:

- **M020 owns**: knowledge entry creation, `status:` field semantics (`experimental`, `stable`, `superseded`, etc.), graduation criteria, review workflows, and any future field additions.
- **M018 owns**: the `compression.knowledge_filter.drop_list` config key, the filter implementation in `scripts/dispatch/build-context.sh`, the `payload_filter` JSONL record schema, and the rollup integration that surfaces filter savings.

Cross-boundary contract: M018 reads `status:` field values verbatim; missing field defaults to `status: stable` (never dropped). Any M020 vocabulary change is back-compat with M018 unless M018 adds the new value to its drop-list (which is M018's call).

## Assumptions

- **A-1 (M020 review-state available)**: M020 is closed (2026-04-25). The `status:` field vocabulary is graduated and authoritative on knowledge entries. Pre-M020 knowledge entries that lack the field are present and treated as `status: stable`.
- **A-2 (M027 surfaces shipped)**: M027 closed (2026-04-27). `orchestrator:cost`, the efficiency footer, and `orchestrator:doctor` anomaly check exist as integration targets for FR-11.
- **A-3 (M019 emitter coverage is M018/P00 prerequisite)**: Telemetry probe shows only 2 `dispatch_usage` records vs 169 `payload_breakdown` records. M018/P00 (US-0) resolves this as a hard prerequisite before any tier code lands. SC-3 / SC-9 / SC-6 depend on the fix; verification gates re-run after P00 closes.
- **A-4 (conversus adapter usable)**: The `scripts/dispatch/adapters/tool/conversus.sh` adapter from M011/P07 is operational and accepts the `gate` subcommand with `--strict` per M013/M014 precedent.
- **A-5 (intensity engine resolved)**: `scripts/engine/intensity-gate.sh` consumes a recommendation and returns a tier ceiling that the compression pipeline reads. M008 / M021 left this in place.
- **A-6 (single-runtime acceptance through P05)**: Phases P01–P05 develop and verify under Claude Code. P06 (US-7) and P07 (US-8) extend to Codex CLI + Cursor. Multi-runtime work does not gate the minimal-slice close.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md`:

- **Principle I (Context Minimization)**: M018 *is* the operationalization of this principle. Every tier reduces dispatch context; every measured saving is evidence the principle is honored. The intensity-gating per D010 enforces "minimum context that gets the job done" — not "maximum compression always."
- **Principle II (Evidence Before Claims)**: Pass-rate parity (US-7 eval harness) is the gate for Tier 3 quality claims. Token-savings claims are M019-emitter-grounded, not narrative. SC-9's threshold is concrete and measurable.
- **Principle III (Design Before Code)**: P01 ships `references/compression-grammar.md` *before* tier implementations; the contract is gated through conversus before P01 closes. D008+D010 are the upstream design substrate; this spec is the operational design.
- **Principle V (Fresh Context Per Unit)**: M018 does not change the dispatch loop's fresh-context contract. Compression operates on the payload assembled for a fresh dispatch, not on cross-dispatch state.
- **Principle VI (State On Disk Is Truth)**: FR-17 ensures originals remain authoritative. Compression artifacts live under `.orchestrator/cache/` and are explicitly disposable (FR-16 prune). No compression operation rewrites canonical files.
- **Principle XII (Measure Costs, Spend Selectively)**: CON-3 enforces zero-LLM-default. Tier 3 is the only LLM-cost surface and is intensity-gated + eval-gated. Every tier ships with M019 savings fields so the operator can measure the wins.
- **Principle XIV (Don't Plan Speculatively)**: NG-1 (Tier 4 deferral) is the load-bearing scope-discipline call. The telemetry probe is the empirical anchor: p95=24k tokens does not justify the staged-collapse complexity. T4 is reframed as demand-driven follow-up.
- **Principle XV (Deliver Less, Ship Sooner)**: Minimal slice = US-1 + US-2 + US-3 (filter + T1). Tiers 2/3 are P2; eval harness + multi-runtime parity are P3. The slice closes the dogfood loop with measurable savings; subsequent priorities defend their phase scope on top of the slice.

## Open Questions (defer to planning)

- **#Q-1 — RESOLVED (committed to P00 per gate RISK-2)**: The savings-target threshold is empirically calibrated in P00's section-level distribution probe (US-0) rather than guessed. SC-9 reflects the probe's empirically-grounded value via `--amend` before P01 closes.
- **#Q-2 — RESOLVED (committed to P00 per gate RISK-1)**: The `dispatch_usage` emitter coverage gap is a hard P00 prerequisite. P00 lands the fix; tier code does not start until parity ≥ 95% across a 20-dispatch test sample.
- **#Q-3 (eval-harness-scope)**: US-7 measures behavioral parity (verification pass rate, retry count, deviation count). Two sub-options: (i) replay historical dispatches with compressed payloads through the same model and compare outcomes (expensive, high-fidelity, real signal); (ii) hold-out comparison — segment dispatches that triggered Tier 3 vs those that didn't, compare outcomes against natural variance (cheap, observational, weaker signal). *Answered at plan-phase for P06; M027's anomaly detection gives a runtime canary that may make (ii) sufficient.*
- **#Q-4 (knowledge-filter-default-drop-list)**: Default drop-list = `["superseded", "experimental"]`. Are there M020 vocabulary values not yet considered? Should the default include `archived` or `deprecated` if M020 adds them? *Answered at plan-phase, after a fresh read of M020's graduated vocabulary.*
- **#Q-5 (tier3-summarization-prompt-design)**: The summarization prompt template (`templates/compression-tier3-prompt.md`) is the load-bearing artifact for Tier 3 quality. Does it differ per artifact class (knowledge entry summarization ≠ task plan summarization ≠ tool-result summarization)? D010's grammar-contract framing suggests yes; but per-class prompts multiply the eval-harness comparison surface. *Answered at plan-phase for P04, informed by sample summarizations against fixture sections.*
- **#Q-6 (cache-eviction-policy)**: NG-6 defers auto-prune. Manual `cache-prune.sh` works; but operators will forget. Is a doctor-surfaced cache-size advisory sufficient, or should the cache include a TTL header that doctor enforces? *Answered post-M018, after cache directory growth is observed in production.*

## Dependencies

- **DEP-1 (M020 — Knowledge Layer Maturation)**: closed 2026-04-25. Provides the `status:` field vocabulary US-2 reads.
- **DEP-2 (M027 — Cost+Quality Observability Surfaces)**: closed 2026-04-27. Provides `orchestrator:cost`, efficiency footer, and `orchestrator:doctor` anomaly check that FR-11 extends.
- **DEP-3 (M019 — Observability Metrics Tier 1+2/3)**: closed. Provides the emitter schema FR-10 extends additively.
- **DEP-4 (M011/P07 — conversus adapter)**: shipped. Provides the `gate` adapter FR-18 invokes.
- **DEP-5 (M008/M021 — intensity engine)**: shipped. Provides `intensity-gate.sh` for FR-14.
- **DEP-6 (`scripts/dispatch/build-context.sh`)**: existing. M018 extends it (knowledge filter + tier pipeline invocation).
- **DEP-7 (`scripts/dispatch/dispatch-interface.sh`)**: existing. Tier 3 routes summarization through it for runtime portability.

## Downstream Consumers (informational, not binding)

- **M009 — Launch & Ecosystem**: consumes US-8 (multi-runtime parity) as part of the runtime-parity launch audit. M018 contributes a row to `references/RUNTIME-ASSUMPTIONS.md` for any documented divergence.
- **M023 — Design Layer**: consumes the eval-harness pattern (US-7) as a reference for design-prototype evaluation, since both surfaces compare alternative outputs against a baseline.
- **Future T4-collapse milestone**: NG-1 reframes T4 as demand-driven. If telemetry shifts (p95 climbs toward context-window), this spec's tier-grammar contract (US-1) and intensity-gating model (FR-14) are the substrate that follow-on T4 work extends.

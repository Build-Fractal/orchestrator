---
schema_version: "1.0"
type: feature-spec
feature_slug: "034-right-sized-entry"
created_at: "2026-05-01"
status: "Draft"
milestone: "M031"
---

# Feature Specification: 034-right-sized-entry

**Feature Branch**: `034-right-sized-entry`
**Created**: 2026-05-01
**Status**: Draft
**Milestone**: M031
**Input**: User description: "M031 right-sized entry: restore knowledge graph + compression access for Quick intensity (commands/dispatch.md:21 leak), add Tier A+ middle flow (research → plan → build, no auto/roadmap/consolidate), universal orchestrator <task> entry with confidence-gated auto-routing, and evaluate.md internal-drift reconciliation."

## Problem Statement

The orchestrator's value proposition is "agents always run on fresh, knowledge-rich context, efficiently." Today that promise quietly leaks at exactly the size where it matters most. `commands/dispatch.md:21` directs Quick intensity to **skip `build-context.sh`** and dispatch with "only the task plan." Standard and Full inject knowledge; Quick does not. The original justification was payload-byte minimization, but that conflates payload bytes with total task tokens — a Quick-profile knowledge inject is ~800 tokens, while the agent's alternative (rediscovery via grep/read across an unfamiliar codebase) burns 5–15k tokens of exploration plus quality regression. The smaller the task, the worse this trade gets, because there is no large-task budget to amortize the rediscovery cost against.

Three pain-points follow from the gap. **(P1)** A Tier A user fixing a one-line bug pays full exploration cost against a small task budget, contradicting the stated promise of Principle VII (Knowledge Compounds). **(P2)** There is no middle flow between "single-shot dispatch" and "full SDD ceremony" (roadmap → phases → auto loop → consolidate); medium-complexity tasks are forced into one of two ill-fitting shapes. **(P3)** The entry surface for new users is too wide — `orchestrator:evaluate`, `orchestrator:specify`, `orchestrator:dispatch`, `orchestrator:auto`, plus status/doctor/cost/resume — and choice paralysis bites hardest on small tasks where ceremony is least appropriate. Compounding the problem, `commands/evaluate.md` carries internal drift: a post-M024 input-shape table (lines 14–23) routes Tier A through `orchestrator:dispatch`, while a pre-M024 section (lines 101–140) instructs the agent to "route directly to standard spec-kit commands" with "no orchestrator overhead" — contradictory instructions in one document.

The minimum surface that fixes all three: (a) make knowledge + M018 compression unconditional across all three intensities, scaling Quick/Standard/Full by **traversal aggressiveness** (1-hop / 2-hop / full provenance) rather than by whether knowledge ships at all; (b) introduce a Tier A+ middle flow — three single-context dispatches (research → plan → build), no roadmap or auto loop or consolidate; (c) add a universal `orchestrator <task>` entry that auto-routes via the existing M024 classifier and gates on classification confidence; (d) reconcile the evaluate.md drift so Tier A always uses orchestrator dispatch with knowledge access.

What this feature explicitly does not attempt: knowledge-layer redesign (M020 territory, closed); cost-surface redesign (M027); model selection (M030); auto-loop hardening (M028); a long-running interactive shell; or auto-tuning of intensity from past task data. M031 is **flow shape + entry UX**, not knowledge or cost or routing internals.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The minimal slice that closes the dogfood loop is **US1 (Quick gets knowledge) + US4 (evaluate.md drift fixed)**. Once Quick dispatches inject knowledge per US1, every subsequent orchestrator self-development task — including the work to ship US2 (Tier A+) and US3 (universal entry) — runs on a knowledge-rich Quick path, not the leaky one. US4 closes the documentation contradiction so the slice is internally consistent. US2 and US3 build on top of the slice; their absence does not invalidate the slice's value.

### User Story 1 — Quick intensity gets knowledge + compression unconditionally (Priority: P1)

A developer dispatches a Quick-intensity task (e.g. one-line bugfix). The dispatch payload includes a scope-filtered knowledge inject (touched-file 1-hop graph hits, no decisions, no glossary beyond touched terms) plus M018 tier-1 + tier-2 compression. The agent does not have to grep/read its way to context that the knowledge graph already contains.

**Why this priority**: This is the load-bearing constitutional fix. Principle I (Context Minimization) targets *total task tokens via efficient context delivery*, not *payload bytes*. Principle VII (Knowledge Compounds) requires that the knowledge layer benefit every dispatch. Today's Quick path violates both. Every other story in this spec is downstream of Quick dispatches being knowledge-rich; shipping US2 or US3 without US1 would build new flows on a broken foundation.

**Independent Test**: Run a fixture Quick-intensity dispatch end-to-end; inspect the dispatch payload manifest and verify it contains a knowledge section sized to the Quick profile (≤ ~1500 tokens), and verify the `payload_breakdown` JSONL record shows non-zero `knowledge_section_tokens` and non-zero compression-tier stats. No dependency on US2/US3/US4.

**Acceptance Scenarios**:

1. **Given** a Quick-intensity task plan with one touched file `src/foo.go`, **When** the dispatch pipeline runs `build-context.sh --profile=quick`, **Then** the assembled payload contains a knowledge section with 1-hop graph hits scoped to `src/foo.go`, no Decisions section, and a glossary slice covering only terms appearing in the touched file.
2. **Given** the same fixture, **When** the dispatch payload is serialized, **Then** M018 tier-1 (tool-result paging) and tier-2 (snip) are applied per `compression.tier1.enabled` / `compression.tier2.enabled` in `.orchestrator/config.yml`.
3. **Given** the empirical baseline corpus (US1 verifier fixture), **When** pre-M031 Quick (no knowledge) and post-M031 Quick (with knowledge) are compared on verifier pass rate, **Then** post-M031 Quick has equal-or-higher pass rate (the load-bearing CON-5 + Principle II claim — pass-rate parity is what the empirical gate enforces; verdict frame inverted at P04/T04 commit `6979afa` per AD-19 because M031 *restores* knowledge access rather than thrifting it, so post-tokens > pre-tokens by construction). Token-budget discipline is owned separately by SC-15 against `quick_knowledge_token_budget`.

### User Story 2 — Tier A+ middle flow (research → plan → build) (Priority: P2)

A developer with a medium-complexity task ("add a new flag to script X with three tests and a doc update") invokes the orchestrator. The classifier emits `tier_a_plus`. The orchestrator runs three single-context dispatches in sequence — `dispatch --role=research` (produces a tight findings doc), `dispatch --role=plan` (produces a single PLAN.md with steps + verifiers), `dispatch --role=build` (executes; verifiers run inline). No roadmap is created, no phase decomposition, no auto loop, no consolidate, no lock. Each dispatch gets full per-profile knowledge + compression per US1.

**Why this priority**: Closes the gap between Tier A (single dispatch) and Tier B (full SDD), which is currently a forced-choice between "underplanning" and "ceremony." P2 because it depends on US1 (each dispatch must inject knowledge) and because Tier A+ tasks are less frequent than the trivial-Tier-A or full-SDD-Tier-B cases — but they are the cases where today's choice is most painful.

**Independent Test**: Submit a fixture 30-word feature request through the universal entry (or directly via the M024 classifier). Verify (a) classifier emits `tier_a_plus`; (b) three dispatches fire in sequence with role payloads `research`, `plan`, `build`; (c) no `.orchestrator/milestones/M###/` scaffolding is created; (d) no auto-loop lock is acquired; (e) each dispatch's payload manifest shows knowledge injection.

**Acceptance Scenarios**:

1. **Given** a 30-word feature request and `--tier=A+` operator override, **When** the universal entry fires, **Then** exactly three dispatches run sequentially with the expected role payloads, no milestone scaffolding is created, and the run completes without invoking `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate`.
2. **Given** the M024 classifier produces a confident `tier_a_plus` verdict, **When** the universal entry executes without operator override, **Then** the orchestrator routes to the Tier A+ flow and asks for one approval prompt before the `plan` dispatch fires (the `--yes` flag skips this prompt).
3. **Given** the `plan` dispatch produces a PLAN.md with verifiers, **When** the `build` dispatch executes, **Then** the verifiers declared in the plan run inline and the build dispatch exits non-zero if any verifier fails.

### User Story 3 — Universal `orchestrator <task>` entry with confidence-gated auto-routing (Priority: P2)

A new user types `orchestrator "fix typo in foo.md"`. The orchestrator runs the M024 classifier, gets a high-confidence Tier A degenerate verdict, and dispatches immediately with a knowledge-injected payload. One stderr line ("doing: fix typo in foo.md — knowledge: N MEMs / X tokens") and a final diff is the entire user-visible flow. No approval prompt for high-confidence trivial tasks. Low-confidence classifications fall back to an explicit "is this Tier A or Tier B?" prompt rather than silently picking the wrong shape.

**Why this priority**: Eliminates choice paralysis for small tasks and lowers adoption friction. P2 because it is downstream of US1 (the dispatched payload must be knowledge-rich) and US2 (Tier A+ is one of the routing destinations). The user-facing UX win is the highest-visibility piece, but it cannot ship before its destinations work.

**Independent Test**: Run `orchestrator "<trivial task>"` against a fixture; verify exactly one stderr summary line, exactly one dispatch fires, the dispatch payload contains a knowledge section, and the operator received zero approval prompts.

**Acceptance Scenarios**:

1. **Given** the universal entry receives `"fix typo in foo.md"`, **When** the M024 classifier emits a high-confidence Tier A degenerate verdict, **Then** the orchestrator dispatches without prompting and the run completes with a single stderr summary line and a final diff.
2. **Given** the classifier produces a low-confidence verdict (confidence below the configured `entry_routing_confidence_floor`), **When** the universal entry runs, **Then** the operator is asked an explicit Tier A vs Tier B question and the chosen shape is recorded in the JSONL `unit_close` record.
3. **Given** a Tier A+ classification, **When** the universal entry runs, **Then** the operator gets exactly one approval prompt (before plan dispatch) unless `--yes` is set.
4. **Given** a Tier B/C classification, **When** the universal entry runs, **Then** the orchestrator routes to `orchestrator:specify` (or the existing `orchestrator:evaluate` flow) without changing today's behavior.

### User Story 4 — `commands/evaluate.md` internal-drift reconciliation (Priority: P1)

A new user reading `commands/evaluate.md` top-to-bottom does not encounter contradicting Tier A definitions. The pre-M024 section that says "route directly to standard spec-kit commands" / "Do NOT create any orchestrator directory structure" is removed. `references/tier-definitions.md` is updated to match. The FR-003 reference to "no orchestrator dir for Tier A" is clarified to mean *no `.orchestrator/milestones/M###/` scaffolding* — `.orchestrator/` itself (config, knowledge, integrations) is always present.

**Why this priority**: Documentation contradiction is a P1 because it actively misleads agents and humans reading the docs. A new operator following the pre-M024 paragraph would skip orchestrator state entirely; a new operator following the M024 paragraph would expect knowledge injection. Internally inconsistent docs are a load-bearing failure for a project whose constitution is "Plans Assume Zero Context" (Principle IV).

**Independent Test**: A documentation drift verifier (grep-based) confirms that `commands/evaluate.md` contains no instruction matching the pattern "no orchestrator overhead" / "Do NOT create any orchestrator directory" for Tier A; `references/tier-definitions.md` contains no contradicting Tier A description; both files describe Tier A as "single dispatch with knowledge + compression."

**Acceptance Scenarios**:

1. **Given** the post-M031 `commands/evaluate.md`, **When** the doc-drift verifier scans the file, **Then** zero matches are found for the pre-M024 Tier A "no orchestrator overhead" phrasing and exactly one canonical Tier A description remains.
2. **Given** the post-M031 `references/tier-definitions.md`, **When** the same verifier scans it, **Then** the Tier A description is consistent with `commands/evaluate.md` and explicitly states that `.orchestrator/` is always present.

---

## Edge Cases

- **Quick-profile inject still exceeds budget**: a Quick task whose touched-file 1-hop graph traversal returns more knowledge than the `quick_knowledge_token_budget` allows. Behavior: M018 tier-2 snip applies as the existing compression contract does; no special-case truncation. If the budget is repeatedly exceeded, the underperformance signal (already shipped) surfaces it for operator tuning.
- **Touched-file set is empty for a Quick task** (e.g. a doc-only task with no file paths in the plan): traversal falls back to the milestone or the project root scope as configured; the behavior is identical to running Quick today on a degenerate plan, not a regression.
- **M024 classifier produces a malformed verdict**: the universal entry treats malformed as low-confidence and asks the explicit Tier A vs Tier B question. No silent guess.
- **Operator declines the Tier A+ pre-plan prompt**: the run aborts cleanly with a `unit_close` record showing `aborted=true`, no PLAN.md or BUILD artifacts written.
- **Tier A+ build dispatch's inline verifier fails**: the build dispatch exits non-zero; no implicit retry. The operator decides whether to re-dispatch or escalate to Tier B.
- **`auto_proceed` config default flip backward-compat**: existing projects whose `.orchestrator/config.yml` does not declare `auto_proceed` see the new default (`true`); existing projects that *explicitly* declare `auto_proceed: false` keep the explicit value. The CHANGELOG names this flip.
- **Universal entry on a runtime that does not support verbless invocation**: the orchestrator falls back to `orchestrator:do <task>` as the canonical surface; the universal entry's documented invocation reflects the active runtime.
- **A scaffold-placeholder marker legitimately needs to appear inside an authored knowledge file** (e.g., a glossary entry naming the placeholder token by name): per D020 + commands/specify.md Gotchas, authors paraphrase as "scaffold-placeholder marker" or escape the angle bracket so the gate adapter's pre-flight does not falsely trip.

---

## Functional Requirements

- **FR-1 (knowledge-unconditional)**: The dispatch pipeline MUST inject knowledge + compression for every intensity. The Quick path MUST NOT skip `build-context.sh`. Satisfies US1.
- **FR-2 (build-context-profile-flag)**: `scripts/dispatch/build-context.sh` MUST accept a `--profile=quick|standard|full` flag. The Quick profile MUST set scope to touched-files-only, traversal to 1-hop direct hits, no Decisions section, and a glossary slice covering only touched terms. Standard MUST set phase scope, 2-hop traversal, phase-relevant Decisions, phase-touched glossary. Full MUST set milestone-plus-dependencies scope, full provenance traversal, all milestone Decisions, full glossary. Satisfies US1.
- **FR-3 (compression-applies-to-quick)**: M018 tier-1 (tool-result paging) and tier-2 (snip) MUST apply to Quick-profile payloads when `compression.tier1.enabled` / `compression.tier2.enabled` are true. The pre-M031 Quick path bypasses build-context entirely and therefore bypasses compression; FR-3 closes that gap. Satisfies US1.
- **FR-4 (dispatch.md-reconciliation)**: `commands/dispatch.md:21` MUST be amended to remove the "skip payload assembly" branch for Quick. The replacement MUST describe Quick as "knowledge + compression with the Quick profile." Satisfies US1.
- **FR-5 (knowledge-token-budget-knob)**: `.orchestrator/config.yml` MUST grow a `quick_knowledge_token_budget` key (default value pinned in P00 empirical baseline; recommended starting value 800 tokens unless P00 evidence dictates otherwise). The knob is an advisory ceiling — M018 tier-2 snip is the enforcement mechanism. Satisfies US1.
- **FR-6 (tier-a-plus-classifier)**: `scripts/intake/paragraph-classify.sh` and `scripts/intake/shape-detect.sh` MUST emit a `tier_a_plus` verdict for medium-complexity inputs that are too large for single-shot but too small for full SDD. The exact heuristic boundary is calibrated in plan-phase (P02 of M031); the verdict surface is required by FR-6. Satisfies US2.
- **FR-7 (tier-a-plus-router)**: `scripts/intake/route-to-dispatch.sh` MUST recognize `tier_a_plus` and chain three dispatches (research → plan → build) without invoking `orchestrator:auto`, `orchestrator:roadmap`, or `orchestrator:consolidate`. Satisfies US2.
- **FR-8 (tier-a-plus-role-payloads)**: Three new dispatch role templates MUST exist — `research`, `plan`, `build` — under `templates/`. Each template is prescriptive (research produces N findings; plan produces a single PLAN.md with explicit steps + verifiers; build executes the plan and runs verifiers inline). Satisfies US2.
- **FR-9 (tier-a-plus-approval-gate)**: The Tier A+ flow MUST emit one approval prompt before the `plan` dispatch fires (operator can sanity-check direction). The `--yes` flag MUST suppress the prompt. There MUST NOT be an approval prompt before `build` if `plan` succeeded. Satisfies US2.
- **FR-10 (universal-entry-skill)**: A new top-level invocation surface MUST exist — `orchestrator <task>` if the runtime supports verbless invocation, otherwise `orchestrator:do <task>`. The skill MUST auto-route via the M024 classifier. Satisfies US3.
- **FR-11 (universal-entry-confidence-gate)**: The universal entry MUST gate routing on classifier confidence. A `entry_routing_confidence_floor` config knob (default pinned in P00 or P03 plan; recommended starting value 0.7) MUST control the threshold below which the entry asks the operator an explicit Tier A vs Tier B question. Satisfies US3.
- **FR-12 (universal-entry-fast-path)**: For high-confidence Tier A degenerate verdicts, the universal entry MUST dispatch without any approval prompt and emit one stderr summary line of shape `doing: <task> — knowledge: N MEMs / X tokens`. Satisfies US3.
- **FR-13 (universal-entry-tier-bc-passthrough)**: For Tier B/C verdicts, the universal entry MUST route to today's `orchestrator:specify` flow without changing existing Tier B/C behavior. Satisfies US3.
- **FR-14 (evaluate-md-drift-fix)**: `commands/evaluate.md` MUST be amended to remove the pre-M024 Tier A "no orchestrator overhead" / "Do NOT create any orchestrator directory" section. The post-M031 file MUST contain exactly one canonical Tier A description: "single dispatch with knowledge + compression via the Quick profile." Satisfies US4.
- **FR-15 (tier-definitions-drift-fix)**: `references/tier-definitions.md` MUST be amended to match `commands/evaluate.md` post-fix. The Tier A entry MUST explicitly state that `.orchestrator/` (config, knowledge, integrations) is always present and that only `.orchestrator/milestones/M###/` scaffolding is conditional. Satisfies US4.
- **FR-16 (auto-proceed-default-flip)**: `templates/orchestrator-config-default.yml` MUST flip the `auto_proceed` default from `false` to `true`. The CHANGELOG entry for M031 MUST name this flip explicitly so existing-project operators know to add an explicit `auto_proceed: false` line if they prefer the old behavior. Satisfies US3.
- **FR-17 (doc-drift-verifier)**: A doc-drift verifier MUST exist (e.g., a `tests/m031-acceptance/` script) that grep-checks `commands/evaluate.md` and `references/tier-definitions.md` for the removed phrasings and confirms the canonical descriptions are present. Satisfies US4 acceptance.
- **FR-18 (empirical-baseline)**: A 20-task fixture corpus + a token/pass-rate comparison harness MUST exist before the FR-1 + FR-2 + FR-3 changes are merged. The harness MUST emit a JSONL record per task showing pre-M031 Quick vs post-M031 Quick total task tokens, verifier pass rate, and re-dispatch rate. Satisfies US1 acceptance scenario 3.
- **FR-19 (tier-a-plus-where-rendering)**: `orchestrator:where` (M029) MUST render Tier A+ runs as a 3-row mini-tree showing research / plan / build state; this requirement is a placeholder until M029 ships and may be deferred to a downstream consumer task. Informational FR; no merge blocker for M031.

## Success Criteria

- **SC-1 (Quick injects knowledge)**: Run `bash tests/m031-acceptance/test-quick-injects-knowledge.sh`. Exit 0. Asserts: a Quick-intensity dispatch payload manifest shows non-zero `knowledge_section_tokens` and non-zero `tier1_replacements` (or empty cache hit) in the JSONL `payload_breakdown` record.
- **SC-2 (build-context profile flag)**: Run `bash scripts/dispatch/build-context.sh --profile=quick --task-plan <fixture> --out /tmp/payload.md`. Exit 0. Resulting `/tmp/payload.md` Knowledge section is ≤ `quick_knowledge_token_budget` tokens AND a tier-2 snip JSONL record is emitted at the budget boundary when the source payload exceeds the budget. (No tolerance band; AD-13 grounds enforcement in M018 tier-2 snip per FR-5's "advisory ceiling" framing — earlier draft's plus-or-minus tolerance clause was contradictory and is dropped.)
- **SC-3 (compression applies to Quick)**: Run `bash tests/m031-acceptance/test-compression-applies-to-quick.sh`. Exit 0. The test fixture MUST construct a Quick-profile payload exceeding the M018 tier-1 `inline_threshold_tokens` value (documented in `references/RUNTIME-ASSUMPTIONS.md`). Asserts: tier-1 and tier-2 records appear in JSONL when the constructed payload meets the threshold.
- **SC-4 (dispatch.md amended)**: `grep -c "Skip payload assembly" commands/dispatch.md` returns 0. `grep -c "Quick profile" commands/dispatch.md` returns ≥ 1.
- **SC-5 (Tier A+ classifier verdict)**: Run `bash scripts/intake/shape-detect.sh < tests/m031-acceptance/fixtures/tier-a-plus-input.txt`. stdout contains `tier_a_plus`.
- **SC-6 (Tier A+ end-to-end)**: Run `bash tests/m031-acceptance/test-tier-a-plus-flow.sh`. Exit 0. Asserts: exactly three dispatches fire (research, plan, build); no `.orchestrator/milestones/M###/` scaffolding is created; no auto-loop lock acquired; one approval prompt observed before `plan` (or zero prompts under `--yes`).
- **SC-7 (universal entry trivial path)**: Run `bash tests/m031-acceptance/test-universal-entry-trivial.sh`. Exit 0. Asserts: one stderr summary line; exactly one dispatch fired; payload manifest shows knowledge injection; zero approval prompts.
- **SC-8 (universal entry low-confidence prompt)**: Run `bash tests/m031-acceptance/test-universal-entry-lowconf.sh`. Exit 0. Asserts: low-confidence classifier verdict produces an explicit Tier A vs Tier B prompt; chosen shape is recorded in `unit_close` record.
- **SC-9 (evaluate.md drift fix)**: Run `bash tests/m031-acceptance/doc-drift-verifier.sh`. Exit 0. Asserts: zero matches for "no orchestrator overhead" / "Do NOT create any orchestrator directory" in `commands/evaluate.md`; canonical Tier A description present in both `commands/evaluate.md` and `references/tier-definitions.md`.
- **SC-10 (auto_proceed default flip)**: `grep "auto_proceed" templates/orchestrator-config-default.yml` shows `auto_proceed: true`. CHANGELOG entry for M031 names the flip.
- **SC-11 (empirical baseline post-M031 maintains pass-rate parity)**: Run `bash tests/m031-acceptance/empirical-baseline.sh --compare`. Exit 0. Reads stored pre-M031 records from `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-baseline.jsonl` (captured at P00 close per AD-14 single-window discipline) and post-M031 records emitted during P01 first-task work; asserts `verdict=wins iff post_pass_rate >= pre_pass_rate` (verdict frame inverted at P04/T04 commit `6979afa` per AD-19 — pass-rate parity is the load-bearing CON-5 + Principle II claim because M031 *restores* knowledge access, so post-tokens > pre-tokens by construction; token-budget discipline is owned separately by SC-15 against `quick_knowledge_token_budget`). If the pass-rate assertion fails, P01 redesigns before merge per CON-5.
- **SC-12 (no scope creep into M020/M027/M030/M028)**: Run `bash tests/m031-acceptance/scope-guard.sh`. Exit 0. Asserts: M031's diff touches none of: `knowledge/` schema files, `scripts/cost/`, `scripts/dispatch/adapters/router/`, `scripts/auto/loop/`. (The list is a strict allow-list defined in the verifier; deletions and additions outside the allow-list fail.)
- **SC-13 (P00 empirical baseline lands first)**: Run `bash tests/m031-acceptance/verify-baseline-ordering.sh`. Exit 0 under Option B (the verifier asserts via `git log --diff-filter=A --follow` that the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/` predates the first commit touching `scripts/dispatch/build-context.sh` and `commands/dispatch.md`). If `git log` is unavailable (shallow clone), Option A activates: SC-13 reclassifies as a P00 protocol note, drops from SC-14's count, and N reduces by 1. The active option is recorded in `tests/m031-acceptance/fixtures/empirical-baseline/SC13-OPTION.md`.
- **SC-14 (acceptance battery green at milestone close)**: Run `bash tests/m031-acceptance/run-acceptance-battery.sh`. Output includes `BATTERY: pass=N fail=0` for some N ≥ 15 (one per SC-1..SC-13 plus SC-15 + SC-16 plus aggregator). Mirrors the M030 acceptance-battery convention. (N ≥ 14 if SC13-OPTION.md records Option A.)
- **SC-15 (Quick budget median compliance)**: Run `bash tests/m031-acceptance/test-quick-budget-median.sh`. Exit 0. Asserts: median `knowledge_section_tokens` emitted by `build-context.sh --profile=quick` across the 20-task corpus is ≤ `quick_knowledge_token_budget`, independent of the pre-M031 baseline. Complements SC-2 (per-task ceiling) and SC-11 (relative comparison).
- **SC-16 (Tier A+ prompt UX integration test)**: Run `bash tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh`. Exit 0. Asserts: captured stdout/stderr from a Tier A+ flow includes (a) plain-language framing strings (no `null`, no JSON braces, no scaffold-placeholder bracket-TODO patterns), (b) the first `tier_a_plus_prompt_summary_lines` lines of the fixture `research.md` rendered inline, (c) all three named options visible (`y`/`n`/`c`), (d) the `(N more lines at <path>)` ellipsis when research exceeds budget, AND (e) when `--yes` is passed, the `research: <path>` audit-line appears on stderr.

## Non-Goals

- **NG-1**: Knowledge-layer redesign (graph schema, indexer, traversal logic). M020 closed; M031 consumes the layer as-is.
- **NG-2**: Cost-surface redesign. M027 already shipped efficiency-footer + metrics-rollup + predictive-surface; M031 reads them but does not modify them.
- **NG-3**: Model selection. M030 closed; M031 composes with M030 routing (Tier A+ defaults to Sonnet/Haiku) but does not re-decide routing logic.
- **NG-4**: Auto-loop hardening. M028 closed; M031 introduces no new auto-loop behavior. The Tier A+ middle flow does NOT use `orchestrator:auto`.
- **NG-5**: A "no-orchestrator-state" mode. `.orchestrator/` is always present. Only milestone scaffolding is conditional.
- **NG-6**: Long-running interactive shell. The orchestrator stays one-shot per command; the universal entry is not a REPL.
- **NG-7**: Auto-tuning of intensity from past task data. P00 + static heuristics ship first; auto-tuning is a future, demand-driven follow-up.
- **NG-8**: Wiki/GitHub knowledge sync redesign. M012/M013 paths remain; M031 changes nothing about how knowledge is *authored*, only about how it is *injected* on dispatch.

## Constraints

- **CON-1 (knowledge-unconditional-invariant)**: Every dispatch path produced by M031 (Quick / Standard / Full / Tier A+ research / plan / build) MUST run through `build-context.sh` and emit a `payload_breakdown` JSONL record. There is no "skip context" exit — only "scope it tighter." Reasoning: Principle VII (Knowledge Compounds) requires every dispatch to benefit from the layer; a skip path is a permanent regression vector.
- **CON-2 (compression-always-applies)**: M018 tier-1 + tier-2 MUST apply to all dispatch payloads regardless of intensity, when the corresponding config tiers are enabled. M031 changes traversal aggressiveness, not compression participation.
- **CON-3 (M024-classifier-is-the-router)**: The universal entry MUST consume the existing M024 classifier verdicts; it MUST NOT introduce a parallel routing implementation. M024 closed; M031 extends it (new `tier_a_plus` shape, FR-6) but does not replace it.
- **CON-4 (no-new-state-machines)**: The Tier A+ flow is a chain of three single-context dispatches recorded as JSONL `unit_close` records; it MUST NOT introduce a new state machine, lock file, or roadmap surface. Reasoning: NG-4 and Principle XIV (No Speculative Complexity).
- **CON-5 (P00-empirical-gate)**: The FR-1/2/3 changes MUST NOT merge until the P00 empirical baseline (FR-18) confirms the Quick-with-knowledge-wins hypothesis on the 20-task fixture corpus. If empirical evidence contradicts, P01 redesigns before merge. Reasoning: Principle II (Evidence Before Claims).
- **CON-6 (CC-only-launch-posture)**: M031 ships CC-only at launch (matching the project's pre-launch posture). Codex CLI / Cursor parity is M009's job; M031 verifies behavior on Claude Code only and notes runtime gaps in `references/RUNTIME-ASSUMPTIONS.md`. The doc-drift verifier (FR-17) is bash-only (POSIX-portable) so it composes with future M009 parity work.
- **CON-7 (D020-todo-token-hygiene)**: All authored prose in this spec and in downstream M031 artifacts MUST avoid embedding the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code, because the conversus.sh gate adapter pre-flight matches that pattern and refuses artifacts containing it. Use "scaffold-placeholder marker" or paraphrase. Reasoning: D020 captured this footgun; M031 honors it preemptively.

### Knowledge-Layer Boundary (M031 vs. M020)

M020 owns the knowledge layer itself: graph schema (`knowledge/patterns/`, `knowledge/lessons/`, `knowledge/conventions/`), indexer, traversal logic, and the wiki view (M012). M020 is closed.

M031 owns **how dispatch payloads consume the knowledge layer**: the `--profile=quick|standard|full` flag on `build-context.sh`, the per-profile scope/traversal/decisions/glossary policy, and the `quick_knowledge_token_budget` config knob. M031 makes zero writes to `knowledge/**`; it changes only the *reader* surface.

Boundary write-sites M031 claims:
- `scripts/dispatch/build-context.sh` (new flag + profile-aware scope/traversal logic)
- `commands/dispatch.md` (Quick branch reconciliation)
- `commands/evaluate.md` (drift fix)
- `references/tier-definitions.md` (drift fix)
- `templates/orchestrator-config-default.yml` (new knobs + `auto_proceed` flip)
- `scripts/intake/paragraph-classify.sh`, `scripts/intake/shape-detect.sh`, `scripts/intake/route-to-dispatch.sh` (M024 surface extension for `tier_a_plus`)
- `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` (new)
- A new `commands/do.md` (or amendment to an existing entry skill) for the universal entry
- `tests/m031-acceptance/` (new acceptance battery)

Boundary write-sites M031 delegates:
- `knowledge/**` (M020-owned; no schema or content changes)
- `scripts/cost/` (M027-owned)
- `scripts/dispatch/adapters/router/` (M030-owned model routing)
- `scripts/auto/loop/` (M028-owned auto-loop internals)

## Assumptions

- **A-1**: M020 (knowledge layer maturation) and M018 (compression layer) ship working APIs that `build-context.sh` already consumes for Standard / Full. M031 extends the consumer to Quick; it does not assume knowledge-API or compression-API changes.
- **A-2**: M024 (universal intake & routing) ships a working classifier whose verdicts include a confidence value or can be extended to emit one in the same record. If the classifier does not emit confidence today, FR-11's confidence gate is a small extension to the M024 surface (in scope for M031 because it falls under FR-6 classifier-shape extension).
- **A-3**: M027 cost surfaces (efficiency-footer, metrics-rollup, predictive-surface) continue to read JSONL records emitted by `build-context.sh`. M031's new Quick-injection records appear in the same JSONL stream and surface naturally on existing M027 dashboards.
- **A-4**: Existing `.orchestrator/config.yml` files (in projects already using the orchestrator) work unchanged after M031: missing keys (`quick_knowledge_token_budget`, `entry_routing_confidence_floor`, flipped `auto_proceed` default) fall back to the new defaults, which preserve or improve behavior.
- **A-5**: `commands/specify.md` Pass 2 + Pass 3 implementation lands per spec 026, so M031's spec was authored under the contract documented in `commands/specify.md` even though the live runtime today only ships Pass 1.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: M031 is the load-bearing fix for a misread of this principle. Principle I targets `Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited` — minimizing *total* tokens via efficient delivery, not minimizing payload bytes by skipping. Today's Quick path optimizes payload bytes locally and burns total task tokens globally (agent rediscovery); M031 inverts the trade. The amendment-text addendum to Principle I (CLAUDE.md forward roadmap section) clarifying "minimize total task tokens via efficient context delivery, not payload bytes" lands as a constitution amendment in the same time window as M031, but is independent and does not block M031 merge.
- **Principle II (Evidence Before Claims)**: SC-11 + SC-13 + CON-5 require the P00 empirical baseline to confirm the Quick-with-knowledge-wins hypothesis before FR-1/2/3 merge. The 20-task fixture corpus is the evidence; the JSONL emission per task is the trail. No "should work" reasoning ships.
- **Principle III (Design Before Code)**: This spec is the design step. The Tier A+ flow shape and the universal entry routing logic are explicitly designed here, not invented at implementation. Open Questions surface intentional ambiguity (naming, approval flow, knowledge budget) for resolution at plan-phase.
- **Principle IV (Plans Assume Zero Context)**: FR-14 + FR-15 + SC-9 fix the existing zero-context violation (evaluate.md drift teaches an agent contradicting things). Phase plans for M031 will be zero-context per the existing plan-phase contract.
- **Principle V (Fresh Context Per Unit)**: Each Tier A+ dispatch (research, plan, build) runs in a fresh context with an explicit per-role payload. This is a strengthening of V, not a relaxation: where a "single Tier A dispatch with rediscovery" inherits no knowledge, the M031 flow inherits a structured per-role knowledge slice.
- **Principle VII (Knowledge Compounds)**: The other load-bearing principle. The orchestrator's value is that the knowledge layer benefits every dispatch; today's Quick path violates this for the smallest tasks (worst possible target). M031 closes the violation by making knowledge unconditional and the gating mechanism into traversal aggressiveness rather than skip-or-not.
- **Principle XIV (No Speculative Complexity)**: NG-1 through NG-8 + CON-4 keep M031 surgical. No new state machines, no auto-loop changes, no knowledge-layer or cost-surface or routing redesigns. The Tier A+ flow is implemented as three sequential dispatches, not as a new orchestration tier with its own lock file.
- **Principle XV (Surgical Precision)**: SC-12 (scope-guard verifier) is the mechanical gate enforcing that M031's diff stays within the declared write-sites and touches none of the delegated surfaces.

## Architectural Decisions (folded post-discuss 2026-05-01)

The 20 architectural decisions below were ratified during `orchestrator:discuss`
(operator review 2026-05-01). They are folded into the spec body post-roadmap so
they can reference pinned phase IDs (P00..P04 from `.orchestrator/milestones/M031/M031-ROADMAP.md`)
and the renumbered SC vocabulary (SC-15 added per AD-18; SC-16 added per AD-20;
SC-13 / SC-2 / SC-3 / SC-11 rewritten per AD-12/13/17/14). Original `## Open Questions`
and `## Gate Findings` sections below are preserved verbatim as the audit trail
for future readers.

### AD-1. Traversal aggressiveness IS the knowledge-scaling dial

**AD-1. Traversal aggressiveness IS the knowledge-scaling dial.** Quick / Standard / Full are distinguished by how aggressively the dispatch payload traverses the knowledge graph (1-hop / 2-hop / full provenance), NOT by whether knowledge ships. Knowledge + M018 compression are unconditional across every dispatch path produced by M031. Reasoning: this resolves the payload-byte vs. total-task-token conflation that motivated the milestone (Constitution Principle I).

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-1)*

### AD-2. M024 is the single routing source

**AD-2. M024 is the single routing source.** The universal entry consumes the existing M024 input-shape classifier. M031 extends M024 by adding a `tier_a_plus` verdict value (an additive change to the verdict set, not a new field on existing records). M031 MUST NOT introduce a parallel routing implementation. (Spec CON-3.)

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-2)*

### AD-3. Tier A+ is three sequential dispatches with no new orchestration surface

**AD-3. Tier A+ is three sequential dispatches with no new orchestration surface.** The middle flow is implemented as `dispatch --role=research` → `dispatch --role=plan` → `dispatch --role=build`, recorded as JSONL `unit_close` records. No new state machine, no lock file, no roadmap surface. (Spec CON-4 + Principle XIV.)

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-3)*

### AD-4. CON-5 empirical gate is the constitutional safeguard

**AD-4. CON-5 empirical gate is the constitutional safeguard.** The FR-1/2/3 changes (knowledge-unconditional in Quick) MUST NOT merge until the P00 empirical baseline confirms the Quick-with-knowledge-wins hypothesis on a 20-task fixture corpus. Principle II (Evidence Before Claims) is operationalized as a merge blocker, not a process exhortation.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-4)*

### AD-5. Quick-profile knowledge token budget default = 800 tokens; P00 may revise

**AD-5. Quick-profile knowledge token budget default = 800 tokens; P00 may revise.** The proposal recommended 800. P00's 20-task corpus produces the empirical evidence; if P00 data shows 800 is too tight (more than 20% of corpus tasks hit the budget ceiling and snip aggressively) or too loose (median injection is far below 800), P00 amends the default before P01 ships. Knob name: `quick_knowledge_token_budget`. Knob is an advisory ceiling enforced by M018 tier-2 snip — not a hard cap.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-5)*

### AD-6. Universal entry surface

**AD-6. Universal entry surface = `orchestrator <task>` if the runtime supports verbless invocation, else `orchestrator:do <task>`.** Detection happens at install time via the runtime adapter's invocation-style capability flag. Claude Code at launch ships `orchestrator:do <task>` (CC slash-commands are verb-prefixed). Codex CLI / Cursor surfaces are M009's call when those runtimes ship; M031 reserves `orchestrator <task>` as the canonical post-runtime-parity form.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-6)*

### AD-7. Tier A+ approval flow = one prompt before plan dispatch; --yes skips

**AD-7. Tier A+ approval flow = one prompt before plan dispatch; `--yes` skips.** The research dispatch fires immediately. Operator sees the research findings file path in an approval prompt before plan dispatch fires. After plan, build runs without an additional prompt. Reasoning: medium tasks deserve a sanity check (research findings can be wrong); small Tier A tasks do not (the universal-entry fast-path skips all prompts for high-confidence Tier A degenerate verdicts per FR-12). Composes with M033's onboarding UX trajectory — first-time users see one prompt, not three.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-7)*

### AD-8. auto_proceed default flips from false to true

**AD-8. `auto_proceed` default flips from `false` to `true`** per FR-16. Existing projects with explicit `auto_proceed: false` keep the explicit value (A-4). Implicit-default operators see the new behavior on first post-M031 dispatch. AD-8 + AD-9 (compound-change comms) ship together.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-8)*

### AD-9. Compound-change communication uses orchestrator:doctor

**AD-9. Compound-change communication uses `orchestrator:doctor`** (resolves Q-4 / MIT-11). On first run after M031 against a project whose `.orchestrator/config.yml` predates M031 (detectable by absence of `quick_knowledge_token_budget`), `orchestrator:doctor` emits a one-time message naming both behavioral changes (auto-proceed flip + unconditional Quick injection) plus the recovery path (add `auto_proceed: false` to config). The CHANGELOG entry for M031 names the compound effect, not just the flip. Reasoning: the compound change has a single root cause (M031's central design decisions); communicating them together is more useful than two separate notes.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-9)*

### AD-10. Tier A+ output paths are deterministic

**AD-10. Tier A+ output paths are deterministic** (resolves MIT-03 / RISK-03 + RISK-09 + RISK-11). Path convention: `.orchestrator/tier-a-plus/<task-slug>/research.md` and `.../plan.md`. `<task-slug>` derivation: first 40 characters of the task description, lower-cased, spaces → hyphens, non-alphanumeric-non-hyphen stripped, with a 4-character truncated SHA-1 of the full task description appended on collision. FR-9's approval prompt MUST display the research findings path AND check for an existing `research.md` to offer resume-vs-rerun. Resolves three risks (RISK-03 cosmetic-prompt, RISK-09 concurrent-flow correctness, RISK-11 session-interruption recovery) in one amendment.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-10)*

### AD-11. build-context.sh exposes a --meta-out JSON sidecar

**AD-11. `build-context.sh` exposes a `--meta-out <file>` JSON sidecar** (resolves MIT-04 / RISK-04). Minimum schema: `{mem_count, total_tokens, profile, compression_applied, snip_applied}`. FR-12's universal-entry stderr summary line reads N (mem_count) and X (total_tokens) from the sidecar. M029 (`orchestrator:where`) and M036 (reference-corpus ingest) consume the same sidecar without reinventing the interface. The sidecar is the cross-milestone interface contract; specifying it at M031 is the right boundary.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-11)*

### AD-12. SC-13 redesigns as a git-history check (Option B)

**AD-12. SC-13 redesigns as a git-history check (Option B)** (resolves MIT-02 / RISK-02). New verifier `tests/m031-acceptance/verify-baseline-ordering.sh` asserts that the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/` predates the first commit touching any of the four FR-1/2/3-related test scripts. If the battery environment cannot access git history at run time (e.g., shallow clone), Option A fallback applies (reclassify SC-13 as a P00 protocol note, drop from SC-14's count, reduce N≥13 → N≥12). Plan-phase P00 picks the active option based on observed CI environment. Reasoning: Option B preserves CON-5's mechanical enforcement; Option A is the honest fallback when mechanism is impossible.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-12)*

### AD-13. SC-2 amendment grounds enforcement in M018 tier-2 snip

**AD-13. SC-2 amendment grounds enforcement in M018 tier-2 snip** (resolves MIT-01 / RISK-01). Drop the contradictory "within plus-or-minus 20 percent" clause. New SC-2: a Quick-profile dispatch fixture configured with `compression.tier2.enabled: true` produces (a) a tier-2 snip JSONL record at the budget boundary AND (b) a final Knowledge section ≤ `quick_knowledge_token_budget`. Reasoning: FR-5 already declares the budget an "advisory ceiling" enforced by tier-2; SC-2 must match.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-13)*

### AD-14. SC-11 explicitly reads stored records from fixtures/empirical-baseline/

**AD-14. SC-11 explicitly reads stored records from `fixtures/empirical-baseline/`** (resolves MIT-05 / THREAT-001). After FR-4 merges the skip branch is gone; live dual-execution is impossible. The pre-M031 stub is preserved at `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` for the post-M031 comparison. P00's exit criteria explicitly require capturing both pre-M031 and post-M031 per-task JSONL records simultaneously while both code paths are live — that capture is the only feasible window.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-14)*

### AD-15. Corpus stratification is normative

**AD-15. Corpus stratification is normative** (resolves MIT-08 / Q-7 / RISK-08). Q-7 closes as a normative requirement, not an open question. Corpus composition: at least 5 historical-JSONL-derived tasks (stratified 2 high-cost / 2 medium / 1 low by pre-M031 rediscovery cost), at least 5 synthetic edge-case tasks (empty / 1-file / 5-file / 10-file / doc-only), 10 spread across at least 3 categories (bugfix / doc / feature). `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` declares the composition; the battery verifies its existence. Reasoning: the gate's tautology argument (corpus author = system author) is real even with a constitutional backstop; mechanical stratification is the structural fix.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-15)*

### AD-16. Tier A+ classifier fixture requires JSONL provenance

**AD-16. Tier A+ classifier fixture requires JSONL provenance** (resolves MIT-06 / RISK-05). The Tier A+ heuristic boundary and the SC-5 fixture are co-authored in P02 — without external grounding this verifies internal consistency, not correctness. P02 exit criteria require `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` documenting at least one historical `.orchestrator/` JSONL `unit_close` record the fixture author classified as a Tier A+ candidate, plus the annotator's rationale.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-16)*

### AD-17. SC-3 prescribes the fixture explicitly

**AD-17. SC-3 prescribes the fixture explicitly** (resolves MIT-07 / RISK-06). Rewrite SC-3 from descriptive ("records appear when payload exceeds thresholds") to prescriptive ("the test fixture MUST construct a payload exceeding M018 tier-1 thresholds"). M018 tier-1 threshold value is documented in `references/RUNTIME-ASSUMPTIONS.md` as a P00 precondition.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-17)*

### AD-18. New SC verifies absolute budget compliance

**AD-18. New SC verifies absolute budget compliance** (resolves MIT-09 / NEW-001). Add SC-15: median `knowledge_section_tokens` emitted by `build-context.sh --profile=quick` across the 20-task corpus is ≤ `quick_knowledge_token_budget`, independent of the pre-M031 baseline. SC-11 (relative comparison) + SC-2 (per-task budget ceiling) + SC-15 (median absolute compliance) form complementary coverage. Update SC-14's count to N≥14.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-18)*

### AD-19. M027 efficiency-footer adds budget-drift warning

**AD-19. M027 efficiency-footer adds budget-drift warning** (resolves MIT-10 / RISK-07). New informational signal: `QUICK_BUDGET_DRIFT` warning when rolling median `knowledge_section_tokens` across the most recent 7 consecutive Quick dispatches exceeds budget × 1.1. Non-blocking; surfaces via the existing M027 efficiency-footer JSONL record. Lands in P04 alongside the doctor compound-change comms (AD-9).

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-19)*

### AD-20. The Tier A+ pre-plan approval prompt is a designed UX surface

**AD-20. The Tier A+ pre-plan approval prompt is a designed UX surface, not an afterthought.** Confirmed during operator review of OQ-2: the prompt MUST be clearly user-friendly. Concrete requirements that gate FR-9 verification:

- **Plain-language framing** — no JSON dumps, no technical jargon, no scaffold-placeholder-style markers in the prompt body. Read like a colleague handing off, not a CLI status line.
- **Inline research summary** — display the first N lines (default N=8, configurable via `tier_a_plus_prompt_summary_lines`) of `research.md` directly in the prompt, NOT just the file path. The path display from MIT-03 is the "where" — the inline summary is the "what."
- **Clear next-step framing** — the prompt names what happens on yes ("plan against this research"), what happens on no ("re-run research with different framing"), and the cancel exit ("abort this Tier A+ flow"). Three named options, single-keystroke responses (`y`/`n`/`c`), default is no-answer = cancel.
- **Resume-vs-rerun visibility** — when MIT-03's check finds an existing `research.md`, the prompt MUST distinguish between "resume from this research" (existing) and "this is fresh research from this session" (new). The operator should never wonder which they are looking at.
- **`--yes` skip honors the path display** — when `--yes` skips the prompt, a single stderr line MUST still emit the research findings path (`research: <path>`) so the operator has the same audit trail as an interactive session.
- **No surprise output** — the prompt MUST NOT scroll past the research summary; if `research.md` exceeds the inline summary budget, the prompt prints the summary + "(N more lines at <path>)" rather than dumping the whole file.

Reasoning (operator note 2026-05-01): the prompt is the load-bearing UX surface for the entire Tier A+ flow — it is the only operator interaction in the research → plan → build chain. A merely-functional prompt (yes/no with a path) would technically satisfy MIT-03 while undermining the user-experience claim in F3 of the proposal. AD-20 promotes the prompt's UX quality from "implementation detail" to "verifiable design constraint." A new SC (SC-16, see Success Criteria above) gates AD-20 mechanically. AD-20 supersedes AD-7's "one prompt, `--yes` skips" only by extending it; the one-prompt decision and `--yes` behavior remain. AD-20 + AD-10 (deterministic paths) + MIT-03 (path display) compose into a single coherent prompt-design contract for plan-phase P02 to implement against.

*(originated in `.orchestrator/milestones/M031/M031-CONTEXT.md` AD-20)*

## Open Questions (defer to planning)

- **#Q-1 (quick-knowledge-token-budget-default)**: What is the right default value for `quick_knowledge_token_budget`? The proposal recommends 800 tokens. The P00 empirical baseline (FR-18) determines the actual default; planner must wire the default-pinning into P00's exit criteria.
- **#Q-2 (universal-entry-naming)**: Verbless `orchestrator <task>` vs. `orchestrator:do <task>`? Recommendation in the proposal: verbless if the runtime supports it, `do` otherwise. Plan-phase decision: how does the install-time runtime detection inform which surface is registered? (Likely a lookup against the runtime adapter's invocation-style capability flag.)
- **#Q-3 (tier-a-plus-approval-flow)**: One prompt before plan, or zero prompts under default config? Recommendation in the proposal: one prompt with `--yes` to skip. Plan-phase confirms this against the M033 (project onboarding) UX trajectory and against M028 auto-loop hardening's prompt conventions.
- **#Q-4 (auto-proceed-default-flip-comm)**: How is the `auto_proceed` flip communicated to existing-project operators beyond CHANGELOG? `orchestrator:doctor` warning? `orchestrator:status` headline note? Plan-phase decides; the FR-16 contract is to flip + name in CHANGELOG.
- **#Q-5 (tier-a-plus-role-template-prescriptiveness)**: How prescriptive are the research/plan/build payload templates? Recommendation: very prescriptive (each role declares an exact output shape — N findings / N steps + verifiers / inline-verifier exit). Plan-phase finalizes the templates; M031 P02 ships them.
- **#Q-6 (entry-routing-confidence-floor-default)**: The proposal does not pin a default for `entry_routing_confidence_floor`; recommended starting value 0.7. Plan-phase decides whether P00's empirical corpus also calibrates this value, or whether the M024 classifier already provides enough data to pin it directly.
- **#Q-7 (P00-empirical-corpus-shape)**: Does the 20-task fixture corpus consist of synthetic tasks, replays of historical dispatches, or a mix? Plan-phase decides; the corpus must be reproducible and stored under `tests/m031-acceptance/fixtures/empirical-baseline/`.
- **#Q-8 (FR-19-deferral)**: Is FR-19 (`orchestrator:where` Tier A+ rendering) a M031 deliverable or an M029 follow-up task? Recommendation: deferred to M029 since M029 is downstream of M031 in the launch sequence and `orchestrator:where` is M029's primary surface. Plan-phase confirms.

### Gate Findings (deferred to discuss)

The Standard-intensity adversarial gate (`conversus.sh gate spec-pressure-test`, 2026-05-01) returned BLOCK with 6 surviving disputes and 11 required mitigations (5 P0, 4 P1, 2 P2). Full deliberation at `specs/034-right-sized-entry/conversus/summary/final.md`. Verdict text: "Proceed with conditions" — core architecture (traversal-aggressiveness dial, M024 reuse, three-dispatch Tier A+ shape, CON-5 empirical gate) survived adversarial review intact; the conditions are prose-level spec amendments. Red conceded all four major architectural decisions. The findings below are deferred to `orchestrator:discuss` for operator review and applied as spec amendments before `orchestrator:plan-phase` is invoked.

**P0 — must apply before plan-phase entry**:

- **#Q-9 (MIT-01: SC-2 contradiction)**: SC-2 contained a "≤ budget" + "within plus-or-minus 20 percent tolerance" contradiction. FR-5 frames the budget as an advisory ceiling enforced by M018 tier-2 snip; the tolerance-band clause was the erroneous one. Required: remove the tolerance-band clause, rewrite SC-2 to gate on (a) tier-2 snip record at the budget boundary and (b) final Knowledge section ≤ budget. (Resolved by AD-13 / current SC-2.)
- **#Q-10 (MIT-02: SC-13 phantom ordering)**: SC-13's "MUST run empirical-baseline.sh before fixtures are added" is a process rule, not a battery-time mechanical check. CON-5's empirical-gate enforcement depends on a verifiable invariant. Required: replace SC-13 with either Option B (`verify-baseline-ordering.sh` that git-checks first-fixture-commit predates first-test-commit) or Option A (reclassify as a P00 exit-criteria protocol note, drop from SC-14's N count, reduce N≥13 → N≥12). Plan-phase decides which.
- **#Q-11 (MIT-03: Tier A+ output paths + FR-9 path display)**: FR-8 specifies role payload shapes but not output locations; FR-9's approval prompt is cosmetic without a path for the operator to inspect. Required: amend FR-8 to specify deterministic paths (`.orchestrator/tier-a-plus/<task-slug>/research.md` and `…/plan.md`, slug = first 40 chars of description, lower-cased, hyphenated, with 4-char SHA-1 collision suffix); amend FR-9 to require the approval prompt display the research findings path AND check for an existing `research.md` to offer resume-vs-rerun; amend SC-6 to verify the path appears in the prompt. Resolves RISK-03 + RISK-09 + RISK-11 in one amendment.
- **#Q-12 (MIT-04: build-context.sh `--meta-out` sidecar)**: FR-12's stderr summary line needs a structured source for N and X; M029 + M036 will independently reinvent the interface without a spec-level contract. Required: extend FR-2 with a `--meta-out <file>` flag writing a JSON sidecar with at minimum `{mem_count, total_tokens, profile, compression_applied, snip_applied}`; amend FR-12 to read N and X from the sidecar; add an SC verifying sidecar emission and schema validity.
- **#Q-13 (MIT-05: SC-11 stored-record language)**: SC-11's "compares post-M031 against pre-M031 baseline" is implementable only if pre-M031 records are captured at P00 and stored in `fixtures/empirical-baseline/`. After FR-4 merges the skip branch is gone; live dual-execution is impossible. Required: amend SC-11 to use the word "stored" and reference `tests/m031-acceptance/fixtures/empirical-baseline/`; require the pre-M031 stub to be preserved at `fixtures/empirical-baseline/pre-m031-stub.sh` for the post-M031 comparison; require P00 exit criteria to capture both paths simultaneously while both are live.

**P1 — wire into plan-phase P00 / P02 exit criteria**:

- **#Q-14 (MIT-06: SC-5 fixture provenance)**: The Tier A+ classifier fixture and the heuristic boundary are co-authored in P02 — verifying internal consistency, not correctness. Required: SC-5 amendment requires `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` documenting at least one historical `.orchestrator/` JSONL `unit_close` record the fixture author considered as a Tier A+ candidate, plus the annotator's classification rationale.
- **#Q-15 (MIT-07: SC-3 prescriptive fixture)**: SC-3's "when the Quick payload exceeds tier thresholds" is read by a naïve implementer as a truth condition, allowing a vacuous-pass 800-token fixture. Required: rewrite SC-3 to require the test fixture to construct a payload exceeding M018 tier-1 thresholds (with the threshold value documented in `references/RUNTIME-ASSUMPTIONS.md` as a P00 precondition).
- **#Q-16 (MIT-08: Q-7 corpus stratification)**: Q-7 leaves corpus composition entirely to the implementer's judgment, creating a structural cherry-pick risk. Required: resolve Q-7 with a normative requirement — at least 5 historical-JSONL-derived tasks (stratified by pre-M031 cost: 2 high / 2 medium / 1 low), at least 5 synthetic edge-case tasks (empty / 1-file / 5-file / 10-file / doc-only), 10 spread across at least 3 categories (bugfix / doc / feature). Require `CORPUS-MANIFEST.md` declaring the composition; battery verifies its existence.
- **#Q-17 (MIT-09: budget-regression SC)**: SC-11 (relative comparison) and SC-2 (budget ceiling) leave a residual gap — an implementation that stays within budget but injects more than P00 projected. Required: add an SC verifying the shipped implementation's median `knowledge_section_tokens` is ≤ `quick_knowledge_token_budget` across the 20-task corpus, independent of the pre-M031 baseline; update SC-14's N count.

**P2 — plan-phase scope (M027-adjacent + comms)**:

- **#Q-18 (MIT-10: M027 budget-drift warning)**: No post-merge runtime safety net for Quick-injection efficiency drift as the knowledge graph grows. Required: a new FR (or extension to FR-5) that the M027 efficiency-footer emits a `QUICK_BUDGET_DRIFT` warning when the rolling median Quick injection across 7 consecutive dispatches exceeds budget × 1.1; informational, non-blocking.
- **#Q-19 (MIT-11: Q-4 compound-change communication)**: Q-4's communication channel for the `auto_proceed` flip should be normative — operators upgrading from a pre-M031 project see two simultaneous behavioral changes (auto-proceed + unconditional Quick injection). Required: resolve Q-4 with `orchestrator:doctor` emitting a one-time M031 upgrade message naming both changes; amend the FR-16 CHANGELOG entry requirement to name the compound effect, not just the flip.

**Accepted risks (no spec amendment)**:

- RISK-09 (concurrent Tier A+ flows wasted-research) — resolved structurally by MIT-03's deterministic paths; remaining efficiency cost is the appropriate exposure under CON-4 (no lock files, Principle XIV).
- RISK-11 (session-interruption efficiency cost) — resolved by MIT-03's resume-detection on existing `research.md`.
- RISK-12 (SC-9 doc-drift verifier scope) — pattern-negative scope is appropriate for a drift-fix verifier; broader completeness is covered by code review.

These items are surfaced in `orchestrator:discuss` as the architectural-decisions input. The standard discuss flow folds the agreed amendments back into the spec body before `orchestrator:roadmap` runs.

## Dependencies

- **M020 (knowledge layer maturation)** — closed. Provides the graph + indexer + traversal API that M031 consumes.
- **M018 (context compression layer)** — closed. Provides tier-1 + tier-2 compression that M031 ensures applies to Quick payloads.
- **M024 (universal intake & routing)** — closed. Provides the input-shape classifier that M031 extends with `tier_a_plus`.
- **M027 (cost+quality observability surfaces)** — closed. Provides the JSONL stream and surfaces that M031's new emission records flow into without surface changes.
- **M030 (adaptive model selection)** — closed. M031 composes with M030 routing on Tier A+ dispatches but does not modify routing logic.
- **M028 (autonomous hardening v3)** — closed. M031 inherits the hook portability + shape-guard + investigation-pattern wrappers but adds none of its own.

## Downstream Consumers (informational, not binding)

- **M029 (roadmap visibility & CLI UX)** — `orchestrator:where` will render Tier A+ runs as 3-row mini-trees per FR-19; M031 emits the JSONL records M029 needs to read.
- **M033 (project onboarding experience)** — the warm conversational front door consumes the universal entry FR-10 to land first-time users on a small-task path that "just works." M033's first-impression depends on M031 + M030 making that path cheap and knowledge-rich.
- **M032 (wiki distribution + init integration)** — independent surface; the `wiki/glossary.md` Finding K surface is referenced by M031's Quick-profile glossary slice but not modified by M031.
- **M035 (packaging & distribution)** — the universal entry FR-10 is part of the surface area packaged for npm / homebrew / curl-install distribution; M035 P02–P06 inherit it.
- **M036 (reference-corpus ingest, deferred post-launch)** — extends `build-context.sh` with a `reference/` chunk family in its own time; the `--profile` flag pattern M031 introduces is the shape M036 will reuse for reference-corpus scoping.

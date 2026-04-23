---
schema_version: "1.0"
type: feature-spec
feature_slug: "026-specify-three-pass-impl"
created_at: "2026-04-23"
status: "Draft"
milestone: "M014"
---

# Feature Specification: 026-specify-three-pass-impl

**Feature Branch**: `026-specify-three-pass-impl`
**Created**: 2026-04-23
**Status**: Draft
**Milestone**: M014
**Input**: User description: "Implement the three-pass (scaffold / author / gate) × intensity flow for orchestrator:specify per D019 contract in commands/specify.md. Wire Pass 2 (author) to draft spec body from Input + DECISIONS.md + constitution via scripts/dispatch/dispatch-interface.sh; at Full intensity, invoke speckit.clarify after the draft lands. Wire Pass 3 (gate) to intensity-scaled conversus gate invocation (Quick=skip, Standard=advisory, Full=strict). Intensity resolution: project default → smell-test escalation via intensity-analyze.sh → CLI --intensity override. Emit specify_intensity_resolution JSONL record. Preserve all current Pass 1 behavior byte-equivalently."

## Problem Statement

D019 (2026-04-23) committed `orchestrator:specify` to a three-pass × intensity contract: Pass 1 (scaffold), Pass 2 (author), Pass 3 (gate), each intensity-scaled via the existing intensity engine. The contract is written into `commands/specify.md` and its TODO pre-flight invariant is wired into `scripts/dispatch/adapters/tool/conversus.sh`. What is missing is the shell. `scripts/specify/specify.sh` today implements only Pass 1; Passes 2 and 3 as specified in the contract are currently executed manually by any agent that invokes the command. That gap is a silent dead zone — the command ships a contract the shell does not honor, and agents that read the command doc without reading the shell source get a false sense of what runs automatically.

Three concrete pain-points follow from the gap. **First**, every agent invoking `orchestrator:specify` pays the cognitive cost of re-executing the author pass + gate pass from the command doc, which is both error-prone (miss a clarify step, miss a JSONL record) and defeats the point of having a command in the first place. **Second**, intensity resolution — project default → smell-test escalation → CLI override — is currently only documented, not enforced; operators invoking the shell see no record of what intensity was resolved or why, so the observability D019 committed to (`specify_intensity_resolution` JSONL record) never appears. **Third**, the Full-intensity `speckit.clarify` loop and intensity-scaled conversus gate invocation have no deterministic entry point; an agent working from memory might skip them on a Full-intensity run without anything refusing the flow, exactly the failure mode D019 was committed to prevent.

The minimum surface that fixes all three: (a) extend `scripts/specify/specify.sh` to resolve intensity at run start and emit the `specify_intensity_resolution` record; (b) add a Pass 2 implementation that dispatches the author task through `scripts/dispatch/dispatch-interface.sh` with a prompt template reading from Input + DECISIONS.md + constitution + Recent Changes; at Full intensity, invoke `speckit.clarify` against the authored draft; (c) add a Pass 3 implementation that runs `scripts/knowledge/spec-complexity-probe.sh` as pre-flight and then dispatches `scripts/dispatch/adapters/tool/conversus.sh gate` with intensity-scaled strictness; (d) preserve Pass 1's current byte-equivalent output on scaffold-only invocations so in-flight specs are not disturbed.

This feature does not attempt: new intensity semantics (the contract is pinned), new gate mechanics beyond what `conversus.sh gate` already exposes, any changes to the command doc itself (D019 is the authority; this spec delivers the shell), or backfilling the author pass onto pre-existing specs authored under Pass-1-only flow.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The smallest coherent subset whose shipment closes the dogfood loop: **US-1 (intensity resolution wiring) + US-2 (Pass 2 author dispatch) + US-3 (Pass 3 gate dispatch)**. Together they deliver an end-to-end path where an operator runs `bash scripts/specify/specify.sh --description "..."` and the shell scaffolds + authors + gates per the D019 contract without agent intervention. US-4 (Full-intensity clarify loop) and US-5 (Pass 1 byte-equivalence regression suite) depend on the slice and layer on afterward.

### User Story 1 — Intensity resolution wiring with observability (Priority: P1)

An operator invokes `scripts/specify/specify.sh --description <prose>` and the shell resolves effective intensity in the contract's documented order (project default → smell-test escalation → `--intensity` CLI override) and appends one `specify_intensity_resolution` record to `.orchestrator/execution-log.jsonl` before any pass runs.

**Why this priority**: intensity is the axis that parameterizes Passes 2 and 3. Without deterministic resolution + JSONL provenance, neither downstream pass can know what behavior to adopt and no one can post-hoc diagnose why a given invocation chose Quick vs Full. Every other user story depends on this wiring.

**Independent Test**: run the shell with a known project default (`standard`), a description whose keywords trip the smell-test to `full`, and no `--intensity` override; assert the resulting `specify_intensity_resolution` record's `resolved=full`, `project_default=standard`, `smell_test_recommendation=full`, `cli_override=null`, `reasoning` non-empty.

**Acceptance Scenarios**:

1. **Given** a project default of `standard` and a description that trips smell-test to `full`, **When** the shell runs without `--intensity`, **Then** the emitted `specify_intensity_resolution` record has `resolved=full` and `reasoning` mentions the smell-test escalation.
2. **Given** a project default of `full` and a smell-test recommendation of `quick`, **When** the shell runs without `--intensity`, **Then** resolved intensity is `full` (smell-test never de-escalates).
3. **Given** any project default + smell-test combination, **When** the shell is invoked with `--intensity quick`, **Then** resolved intensity is `quick` and `cli_override=quick` in the JSONL record.
4. **Given** `scripts/engine/intensity-analyze.sh` is missing or non-executable, **When** the shell runs, **Then** effective intensity falls back to the project default with a stderr warning and `smell_test_recommendation=unavailable` in the record (command does not fail).

### User Story 2 — Pass 2 author dispatch wiring (Priority: P1)

An operator runs the shell and after scaffold completes, the shell automatically dispatches an author task through `scripts/dispatch/dispatch-interface.sh` that reads Input + DECISIONS.md + constitution + CLAUDE.md/AGENTS.md Recent Changes, fills the Section Contract scaffold-placeholder markers with authored prose, and returns control to the shell with the spec body in place.

**Why this priority**: the author pass is the load-bearing productivity win — it is what turns `orchestrator:specify` from a scaffold emitter into a true spec-authoring command. Without automated Pass 2, the command remains indistinguishable from its Pass-1-only predecessor for any agent that already does manual authoring.

**Independent Test**: run the shell at Standard intensity against a short description; after the shell exits, assert the scaffold-placeholder count is zero (per `scripts/verify/spec-shape-lint.sh`'s `todo_count`) and that the same script reports `checks=10 passed=10 failed=0`.

**Acceptance Scenarios**:

1. **Given** a scaffolded spec with Section Contract placeholders, **When** Pass 2 runs at Quick intensity, **Then** the spec body is authored in one dispatch round-trip and no self-review warnings are emitted.
2. **Given** Pass 2 runs at Standard intensity, **When** the authored body has a weak section (e.g., zero acceptance scenarios under a user story), **Then** one `specify_author_warnings` JSONL record is emitted listing the weak sections; the command exit code is unchanged.
3. **Given** Pass 2's dispatch returns an empty or placeholder-preserving body (agent failure), **When** the shell inspects the result, **Then** the shell exits 1 with a diagnostic pointing at the dispatch log and the scaffolded placeholders are preserved on disk.
4. **Given** `dispatch-interface.sh` is missing or the selected backend is unavailable, **When** Pass 2 runs, **Then** the shell exits 1 with a diagnostic naming the unavailable dependency.

### User Story 3 — Pass 3 gate dispatch wiring (Priority: P1)

An operator runs the shell and after Pass 2 completes, the shell runs `scripts/knowledge/spec-complexity-probe.sh` against the authored body and then invokes `scripts/dispatch/adapters/tool/conversus.sh gate spec-pressure-test` with intensity-scaled strictness: Quick = skip, Standard = advisory (no `--strict`, findings folded into Open Questions on BLOCK), Full = strict (BLOCK halts with exit 2).

**Why this priority**: the gate is the adversarial value-add D019 commits to. Without it wired, every Full-intensity invocation silently skips the pressure-test — exactly the spec-025 failure mode that drove D019. Pass 3 wiring is the direct fix.

**Independent Test**: run the shell at Quick intensity against an authored fixture; assert one `specify_gate_skipped` record with `reason="intensity=quick"` and zero conversus adapter invocations. Separately, run at Full intensity against a fixture with authored content + no scaffold-placeholder markers; assert the adapter is invoked with `--strict`.

**Acceptance Scenarios**:

1. **Given** Pass 3 runs at Quick intensity, **When** the shell reaches the gate step, **Then** a `specify_gate_skipped` JSONL record is emitted with `reason="intensity=quick"` and `probe_verdict` populated; the adapter is not invoked.
2. **Given** Pass 3 runs at Standard intensity and the adapter returns BLOCK, **When** the shell processes the verdict, **Then** the BLOCK findings are appended to the spec's `## Open Questions` section with a deferred-to-discuss annotation; command exit is 0 (advisory).
3. **Given** Pass 3 runs at Full intensity and the adapter returns BLOCK, **When** the shell processes the verdict, **Then** the command exits 2 with the dispute list printed and the spec body is preserved byte-equivalently (no rollback, no promotion).
4. **Given** Pass 3 runs at Full intensity and the adapter returns PASS, **When** the shell processes the verdict, **Then** spec frontmatter `status` is promoted `Draft` → `Ready-for-discuss` and `Last Revised: <today>` is appended below the `**Status**:` header line.
5. **Given** the gate adapter's TODO pre-flight refuses the artifact (contract violation — Pass 2 left placeholders), **When** Pass 3 attempts the gate invocation, **Then** the shell exits 1 with a diagnostic naming Pass 2 as the failure surface.

### User Story 4 — Full-intensity speckit.clarify loop (Priority: P2)

An operator runs the shell at Full intensity and after the initial author dispatch lands a draft, the shell invokes `speckit.clarify` against the draft, surfaces up to five load-bearing ambiguity questions to the operator (or auto-answers them with agent defaults under `--yes`), incorporates the answers back into the draft, and only then proceeds to Pass 3.

**Why this priority**: clarify is the Full-intensity differentiator — it is what makes Full worth paying for over Standard on architecturally load-bearing specs. But US-1/US-2/US-3 deliver a working Quick + Standard + Full flow without it (Full at this tier would behave like Standard-plus-strict-gate); shipping clarify in P2 lets the minimal slice prove itself under real dogfooding before the ambiguity-surfacing loop lands.

**Independent Test**: run the shell at Full intensity against a description whose authored draft contains ≥3 load-bearing ambiguities (fixture prepared); with `--yes`, assert the shell emits one `specify_clarify_auto_answered` JSONL record per question and that agent-default answers are logged verbatim in the spec's Open Questions section.

**Acceptance Scenarios**:

1. **Given** Full intensity + no `--yes`, **When** clarify surfaces 3 questions, **Then** the shell pauses for operator input, consumes the responses, and dispatches a revision pass whose diff folds the answers into the draft.
2. **Given** Full intensity + `--yes`, **When** clarify surfaces 3 questions, **Then** each question is auto-answered with the agent's best-guess default and a `specify_clarify_auto_answered` JSONL record is emitted per question; the defaults appear in the spec's Open Questions section so a human can revisit.
3. **Given** clarify surfaces zero questions (well-authored draft, no load-bearing ambiguities), **When** the shell checks clarify's output, **Then** the shell proceeds directly to Pass 3 with a `specify_clarify_noop` JSONL record.

### User Story 5 — Pass 1 byte-equivalence regression suite (Priority: P2)

A maintainer running the test suite verifies that invoking the shell with no automatic author/gate (e.g., a future `--scaffold-only` flag reserved for tests, or an implicit Quick-with-gate-skipped path) produces byte-identical Pass 1 output to the current shipped `specify.sh`, guaranteeing no existing spec in-flight under the old flow is disturbed by the upgrade.

**Why this priority**: Pass 1 byte-equivalence is a correctness invariant, not a feature, so it lands after the value-add slice (US-1..US-3) is verified. But it is load-bearing enough to ship in the same milestone so the D019 transition is observably non-regressing.

**Independent Test**: capture a reference scaffold under the current (pre-impl) `specify.sh` at a fixed slug + description + date; run the new implementation's scaffold-only path with the same inputs; assert `diff` reports zero bytes of difference.

**Acceptance Scenarios**:

1. **Given** a reference scaffold captured pre-implementation, **When** the new shell produces a scaffold under identical inputs, **Then** `diff` reports no differences in the generated `spec.md`, no differences in the CLAUDE.md/AGENTS.md Recent Changes region, and identical JSONL `unit_close` record shape.
2. **Given** the reference scaffold's frontmatter omits `last_revised`, **When** the new scaffold runs, **Then** the new `spec.md` also omits `last_revised` (Pass 3 promotion is the only writer of that field).

---

## Edge Cases

- **Concurrent invocations racing on spec number**: Pass 1's existing `scripts/lifecycle/lock-manager.sh` acquisition is preserved byte-equivalently; Pass 2 + Pass 3 run after the spec directory exists, so no additional lock is needed.
- **Author pass emits body with scaffold-placeholder markers above threshold**: the gate adapter's TODO pre-flight refuses the Pass 3 invocation; shell exits 1 pointing at Pass 2 as the failure surface (US-3 AS-5).
- **Operator aborts during Full-intensity clarify prompt (Ctrl-C)**: the shell's signal handler leaves the partially-authored spec on disk, emits a `specify_aborted` JSONL record naming the stage, and exits non-zero. No partial status promotion.
- **`orchestrator:auto` invokes the shell with `--yes` under Full intensity**: clarify auto-answers with agent defaults; a `specify_clarify_auto_answered` record is emitted per question so auto-loop observability can detect over-reliance on defaults and propose escalation.
- **CLI `--intensity` override targets an unknown value**: the shell rejects with exit 2 and a message listing the valid set (`quick|standard|full`). No silent coercion.
- **Execution-log append fails (disk full, permission denied)**: per `commands/specify.md` "Error Handling", the shell warns on stderr but does not fail the command; observability is best-effort.
- **Project config missing `intensity.default`**: the shell assumes `standard` and emits a `specify_intensity_default_missing` diagnostic; behavior is deterministic.

---

## Functional Requirements

- **FR-1 (intensity-resolution)**: The shell resolves effective intensity in the exact order specified in `commands/specify.md` (project default → smell-test escalation → CLI override). Smell-test can only escalate, never de-escalate. Satisfies US-1.
- **FR-2 (intensity-resolution-observability)**: The shell appends exactly one `specify_intensity_resolution` record to `.orchestrator/execution-log.jsonl` at run start with `{resolved, project_default, smell_test_recommendation, cli_override, reasoning, source:"runtime"}`. Satisfies US-1.
- **FR-3 (pass-2-dispatch-wiring)**: After Pass 1 completes, the shell invokes `scripts/dispatch/dispatch-interface.sh` with a prompt template that reads Input + DECISIONS.md + constitution + CLAUDE.md/AGENTS.md Recent Changes and fills the Section Contract placeholders. Under Quick, no self-review; under Standard, a self-review checklist emits `specify_author_warnings` on weak sections. Satisfies US-2.
- **FR-4 (pass-2-failure-handling)**: If Pass 2's dispatch returns an empty body, preserves scaffold-placeholder markers, or fails with a dispatch-interface error, the shell exits 1 with a diagnostic naming the dispatch log path; the scaffolded body is preserved on disk. Satisfies US-2.
- **FR-5 (pass-3-probe-pre-flight)**: Before Pass 3's adapter invocation, the shell runs `scripts/knowledge/spec-complexity-probe.sh <spec-path>` and captures the probe verdict into every Pass-3-emitted JSONL record. Satisfies US-3.
- **FR-6 (pass-3-intensity-gate)**: Quick skips the adapter with one `specify_gate_skipped` record. Standard invokes `conversus.sh gate spec-pressure-test` without `--strict`; BLOCK findings are folded into `## Open Questions` with a deferred-to-discuss annotation; exit 0. Full invokes with `--strict`; BLOCK halts with exit 2 and the dispute list printed; PASS promotes status to `Ready-for-discuss` + adds `Last Revised:` line. Satisfies US-3.
- **FR-7 (pass-3-todo-guard-interaction)**: If the gate adapter's TODO pre-flight (D019) refuses the Pass 3 invocation, the shell exits 1 with a diagnostic that names Pass 2 as the failure surface (rather than the gate itself). Satisfies US-3.
- **FR-8 (clarify-loop)**: At Full intensity, after Pass 2's initial draft lands, the shell invokes `speckit.clarify` against the draft; up to 5 load-bearing ambiguity questions are surfaced. Without `--yes`, the shell pauses for operator input and then dispatches a revision pass. With `--yes`, each question is auto-answered with the agent's best-guess default and a `specify_clarify_auto_answered` record is emitted per question; the defaults are written into the spec's `## Open Questions` section verbatim. Satisfies US-4.
- **FR-9 (pass-1-byte-equivalence)**: Pass 1's scaffold output (spec body, dual-write Recent Changes region, JSONL `unit_close` shape) is byte-equivalent to the pre-implementation `specify.sh` under the scaffold-only path. A regression test in `tests/test-specify-shell.sh` (or equivalent) pins this against a captured reference. Satisfies US-5.
- **FR-10 (unit-close-fields)**: The `unit_close` record appended at end-of-run populates `author_pass_ran`, `clarify_invocations`, `conversus_invocations`, `adapter_verdicts`, and `resolved_intensity` per the `commands/specify.md` Observability section. Satisfies the command contract.
- **FR-11 (intensity-missing-script-fallback)**: If `scripts/engine/intensity-analyze.sh` is missing or non-executable, the shell falls back to project default with a stderr warning and sets `smell_test_recommendation=unavailable` in the JSONL record. The command does not fail. Satisfies US-1 AS-4.
- **FR-12 (amend-compat)**: The `--amend` subsurface (already specified in `commands/specify.md`) is orthogonal to this spec's scope. The Pass 2/3 implementation MUST NOT regress `--amend`'s three-case semantics; regression tests covering `--amend` remain green after this spec's work lands. Satisfies the command contract.

## Success Criteria

- **SC-1**: `bash scripts/specify/specify.sh --description "<prose>" --yes` against a smell-test-escalating description, with project default `standard`, appends a JSONL line matching `"resolved":"full"` to `.orchestrator/execution-log.jsonl`; exit 0. (US-1, FR-1, FR-2)
- **SC-2**: After the shell runs at Standard intensity against a short description, `bash scripts/verify/spec-shape-lint.sh specs/<NNN>-<slug>/spec.md` reports `failed=0` and `todo_count=0`. (US-2, FR-3)
- **SC-3**: Running at Quick intensity emits a JSONL record with `"specify_gate_skipped"` and `"reason":"intensity=quick"`; the conversus adapter is not invoked (verified by `grep -c 'conversus' .orchestrator/execution-log.jsonl` not incrementing across the run). (US-3, FR-6)
- **SC-4**: Running at Full intensity against a fixture whose gate result is PASS flips the spec frontmatter from `status: "Draft"` to `status: "Ready-for-discuss"` and inserts a `**Last Revised**:` line below the `**Status**:` line; exit 0. (US-3, FR-6)
- **SC-5**: Running at Full intensity against a fixture whose gate result is BLOCK exits 2 with the dispute list printed on stdout; spec body on disk is byte-equivalent to the pre-Pass-3 body (only the JSONL records change). (US-3, FR-6)
- **SC-6**: Running Pass 2 at Standard against a fixture with one empty user-story's acceptance-scenario list emits a `specify_author_warnings` JSONL record listing the weak section; exit 0. (US-2, FR-3)
- **SC-7**: A reference scaffold captured pre-implementation diffs to zero bytes against the new shell's scaffold-only path; `tests/test-specify-shell.sh` (or equivalent) exits 0. (US-5, FR-9)
- **SC-8**: Running at Full with `--yes` against a fixture where `speckit.clarify` surfaces 2 questions emits exactly 2 `specify_clarify_auto_answered` JSONL records; the spec's `## Open Questions` section contains both auto-answered defaults verbatim. (US-4, FR-8)
- **SC-9**: With `scripts/engine/intensity-analyze.sh` renamed (simulating missing), the shell run against any description emits a JSONL record with `"smell_test_recommendation":"unavailable"`; exit 0. (US-1, FR-11)
- **SC-10**: The `--amend` regression suite (existing tests covering three-case amend semantics) reports zero failures after the Pass 2/3 implementation lands. (FR-12)

## Non-Goals

- **NG-1**: This spec does NOT rewrite the three-pass contract. D019 and `commands/specify.md` are the SSOT; this spec delivers the shell that honors them.
- **NG-2**: This spec does NOT introduce new intensity values, new gate presets, or new observability record types beyond those enumerated in `commands/specify.md`.
- **NG-3**: This spec does NOT backfill authored bodies onto pre-existing Pass-1-only specs. Retroactive authoring is out of scope; the `--amend` subsurface covers case-by-case needs.
- **NG-4**: This spec does NOT change the conversus adapter's internals or the TODO pre-flight threshold; the adapter is consumed through its current surface.
- **NG-5**: This spec does NOT ship a `--gate-only` subsurface. That surface is mentioned in `commands/specify.md` as a future addition; a follow-up D-row will commission it.
- **NG-6**: This spec does NOT introduce a new Codex/Cursor-specific author-pass path. If a runtime lacks the dispatch backend required for Pass 2, the shell exits 1 per FR-4; runtime-parity audits live at M009.

## Constraints

- **CON-1 (contract-fidelity)**: Every behavior enumerated in `commands/specify.md` under the three-pass flow (intensity matrix, resolution order, JSONL record shapes, exit codes, `--yes` semantics at Full) MUST be implemented byte-exactly by the shell. Divergence from the command doc is a regression.
- **CON-2 (principle-i-context-budget)**: The Pass 2 dispatch prompt MUST NOT inline the full DECISIONS.md + constitution + Recent Changes bodies into the dispatched context. Instead, the prompt passes file paths + narrow excerpts scoped to the spec's topic; the author agent is responsible for reading what it needs. This preserves Principle I's dispatch-context budget.
- **CON-3 (principle-iv-plans-assume-zero-context)**: The author-pass prompt template MUST be self-contained — a fresh agent reading only the prompt + the referenced files should produce a Section-Contract-conforming body. No reliance on conversation history, no "as we discussed" hedges.
- **CON-4 (principle-vi-state-on-disk)**: All state the shell produces — intensity resolution, clarify answers, gate verdicts — lands on disk (JSONL log, spec frontmatter, Open Questions prose) before the command exits. No in-memory-only state survives the run.
- **CON-5 (principle-xv-surgical-precision)**: This spec's implementation MUST NOT touch command doc prose, DECISIONS.md entries, or the conversus adapter's TODO pre-flight logic. Scope is the shell only.
- **CON-6 (principle-xiv-no-speculative-complexity)**: The Pass 2 dispatch MUST use the existing `scripts/dispatch/dispatch-interface.sh` surface. Adding a specify-specific dispatch path is out of scope; if the generic interface is insufficient, that is a separate D-row.

### Knowledge-Layer Boundary (M014 vs. M020)

M014 (this spec's owning milestone) authors the shell that consumes the knowledge layer's complexity probe (`scripts/knowledge/spec-complexity-probe.sh`). M020 holds schema authority over `knowledge/spec/**` and `knowledge/**/MEM*.md`. This spec interacts with the knowledge layer as a READER only:

- M014 invokes the complexity probe as a black box; no changes to the probe's output schema.
- M014 does NOT write to `knowledge/**` from any pass. All writes remain within `specs/<NNN>-<slug>/`, `.orchestrator/execution-log.jsonl`, and the Recent Changes region.
- If Pass 2 would benefit from querying existing knowledge entries to enrich the author prompt, that capability is M020/FR-2's responsibility and is out of scope here. Consuming the query surface lands in a post-M020 follow-up, not this spec.

## Assumptions

- **A-1**: D019's three-pass contract in `commands/specify.md` is stable as of 2026-04-23. If a follow-up D-row amends the contract before this spec's work lands, scope absorbs the amendment through an explicit `--revised` D-row reference.
- **A-2**: `scripts/dispatch/dispatch-interface.sh` already supports a backend-agnostic LLM dispatch surface adequate for author-pass prompting. If the surface is insufficient (e.g., lacks a way to return structured results), the gap is filed as a separate follow-up D-row; this spec does not absorb dispatch-interface scope.
- **A-3**: `speckit.clarify` (skill) is invocable from within a shell-driven dispatch context under Claude Code. Codex and Cursor parity for clarify is a separate runtime-parity concern (M009); Full intensity under those runtimes may fall back to Standard behavior with a diagnostic.
- **A-4**: `scripts/engine/intensity-analyze.sh` returns a deterministic recommendation for a given description. Its keyword set may evolve (per D019 "Reversibility" clause); the shell consumes the recommendation through the script's interface, not its keyword list.
- **A-5**: The TODO pre-flight guard in `scripts/dispatch/adapters/tool/conversus.sh` (D019, landed) remains in place. This spec depends on it refusing placeholder-filled artifacts.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle I (Context Minimization)**: CON-2 bounds the Pass 2 prompt to file-path references + narrow excerpts, not full-document inlining. The shell itself consumes minimal context — it only reads what each pass needs.
- **Principle II (Evidence Before Claims)**: Every SC- above pins a mechanical command + observable artifact (JSONL record, grep match, exit code). No "works as expected" language.
- **Principle III (Design Before Code)**: The three-pass contract (D019 + `commands/specify.md`) is the design; this spec converts design into shell. Load-bearing ambiguities (dispatch-interface prompt template shape, clarify-failure retry behavior) are enumerated in Open Questions, not guessed.
- **Principle IV (Plans Assume Zero Context)**: CON-3 binds the author-pass prompt to self-containment so a fresh agent can author from prompt + referenced files alone.
- **Principle VI (State On Disk Is Truth)**: CON-4 enforces on-disk persistence for every observable event. Frontmatter promotion, JSONL records, Open Questions updates all land on disk before exit.
- **Principle XIV (No Speculative Complexity)**: NG-1..NG-6 fence off scope creep; CON-6 forbids adding a specify-specific dispatch path when the generic interface exists.
- **Principle XV (Surgical Precision)**: CON-5 forbids touching command doc prose, DECISIONS.md, or the conversus adapter; scope is the shell only. FR-9's byte-equivalence regression protects Pass 1's behavior during the upgrade.

## Open Questions (defer to planning)

- **#Q-1 (dispatch-interface-prompt-template-shape)**: What is the canonical shape of the author-pass prompt template — inline markdown with `{{input}}`/`{{decisions_excerpts}}` placeholders, or a structured manifest the dispatch backend assembles? Pinned at plan-phase after inspecting `scripts/dispatch/dispatch-interface.sh`'s current callers.
- **#Q-2 (clarify-failure-retry-behavior)**: If `speckit.clarify` invocation itself errors at Full intensity (not "surfaced zero questions" but hard failure), does the shell retry, downgrade to Standard for this run with a diagnostic, or exit 1? Default if not decided: exit 1 (fail loud). Revisit if auto-loop dogfooding surfaces friction.
- **#Q-3 (specify-author-warnings-threshold-tuning)**: What counts as a "weak section" under Standard's self-review checklist — zero acceptance scenarios, fewer than N FRs per user story, something else? Candidate rules pinned at plan-phase after reviewing the first 3 specs authored under this flow.
- **#Q-4 (clarify-auto-answered-dogfood-telemetry)**: If `--yes` + Full consistently auto-answers > N questions per run, is that a signal to escalate to non-`--yes` Full or to downgrade default intensity for auto-loop invocations? Revisit after one milestone of dogfood data from `specify_clarify_auto_answered` records.
- **#Q-5 (pass-1-byte-equivalence-reference-capture-workflow)**: How is the reference scaffold captured (committed fixture, test-run-time generation, checksum manifest)? Pinned at plan-phase; lightest option preferred.

## Dependencies

- **D019 (DECISIONS.md, 2026-04-23)** — authoritative three-pass × intensity contract this spec implements.
- **commands/specify.md (contract SSOT, updated 2026-04-23)** — defines intensity matrix, resolution order, JSONL record shapes, exit codes, `--yes` semantics. This spec is the shell that honors the doc.
- **M014/P01 (shipped)** — landed the scaffold-only `specify.sh`, the dual-write helper (`scripts/util/dual-write-runtime-md.sh`), the shape-lint verifier (`scripts/verify/spec-shape-lint.sh`), and the complexity probe (`scripts/knowledge/spec-complexity-probe.sh`). This spec's implementation extends that foundation.
- **scripts/dispatch/dispatch-interface.sh** — generic dispatch surface consumed by Pass 2. Must support returning a dispatched agent's final output for the shell to inspect.
- **scripts/dispatch/adapters/tool/conversus.sh** — gate adapter consumed by Pass 3. TODO pre-flight (D019) is load-bearing; the shell depends on it refusing placeholder artifacts.
- **speckit.clarify (skill)** — invoked at Full intensity after the initial Pass 2 draft.
- **scripts/engine/intensity-analyze.sh** — smell-test recommendation source.

## Downstream Consumers (informational, not binding)

- **orchestrator:auto** — invokes `specify.sh --yes` as part of the Tier C autonomous loop. Depends on deterministic intensity resolution + JSONL observability to drive the loop's budget/escalation logic.
- **orchestrator:evaluate** — consumes `Status: Ready-for-discuss` as its precondition on Full-intensity invocations. This spec is the writer of that status-promotion path.
- **M020 (knowledge-layer maturation)** — once M020's query surface (FR-2) lands, a follow-up can enrich the Pass 2 prompt with pre-existing-knowledge-entry resolution. Not binding on this spec; M020 can ship independently and the enrichment lands post-facto.
- **M009 (launch)** — runtime-parity audit consumes this spec's Pass 2/3 behavior to verify CC / Codex / Cursor all produce equivalent output under identical inputs. Audit-time concern, not a dependency of this spec.

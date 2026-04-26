---
schema_version: "1.0"
type: feature-spec
feature_slug: "028-universal-intake-routing"
created_at: "2026-04-25"
status: "Draft"
milestone: "M024"
---

# Feature Specification: M024 Universal Intake & Routing — `orchestrator:evaluate` Extended To Input-Agnostic With A Reviewable Proposal Artifact

**Feature Branch**: `028-universal-intake-routing`
**Created**: 2026-04-25
**Status**: Draft
**Milestone**: M024 (see `.orchestrator/milestone-summary.md` line 10; promoted 2026-04-22 per D016)
**Input**: User description: "Extend `orchestrator:evaluate` so it accepts any of five input shapes — full spec, fragment, paragraph, idea, or empty + Q&A — and emits a single reviewable proposal artifact at `.orchestrator/intake/<id>/proposal.md` covering six routing axes: input shape, scope tier, decomposition, design gate, conversus gate, and intensity. A degenerate fast-path auto-proceeds when the proposal lands at Tier A + Quick + no conversus + no design; every other shape gates on operator approval before any downstream command runs. Reuse existing machinery (intensity engine, conversus adapter, M020 knowledge surface, M014's `orchestrator:specify` authoring) — M024 is the router, not the author. Pre-M023, design-gate recommendations degrade gracefully to a 'author DESIGN.md manually or skip' branch. Honor the M014/D017 FR-7 interim-manifest migration handshake so the intake artifact shape stays compatible. Non-goals: no new tier-classification thresholds, no new conversus tool plumbing, no spec authoring (M014 owns), no design renderer (M023 owns), no knowledge writes (M020 owns)."

## Problem Statement

Today `orchestrator:evaluate` requires a feature spec on disk at `specs/{NNN}-{name}/spec.md` before it can run (commands/evaluate.md:25–35). That assumption is load-bearing for every downstream command — `discuss`, `roadmap`, `plan-phase`, `auto`, `dispatch`, `verify` all key off the spec path that `evaluate` confirms. It works when the operator already knows the work is a multi-phase Tier C feature and has already authored a spec via `orchestrator:specify`. It does not work for the much larger set of intake shapes operators actually arrive with: a one-paragraph idea, a half-written fragment pasted from Slack, a single sentence ("can we make `orchestrator:status` cache the last result?"), or no input at all — they sat down to start work and want the orchestrator to ask what to do.

Three pain-points follow from the spec-only intake assumption. **First**, sub-spec work has no on-ramp: a one-task fix (a script bug, a doc typo, a single FR addition to an existing spec) cannot be routed through the orchestrator without authoring a full spec scaffold first, which is wildly disproportionate. Operators either (a) bypass the orchestrator entirely (constitution VI is silently violated — state changes happen off the record) or (b) author a fake spec just to satisfy `evaluate`, polluting `specs/` with one-shot stubs. **Second**, six routing decisions — input shape, scope tier, decomposition, design-gate need, conversus-gate need, and intensity — are made implicitly today, scattered across `evaluate` (tier), `intensity-recommend.sh` (intensity), and the operator's head (the other four). There is no single artifact a human can review before the workflow commits to a path; by the time a divergence is visible (a Tier-A fix dispatched as Tier C, or a design-gated phase missing its DESIGN.md), several agents have already burned context. **Third**, downstream milestones — M019 T2+3 metrics, M018 autonomous loop hardening, M023 design layer, M009 runtime parity audit — assume an upstream router exists. M013 GitHub integration's UAT-bug intake (US-3) already routes inbound work *somewhere*; without M024, that "somewhere" is ad-hoc per consumer.

The minimum surface that fixes all three: **(a)** extend `orchestrator:evaluate` to accept any of five input shapes (idea / paragraph / fragment / spec / empty) — detection happens before tier classification, not after; **(b)** emit a single reviewable proposal artifact at `.orchestrator/intake/<id>/proposal.md` covering all six axes with per-axis rationale, replacing implicit decisions with one inspectable file; **(c)** degenerate fast-path: if and only if the proposal lands at Tier A *and* Quick intensity *and* no-conversus *and* no-design, auto-proceed to dispatch — every other proposal halts at an approval gate; **(d)** reuse existing machinery for every axis decision (tier from current `evaluate` logic, intensity from `intensity-recommend.sh`, conversus from M011/P07 adapter, knowledge evidence from M020 query surface) — M024 is glue, not new infrastructure; **(e)** for empty input, run a bounded Q&A turn (≤5 load-bearing questions, mirroring M014's `speckit.clarify`-style cap) before emitting the proposal; **(f)** when the design-gate axis recommends a design walkthrough but M023 has not yet shipped, emit the exact graceful-degradation message ("design walkthrough lands in M023; author DESIGN.md manually or skip") and treat skip as a first-class branch, not a failure.

This feature explicitly does not attempt: (1) re-opening tier-classification thresholds — M016/M020's existing tier rules are consumed read-only; (2) new conversus tool plumbing — the M011/P07 adapter is invoked unchanged; (3) spec authoring — M014's `orchestrator:specify` owns scaffold/author/gate, M024 routes *to* it for non-trivial inputs and is invoked *from* it for self-routing; (4) the M023 design renderer — M024 only emits the design-gate signal, never renders; (5) any knowledge-tree write — M020 owns knowledge writes, M024 reads via the M020 query surface; (6) any change to `orchestrator:ingest`'s chunk format — consumed read-only; (7) fully autonomous approval bypass — operator approval is the gate for non-degenerate proposals, configurable but not removable.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The dogfood loop closes on US-1 + US-2 + US-3:

- **Full US-1**: input-shape detector + six-axis proposal emission for a paragraph-shaped input on a project with mature knowledge (M020 already shipped per sequencing).
- **Minimal US-2**: backward-compat — pre-existing `evaluate <spec-path>` invocation produces an additional proposal.md alongside the today-shape evaluation output, with axes derived from the spec.
- **Full US-3**: degenerate fast-path — Tier A + Quick + no-conversus + no-design auto-proceeds without an approval prompt, recorded as `auto_proceeded: true` in the proposal frontmatter.

US-4 (empty + Q&A), US-5 (approval revision), and US-6 (pre-M023 design degradation) ride in Phase 2; the slice does not depend on them.

---

### User Story 1 — Operator Pastes A Paragraph And Gets A Reviewable Routing Proposal (Priority: P1)

An operator opens a fresh terminal in their project, types `orchestrator:evaluate "We should add a 'last seen' timestamp to the status command output, and probably cache it for ~5 seconds so repeated calls don't hammer the filesystem. Maybe also a --no-cache flag."`, and gets back a single artifact at `.orchestrator/intake/<id>/proposal.md` covering all six routing axes with per-axis rationale, plus an "approve / revise / cancel" prompt. They read it, approve, and the orchestrator proceeds with the recommended workflow.

**Why this priority**: This is the entry-point experience for the most common intake shape (a paragraph). Without it, the milestone has no user-visible "it works" moment and the spec-only legacy path remains the only on-ramp.

**Independent Test**: On a project with M020 shipped (knowledge query surface available), invoke `orchestrator:evaluate "<paragraph above>"`. Confirm: (a) `.orchestrator/intake/<id>/proposal.md` is created with frontmatter naming all six axes; (b) each axis has a non-empty rationale block citing at least one piece of evidence (existing spec chunk, prior phase, or constitution principle); (c) the operator is prompted for approval; (d) on `approve`, the recommended downstream command is invoked with the proposal as input; (e) on `cancel`, no further state changes occur.

**Acceptance Scenarios**:

1. **Given** a project with mature knowledge, **When** the operator invokes `evaluate` with a paragraph-shaped input, **Then** the input-shape detector classifies it as `paragraph` and records that classification in the proposal frontmatter.
2. **Given** input is classified, **When** the proposal is generated, **Then** all six axes (input_shape, scope_tier, decomposition, design_gate, conversus_gate, intensity) are populated with values and per-axis rationale.
3. **Given** the proposal is emitted, **When** the operator reads it, **Then** the file contains a top-level `Approval` block with three options (approve / revise / cancel) and a placeholder for the operator's response.
4. **Given** the operator approves, **When** approval is recorded, **Then** the proposal frontmatter gains `approved_at: <ISO8601>` and the recommended downstream command is invoked with the proposal path as input.
5. **Given** the operator cancels, **When** cancellation is recorded, **Then** the proposal is marked `cancelled_at: <ISO8601>` but retained on disk for audit.
6. **Given** the operator revises, **When** revision is recorded, **Then** the proposal can be re-emitted with operator-supplied axis overrides (covered in US-5).

---

### User Story 2 — Existing Spec-On-Disk Path Still Works Byte-Compatibly (Priority: P1)

An operator who has already authored a spec at `specs/028-universal-intake-routing/spec.md` runs `orchestrator:evaluate specs/028-universal-intake-routing/spec.md`. The legacy spec-driven path runs as it does today (tier classification, scope analysis, today-shape evaluation output) *and* additionally emits the new proposal.md so downstream commands can opt into the unified intake surface without breaking pre-M024 callers.

**Why this priority**: Backward compatibility is what lets M024 land without a coordinated rewrite of every downstream command. Demoting this would make M024 a flag-day migration, which is incompatible with the dogfooding posture.

**Independent Test**: Take an existing spec from this repo (e.g., `specs/023-github-native-integration/spec.md`), run `orchestrator:evaluate <that-path>` on a checkout where M013 already shipped, and confirm: (a) today's evaluation output is byte-compatible with the pre-M024 shape; (b) the new proposal.md is additionally emitted at `.orchestrator/intake/<id>/proposal.md`; (c) downstream commands invoked with the spec path keep working; (d) downstream commands invoked with the proposal path work identically.

**Acceptance Scenarios**:

1. **Given** an existing spec on disk, **When** `evaluate` is invoked with the spec path, **Then** the pre-M024 evaluation output (tier, story_count, requirement_count, acceptance_count) is produced byte-compatibly.
2. **Given** the legacy output is produced, **When** the same invocation completes, **Then** a proposal.md is additionally emitted with input_shape=`spec` and the other five axes derived from the spec content.
3. **Given** both outputs exist, **When** `orchestrator:roadmap` runs against the spec path, **Then** it succeeds without referencing the proposal (legacy path).
4. **Given** both outputs exist, **When** `orchestrator:roadmap` runs against the proposal path, **Then** it succeeds and consumes the same axis decisions (no divergence).

---

### User Story 3 — Trivial Input Auto-Proceeds Without An Approval Prompt (Priority: P1)

An operator types `orchestrator:evaluate "fix typo in commands/evaluate.md line 12: 'sope' should be 'scope'"`. The router classifies it as Tier A + Quick + no-conversus + no-design, recognizes the four-condition fast-path, and auto-proceeds to dispatch without halting for approval. The proposal is still emitted on disk for audit, with `auto_proceeded: true` in the frontmatter.

**Why this priority**: Without the fast-path, every trivial fix requires an approval keystroke, which makes the orchestrator strictly worse than direct editing for the long tail of small work and discourages adoption. With the fast-path, the orchestrator can absorb sub-task work without ceremony.

**Independent Test**: Invoke `orchestrator:evaluate` on three trivial inputs (single-line typo fix, single-script bug, single-FR addition to an existing spec). For each, confirm: (a) the proposal lands at Tier A + Quick + no-conversus + no-design; (b) no approval prompt is shown; (c) the recommended downstream command runs; (d) `auto_proceeded: true` is recorded in the proposal frontmatter.

**Acceptance Scenarios**:

1. **Given** an input that classifies to all four fast-path values, **When** the proposal is generated, **Then** the operator is not prompted and the recommended command runs.
2. **Given** an input that satisfies three of four fast-path conditions but not the fourth (e.g., Tier A + Quick + no-conversus but design-gated), **When** the proposal is generated, **Then** the operator is prompted as in US-1.
3. **Given** auto-proceed fires, **When** the proposal is read post-hoc, **Then** the frontmatter contains `auto_proceeded: true` and `proceeded_at: <ISO8601>`.
4. **Given** auto-proceed is disabled by config (`evaluate.auto_proceed: false`), **When** a fast-path-eligible input is processed, **Then** the operator is still prompted.

---

### User Story 4 — Empty Input Triggers A Bounded Q&A Then Emits A Proposal (Priority: P2)

An operator types `orchestrator:evaluate` with no argument and no spec path. Instead of erroring, the router runs a bounded Q&A turn (≤5 load-bearing questions, mirroring M014's `speckit.clarify` cap per D019), absorbs the answers, and emits a proposal.md as if the operator had typed those answers as a paragraph.

**Why this priority**: This is the "I don't know what I want yet" intake shape, common during exploratory sessions. P2 because non-empty inputs (US-1 / US-2 / US-3) cover the bulk of intake; empty + Q&A is an ergonomic win, not a blocker.

**Independent Test**: Invoke `orchestrator:evaluate` with no arguments. Confirm: (a) up to 5 questions are asked sequentially; (b) the operator can answer or say `enough` after any question to short-circuit; (c) the proposal is emitted with `input_shape: empty_qa` and the question/answer transcript embedded; (d) the rest of US-1's invariants hold (six axes, approval gate or auto-proceed).

**Acceptance Scenarios**:

1. **Given** no input and no spec path, **When** `evaluate` is invoked, **Then** the first Q&A question is presented and at most four follow-ups are presented.
2. **Given** the operator types `enough`, **When** the short-circuit fires, **Then** the proposal is emitted from the answers gathered so far.
3. **Given** all 5 questions are answered, **When** the proposal is emitted, **Then** the transcript is embedded in the proposal under a `## Q&A` section.

---

### User Story 5 — Operator Revises The Proposal And Re-Emits Before Approval (Priority: P2)

The operator reads a proposal that landed at Tier B + Standard + conversus-gated, decides Tier C + Standard + conversus-gated is the right shape, and types `revise tier=C`. The router accepts the override, re-emits the proposal with the new axis values and adjusted decomposition, and re-prompts for approval.

**Why this priority**: Revision is what keeps the approval gate honest — without it, the operator's only recourse on a wrong proposal is `cancel` and re-run, which loses the analysis. P2 because the first-cut classification is correct most of the time; revision is the exception path.

**Independent Test**: Generate a proposal that lands at Tier B. Issue `revise tier=C`. Confirm: (a) the proposal is re-emitted with the new tier; (b) downstream-affected axes (decomposition; intensity if smell-test escalates) are re-derived; (c) the operator is re-prompted; (d) the prior proposal version is preserved as `proposal-v1.md` in the same directory.

**Acceptance Scenarios**:

1. **Given** a proposal exists, **When** the operator issues `revise <axis>=<value>`, **Then** the named axis is overridden and dependent axes are re-derived.
2. **Given** revision completes, **When** the directory is inspected, **Then** the prior version is preserved with a `-v<N>` suffix and the current `proposal.md` is the latest.
3. **Given** the operator revises an unsupported axis, **When** the override fails validation, **Then** an actionable error names the supported axes and exits non-zero without modifying state.

---

### User Story 6 — Design-Gate Recommendation Degrades Gracefully Pre-M023 (Priority: P2)

A proposal recommends a design walkthrough on a checkout where M023 has not yet shipped (no `orchestrator:design` command available). The router emits the exact graceful-degradation message — "design walkthrough lands in M023; author DESIGN.md manually or skip" — and offers two branches: (a) `manual` (operator authors `DESIGN.md` at the path the proposal names, then re-invokes evaluate), or (b) `skip` (proceed without a design step, recorded as `design_skipped: true` in the proposal).

**Why this priority**: Without graceful degradation, M024 is blocked from landing pre-M023, breaking the D016 sequence (M020 → M024 → M019 T2+3 → M018 → M023). P2 because most early-M024 dogfooding will not be design-gated; this branch matters when it does fire.

**Independent Test**: On a checkout pre-M023, force a design recommendation (e.g., a UI-tagged feature input). Confirm: (a) the exact graceful-degradation message is emitted; (b) `manual` and `skip` branches are presented; (c) `skip` proceeds with `design_skipped: true` recorded; (d) `manual` halts cleanly and the operator can re-invoke after authoring `DESIGN.md`.

**Acceptance Scenarios**:

1. **Given** M023 is not shipped, **When** the proposal recommends a design gate, **Then** the exact "design walkthrough lands in M023; author DESIGN.md manually or skip" message is emitted.
2. **Given** the operator picks `skip`, **When** the proposal is finalized, **Then** the frontmatter records `design_skipped: true` and downstream proceeds without a design step.
3. **Given** the operator picks `manual`, **When** the operator re-invokes `evaluate` after authoring `DESIGN.md`, **Then** the proposal is re-emitted with `design_authored_manually: true` and an evidence pointer to the file.
4. **Given** M023 has shipped, **When** a design-gated proposal is approved, **Then** the recommended downstream command is `orchestrator:design`, not the manual-or-skip branch.

---

## Edge Cases

- **Input shape is ambiguous** (e.g., a paragraph that is *also* a fragment of a larger thought): the detector picks the lowest-cost shape that classifies cleanly; if no shape classifies, the input is treated as `paragraph` and a `shape_classification: low_confidence` flag is recorded in the proposal for the operator to review.
- **Existing spec on disk plus inline argument**: the spec path wins (legacy invariant) and the inline argument is recorded as `supplemental_input` in the proposal frontmatter.
- **Re-running `evaluate` on the same input**: produces a byte-identical proposal (idempotent — see FR-14). If the operator wants a fresh classification, they must `revise` or pass `--force`.
- **Q&A short-circuit on question 1**: emits a proposal from a single answer, with `qa_short_circuited: true` and `low_confidence: true` flags so the approval gate cannot be auto-bypassed by the fast-path.
- **Approval prompt times out** (interactive session abandoned): the proposal is left in `pending_approval` state on disk; the next `evaluate` invocation on the same intake id resumes the prompt rather than re-classifying.
- **Conversus-gate axis recommends but conversus adapter is unavailable** (no `~/Sites/conversus-oss` or `~/Sites/conversus`): emits the M026/D022 OSS-edition diagnostic shape and treats the axis as `conversus_skipped: adapter_unavailable`, prompting for confirm.

---

## Functional Requirements

- **FR-1 (input-shape-detector)**: A pre-tier classification step assigns one of five values — `idea`, `paragraph`, `fragment`, `spec`, `empty` — to every `evaluate` invocation. Detection runs before tier classification. Heuristics are mechanical (length thresholds, structural markers, presence/absence of a spec path) — see #Q-1.
- **FR-2 (proposal-artifact-shape)**: Every `evaluate` invocation emits exactly one `proposal.md` at `.orchestrator/intake/<id>/proposal.md` with frontmatter containing all six axes plus metadata (`created_at`, `input_shape`, `auto_proceeded`, `approved_at`, `cancelled_at`, `design_skipped`, `qa_short_circuited`). Body sections per axis include rationale + evidence pointers (spec chunks, prior phases, constitution principles).
- **FR-3 (degenerate-fast-path)**: When and only when the proposal lands at `scope_tier=A` AND `intensity=Quick` AND `conversus_gate=none` AND `design_gate=none`, the router auto-proceeds to dispatch without an approval prompt. Operator can disable globally via config `evaluate.auto_proceed: false` (default true).
- **FR-4 (approval-gate)**: For every proposal that does not auto-proceed, the operator is prompted with `approve / revise / cancel`. Approval records `approved_at: <ISO8601>` to the proposal; cancellation records `cancelled_at`; revision routes to FR-12.
- **FR-5 (empty-input-qa)**: When `input_shape=empty`, run a bounded Q&A loop of at most 5 load-bearing questions. The operator can short-circuit with `enough` after any question. The transcript is embedded in the proposal under `## Q&A`. The cap mirrors M014's `speckit.clarify` cap per D019.
- **FR-6 (legacy-spec-path-preserved)**: When a spec path is supplied, the today-shape evaluation output (tier, story_count, requirement_count, acceptance_count) is produced byte-compatibly and a proposal.md is additionally emitted with `input_shape=spec`. Pre-M024 callers that read only the today-shape output are unbroken.
- **FR-7 (design-gate-degradation)**: When the design axis recommends a walkthrough and `orchestrator:design` (M023) is not shipped, emit the exact string "design walkthrough lands in M023; author DESIGN.md manually or skip" and offer `manual` / `skip` branches. `manual` halts; `skip` records `design_skipped: true` and proceeds. The string is pinned for grep-stability.
- **FR-8 (conversus-gate-reuse)**: The conversus axis is decided by an existing M011/P07 `scripts/dispatch/adapters/tool/conversus.sh` invocation. M024 does not introduce a new conversus integration surface. When the adapter is unavailable, the axis records `conversus_skipped: adapter_unavailable` (covered in Edge Cases).
- **FR-9 (intensity-reuse)**: The intensity axis is decided by an existing `scripts/engine/intensity-recommend.sh` invocation per D019's reuse-over-rebuild posture. M024 does not introduce parallel intensity machinery.
- **FR-10 (decomposition-axis-output)**: The decomposition axis names exactly one of four values — `single-task`, `single-phase`, `milestone-with-phases`, `multi-milestone` — and points at the recommended downstream command (`dispatch`, `plan-phase`, `roadmap`, or a coordinated multi-roadmap plan respectively).
- **FR-11 (intake-id-allocation)**: When a spec path exists, `<id>` is the spec slug (e.g., `028-universal-intake-routing`) so the proposal lands inside the spec ecosystem. When no spec path exists, `<id>` is allocated as `intake/<NNN>-<short-slug>` where `<NNN>` is the next free integer in `.orchestrator/intake/`. See #Q-2.
- **FR-12 (revision-flow)**: An operator can issue `revise <axis>=<value>` to override one or more axes. Dependent axes are re-derived; the prior proposal is preserved as `proposal-v<N>.md`; the current `proposal.md` is the latest. Only the six named axes are revisable.
- **FR-13 (evidence-citations)**: Each axis rationale cites at least one piece of evidence (M020 knowledge-graph chunk id, prior phase id, constitution principle, or "no-evidence — operator-supplied" honest fallback for empty-input cases).
- **FR-14 (idempotency)**: Re-running `evaluate` on the same input (same shape, same content hash, same project state) produces a byte-identical `proposal.md`. `--force` bypasses the cache.
- **FR-15 (m014-handshake)**: The proposal artifact frontmatter is a strict superset of the interim manifest M014 emits per D017's FR-7 commitment, so an M014 `orchestrator:specify` run that hands off to M024 (and an M024 run that hands off back to `specify` for non-trivial authoring) reads the same shape on both sides.

## Success Criteria

- **SC-1**: `orchestrator:evaluate "fix typo in commands/status.md"` on a project with M020 shipped exits 0, emits `.orchestrator/intake/<id>/proposal.md` with `auto_proceeded: true`, and dispatches without an approval prompt — verified by absence of `approved_at` and presence of `proceeded_at` in the proposal frontmatter.
- **SC-2**: `orchestrator:evaluate "<paragraph that classifies as Tier B>"` exits 0, emits a proposal with `auto_proceeded: false`, and halts at an approval prompt — verified by `pending_approval: true` in the proposal frontmatter and absence of any downstream command invocation in the execution log.
- **SC-3**: `orchestrator:evaluate` invoked with no arguments exits 0 only after at most 5 Q&A turns, emits a proposal with `input_shape=empty_qa`, and embeds the transcript under `## Q&A` — verified by `grep -c '^### Q[0-9]' proposal.md` returning ≤5.
- **SC-4**: `orchestrator:evaluate <existing-spec-path>` produces today-shape evaluation output byte-compatibly with the pre-M024 baseline — verified by `diff` against a captured baseline fixture.
- **SC-5**: On a pre-M023 checkout, a design-gated proposal emits the exact string "design walkthrough lands in M023; author DESIGN.md manually or skip" — verified by `grep -F` against stdout.
- **SC-6**: Re-running `evaluate` on the same input produces a byte-identical `proposal.md` — verified by `shasum` equality across two runs.
- **SC-7**: Every proposal frontmatter contains all six named axes with non-null values — verified by a frontmatter-completeness assertion in the test suite.
- **SC-8**: An M014 `orchestrator:specify` run that hands off an interim manifest to M024 produces a proposal whose frontmatter is a strict superset of the manifest's keys — verified by JSON key-set containment per D017.

## Non-Goals

- **NG-1 (no new tier thresholds)**: Tier-classification thresholds are inherited from current `evaluate` logic and M020's mature knowledge surface; M024 does not re-tune them.
- **NG-2 (no new conversus plumbing)**: The M011/P07 adapter is invoked unchanged; M024 does not introduce a parallel conversus integration.
- **NG-3 (no spec authoring)**: M014 owns scaffold/author/gate; M024 routes to it for non-trivial inputs and is invoked from it for self-routing — no body authoring happens inside M024.
- **NG-4 (no design rendering)**: M024 emits the design-gate signal only; M023 owns the renderer.
- **NG-5 (no knowledge writes)**: M020 owns the knowledge tree; M024 reads via M020's query surface and writes only to `.orchestrator/intake/`.
- **NG-6 (no autonomous approval bypass)**: Approval is the gate for non-degenerate proposals; the only auto-proceed path is the four-condition degenerate fast-path. Operators cannot configure "always auto-approve."

## Constraints

- **CON-1 (constitution-iii-design-before-code)**: The proposal-as-artifact gates the router on Constitution III. No downstream command runs without either (a) the four-condition auto-proceed path or (b) recorded operator approval.
- **CON-2 (constitution-xiv-extension-not-new-command)**: M024 extends `orchestrator:evaluate` rather than introducing a new `orchestrator:start` command per D016. The surface area count stays at 13.
- **CON-3 (runtime-portability)**: Implementation lands portably (POSIX sh + bash 3.2+) across CC + Codex CLI + Cursor. Any CC-specific shape is logged in `RUNTIME-ASSUMPTIONS.md` per D016 (7).
- **CON-4 (m011-p07-conversus-adapter-untouched)**: The conversus adapter at `scripts/dispatch/adapters/tool/conversus.sh` is consumed read-only; M024 adds a caller, not a new code path inside the adapter.
- **CON-5 (d019-todo-preflight-respected)**: Any conversus-gate invocation M024 makes inherits the D019 universal TODO pre-flight invariant; M024 must not author `<TODO:` markers into proposals that subsequently flow through the gate.

### Knowledge-Layer Boundary (M024 vs. M020)

M020 owns the knowledge graph and its query surface (`scripts/state/knowledge-query.sh` and successors). M024 reads from that surface to populate axis evidence (FR-13) and writes nothing into `knowledge/`. M024's writes are confined to `.orchestrator/intake/<id>/`. When the proposal cites an M020 chunk, the citation is by chunk id only — never a duplicated body — so re-reading remains M020's responsibility.

## Assumptions

- **A1**: M020 has shipped before M024 starts (D016 sequence). Mature knowledge query surface is available; degraded behavior on a pre-M020 checkout is out of scope.
- **A2**: M014 extended (`orchestrator:specify` three-pass per D019) has shipped before M024 starts. The handshake direction is M014 → M024 → M014; both endpoints exist.
- **A3**: M011/P07 conversus adapter is the canonical conversus integration surface (M026/D022 OSS-primary posture).
- **A4**: M016's intensity engine (`intensity-recommend.sh`, `intensity-analyze.sh`, `intensity-override.sh`) is the canonical intensity surface and is not under active redesign at M024 plan-phase time.
- **A5**: M023 has *not* shipped at M024 plan-phase time (FR-7 graceful degradation is exercised). Post-M023, FR-7's `manual`/`skip` branches become a fallback used only when the operator opts out of the design walkthrough.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle III (Design Before Code)**: The proposal artifact gates dispatch on a reviewable design — every non-trivial run produces an inspectable file before any agent burns context. Auto-proceed fires only on the four-condition degenerate path where design overhead would itself be the larger waste.
- **Principle I (Context Minimization)**: The proposal is a single ≤200-line artifact replacing six implicit decisions; downstream commands consume the proposal frontmatter rather than re-deriving axes.
- **Principle II (Evidence Before Claims)**: Per-axis rationale (FR-13) requires at least one cited evidence pointer; "no-evidence — operator-supplied" is the honest fallback for empty-input cases rather than a fabricated rationale.
- **Principle VI (State On Disk Is Truth)**: The proposal is the authoritative record of routing decisions; approval state, revision history, and auto-proceed flags all live in the file.
- **Principle XIV (Surface Discipline)**: M024 extends `evaluate`, does not add a new command (D016, CON-2). Reuses tier / intensity / conversus / knowledge surfaces unchanged (FR-8, FR-9, NG-1).

## Open Questions (defer to planning)

- **#Q-1 (input-shape-heuristics)**: What are the exact length thresholds and structural markers that distinguish `idea` / `paragraph` / `fragment`? Plan-phase decides — candidates include word-count buckets (≤10 / 11–80 / 81+), presence of section headers, presence of a `Given/When/Then` skeleton.
- **#Q-2 (intake-id-allocation-when-no-spec)**: Counter-based (`intake/001-…`, `intake/002-…`) or content-hash-based (`intake/<sha8>-…`)? Counter is simpler; hash is idempotent across operators. Plan-phase decides.
- **#Q-3 (qa-question-source)**: Static template, conversus-loop, or knowledge-driven? Plan-phase decides — D019 reuse posture argues for static template if it earns its keep on dogfood.
- **#Q-4 (decomposition-recommendation-depth)**: Flat 4-value enum (FR-10) or a richer DAG? Flat first; DAG can land in M024.x if dogfood signal demands.
- **#Q-5 (proposal-schema-version-pinning)**: `schema_version: "1.0"` aligned with spec frontmatter, or `intake-schema-version: "0.1"` to telegraph instability? Plan-phase decides; D017's FR-15 handshake commitment constrains the choice.
- **#Q-6 (revision-mutates-vs-clones)**: Does `revise` re-emit the same `<id>` (preserving prior versions in-place per FR-12) or allocate a new `<id>`? FR-12 currently commits to in-place; plan-phase confirms the version-suffix scheme.
- **#Q-7 (auto-proceed-config-scope)**: Is `evaluate.auto_proceed` a project-wide config or a per-invocation `--no-auto-proceed` flag? FR-3 currently commits to project-wide; plan-phase confirms or splits.

## Dependencies

- **M020 — Knowledge Layer Maturation** (precedes M024 per D016 sequencing): provides the query surface that FR-13 evidence citations consume.
- **M014 extended** (precedes M024 per D016): provides `orchestrator:specify`'s three-pass flow and the FR-7 interim-manifest handshake (D017) that M024's FR-15 mirrors.
- **M016 — Autonomous Hardening** (already shipped): provides `intensity-recommend.sh` consumed unchanged per FR-9.
- **M011/P07 conversus adapter** (already shipped, M026 OSS-primary per D022): consumed unchanged per FR-8.
- **M013 GitHub Native Integration** (already shipped): UAT-bug intake (US-3) is one of M024's intake shapes when M013 sync mode is `on-transition`.

## Downstream Consumers (informational, not binding)

- **M019 Tier 2+3 (observability rollup + `orchestrator:cost`)**: consumes routing telemetry from `.orchestrator/intake/` to surface input-shape distribution and auto-proceed rate.
- **M018 (autonomous hardening v3)**: consumes the proposal frontmatter as the authoritative routing record for autonomous loop entry.
- **M023 (Design Layer)**: consumes the design-gate axis to decide whether to invoke `orchestrator:design`; FR-7 graceful degradation flips into the post-M023 happy path.
- **M009 (extended) — runtime-parity audit**: consumes `RUNTIME-ASSUMPTIONS.md` entries logged by M024 implementation to validate CC + Codex CLI + Cursor parity before launch.
- **M010 (Managed Agents primary + Codex Cloud stub)**: consumes the proposal as the entry point for managed-agent runs — same shape across both backend adapters.

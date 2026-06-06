---
schema_version: "1.0"
type: feature-spec
feature_slug: "044-interactive-review-gates"
created_at: "2026-06-06"
status: "Ready-for-discuss"
milestone: "M034"
---

# Feature Specification: 044-interactive-review-gates

**Feature Branch**: `044-interactive-review-gates`
**Created**: 2026-06-06
**Status**: Ready-for-discuss
**Last Revised**: 2026-06-06
**Milestone**: M034
**Gate**: Pass-3 conversus `spec-pressure-test` (red-blue, 6 phases, 2026-06-06) → "Proceed with conditions" (6 disputes → PC-1..PC-6). Operator accepted proceed-with-conditions; all 8 mitigations folded in (MIT-7/MIT-8 direct, MIT-1..MIT-6 → PC-1..PC-6).
**Input**: User description: "Interactive review gates: a first-class review stage between artifact authoring and SIGNOFF.md, built on a single versioned decision-packet schema (DECISIONS.md) with an interactive walkthrough routed per-runtime via dispatch-interface.sh — Claude Code AskUserQuestion, a Cursor MCP elicitation review-gate server, and a headless QUESTIONS.md hand-off with auto-mode policies (defer/accept-with-audit/block). Conversus deliberation is an optional packet producer (gate-result -> packet entries). REVIEW.md is the append-only audit trail that populates SIGNOFF.md. Adds a boundary-translation packet type and a warn|block severity tier. Consolidates the M009 Cursor MCP renderer (FR-6) and byte-parity audit (FR-8); the Cursor cost rate-card (FR-7) stays deferred. Demand-driven by a real Cursor dogfooder testing both interactive and headless modes."

## Problem Statement

The orchestrator's sign-off boundary is approve-or-don't, not deliberate-then-approve. `SIGNOFF.md` asks `approved_by: null` to be flipped to a name; it carries no structure for *what* was reviewed, *which* decisions were load-bearing, or *what alternatives* were on the table. The operator must reverse-engineer that scaffolding by reading the artifact line-by-line. That works for short artifacts and small decision counts and fails at scale — on lakeledger M066/P01 a 197-line catalog carried 8 load-bearing decisions, of which a static read surfaced only 2–3 as "do I agree?" while a conversational walkthrough surfaced 5–6 more, because each arrived with concrete impact framing the artifact itself did not carry.

Three pain-points follow. First, the materially-better walkthrough is today *agent improvisation on top of the orchestrator*, not an orchestrator stage — so the next operator who hits a contract-defining gate gets the "go read the file" UX unless they happen to ask for a walkthrough. Second, there is no abstraction over runtime question primitives: Claude Code has `AskUserQuestion`, Cursor has MCP elicitation, headless runs have neither — direct calls fragment, and a gate that blocks indefinitely deadlocks every autonomous run. Third, load-bearing *boundary-translation* decisions (spec/catalog vocabulary → schema-native names) survive no formal gate; they pass mock-only verification and fail at first real run (lakeledger M066/P04: `surface_acres` vs `surface_area_acres`).

The minimum surface that fixes all three is a first-class **interactive review gate** stage between artifact authoring and `SIGNOFF.md` population, built on a single **decision-packet schema** consumed by an **interactive walkthrough** that routes per-runtime through `dispatch-interface.sh`, captures responses to an append-only `REVIEW.md`, and populates `SIGNOFF.md` from it. Conversus deliberation plugs in as an optional *producer* of packet content. This milestone also consolidates the M009 Cursor work that is really *this* feature's Cursor renderer (FR-6 MCP review-gate server) plus its byte-parity audit (FR-8).

This feature explicitly does not replace `SIGNOFF.md` (it populates it), does not replace `orchestrator:verify` (it sits before it), is not a new dispatch mode (the gate is opt-in metadata on existing tasks/phases), and is never a blocking default.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The smallest coherent subset that closes the dogfood loop is **US1 (decision-packet schema + writer + surfacing)** plus **US2 (interactive walkthrough on Claude Code → REVIEW.md → SIGNOFF)**. US1 alone ships standalone value — a structured packet gives `doctor`/`status` something to surface ("phase has N unreviewed load-bearing decisions") and gives operators reading the markdown a clearer surfacing of load-bearing items than prose — but the headline UX (the walkthrough the lakeledger operator preferred) needs US2. Cursor rendering (US4), the conversus producer (US5), auto-mode/headless behavior (US3), and the boundary-translation type (US6) are all defended on top of this slice and add no value without it.

### User Story 1 — Structured decision packet (Priority: P1)

An artifact-writing task that declares `decision_packet: true` emits, alongside its primary artifact, a structured `*-DECISIONS.md` packet — one entry per load-bearing decision (picked value, rationale, alternatives considered, concrete impact, severity). `doctor` and `status` report unreviewed decisions. The operator reading the markdown sees load-bearing items called out as typed entries rather than buried in prose.

**Why this priority**: It is the shared contract every other story consumes. Nothing downstream (walkthrough, Cursor renderer, conversus producer) can exist without the packet schema, and it delivers audit/observability value even before any walkthrough ships.

**Independent Test**: Run a task fixture declaring `decision_packet: true`; assert a schema-valid `*-DECISIONS.md` is written next to the artifact, that `spec-shape-lint`-style schema validation passes, and that `status` reports the unreviewed-decision count. No walkthrough, no runtime question primitive involved.

**Acceptance Scenarios**:

1. **Given** a task plan with `decision_packet: true` and an artifact carrying ≥1 load-bearing decision, **When** the task completes, **Then** a `*-DECISIONS.md` with versioned frontmatter and one typed entry per decision is written, and `status` reports "N unreviewed decisions" for the phase.
2. **Given** a task plan with no `decision_packet` declaration, **When** the task completes, **Then** no packet is written (opt-in default).

---

### User Story 2 — Interactive walkthrough on Claude Code (Priority: P1)

At a declared review gate, the operator is walked through the decision packet conversationally via Claude Code's `AskUserQuestion`: each load-bearing decision is presented with concrete impact framing and the option to accept, override, or push back. Responses are captured to an append-only `REVIEW.md`; `SIGNOFF.md` is populated from `REVIEW.md`'s terminal entry.

**Why this priority**: This is the headline value — the lakeledger evidence shows the walkthrough surfaces ~2× the load-bearing concerns a static read does. CC is the launch runtime, so it is the first renderer.

**Independent Test**: Drive the `interactive_review` stage against a captured packet fixture in a CC context; simulate operator answers; assert `REVIEW.md` records each answer append-only and `SIGNOFF.md` is populated from the terminal entry. No Cursor, no conversus.

**Acceptance Scenarios**:

1. **Given** a phase declaring `review_gates: [...]` and a present `*-DECISIONS.md`, **When** the gate runs interactively in CC, **Then** each decision is surfaced via `AskUserQuestion`, the operator's response is appended to `REVIEW.md`, and `SIGNOFF.md` reflects the terminal review entry.
2. **Given** an operator overrides a decision at the gate, **When** the gate completes, **Then** the override and its rationale are captured in `REVIEW.md` and the artifact is NOT silently re-approved (CON-5/SC-5 invariant: operator-touch is gated, the decision artifact is always written).

---

### User Story 3 — Autonomous & headless behavior (Priority: P2)

In `auto` mode or a headless `cursor-agent` run there is no human in the loop. A declared gate must not deadlock. The gate applies its plan-declared auto-mode policy — **default `defer`**: emit a `pending-review` event, write a continue-file, exit cleanly; the operator runs `orchestrator:resume` and completes the walkthrough. `accept-with-audit` (auto-accept + per-decision audit record) and `refuse-entry` (refuse to enter the phase) are available per-gate overrides. (The policy enum is `defer | accept-with-audit | refuse-entry`; `refuse-entry` is deliberately NOT named `block` to avoid lexical collision with the conversus `BLOCK` verdict, which is operator-overridable content — see CON-8.) The runtime-native fallback when no interactive surface exists is a `QUESTIONS.md` hand-off (same shape as M033 P04's >5-conflicts hand-off).

**Why this priority**: The dogfooder runs headless, so this governs their autonomous experience directly; but it is built on US1/US2 and is a policy layer over them.

**Independent Test**: Run the gate under a simulated `auto` context with each policy; assert `defer` writes a continue-file + `pending-review` JSONL and exits 0; `accept-with-audit` writes one `auto-accepted` record per decision; `refuse-entry` refuses entry. Assert in all three the `*-DECISIONS.md` is still written (always-write invariant).

**Acceptance Scenarios**:

1. **Given** a gated phase with policy `defer` entered under `auto` mode, **When** the gate is reached, **Then** a `pending-review` JSONL event + continue-file are written and the run exits cleanly (no deadlock), resumable via `orchestrator:resume`.
2. **Given** a headless `cursor-agent` run hitting a gate, **When** elicitation is unavailable (auto-declines per M009 Q1), **Then** the gate falls back to `QUESTIONS.md` hand-off and applies the declared policy — no hang, no error.

---

### User Story 4 — Native review gates in interactive Cursor (Priority: P2)

In an interactive Cursor IDE/TUI session, the operator gets native review prompts (not a file hand-off) via an orchestrator-owned MCP server that exposes review gates through `elicitation/create`. The server is registered in `.cursor/mcp.json`; interactive sessions render a form (`action:accept` with content), and the same server in a headless session receives the deterministic `action:decline` that maps onto the auto-mode policy (US3).

**Why this priority**: Required because the dogfooder tests interactive Cursor, but it is one renderer behind the CC renderer (US2) and the runtime-agnostic stage (US3) in dependency order. Architecture de-risked by the M009 Q1 elicitation probe.

**Independent Test**: Register the orchestrator MCP server in a hermetic `.cursor/mcp.json`; drive a gate in an interactive-simulating harness and assert a form is rendered + an `accept` response is captured to `REVIEW.md`; drive the same server headless and assert the `decline` maps to the declared policy. (Live interactive rendering verified with the dogfooder; hermetic test stubs the elicitation transport.)

**Acceptance Scenarios**:

1. **Given** the orchestrator MCP server registered in `.cursor/mcp.json` and an interactive Cursor session at a gate, **When** the gate fires, **Then** a native elicitation form renders and the operator's `accept` response populates `REVIEW.md`.
2. **Given** the same server in a headless `cursor-agent -p` run, **When** the gate fires, **Then** elicitation returns `action:decline` instantly and the auto-mode policy is applied (US3) with no hang.

---

### User Story 5 — Conversus as an optional packet producer (Priority: P2)

A gate may declare `producer: conversus`. The orchestrator runs the existing conversus gate adapter over the artifact, and maps its `gate-result.md` (verdict PASS|BLOCK, surviving disputes, rationale, link to the full deliberation) into decision-packet entries the walkthrough then surfaces — so the operator adjudicates conversus's findings rather than re-deriving them. When `producer: conversus` is declared but the conversus binary is absent/unauthed, the gate **blocks** with an install pointer (strict) rather than silently skipping.

**Why this priority**: High-value composition the dogfooder explicitly wants, but additive on top of the packet schema (US1) and walkthrough (US2).

**Independent Test**: With a stubbed conversus adapter returning a known `gate-result.md`, assert the producer maps verdict/disputes/rationale into packet entries. With the binary absent and `producer: conversus` declared, assert the gate exits non-zero with an install-conversus message (no silent SKIP).

**Acceptance Scenarios**:

1. **Given** a gate with `producer: conversus` and conversus installed, **When** the gate runs, **Then** the conversus `gate-result.md` verdict + surviving disputes are folded into the packet as decision entries linked to `summary/final.md`.
2. **Given** a gate with `producer: conversus` and conversus NOT installed, **When** the gate runs, **Then** the gate exits non-zero with a clear `pipx install conversus-oss` + `conversus login` message and does not mark the gate reviewed.

---

### User Story 6 — Boundary-translation packet type (Priority: P3)

Tasks that declare `touches_persistence: true` (or trip a planner heuristic: SQL reads, schema migrations, ORM models, file-format readers, protocol parsers) auto-emit a `boundary_translation` packet entry recording (a) the source-vocabulary identifier the spec/catalog/plan uses, (b) the target-vocabulary identifier the persistence/protocol/format actually uses, (c) the transformation site (`file:line`), (d) the verification mechanism (real-DB column-existence check / schema introspection / fixture round-trip). The walkthrough surfaces these as explicit confirm-the-bridge decisions.

**Why this priority**: Prevents the lakeledger M066/P04-class post-deploy drift, but it is an additional packet *type* folded into the existing schema and walkthrough — additive, not a new stage, and lower-frequency than the core gate.

**Independent Test**: Run a fixture task with `touches_persistence: true` whose plan vocabulary diverges from a fixture schema; assert a `boundary_translation` entry is emitted with all four fields and surfaced in the walkthrough.

**Acceptance Scenarios**:

1. **Given** a task declaring `touches_persistence: true` with source vocabulary `surface_acres` and schema column `surface_area_acres`, **When** the packet is emitted, **Then** a `boundary_translation` entry records source, target, transform site, and verification mechanism, and the walkthrough surfaces it as a confirm decision.

---

## Edge Cases

- **Gate reached, packet absent**: a phase declares `review_gates` but no `*-DECISIONS.md` exists (upstream task didn't emit one). Behavior: the gate fails closed with an actionable diagnostic naming the missing packet — it does not silently pass.
- **Operator answers, then crash before SIGNOFF write**: `REVIEW.md` is append-only, so partial answers survive; `orchestrator:resume` re-enters the gate from the last recorded `REVIEW.md` entry rather than restarting the walkthrough.
- **conversus declared producer returns BLOCK**: BLOCK is *content*, not a hard stop — the BLOCK verdict + disputes become packet entries the operator adjudicates at the gate (the human can override). conversus adapter exit 2 (BLOCK) is distinct from exit 1 (adapter error); only adapter error / missing-binary blocks the gate.
- **Cursor MCP server present but elicitation capability absent** (older Cursor): the gate degrades to the `QUESTIONS.md` hand-off rather than erroring.
- **Re-run of an artifact-authoring task that already emitted a packet**: packet emission is idempotent on unchanged decisions; changed decisions supersede prior entries (supersede semantics resolved at P00/P01 — see Open Questions).
- **`auto_mode` policy `refuse-entry` on a phase the autonomous run must traverse**: the run halts at the phase boundary with a `refused-entry` event; this is the declared strict behavior, not a bug.
- **Boundary-translation heuristic false-positive** (a task touches no real persistence but trips the heuristic): the operator can mark the emitted entry N/A at the gate; the entry is recorded as acknowledged-not-applicable in `REVIEW.md`.

---

## Functional Requirements

- **FR-1 (decision-packet-schema)**: A versioned template `templates/decisions-packet.md` defines the decision-packet schema — frontmatter `schema_version` + an array of typed entries `{id, summary, picked_value, rationale, alternatives_considered, concrete_impact, severity, type}`. `severity ∈ {warn, block}` (default `block`); `type ∈ {decision, boundary_translation}` (default `decision`). Any weight/threshold/severity boundary appears as a NAMED CONSTANT in exactly one place that prompts/docs/tests reference (no magic numbers). Satisfies US1. (M034 Finding A; GSD eval-review discipline.)
- **FR-2 (packet-writer)**: A single-file bash 3.2 helper `scripts/knowledge/write-decisions.sh` (modeled on `write-summary.sh`) emits a schema-valid packet next to the primary artifact when the task plan declares `decision_packet: true`. Satisfies US1.
- **FR-3 (opt-in-emission)**: Packet emission is opt-in per task via plan frontmatter `decision_packet: true`; absent the declaration, no packet is written. Satisfies US1 (resolved clarify: opt-in, not default-on).
- **FR-4 (packet-surfacing)**: `status` and `doctor` read the packet and report unreviewed load-bearing decision counts per phase; recurring unreviewed `warn`-severity entries surface as a `doctor` health finding. Satisfies US1.
- **FR-5 (interactive-review-stage)**: A new lifecycle stage `scripts/lifecycle/interactive-review.sh`, invoked for phases declaring `review_gates: [...]` in frontmatter, reads `*-DECISIONS.md`, surfaces entries, captures responses to `REVIEW.md`, and populates `SIGNOFF.md` from `REVIEW.md`'s terminal entry. Routed through `dispatch-interface.sh` so the runtime renderer is selected uniformly. Satisfies US2.
- **FR-6 (cc-askuserquestion-renderer)**: The CC renderer surfaces each decision via `AskUserQuestion` with concrete impact framing; accept/override/push-back responses append to `REVIEW.md`. Satisfies US2.
- **FR-7 (review-md-audit)**: `REVIEW.md` is append-only (one block per gate visit); `SIGNOFF.md` is populated from its terminal entry. Co-located with the packet (`*-REVIEW.md`). The decision artifact is ALWAYS written regardless of policy (CON-5/SC-5). Satisfies US2/US3.
- **FR-8 (auto-mode-policies)**: Plan frontmatter declares one of `defer | accept-with-audit | refuse-entry` per gate. **Default `defer`**: emit `pending-review` JSONL + continue-file, exit cleanly, resumable via `orchestrator:resume`. `accept-with-audit`: auto-accept + one `auto-accepted` JSONL per decision. `refuse-entry`: refuse phase entry (named `refuse-entry`, not `block`, to avoid collision with the conversus `BLOCK` verdict — CON-8). `orchestrator:auto` reads the policy before entering the phase. Satisfies US3 (resolved clarify: default `defer`).
- **FR-9 (headless-questions-fallback)**: When no interactive question primitive is available (headless CC or headless `cursor-agent` whose elicitation auto-declines), the stage writes a `QUESTIONS.md` hand-off and applies the declared auto-mode policy — no hang, no error. Satisfies US3. (M009 Q1 / Addendum (b).)
- **FR-10 (cursor-mcp-review-server)**: An orchestrator-owned stdio MCP server exposes review gates via `elicitation/create`, registered in `.cursor/mcp.json` by the Cursor install path. Interactive Cursor renders a form (`action:accept` → response captured); headless receives `action:decline` mapped to the auto-mode policy (FR-8). This is the consolidated M009 FR-6. Satisfies US4.
- **FR-11 (conversus-producer)**: A gate declaring `producer: conversus` runs `scripts/dispatch/adapters/tool/conversus.sh gate <preset> <artifact> <out>` and maps the resulting `gate-result.md` (verdict, surviving disputes, rationale, `conversus_output_dir`/`summary/final.md` link) into decision-packet entries. Satisfies US5.
- **FR-12 (conversus-strict-when-declared)**: When `producer: conversus` is declared and the conversus binary is absent/unauthed, the gate runs `--strict` semantics — it BLOCKS with a `pipx install conversus-oss` + `conversus login` pointer and does not mark the gate reviewed (no silent SKIP). Satisfies US5 (resolved clarify: block, not warn-continue).
- **FR-13 (boundary-translation-type)**: Tasks declaring `touches_persistence: true` (or, **advisory for v1**: matching the planner heuristic — SQL reads, schema migrations, ORM models, file-format readers, protocol parsers) auto-emit `type: boundary_translation` packet entries recording source-vocabulary id, target-vocabulary id, transform site (`file:line`), and verification mechanism; the walkthrough surfaces them as confirm decisions. Only the explicit `touches_persistence: true` path is normative for v1 (#Q-6); the heuristic is advisory. Satisfies US6. (M034 Finding E.)
- **FR-14 (runtime-assumptions-rows)**: `references/RUNTIME-ASSUMPTIONS.md` gains rows for the interactive-review question primitive per runtime (CC AskUserQuestion / Cursor MCP elicitation / headless QUESTIONS.md hand-off), with parity fixtures per `dispatch-interface.sh` convention. Satisfies US3/US4.
- **FR-15 (cursor-byte-parity-audit)**: A byte-parity audit fixture runs the zero-LLM review-gate paths under `ORCH_BACKEND=cursor` and asserts equality with the CC paths where the path is deterministic (the consolidated M009 FR-8). Satisfies the consolidation's parity goal.

## Success Criteria

- **SC-1**: Running a task fixture with `decision_packet: true` writes a schema-valid `*-DECISIONS.md` (schema validator exits 0) with one typed entry per load-bearing decision; a task without the declaration writes none. (FR-1/2/3)
- **SC-2**: `bash scripts/diagnostics/render-status-json.sh` (or `status`) reports a non-zero `unreviewed_decisions` count for a phase with an unreviewed packet, and zero after the gate populates `SIGNOFF.md`. (FR-4)
- **SC-3**: Driving `interactive-review.sh` in a CC harness against a packet fixture appends one operator response per decision to `REVIEW.md` and populates `SIGNOFF.md` from the terminal entry; an override is captured verbatim. (FR-5/6/7)
- **SC-4**: Under a simulated `auto` context, policy `defer` writes a `pending-review` JSONL + continue-file and exits 0; `accept-with-audit` writes one `auto-accepted` JSONL per decision; `refuse-entry` refuses entry — and in all three the `*-DECISIONS.md` exists. The extended round-trip (`orchestrator:resume` re-enters the deferred gate at the recorded position) is verified per MIT-5. (FR-8)
- **SC-5**: A headless run with no interactive primitive writes `QUESTIONS.md` and applies the declared policy without hanging (watchdog never fires). (FR-9)
- **SC-6**: With the orchestrator MCP server registered in a hermetic `.cursor/mcp.json`, the gate captures an `accept` response interactively (stubbed transport) and maps a headless `decline` to the auto-mode policy. (FR-10)
- **SC-7**: With a stubbed conversus adapter, a `producer: conversus` gate folds the `gate-result.md` verdict + disputes into packet entries; with the binary absent the same gate exits non-zero with an install pointer and leaves the gate unreviewed. (FR-11/12)
- **SC-8**: A `touches_persistence: true` fixture whose plan vocabulary diverges from a fixture schema emits a `boundary_translation` entry carrying all four fields. (FR-13)
- **SC-9**: `references/RUNTIME-ASSUMPTIONS.md` carries the interactive-review primitive rows and the parity fixture under `ORCH_BACKEND=cursor` passes for the deterministic paths. (FR-14/15)

## Non-Goals

- **Replacing `SIGNOFF.md`** — this feature populates it from `REVIEW.md`; the gate primitive is unchanged.
- **Replacing `orchestrator:verify`** — verify runs after SIGNOFF; this stage runs before it. They compose.
- **A general AskUserQuestion / interactive-UX harness** — M033 owns interactive UX patterns; this milestone invokes them.
- **A spec-amendment review surface** — M014's `commands/comments.md` review-queue owns PR-comment→spec-amendment; this milestone reuses the CON-5/SC-5 convention only, not the code.
- **Cursor cost accounting (M009 FR-7)** — deferred. `cursor-agent` JSON carries no USD; a hand-maintained rate card is out of scope. The Tier-A `estimated_cost_usd:null` + `pricing_warning` degrade stands.
- **A blocking-by-default gate** — gates are opt-in per plan; `decision_packet` and `review_gates` are never global defaults.
- **Knowledge-graph integration of decisions** — writing decisions into `knowledge/**` chunks or a decision-contradiction gate is M038/M040 territory (see Knowledge-Layer Boundary).

## Constraints

- **CON-1 (bash-3.2-single-file)**: Every new script is a single bash 3.2 / POSIX-sh file (AD-19): no associative arrays, no `${var,,}`, no process substitution in the hot path. `write-decisions.sh` follows `write-summary.sh`; `interactive-review.sh` follows `auto-loop.sh`.
- **CON-2 (ap-009-chains)**: Interactive flows invoke ≤2 commands per chain; longer flows route through `scripts/util/run-probe.sh`.
- **CON-3 (con5-sc5-never-auto-applied)**: Inherited verbatim from `commands/comments.md`. The decision artifact is always written; only operator-touch is gated; all three auto-mode policies preserve this.
- **CON-4 (named-constants-ssot)**: Every threshold/weight/severity boundary is a named constant in one place referenced by prompts, docs, and tests (GSD eval-review discipline — prevents two callers disagreeing on a threshold).
- **CON-5 (conversus-oss-dependency)**: conversus-backed gates require the OSS build on `PATH` or at `~/Sites/conversus-oss`; on OAuth set `CONVERSUS_PROVIDER=claude-code` (auto-detected from `~/.conversus/auth.json`). A declared conversus producer with a missing binary BLOCKS (FR-12), never silently SKIPs.
- **CON-6 (mcp-server-stdio)**: The Cursor review-gate MCP server is a stdio server registered in `.cursor/mcp.json`, non-clobbering of operator MCP config (merge, don't overwrite — mirrors the M009 hooks.json discipline).
- **CON-7 (runtime-routing-via-dispatch-interface)**: The walkthrough never calls a runtime question primitive directly; it routes through `dispatch-interface.sh` so renderer selection (CC / Cursor-MCP / headless-fallback) is uniform (M034 Finding D / M025 pattern).
- **CON-8 (block-term-disambiguation)**: Three distinct uses of "block" must stay lexically separable: the auto-mode policy enum value is `refuse-entry` (never `block`); the decision-packet `severity` field uses `block` (an entry-level severity); the conversus `BLOCK` verdict is operator-overridable *content*, not a hard stop. Prompts/docs/tests reference the precise term per context (gate-derived, conversus RISK-8/MIT-7).

## Pre-Planning Conditions (gate-derived, binding)

The Pass-3 conversus `spec-pressure-test` deliberation (red-blue, 6 phases, 2026-06-06; artifacts under `conversus/`) returned **"Proceed with conditions"** — architecture sound, with mitigations that resolve at plan-phase, not in this spec. These are recorded here on disk (Principle VI) so the relevant plan-phase inherits them as binding entry conditions:

- **PC-1 (P0, blocks P00→P01) — `write-decisions.sh` calling convention (MIT-1, RISK-1)**: the P00 plan-phase addendum MUST specify the wire format for passing LLM-generated multi-field decision content to `write-decisions.sh` (recommended: stdin JSON document of the FR-1 entry array, safe for newlines/shell metacharacters), the milestone-id/output-path argument encoding, and the multi-line-field escaping contract; the LLM instruction template must match it exactly. A second author following only the spec must produce an identical SC-1 fixture.
- **PC-2 (P0, blocks P00→P01) — CC renderer execution context (MIT-2, RISK-5)**: the P00 addendum MUST inspect `scripts/dispatch/adapters/backend/cc.sh` + `dispatch-interface.sh` and resolve **Case A** (the renderer runs in the already-interactive top-level CC session and issues `AskUserQuestion` directly) vs **Case B** (it routes through a spawned `claude -p` subagent). For Case B it MUST demonstrate `AskUserQuestion` is interactive under the specific invocation args, or specify a non-`claude -p` invocation model (amending FR-5/FR-6). If no CC path surfaces `AskUserQuestion` interactively, **RISK-5 escalates to a standalone P0 blocker** and US2/FR-6 are amended before P01. It MUST also specify the `REVIEW.md` write path (agent-writes-directly vs `interactive-review.sh`-writes-returned-output).
- **PC-3 (P1, blocks P01) — SC-3 simulation approach (MIT-3, RISK-2)**: the P01 plan-phase artifact MUST specify the synthetic-operator-response harness (recommended option A: recorded-response fixtures injected as prompt overrides; option B: mock-dispatch intercept as fallback if option A is non-deterministic), the fixture format, the `interactive-review.sh` test-mode flag, and the `REVIEW.md`/`SIGNOFF.md` assertions, such that SC-3 runs deterministically in CI with no human.
- **PC-4 (P1, blocks P01) — headless detection mechanism (MIT-4, RISK-4)**: the P01 artifact MUST specify how `interactive-review.sh` detects "no interactive primitive available" (recommended: a `dispatch-interface.sh` capability probe over a bare `ORCH_HEADLESS=1`), the states it distinguishes, and how CI/`auto` entry points set that state for SC-5.
- **PC-5 (P1, blocks the `defer` path) — continue-file schema + `orchestrator:resume` surface (MIT-5, RISK-6)**: the P01/P02 artifact (whichever ships `defer` first) MUST specify the continue-file schema (≥ `milestone_id`, `phase_id`, `gate_id`, `last_review_md_block_index`, `declared_policy`), its location under `.orchestrator/milestones/<M>/`, and the `orchestrator:resume` (M029) state-scan modification for the `pending-review` type. SC-4 is extended to the full defer→resume round-trip (re-entry at the recorded position), not just continue-file-written.
- **PC-6 (P2, blocks P03) — SC-6 MCP stub protocol (MIT-6, RISK-3)**: the P03 plan-phase artifact (which resolves #Q-5) MUST specify the stub `elicitation/create` JSON-RPC shape, the `accept`/`decline` injection mechanism, and the stub session lifecycle (following the #Q-5 lifecycle answer); the M009 `probe-harness/mcp-elicit-server.py` is the reference.

Accepted (tolerated) risks from the deliberation: RISK-7 (SC-1 re-run case underdetermined until #Q-1 — on the P00 critical path already), RISK-8 (block-term overload — mitigated by CON-8 + MIT-7 rename), RISK-9 (FR-13 normative/advisory wording — mitigated by the FR-13 edit). Full record: `conversus/summary/final.md` + `conversus/arbiter/resolution.md`.

### Knowledge-Layer Boundary (M034 vs. M038/M040 knowledge layer)

M034 **owns** the decision-packet artifact (`*-DECISIONS.md`), the `REVIEW.md` audit trail, and `SIGNOFF.md` population — all project artifacts under `.orchestrator/milestones/<M>/`. M034 **does not** write into the knowledge graph (`knowledge/**` chunks, `KNOWLEDGE-INDEX.md`, graph edges). Knowledge-graph integration of decisions — a `living-doc/section` node type binding packet entries to code anchors, or a decision-contradiction gate over `DECISIONS.md` writes — is delegated to **M038 (living documents)** and **M040 (ambient feedback loop)**. The decision-packet schema is designed to be a clean *input* to those (M038 §9.8 names `feedback/brief` a living-doc type; M040's contradiction gate emits a decision-packet-shaped record), but this milestone ships none of that integration.

## Assumptions

- The dogfooder's machine has `conversus-oss` installed and authed before exercising conversus-backed gates (the milestone surfaces a BLOCK + install pointer if not — FR-12).
- Claude Code's `AskUserQuestion` is available in the operator's interactive CC sessions (true at launch).
- Cursor Hooks/MCP elicitation v1.7+ is present (proven live in M009 Tier-A; `capabilities:{elicitation:{form:{}}}` declared by interactive Cursor, auto-decline in headless).
- The operator runs `orchestrator:resume` after an `auto`-mode `defer` to complete the walkthrough.
- M009 Tier-A is merged (cursor-agent dispatch backend, hooks, `.cursor/commands`/rules, the MCP-elicitation proof harness) — it is (PR #10, 2026-06-06).

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle II (Evidence Before Claims)**: directly operationalized. The packet's `concrete_impact` field and the walkthrough's impact framing ARE Principle II applied at the sign-off boundary — decisions arrive with evidence (which lakes pass/fail at threshold X), not bare assertions. conversus-as-producer strengthens this with adversarial deliberation evidence.
- **Principle III (Design Before Code)**: sign-off-gated artifact authoring is explicit Principle III territory; this milestone makes the gate substantively reviewable rather than a name-flip.
- **Principle IV (Plans Assume Zero Context)**: each packet entry is self-contained — picked value + rationale + alternatives + impact — enough for an operator with no surrounding context to make the call. Same standard as plan task-units.
- **Principle I (Context Minimization)**: the packet schema stays tight; impact tables are regenerated on demand by the walkthrough agent rather than embedded, bounding the payload.
- **Principle XVI (Distribution Surface Integrity)**: the new template (`decisions-packet.md`), scripts, and the Cursor MCP server ship through the packaging bundle + per-runtime installers; the MCP-server registration into `.cursor/mcp.json` follows the M009 non-clobbering install discipline.

## Open Questions (defer to planning)

- **#Q-1 (packet-supersede-semantics)**: How do packet entries version across re-runs of an artifact-authoring task — supersede-in-place vs append-with-supersede-chain (mirroring M036's supersede mechanism)? Resolve at P00 baseline against the lakeledger M066/P01 fixture. Answered by: plan-phase + P00.
- **#Q-2 (review-md-placement) [defaulted]**: `REVIEW.md` placement — decisions-co-located (`*-REVIEW.md`) chosen for v1 (mirrors SUMMARY/PLAN convention). Revisit if task-level vs phase-level friction surfaces. Logged per M034 brief recommendation.
- **#Q-3 (question-granularity) [defaulted]**: single-question-per-decision chosen for v1 (simpler capture) over grouped prompts. Revisit if walkthrough fatigue surfaces. Logged per M034 brief recommendation.
- **#Q-4 (cost-axis) [defaulted]**: a `decisions:` axis on the M027 efficiency footer is a P02 success-criterion add, not P01 scope. Logged per M034 brief recommendation.
- **#Q-5 (mcp-server-lifecycle)**: how is the orchestrator Cursor MCP server launched and process-managed (per-session spawn vs long-lived), and how does it authenticate to orchestrator state? The M009 probe harness (`probe-harness/mcp-elicit-server.py`) is the starting point. Answered by: P03 plan-phase.
- **#Q-6 (planner-heuristic-precision)**: the `boundary_translation` planner heuristic (SQL reads / migrations / ORM / format readers / protocol parsers) — explicit `touches_persistence: true` only, or also auto-detected? Recommendation: explicit flag for v1, heuristic as advisory. Answered by: P02/P03 plan-phase.
- **#Q-7 (milestone-identity) [resolved]**: this milestone IS M034 and absorbs M009 FR-6 (→ FR-10) + FR-8 (→ FR-15); M009 FR-7 (Cursor cost) remains the lone deferred Cursor item. Recorded in both briefs.

## Dependencies

- **M014** — review-queue convention + CON-5/SC-5 human-gated-apply invariant (`commands/comments.md`, `scripts/comments/`). Reuse convention, not code.
- **M025** — runtime adapters + `scripts/dispatch/dispatch-interface.sh` runtime-routing (the renderer-selection seam).
- **M018** — versioned-template-frontmatter pattern (`templates/compression-tier3-prompt.md`) for the packet schema.
- **M027** — cost surfaces (`efficiency-footer.sh`, `metrics-rollup.sh`) for the optional `decisions:` axis.
- **M030** — adaptive model routing for the (surgical-character) walkthrough agent.
- **M033 P04** — the ≤N-interactive / >N-hand-off threshold pattern.
- **conversus adapter (M011/P07)** + **conversus-OSS** — `scripts/dispatch/adapters/tool/conversus.sh gate`; OSS install/auth a runtime precondition for conversus-backed gates.
- **M009 Tier-A** — `cursor-agent` dispatch backend, `.cursor/hooks.json` + `.cursor/commands`/rules, and the MCP-elicitation proof harness (PR #10).
- **`SIGNOFF.md` primitive** — existing artifact, consumed not replaced.

## Downstream Consumers (informational, not binding)

- **M038 (living documents)** — decision-packet entries are candidate inputs to section-level code-anchor bindings; `feedback/brief` as a living-doc type composes with the packet schema.
- **M040 (ambient feedback loop)** — the decision-contradiction gate consumes `DECISIONS.md` writes; its FLAG/BLOCK records are decision-packet-shaped.
- **A future Codex CLI renderer** — the runtime-routing seam (FR-5/CON-7) admits a Codex question-primitive renderer without re-architecting the stage.
- **`orchestrator:doctor` / `status`** — consume the unreviewed-decision counts (FR-4).

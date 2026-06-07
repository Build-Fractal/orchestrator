---
schema_version: "1.0"
type: context-draft
milestone: "M034"
status: finalized
created_at: "2026-06-06"
finalized_at: "2026-06-06"
---

## Architectural Decisions

Consolidated from the spec (`specs/044-interactive-review-gates/spec.md`), the consolidation note (`.orchestrator/proposals/interactive-review-gates-consolidation.md`), the three clarify decisions, and the Pass-3 conversus deliberation (`specs/044-interactive-review-gates/conversus/`). These are settled; roadmap consumes them.

- **AD-1 — One schema, three renderers, one optional producer.** A single versioned decision-packet schema (`*-DECISIONS.md`) is the shared contract. The interactive walkthrough routes through `dispatch-interface.sh` to one of three renderers: Claude Code `AskUserQuestion`, a Cursor MCP `elicitation/create` server, or a headless `QUESTIONS.md` hand-off. Conversus is an *optional packet producer* (gate-result → packet entries), never a renderer.
- **AD-2 — FR-6 (Cursor MCP server) is M034's Cursor renderer, not an M009 silo.** The conversus deliberation confirmed this consolidation is "architecturally correct" — keeping it in M009 would create a sequencing dependency. M009 FR-6 (→ FR-10) and FR-8 (→ FR-15) fold into M034; M009 FR-7 (Cursor cost rate-card) stays deferred.
- **AD-3 — Two-layer dispatch model (load-bearing).** Bash (`dispatch-interface.sh`) selects the runtime context; the *agent executing in that context* issues the question primitive. The walkthrough never calls a question primitive directly. This is the resolution of the THREAT-1 "bash can't call AskUserQuestion" objection — the direction-of-control is correct because rendering is an agent-layer responsibility downstream of dispatch.
- **AD-4 — auto-mode default = `defer`.** Autonomous/headless runs at a gate pause (pending-review event + continue-file), exit cleanly, and resume via `orchestrator:resume`. `accept-with-audit` and `refuse-entry` are per-gate overrides. The decision artifact is ALWAYS written regardless of policy (CON-5/SC-5 always-write invariant).
- **AD-5 — Packet emission is opt-in per task** (`decision_packet: true`); absent the declaration, no packet. Preserves the "load-bearing decisions" framing and minimizes churn.
- **AD-6 — Conversus producer is opt-in and strict-when-declared.** A gate declaring `producer: conversus` with a missing/unauthed binary BLOCKS with an install pointer — it never silently SKIPs (closes the silent-review trap).
- **AD-7 — `block` → `refuse-entry` (CON-8).** The auto-mode policy enum is `refuse-entry`, lexically distinct from the conversus `BLOCK` verdict (operator-overridable content) and the packet `severity: block` field.

## Scope Boundaries

**In scope (4 phases, P00–P03):**

- **P00 — Empirical baseline + P0 pre-planning addendum.** Replay the lakeledger M066/P01 walkthrough as the canonical fixture; capture the decision-packet field-set. Resolve the two P0 conditions **before P01**: PC-1 (`write-decisions.sh` calling convention) and PC-2 (CC interactive-vs-headless execution context — inspect `scripts/dispatch/adapters/backend/cc.sh`). Resolve #Q-1 supersede semantics (RISK-7 is on this critical path).
- **P01 — Decision-packet schema + writer + conversus producer + surfacing** (US1, US5): `templates/decisions-packet.md`, `scripts/knowledge/write-decisions.sh`, conversus gate-result→packet mapping, `doctor`/`status` unreviewed-decision counts. Ships standalone audit value.
- **P02 — Interactive walkthrough + REVIEW.md + SIGNOFF + auto-mode policies + headless fallback + boundary-translation type** (US2, US3, US6): `scripts/lifecycle/interactive-review.sh`, CC `AskUserQuestion` renderer, `QUESTIONS.md` fallback, `defer`/`accept-with-audit`/`refuse-entry`. Resolves PC-3 (SC-3 simulation), PC-4 (headless detection), PC-5 (continue-file + `orchestrator:resume` surface).
- **P03 — Cursor MCP review-gate server + byte-parity audit** (US4, FR-15): orchestrator-owned stdio MCP server via `elicitation/create`, registered in `.cursor/mcp.json`; RUNTIME-ASSUMPTIONS rows. Resolves PC-6 (SC-6 stub protocol) + #Q-5 (server lifecycle).

**Out of scope:** replacing `SIGNOFF.md` (populated, not replaced) or `orchestrator:verify` (composes, runs after); a general AskUserQuestion harness (M033 owns); the spec-amendment review queue (M014 owns — convention reused, not code); the Cursor cost rate-card (M009 FR-7, deferred); blocking-by-default gates (opt-in only); knowledge-graph integration of decisions (M038/M040 territory — see knowledge-layer boundary below).

**Knowledge-layer boundary (M034 vs M038/M040):** M034 owns the decision-packet artifact, `REVIEW.md`, and `SIGNOFF.md` population — all project artifacts under `.orchestrator/milestones/<M>/`. M034 does NOT write `knowledge/**` chunks, graph edges, or a decision-contradiction gate; those are M038 (living-doc/section node + bindings) and M040 (contradiction gate over DECISIONS.md). The packet schema is designed as a clean *input* to both.

## Design Constraints

- **PC-1..PC-6 (binding pre-planning conditions, gate-derived).** P0: PC-1 calling convention + PC-2 CC execution context (both block P00→P01; PC-2 carries the RISK-5 escalation trigger — if no CC path surfaces `AskUserQuestion` interactively, US2/FR-6 must be amended before P01). P1: PC-3 SC-3 simulation, PC-4 headless detection, PC-5 continue-file/resume. P2: PC-6 MCP stub (gated by #Q-5). Full text in the spec's "Pre-Planning Conditions" section + `conversus/arbiter/resolution.md`.
- **CON-1 bash 3.2 single-file (AD-19)**; **CON-2 AP-009** (≤2-connector chains; `run-probe.sh` for longer); **CON-3 CON-5/SC-5 never-auto-applied**; **CON-4 named-constant thresholds SSOT**; **CON-6 MCP stdio non-clobbering** of operator `.cursor/mcp.json`; **CON-7 runtime-routing via `dispatch-interface.sh`**; **CON-8 block-term disambiguation**.
- **Conversus-OSS runtime dependency.** Conversus-backed gates require the OSS build on PATH / `~/Sites/conversus-oss`; `CONVERSUS_PROVIDER=claude-code` on OAuth (auto-detected). The dogfooder must `pipx install conversus-oss` + `conversus login` or conversus-backed gates BLOCK (PC-2/FR-12).
- **Dependencies:** M014 (review-queue convention + CON-5/SC-5), M025 (`dispatch-interface.sh` + runtime adapters), M018 (versioned-template-frontmatter), M027 (cost surfaces), M030 (walkthrough-agent routing), M033 P04 (≤N-interactive/>N-handoff threshold), conversus adapter (M011/P07) + conversus-OSS, M009 Tier-A (cursor-agent backend, hooks, MCP-elicitation proof harness — merged PR #10), `SIGNOFF.md` primitive.
- **Demand context:** a live Cursor dogfooder testing **both** interactive and headless, so the MCP renderer (P03) and the headless fallback (P02) are both load-bearing.

## Open Questions

These are plan-phase design questions (resolved by the planner at the named phase), not operator/SME questions. They were dispositioned `kept` through the M042 corpus-exhaustion gate during `orchestrator:specify` (PASS) and carry forward unchanged.

- **#Q-1 (packet-supersede-semantics)** — supersede-in-place vs append-with-supersede-chain (M036 prior art) for packet re-runs. Answered by: P00 plan-phase (on the PC-1 critical path).
- **#Q-5 (mcp-server-lifecycle)** — per-session spawn vs long-lived for the Cursor MCP server, and how it authenticates to orchestrator state. Answered by: P03 plan-phase (gates PC-6).
- **#Q-6 (boundary-translation-heuristic-precision)** — explicit `touches_persistence: true` only (v1 normative) vs auto-detection (advisory). Recommendation: explicit-only for v1, heuristic advisory (FR-13/MIT-8). Answered by: P02 plan-phase.

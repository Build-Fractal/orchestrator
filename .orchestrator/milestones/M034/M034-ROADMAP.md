---
schema_version: "1.0"
type: roadmap
milestone: "M034"
feature_ref: "044-interactive-review-gates"
feature_spec: "specs/044-interactive-review-gates/spec.md"
vision: "A first-class interactive review gate — one decision-packet schema, three runtime renderers, an optional conversus producer — that lets operators deliberate load-bearing decisions at sign-off instead of reverse-engineering them from a static artifact."
tier: "C"
created_at: "2026-06-06"
updated_at: "2026-06-06"
---

## Phases

- [x] **P00**: Empirical baseline + P0 pre-planning addendum — "Replaying the lakeledger M066/P01 walkthrough produces a captured decision-packet field-set, and the P0 addendum resolves the write-decisions.sh calling convention and the CC interactive-vs-headless execution context before any code is written." *(closed 2026-06-06: PC-1 stdin-JSON, PC-2 Case A / RISK-5 cleared, #Q-1 append-with-supersede-chain; verifier PASS)*
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `M034-P00-ADDENDUM.md` (PC-1 `write-decisions.sh` calling-convention spec — recommended stdin-JSON of the FR-1 entry array; PC-2 CC execution-context determination resolving Case A non-spawned vs Case B `claude -p`, citing `scripts/dispatch/adapters/backend/cc.sh`; #Q-1 supersede decision); captured-packet fixture from lakeledger M066/P01 (8-decision structure + walkthrough transcript)
    - Consumes: `specs/044-interactive-review-gates/spec.md` (FR-1 schema shape, PC-1/PC-2 acceptance criteria); `scripts/dispatch/adapters/backend/cc.sh` + `scripts/dispatch/dispatch-interface.sh` (read-only, for the PC-2 determination)
- [x] **P01**: Decision-packet schema + writer + conversus producer + surfacing — "A task declaring decision_packet: true emits a schema-valid *-DECISIONS.md (optionally enriched from a conversus gate-result), and status/doctor report the unreviewed-decision count." (US1, US5) *(closed 2026-06-06: templates/decisions-packet.md + CON-4 SSOT + write-decisions.sh (PC-1 stdin-JSON, #Q-1 supersede chain) + decisions-from-conversus.sh (FR-11/12 strict) + FR-4 status/doctor surfacing; PC-3/4/5 forward-specified in M034-P01-ADDENDUM.md for P02; phase-suite PASS 4/4 + addendum; check-must-haves all PASS)*
  - Risk: medium
  - Depends: P00
  - Boundary Map:
    - Produces: `templates/decisions-packet.md` (versioned schema, `severity: warn|block`, `type: decision|boundary_translation`, named-constant thresholds); `scripts/knowledge/write-decisions.sh` (bash 3.2, the PC-1 calling convention); conversus-producer mapping (gate-result.md verdict/disputes/rationale → packet entries; strict-when-declared per FR-12); `status`/`doctor` unreviewed-decision surfacing
    - Consumes: P00 `M034-P00-ADDENDUM.md` (calling convention + supersede decision); `scripts/dispatch/adapters/tool/conversus.sh` (existing `gate`/`parse-verdict`); `scripts/knowledge/write-summary.sh` (prior-art shape)
- [x] **P02**: Interactive walkthrough + REVIEW.md + SIGNOFF + auto-mode policies + headless fallback + boundary-translation type — "An operator is walked through the packet in Claude Code, responses land append-only in REVIEW.md and populate SIGNOFF.md; autonomous runs apply the declared policy (defer/accept-with-audit/refuse-entry) without deadlock." (US2, US3, US6) *(closed 2026-06-06: interactive-review.sh stage + CC AskUserQuestion renderer (FR-6 Case A) + templates/review.md+signoff.md + defer/accept-with-audit/refuse-entry policies + continue-file + orchestrator:resume pending-review-continue round-trip (PC-5) + headless QUESTIONS.md (FR-9) + boundary_translation type (FR-13); verifies SC-3/SC-4/SC-5/SC-8; phase-suite PASS 5/5 + FR-6 surface; check-must-haves all PASS)*
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/lifecycle/interactive-review.sh` (the `interactive_review` stage, routed via `dispatch-interface.sh`); `templates/review.md`; CC `AskUserQuestion` renderer; `REVIEW.md` append-only audit + `SIGNOFF.md` population; auto-mode policy handling (`defer`/`accept-with-audit`/`refuse-entry`); headless `QUESTIONS.md` hand-off + headless-detection mechanism (PC-4); continue-file schema + `orchestrator:resume` modification (PC-5); `boundary_translation` packet type (FR-13); SC-3 simulation harness (PC-3)
    - Consumes: P01 `templates/decisions-packet.md` + `write-decisions.sh` (the packet to surface); P00 PC-2 CC execution-context determination (so the renderer reaches the operator's terminal, not the headless fallback)
- [ ] **P03**: Cursor MCP review-gate server + RUNTIME-ASSUMPTIONS + byte-parity audit — "An interactive Cursor session renders a native elicitation form at a gate and captures the operator's accept; a headless cursor-agent run gets the deterministic decline mapped to the auto-mode policy." (US4, FR-14, FR-15; consolidates M009 FR-6 + FR-8)
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces: orchestrator-owned stdio MCP review-gate server (`elicitation/create`); `.cursor/mcp.json` registration in the Cursor install path (non-clobbering); SC-6 stub protocol (PC-6); `references/RUNTIME-ASSUMPTIONS.md` interactive-review primitive rows; byte-parity audit fixture under `ORCH_BACKEND=cursor` (FR-15)
    - Consumes: P02 `interactive-review.sh` stage + renderer-routing seam (the gate the server fronts); M009 Tier-A `probe-harness/mcp-elicit-server.py` (reference) + `.cursor/` install path; #Q-5 server-lifecycle resolution (decided in this phase)

## Cross-Cutting Concerns

- **Decision-packet schema (SSOT)** — P00 (field-set), P01 (establishes the versioned template + named-constant thresholds), P02, P03. P01 is the authority; P02/P03 consume the schema unchanged. Any schema change is a P01-owned versioned bump.
- **CON-5/SC-5 always-write invariant** — P02, P03. The decision artifact is written regardless of auto-mode policy or renderer; only operator-touch is gated. Every policy path (`defer`/`accept-with-audit`/`refuse-entry`) and the conversus `BLOCK`-as-content path must preserve this.
- **Runtime-routing via `dispatch-interface.sh` (CON-7)** — P02 establishes the renderer-selection seam (CC + headless); P03 adds the Cursor MCP renderer behind the same seam. No phase calls a question primitive directly.
- **conversus-OSS runtime dependency** — P01 (producer mapping + strict-when-declared). A declared `producer: conversus` with a missing binary BLOCKs (PC-2/FR-12); the dogfooder must install `conversus-oss` + auth. Not a per-phase build dep, but a runtime precondition surfaced at P01.
- **`block`→`refuse-entry` term disambiguation (CON-8)** — P01 (`severity: block` field), P02 (`refuse-entry` policy enum). Prompts/docs/tests use the precise term per context; never collapse the policy enum, the severity value, and the conversus `BLOCK` verdict into one token.
- **Knowledge-layer boundary (M034 vs M038/M040)** — all phases. M034 writes only project artifacts under `.orchestrator/milestones/<M>/` (packet, REVIEW.md, SIGNOFF.md). No phase writes `knowledge/**` chunks, graph edges, or a decision-contradiction gate — those are M038/M040.

## Dependency Graph

```
P00 ──▶ P01 ──▶ P02 ──▶ P03
(P0      (schema  (walk-   (Cursor
 addendum +writer  through  MCP +
 +baseline +producer +auto   parity)
           )       +fallback)
```

Strictly linear: each phase consumes the prior phase's primary deliverable. No concurrency.

## Execution Order

1. **P00** — foundation, no dependencies. Gates everything: the two P0 conditions (PC-1, PC-2) must be resolved before P01 begins. If the PC-2 inspection finds no CC path surfaces `AskUserQuestion` interactively, RISK-5 escalates to a standalone P0 blocker and the spec (US2/FR-6) is amended before P01.
2. **P01** — depends on P00 (calling convention + supersede decision). Ships standalone audit value (packet + surfacing) even before the walkthrough exists.
3. **P02** — depends on P01 (the schema/writer it surfaces) and P00 (the PC-2 determination that keeps the CC renderer interactive). The headline UX; resolves the three P1 conditions (PC-3/PC-4/PC-5).
4. **P03** — depends on P02 (the walkthrough stage the MCP server fronts). Resolves PC-6 + #Q-5. Last because the Cursor native renderer is only meaningful once the runtime-agnostic stage + CC renderer exist.

No phases run concurrently — the chain is fully sequential. This is intentional: the shared schema (P01) and the runtime-agnostic stage (P02) are load-bearing for everything downstream, and parallelizing would mean building renderers against an unstable schema.

## Validation

- **No conflicting producers**: PASS — each phase produces a disjoint artifact set (P00: addendum/fixture; P01: schema template + writer + producer mapping + surfacing; P02: review stage + renderers + REVIEW/SIGNOFF + policies + boundary-translation type; P03: MCP server + parity audit + RUNTIME-ASSUMPTIONS rows). No artifact is produced by two phases.
- **All consumed items have producers**: PASS — P01 consumes P00's addendum; P02 consumes P01's schema/writer + P00's PC-2 determination; P03 consumes P02's stage. External consumables (existing `conversus.sh`, `write-summary.sh`, `cc.sh`, `dispatch-interface.sh`, M009 Tier-A `.cursor/` install path + probe harness) are pre-existing on disk, not unresolved dependencies. #Q-5 is resolved within P03 itself (not consumed from an upstream phase).
- **DAG is acyclic**: PASS — linear chain P00→P01→P02→P03, no back-edges.
- **Demo sentence coverage**: PASS — each phase has a concrete, observable demo sentence tied to its user stories.

## Open Questions

No new operator-facing open questions are introduced by this roadmap. The three inherited plan-phase design questions (#Q-1 supersede → P00; #Q-5 MCP lifecycle → P03; #Q-6 heuristic precision → P02) were dispositioned `kept` through the M042 corpus-exhaustion gate at both the `specify` and `discuss` checkpoints (PASS) and are resolved at their named phases — not surfaced to an operator/SME — so the roadmap corpus-gate run is a no-op (no new questions to sweep).

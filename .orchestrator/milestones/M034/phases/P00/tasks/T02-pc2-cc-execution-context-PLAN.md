---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M034"
name: "Determine the CC renderer execution context (PC-2 / RISK-5)"
depends_on: ["T01"]
---

## Prerequisites

- `.orchestrator/milestones/M034/M034-P00-ADDENDUM.md` exists (created by T01). Confirm before appending.
- `scripts/dispatch/adapters/backend/local-agent.sh` exists — this is the REAL Claude Code dispatch backend (13 lines of probe + a coordination-boundary normal mode). NOTE: the conversus arbiter referred to it as `scripts/dispatch/adapters/backend/cc.sh`, which **does not exist** — that path was a confabulation; the actual CC backend filename is `local-agent.sh`. Confirmed on disk at plan-authoring time.
- `scripts/dispatch/dispatch-interface.sh` exists (45709 bytes). Confirmed on disk.

## Description

PC-2 (P0, RISK-5) is the load-bearing execution-context question: does the CC interactive-review renderer issue `AskUserQuestion` from an interactive context that reaches the operator's terminal, or from a headless subprocess where `AskUserQuestion` is unavailable (silently degrading US2 to the FR-9 headless fallback)? This task inspects the real dispatch path and records a binding determination plus the RISK-5 escalation decision.

**Plan-time signal (confirm during execution, do not assume):** `local-agent.sh`'s header documents (per MEM018) that "the Agent tool cannot be invoked directly from a shell script; it is an in-process capability of the orchestrating agent runtime" — the adapter is a *coordination boundary* that emits a dispatch-result whose Notes instruct the orchestrating agent layer to perform the Agent invocation in-process. It does **not** spawn `claude -p`. This strongly points to **Case A** for the `interactive_review` *stage* (FR-5 is a lifecycle stage, not a task-unit dispatch — it runs at the orchestration layer where `AskUserQuestion` is interactive). The executor must confirm this by reading the actual files, not inherit it as a given.

## Steps

1. Read `scripts/dispatch/adapters/backend/local-agent.sh` in full. Record: (a) does normal mode spawn any subprocess (`claude -p` or otherwise)?; (b) the MEM018 coordination-boundary semantics; (c) the probe contract.
2. Read `scripts/dispatch/dispatch-interface.sh` to confirm how the CC backend is selected and what the dispatch boundary actually invokes for the Claude Code runtime. Identify whether the `interactive_review` lifecycle stage would route through task-unit dispatch at all, or run at the orchestration layer.
3. Determine the case:
   - **Case A** — the `interactive_review` stage runs at the already-interactive top-level CC session (or issues `AskUserQuestion` directly from the orchestration layer, not a spawned subagent). `AskUserQuestion` is interactive. RISK-5 is CLEARED.
   - **Case B** — the renderer routes through a spawned subagent / `claude -p`. Then EITHER (i) demonstrate `AskUserQuestion` is interactive under the specific invocation args, OR (ii) specify a non-spawned invocation model and the FR-5/FR-6 amendment needed.
4. If neither Case A nor Case B(i)/B(ii) yields a viable interactive path: **escalate RISK-5 to a standalone P0 blocker** — record that US2 + FR-6 require a spec amendment BEFORE P01, and stop (do not mark P00 complete without surfacing the escalation to the operator).
5. Specify the `REVIEW.md` write path: does the agent issuing `AskUserQuestion` write `REVIEW.md` directly (under a named path contract), or return structured output that `interactive-review.sh` writes? State which.
6. Append a `## PC-2 — CC renderer execution context (RISK-5)` section to `M034-P00-ADDENDUM.md` recording the inspected files (with file:line), the case determination, the RISK-5 escalation decision (cleared / escalated), and the `REVIEW.md` write-path contract.

## Must-Haves

- The addendum's PC-2 section names the actual inspected backend (`local-agent.sh`), states Case A or Case B, and records the RISK-5 escalation decision — zero-context-complete for a P01 implementer (PC-2 acceptance criterion).

## Verification

`grep -q "PC-2" .orchestrator/milestones/M034/M034-P00-ADDENDUM.md`
`grep -q "local-agent.sh" .orchestrator/milestones/M034/M034-P00-ADDENDUM.md`
`grep -q "RISK-5" .orchestrator/milestones/M034/M034-P00-ADDENDUM.md`

## Notes

Expected: all three checks exit 0. The most likely outcome is Case A (RISK-5 cleared) given `local-agent.sh`'s in-process coordination-boundary design, but the executor MUST verify against the real files and record evidence (file:line) — a "should be Case A" without reading the backend is exactly the Principle II violation the conversus gate flagged. If the determination is Case B with no viable interactive path, this is a milestone-level escalation: surface it to the operator and do not proceed to P01.

## Inputs

### From Previous Tasks
- `.orchestrator/milestones/M034/M034-P00-ADDENDUM.md` (from T01)
  - Key API: an existing markdown file with frontmatter + a `## PC-1` section; T02 APPENDS a `## PC-2` section (does not rewrite).

### From Disk (Pre-existing)
- `scripts/dispatch/adapters/backend/local-agent.sh` — the CC dispatch backend; read to determine subprocess vs in-process behavior.
- `scripts/dispatch/dispatch-interface.sh` — the dispatch boundary; read to determine renderer routing.
- `specs/044-interactive-review-gates/spec.md` — FR-5/FR-6 (renderer), US2 (the interactive walkthrough at stake), and the PC-2 acceptance criteria + RISK-5 escalation trigger.

## Constraints

- Determination must cite real file:line evidence — no inherited assumptions.
- Append-only to the addendum; do not modify T01's PC-1 section.
- If RISK-5 escalates, STOP and surface to the operator (do not silently proceed).

## Expected Output

`M034-P00-ADDENDUM.md` gains a complete `## PC-2 — CC renderer execution context (RISK-5)` section with the inspected-file evidence, the Case A/B determination, the RISK-5 escalation decision, and the `REVIEW.md` write-path contract.

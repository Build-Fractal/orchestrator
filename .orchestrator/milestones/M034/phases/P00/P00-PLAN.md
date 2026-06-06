---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M034"
goal: "Resolve the two P0 pre-planning conditions (PC-1 calling convention, PC-2 CC execution context) and #Q-1 supersede semantics, and capture a representative decision-packet fixture — so P01 starts zero-context-complete."
demo_sentence: "M034-P00-ADDENDUM.md resolves PC-1, PC-2 (with the RISK-5 escalation determination), and #Q-1; a representative 8-decision packet fixture exists; and the phase verifier passes."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- The addendum specifies a concrete, zero-context `write-decisions.sh` calling convention (wire format + escaping contract) that a P01 implementer can build against without inventing an encoding (PC-1).
  - Check: `bash tools/verify/m034-p00-addendum.sh`
- The addendum records the CC renderer execution-context determination as Case A or Case B, names the actual inspected backend (`local-agent.sh`), and states the RISK-5 escalation decision (escalate-to-P0-blocker vs cleared) (PC-2).
  - Check: `bash tools/verify/m034-p00-addendum.sh`
- The addendum records a #Q-1 supersede-semantics decision (supersede-in-place vs append-with-supersede-chain) with rationale.
  - Check: `bash tools/verify/m034-p00-addendum.sh`
- A representative decision-packet fixture exists with the multi-field entry structure the P01 schema must support.
  - Check: `bash tools/verify/m034-p00-addendum.sh`

### Artifacts

- .orchestrator/milestones/M034/M034-P00-ADDENDUM.md (min 60 lines, contains "PC-1")
- .orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md (min 30 lines, contains "alternatives_considered")
- tools/verify/m034-p00-addendum.sh (min 20 lines, contains "PC-2")

### Key Links

- .orchestrator/milestones/M034/M034-P00-ADDENDUM.md → specs/044-interactive-review-gates/spec.md (the addendum cites the spec FRs/PCs it resolves)

## Tasks

### T01: Specify the write-decisions.sh calling convention (PC-1)

Inspect `scripts/knowledge/write-summary.sh`'s actual calling convention, then create `M034-P00-ADDENDUM.md` with a `## PC-1 — write-decisions.sh calling convention` section specifying the wire format (recommended: a stdin-fed JSON document carrying the full FR-1 decision-entry array, safe for newlines/shell metacharacters), the milestone-id/output-path argument encoding, and the multi-line-field escaping contract. Full zero-context plan: `tasks/T01-pc1-calling-convention-PLAN.md`.

### T02: Determine the CC renderer execution context (PC-2 / RISK-5)

Inspect `scripts/dispatch/adapters/backend/local-agent.sh` (the real CC backend — NOT `cc.sh`, which does not exist) and `scripts/dispatch/dispatch-interface.sh`. Determine Case A (the `interactive_review` stage runs at the top-level orchestration layer and issues `AskUserQuestion` directly) vs Case B (a spawned task-unit subagent). Record the RISK-5 escalation decision and the `REVIEW.md` write path. Append a `## PC-2 — CC renderer execution context` section to the addendum. Full zero-context plan: `tasks/T02-pc2-cc-execution-context-PLAN.md`.

### T03: Decide #Q-1 supersede semantics + capture fixture + author the verifier

Append a `## #Q-1 — packet supersede semantics` section to the addendum (decision + rationale); create the representative `fixtures/decisions-packet-baseline.md` (8-entry structure, representative-of-lakeledger-M066/P01 since that repo is external); author `tools/verify/m034-p00-addendum.sh` (the phase verifier that checks the addendum + fixture completeness). Full zero-context plan: `tasks/T03-supersede-fixture-verifier-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03
```

Linear: T01 creates the addendum (PC-1 section); T02 appends the PC-2 section; T03 appends #Q-1, creates the fixture, and authors the verifier that checks the whole addendum. Sequential because all three write to the same `M034-P00-ADDENDUM.md` and the T03 verifier asserts all sections present.

## Files Likely Touched

- .orchestrator/milestones/M034/M034-P00-ADDENDUM.md (create)
- .orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md (create)
- tools/verify/m034-p00-addendum.sh (create)

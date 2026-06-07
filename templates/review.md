---
schema_version: "1.0"
type: review-log
milestone: "M###"
phase: "P##"
gate_id: "<gate name from review_gates[]>"
packet: "<path to the *-DECISIONS.md this log adjudicates>"
---

<!--
  REVIEW.md SCHEMA (M034 FR-7). Append-only audit trail. One block per
  operator response per gate visit, in packet order. Written by the
  orchestrating agent (interactive-cc path, Case A) or by
  interactive-review.sh (test-responses / auto / headless paths).

  Block fields:
    id            The decision id this block adjudicates (matches a
                  *-DECISIONS.md `## <id>` block).
    action        Enum DECISIONS_ACTION_VALUES (accept|override|pushback|na).
    reviewed_at   ISO timestamp.
    rationale     Present for override|pushback|na (operator's reason).
    override_value Present for override only (the new picked_value, verbatim).
  Each block ENDS with `reviewed: <id>` — the reviewed-marker line
  read-decisions.sh::_is_reviewed matches. `defer` writes NO block (the
  decision stays pending until orchestrator:resume completes it).
-->

# Review Log — <gate_id>

## <id> — review block 1
- **id**: D-1
- **action**: accept
- **reviewed_at**: <iso>
reviewed: D-1

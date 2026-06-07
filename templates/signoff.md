---
schema_version: "1.0"
type: signoff
milestone: "M###"
phase: "P##"
gate_id: "<gate name from review_gates[]>"
approved_by: null
review_md: "<path to the sibling *-REVIEW.md>"
terminal_review_block: 0
signed_at: null
---

<!--
  SIGNOFF.md (M034 FR-7). Populated from REVIEW.md's terminal entry by
  scripts/lifecycle/interactive-review.sh. `approved_by` is flipped from
  null to the reviewer label (operator name, or "auto-accept" for the
  accept-with-audit policy). `terminal_review_block` is the count of
  REVIEW.md blocks written when sign-off occurred. This feature POPULATES
  SIGNOFF.md; it does not replace the sign-off primitive (non-goal).
-->

# Sign-off — <gate_id>

Populated from REVIEW.md terminal entry (block <terminal_review_block>).

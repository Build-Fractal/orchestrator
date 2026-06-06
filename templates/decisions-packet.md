---
schema_version: "1.0"
type: decision-packet
milestone: "M###"
source: "<task-id or producer label>"
artifact: "<path to the primary artifact this packet accompanies>"
---

<!--
  DECISION-PACKET SCHEMA (M034 FR-1). This template is the versioned
  schema definition AND the canonical example. Emitted by
  scripts/knowledge/write-decisions.sh. Every enum/default/threshold is
  owned by scripts/knowledge/lib/decisions-constants.sh (CON-4 SSOT) —
  the values shown here are illustrative; the SSOT is authoritative.

  Per-entry fields:
    REQUIRED (the eight FR-1 fields):
      id                      Stable entry id, e.g. D-1.
      summary                 One-line decision title.
      picked_value            The value/option chosen.
      rationale               Why this value (free text, multi-line ok).
      alternatives_considered Options weighed + why rejected (free text).
      concrete_impact         What breaks / who depends on this (Principle II).
      severity                Enum DECISIONS_SEVERITY_VALUES (warn|block);
                              default DECISIONS_SEVERITY_DEFAULT (block).
      type                    Enum DECISIONS_TYPE_VALUES
                              (decision|boundary_translation);
                              default DECISIONS_TYPE_DEFAULT (decision).
    OPTIONAL (writer-added, supersede chain — #Q-1):
      content_hash            Hash over the field bodies; idempotency key.
      supersedes              Prior entry id this one replaces (re-emit only).
      superseded_by           Set on the prior entry when superseded.

  Active view = entries WITHOUT a superseded_by marker. Superseded
  entries remain in the file for audit (Principle VI) and are excluded
  from the FR-4 unreviewed-decision count.
-->

# Decision Packet — <artifact label>

## D-1
- **id**: D-1
- **summary**: <one-line decision title>
- **picked_value**: <chosen value>
- **rationale**: <why this value>
- **alternatives_considered**: <options weighed and why rejected>
- **concrete_impact**: <what breaks / who depends on this>
- **severity**: block
- **type**: decision
- **content_hash**: <writer-computed; omit in hand-authored packets>

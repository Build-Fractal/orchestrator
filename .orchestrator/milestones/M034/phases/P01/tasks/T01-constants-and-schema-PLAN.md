---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M034"
name: "Named-constants SSOT + versioned schema template"
depends_on: []
---

## Prerequisites

- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` exists (the P00 SC-1 schema-coverage fixture — 8 entries, one `severity: warn` = D-5, one `type: boundary_translation` = D-7). Confirmed on disk at plan-authoring time.
- `scripts/knowledge/lib/` exists (home for the constants SSOT). Confirmed on disk.
- `templates/` exists (home for the schema template). Confirmed on disk.

## Description

FR-1 requires a versioned schema template `templates/decisions-packet.md` defining the decision-packet schema, and CON-4 requires every enum/threshold/severity boundary to be a NAMED CONSTANT in exactly one place. This task authors both: the SSOT shell file and the template, plus the schema-shape slice verifier.

The schema MUST accept the P00 baseline fixture (`fixtures/decisions-packet-baseline.md`) **unchanged** — that fixture is the SC-1 coverage standard. The baseline entries carry the eight FR-1 fields (`id`, `summary`, `picked_value`, `rationale`, `alternatives_considered`, `concrete_impact`, `severity`, `type`) but NOT the supersede-chain fields (`content_hash`, `supersedes`, `superseded_by`) — those are writer-added and therefore OPTIONAL in the schema. The validator treats the eight FR-1 fields as required and the three supersede fields as optional.

## Steps

1. Create `scripts/knowledge/lib/decisions-constants.sh` with EXACTLY this content:

```bash
#!/usr/bin/env bash
# scripts/knowledge/lib/decisions-constants.sh — M034 P01 (CON-4 SSOT).
#
# Single source of truth for every decision-packet enum, default, and
# threshold. Sourced by write-decisions.sh, read-decisions.sh,
# decisions-from-conversus.sh, check-decisions.sh, and the M034 P01
# verifiers. No top-level execution — defines variables + helper
# validators only. Bash 3.2 / POSIX-sh (CON-1 / AD-19).
#
# FR-1: "Any weight/threshold/severity boundary appears as a NAMED
# CONSTANT in exactly one place that prompts/docs/tests reference."
# This file IS that place. Do not redeclare these values anywhere else.

# Schema version stamped into every emitted *-DECISIONS.md frontmatter.
DECISIONS_SCHEMA_VERSION="1.0"

# severity in {warn, block}; default block (FR-1).
DECISIONS_SEVERITY_VALUES="warn block"
DECISIONS_SEVERITY_DEFAULT="block"

# type in {decision, boundary_translation}; default decision (FR-1).
DECISIONS_TYPE_VALUES="decision boundary_translation"
DECISIONS_TYPE_DEFAULT="decision"

# FR-4: when the count of active, unreviewed, warn-severity decision
# entries reaches this threshold, `doctor` raises an advisory health
# finding ("recurring unreviewed warn-severity entries"). v1 semantics
# are count-based (not time-series); see M034-P01-ADDENDUM.md.
DECISIONS_WARN_FINDING_THRESHOLD="3"

# Validator: print "ok" if $1 is a member of the severity enum, else "".
decisions_is_valid_severity() {
  case " $DECISIONS_SEVERITY_VALUES " in
    *" $1 "*) printf 'ok' ;;
    *) printf '' ;;
  esac
}

# Validator: print "ok" if $1 is a member of the type enum, else "".
decisions_is_valid_type() {
  case " $DECISIONS_TYPE_VALUES " in
    *" $1 "*) printf 'ok' ;;
    *) printf '' ;;
  esac
}
```

2. Create `templates/decisions-packet.md` — the versioned schema template. It MUST: (a) carry YAML frontmatter with `schema_version: "1.0"`, `type: decision-packet`, and placeholder `milestone`/`source`/`artifact` keys; (b) carry an HTML-comment schema-doc block enumerating each field, its enum/default (referencing the SSOT constant names, NOT re-stating the literal values as authority), and which fields are required vs optional; (c) carry ONE worked example entry (`## D-1`) showing every field including the supersede-chain fields with explanatory inline notes. Use this content:

```markdown
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
```

3. Create `tools/verify/m034-p01-schema-shape.sh` — the schema-shape slice verifier. It MUST: (a) assert `templates/decisions-packet.md` exists, has `schema_version`, the `type: decision-packet` frontmatter, and the schema-doc comment naming all eight required fields; (b) assert `scripts/knowledge/lib/decisions-constants.sh` exists and defines `DECISIONS_SEVERITY_DEFAULT`, `DECISIONS_TYPE_DEFAULT`, and `DECISIONS_WARN_FINDING_THRESHOLD`; (c) validate the P00 baseline fixture against the schema — for each `## D-N` block in `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md`, assert the eight required `- **<field>**:` lines are present. Print `PASS: m034-p01 schema-shape` on success, `FAIL: <file>:<reason>` + exit 1 on any miss. Single bash file, no compound-chain shapes (CON-2). Use grep/test only; iterate fixture blocks with a `for`/`while` loop INSIDE the script body (the AD-19 shape rules constrain `Check:` command lines in plans, not the internal logic of a verifier script).

## Must-Haves

- `templates/decisions-packet.md` exists, is versioned, documents the eight required fields + the three optional supersede fields, and references the SSOT constants by name (FR-1, CON-4).
- `scripts/knowledge/lib/decisions-constants.sh` defines the severity enum + default, type enum + default, and the FR-4 warn-finding threshold (CON-4 SSOT).
- The P00 baseline fixture validates against the schema unchanged (SC-1 coverage standard).

## Verification

`bash tools/verify/m034-p01-schema-shape.sh`
`test -f scripts/knowledge/lib/decisions-constants.sh`
`grep -q "DECISIONS_SEVERITY_DEFAULT" scripts/knowledge/lib/decisions-constants.sh`
`grep -q "schema_version" templates/decisions-packet.md`

## Notes

Expected: `bash tools/verify/m034-p01-schema-shape.sh` prints `PASS: m034-p01 schema-shape` and exits 0; the three `test`/`grep` commands exit 0. The slice verifier is co-authored in this task (plan-time discipline rule 2 — no cross-task verifier dependency). The phase-suite aggregator (T05) will call this verifier.

The SSOT is sourced (not re-stated) by every downstream consumer: T02's writer reads `DECISIONS_SEVERITY_DEFAULT`/`DECISIONS_TYPE_DEFAULT` for its defaults; T04's reader/check read `DECISIONS_WARN_FINDING_THRESHOLD`. Do not hard-code `block`/`decision`/`3` anywhere else.

## Inputs

### From Disk (Pre-existing)
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` — the 8-entry SC-1 coverage fixture; each entry is a `## D-N` block with `- **field**: value` bullet lines for all eight FR-1 fields. D-5 has `severity: warn`; D-7 has `type: boundary_translation`. Your schema + verifier must accept this shape unchanged.
- `scripts/knowledge/lib/extract-supersede.sh` — M036 supersede-chain prior art (reference for the supersede field semantics; do not modify).

## Constraints

- Bash 3.2 / POSIX-sh, single file each (CON-1 / AD-19): no `declare -A`, no `${var,,}`, no process substitution.
- CON-4: the SSOT is the ONLY place the enums/defaults/threshold are defined. The template references constant NAMES; it does not become a second authority.
- Do NOT author `write-decisions.sh` (T02), the reader (T04), or the producer (T03).

## Expected Output

Three files created: `scripts/knowledge/lib/decisions-constants.sh`, `templates/decisions-packet.md`, `tools/verify/m034-p01-schema-shape.sh`. The schema-shape verifier passes against the template + the P00 baseline fixture.

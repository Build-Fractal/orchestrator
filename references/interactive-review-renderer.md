# Interactive Review Renderer (FR-6, Case A)

The agent-facing instruction surface for the **interactive-cc** walkthrough of an
`interactive_review` gate. When `scripts/lifecycle/interactive-review.sh` resolves
`renderer=interactive-cc` it does NOT call any question primitive from bash
(CON-7 / AD-3). Instead it emits a `type: "interactive-review-descriptor"`
render-descriptor on stdout and exits 0 — a coordination boundary mirroring
`scripts/dispatch/adapters/backend/local-agent.sh`. The orchestrating agent (the
already-interactive top-level Claude Code session, **Case A** per
`M034-P00-ADDENDUM.md` §PC-2) reads that descriptor and performs the walkthrough
**in-process**.

## When this runs

- `interactive-review.sh` was invoked WITHOUT `--test-responses` and WITHOUT
  `--resume`, AND `dispatch-interface.sh --probe-renderer` resolved
  `renderer=interactive-cc` (or `interactive-cursor`, the P03 sibling).
- The script emitted a render-descriptor carrying `gate_id`, `packet`,
  `review_out`, and `signoff_out`, then exited 0.
- Because there is no `claude -p` in the CC dispatch path, the orchestrating
  agent layer that control returns to IS the interactive session — it has
  `AskUserQuestion` available as a live tool and reaches the operator's terminal
  directly. The agent, not bash, drives the walkthrough.

## How to walk through the packet

1. Resolve the active (non-superseded) decisions in packet order:
   `bash scripts/knowledge/read-decisions.sh active-ids <packet>`.
2. For EACH active id, read its `## <id>` block from the `*-DECISIONS.md` packet
   and surface it to the operator via **`AskUserQuestion`** with concrete-impact
   framing drawn from the entry's fields:
   - `summary` — the one-line decision statement (question header).
   - `picked_value` — what the authoring stage chose.
   - `concrete_impact` — what changes downstream if this stands (lead with this).
   - `alternatives_considered` — the options to offer as override targets.
3. Offer the operator these responses on an ordinary decision:
   - **accept** — the picked_value stands.
   - **override** — supply a replacement value (record it verbatim).
   - **pushback** — reject with a rationale (no value change; flags for re-author).
4. For a `type: boundary_translation` entry (the FR-13 bridge-confirmation
   shape), offer instead:
   - **confirm-the-bridge** — the operator affirms the boundary translation is
     correct (recorded with `gate_kind: confirm-the-bridge`).
   - **mark N/A** — the operator declares the bridge not applicable here
     (`action: na`, recorded with `acknowledged_not_applicable: true`); the
     decision still counts reviewed.

## How to record

The AGENT writes `REVIEW.md` DIRECTLY on this path — `interactive-review.sh` does
NOT write it under the interactive-cc renderer (Case A). Append one block per
operator response, in packet order, in the `templates/review.md` shape:

- A frontmatter header (`type: review-log`, `milestone`, `phase`, `gate_id`,
  `packet`) written once iff the file is absent — append-only thereafter.
- One `## <id> — review block <n>` block per response carrying `- **id**`,
  `- **action**`, `- **reviewed_at**` (ISO), `- **rationale**` (for
  override/pushback/na), `- **override_value**` (override only), and the
  `confirm-the-bridge` / `acknowledged_not_applicable` lines for the
  boundary_translation cases.
- Each block ENDS with the literal marker line `reviewed: <id>` — the line
  `read-decisions.sh` matches to count a decision reviewed.

After the terminal response, populate the sibling `SIGNOFF.md` from the terminal
REVIEW.md entry (mirror `_populate_signoff` in `interactive-review.sh`:
`type: signoff`, `approved_by`, `review_md`, `terminal_review_block`,
`signed_at`). The gate is satisfied only once SIGNOFF.md is on disk (CON-5/SC-5 —
the stage NEVER silently skips).

## boundary_translation heuristic (advisory, #Q-6)

v1 emits `boundary_translation` packet entries ONLY when an authoring stage sets
an explicit `touches_persistence: true` on the source change. The planner-side
heuristic (SQL reads / migrations / ORM mappings / format readers / protocol
parsers) is **advisory documentation only — it does NOT auto-fire**. Do not
synthesize boundary_translation gates from the heuristic during the walkthrough;
surface only the entries the packet already carries.

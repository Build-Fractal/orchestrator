---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M044"
goal: "Close the capture→inject loop at the default (Quick) intensity: an explicitly-captured decision always runs the append-decision.sh row-append even at Quick, and the Quick-profile inject carries a bounded, budget-bounded Decisions digest — so a Quick project never ships an empty-forever Decisions slot."
demo_sentence: "On a fresh Quick-intensity fixture, an explicitly-captured decision lands in DECISIONS.md, is indexed by rebuild-index.sh, and is present in the next build-context.sh inject — which now carries a bounded, budget-bounded Decisions digest at the Quick profile."
risk: "high"
depends_on: ["P01", "P02"]
---

## Must-Haves

### Truths

- `intensity-knowledge.sh` runs `append-decision.sh` for an explicitly-supplied decision at ANY intensity — including Quick — without changing the no-explicit-decision auto-pipeline step counts (Quick auto = write-summary only). (FR-8/G-1 / SC-8)
  - Check: `bash tools/verify/m044-p04-t01-capture-at-quick.sh`
- The Quick-profile inject includes a bounded, budget-bounded Decisions digest (the `## Decisions` section is no longer omitted at Quick); the digest routes its read-into-payload through the M036a token governor (CON-2) and is deterministic (CON-3). (FR-6 / SC-8)
  - Check: `bash tools/verify/m044-p04-t02-decisions-digest.sh`
- Capture-by-default round-trip: on a Quick fixture, an explicitly-captured decision lands in `DECISIONS.md`, is indexed by `rebuild-index.sh`, and appears in the next Quick inject's Decisions digest. (SC-8 / SC-9, composes SC-1)
  - Check: `bash tools/verify/m044-p04-t03-capture-roundtrip.sh`

### Artifacts

- `tools/verify/m044-p04-t01-capture-at-quick.sh` (create — min 30 lines)
- `tools/verify/m044-p04-t02-decisions-digest.sh` (create — min 30 lines)
- `tools/verify/m044-p04-t03-capture-roundtrip.sh` (create — min 30 lines)
- `tools/verify/m044-p04-phase-suite.sh` (create — aggregator)
- `.orchestrator/milestones/M044/phases/P04/P04-SUMMARY.md` (create at phase close — min 20 lines)

### Key Links

- `scripts/knowledge/intensity-knowledge.sh` → `scripts/knowledge/append-decision.sh` (the gate runs the legacy decision-capture primitive — DQ-7 no net-new verb — even at Quick for an explicit decision)
- `scripts/dispatch/build-context.sh` → `scripts/dispatch/lib/reference-budget.sh` (the Decisions digest read routes through the M036a token governor — CON-2)

## Tasks

### T01: FR-8/G-1 explicit-decision capture at Quick

Add an explicit-decision path to `scripts/knowledge/intensity-knowledge.sh`: a
repeatable `--decision-arg <value>` flag accumulates the positional arguments for
`append-decision.sh` (`<decisions-file> <when> <scope> <decision> <choice> <rationale>
[revisable]`). When ≥1 `--decision-arg` is present, `append-decision.sh` runs at ANY
intensity (including Quick) with exactly those args — independent of the
intensity-gated auto steps (which still forward `$FORWARD_ARGS` and keep their
per-level membership). In `--dry-run`, emit a `WOULD_RUN: <append-decision.sh> …`
line for the explicit decision. No net-new capture verb (DQ-7) — the legacy
primitive is the mechanism. Co-author `tools/verify/m044-p04-t01-capture-at-quick.sh`.
See `tasks/T01-capture-at-quick-PLAN.md`.

### T02: FR-6 bounded budget-bounded Decisions digest at Quick

In `scripts/dispatch/build-context.sh` direct-mode (Quick) payload assembly, drop the
`if [ "$PROFILE" != "quick" ]` omission and emit a bounded Decisions digest under
`## Decisions`. Add a `_bc_decisions_digest <decisions_file> <budget_tokens> <max_rows>`
helper that reads the system-of-record `.orchestrator/DECISIONS.md`, ranks rows
newest-first, and routes them through `reference_apply_budget` (CON-2 — no silent
over-inject); deterministic (file order is the rank, no wall-clock — CON-3). Ships in
the same phase as T01 so a Quick project never carries an empty-forever Decisions
slot. Co-author `tools/verify/m044-p04-t02-decisions-digest.sh`. See
`tasks/T02-decisions-digest-PLAN.md`.

### T03: Capture-by-default round-trip fixture + phase suite (SC-8/SC-9)

Build the round-trip oracle: a `mktemp -d` Quick fixture → capture an explicit
decision via `intensity-knowledge.sh --intensity Quick --decision-arg …` → assert
the row in `.orchestrator/DECISIONS.md` (consumer-order, from P02) →
`rebuild-index.sh` (no-op-safe) → `build-context.sh --profile=quick` → assert the
captured decision appears in the inject's `## Decisions` digest. Build
`tools/verify/m044-p04-phase-suite.sh` (copy P01's aggregator, retarget `m044-p04-*`).
See `tasks/T03-capture-roundtrip-PLAN.md`.

## Task Dependencies

```
T01 ─┐
     ├─► T03
T02 ─┘
```

- T01 (explicit capture) and T02 (digest) touch disjoint files; build in either order.
- T03 composes both: capture (T01) → DECISIONS.md → digest (T02) → inject.

## Files Likely Touched

- `scripts/knowledge/intensity-knowledge.sh` (modify — explicit `--decision-arg` path)
- `scripts/dispatch/build-context.sh` (modify — FR-6 Decisions digest at Quick + `_bc_decisions_digest` helper)
- `tools/verify/m044-p04-t01-capture-at-quick.sh` (create)
- `tools/verify/m044-p04-t02-decisions-digest.sh` (create)
- `tools/verify/m044-p04-t03-capture-roundtrip.sh` (create)
- `tools/verify/m044-p04-phase-suite.sh` (create)

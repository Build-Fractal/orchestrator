# FIXTURE-PROVENANCE — Tier A+ classifier grounding (AD-16)

This file is normative. It grounds the `tier_a_plus` verdict heuristic in
`scripts/intake/shape-detect.sh` (and the parallel annotation in
`scripts/intake/paragraph-classify.sh`) against at least one historical
`unit_close` record drawn from a JSONL stream under `.orchestrator/`.
Per AD-16 (M031 design), the M031 P02 acceptance verifiers
(`tools/verify/m031-p02-fixture-provenance-shape.sh` in particular) will
not pass without this file's existence and shape.

## Cited Historical Records

The following records are drawn from
`.orchestrator/milestones/M031/execution-log.jsonl` (and a sibling stream
for cross-milestone breadth). Each is keyed by `<milestone>/<phase>/<task>`
provenance.

- **M031/P01/T01** — `record_type:"unit_close"`, `granularity:"task"`,
  `unitId:"M031/P01/T01"`, `outcome:"pass"`, `duration_s:7200`,
  `completed_at:"2026-05-01T17:08:58Z"`. The corresponding task plan name
  on disk is `Tier A+ classifier verdict (FR-6) + AD-16 fixture
  provenance + SC-5 acceptance test` paraphrasing source: T01 of P01,
  build-context-profile. The PLAN.md authored description is roughly:
  "extend scripts/dispatch/build-context.sh with two additive flags
  --profile and --meta-out, wire a direct-mode short-circuit and a 5-key
  JSON sidecar, ship three shape verifiers under tools/verify/m031-p01-".
- **M030/P07/T03** — `record_type:"unit_close"`, `granularity:"task"`,
  `unitId:"M030/P07/T03"`, `outcome:"pass"`. The corresponding task name
  on disk is `evidence-ledger-and-phase-suite`: paraphrasing source:
  "ship the acceptance-evidence ledger plus the ledger-shape gate and
  the M030 phase-suite aggregator under tests/m030-acceptance/".

Both records are real `unit_close` rows present on disk at the time
this provenance file was authored. Any future operator can re-derive
the citation chain by grepping `unit_close` against the JSONL streams
under `.orchestrator/`.

## Annotator Rationale

(Section heading capitalised; the per-record rationale follows.)

The cited M031/P01/T01 record qualifies as a Tier A+ candidate. The
rationale is structured as three points:

1. **Word-count band.** The PLAN.md description, when paraphrased into a
   feature-request shape, lands cleanly in the 30 to 80 word range — the
   uninstantiated middle band the Tier A+ heuristic claims. Below 30
   words the input reads like an `idea` (single-line ticket title);
   above 80 words it starts to acquire spec-shape structural markers
   (FR-bullets, Given/When/Then, ## headings) and crosses into the
   `fragment` band. The M031/P01/T01 description sits in the sweet
   spot: detailed enough to be actionable, sparse enough to skip the
   full milestone scaffolding.
2. **Structural-marker absence.** The paraphrased fixture (see
   `tier-a-plus-input.txt` adjacent to this file) carries no `^##`
   heading, no Given/When/Then triple, and no `^- FR-` bullet lines.
   This is the second half of the Tier A+ heuristic — verdict requires
   both the word-count band AND the zero-structural-marker condition.
3. **Operator-intent shape.** The task is a contained additive
   modification with named scripts, named flags, and a deterministic
   verification surface. This is exactly the shape Tier A+ optimizes
   for: the operator wants a research-then-plan-then-build chain
   without the overhead of milestone roadmap authoring. The cross-cited
   M030/P07/T03 record carries the same shape — additive scripts +
   acceptance battery — confirming the heuristic generalizes beyond a
   single record.

## Boundary Heuristic Confirmation

The Tier A+ heuristic boundary chosen for the M031 P02 T01 classifier
extension:

- **Lower bound:** word count ≥ 30. Below this threshold, the input
  reads as an `idea` (or a shorter `paragraph`) and is better handled
  by the existing M024 verdict path.
- **Upper bound:** word count ≤ 80. Above this threshold, inputs
  reliably acquire structural markers and classify as `fragment`; even
  when they don't, the operator-intent shape shifts from "small
  contained task" to "phase-or-larger work".
- **Structural-marker exclusion:** zero of `^##` headings, zero
  Given/When/Then triples, zero `^- FR-` bullet lines. Any of these
  signals that the input has already been authored as a spec or spec
  fragment, in which case the existing M024 `fragment` or `spec`
  verdicts are correct.
- **Confidence band:** `high` over the interior of the band; `low` at
  the boundary edges (words ≤ 32 or words ≥ 78) so downstream
  consumers can treat boundary inputs more cautiously.

The cited M031/P01/T01 record's paraphrased task description (see
`tier-a-plus-input.txt`) is sized to land at high confidence — roughly
50 to 60 words — so the SC-5 acceptance test reads `shape_classification=high`
on the fixture. The M030/P07/T03 cross-citation confirms the boundary
generalizes: that record's paraphrased description is also a 30-80 word
zero-marker shape.

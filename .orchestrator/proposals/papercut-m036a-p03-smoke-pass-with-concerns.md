---
schema_version: "1.0"
type: papercut-proposal
id: "papercut-m036a-p03-smoke-pass-with-concerns"
captured_at: "2026-05-07"
captured_from: ".orchestrator/milestones/M036/M036-ACCEPTANCE-EVIDENCE.md (caveat C1)"
related_milestone: "M036 (M036b post-launch slice)"
priority: "before-pilot if achievable; else operator-runbook addendum before 2026-05-15"
---

# Paper-cut — M036a P03: PASS verdict promotes artifact unchanged despite advisory corrections

## What I observed

The 2026-05-07 live-LLM smoke produced verdict **PASS** with
`surviving_disputes=0`. Per the smoke brief, the promote-or-retain
logic fired correctly:

```
extract_tier_2_promote_or_retain 0 ... → mv tmp.structured.md final.structured.md
```

The promoted artifact is byte-identical to the in-session extraction
(diff is empty). The deliberation's `summary/final.md` proposes 7
substantive P1/P2 corrections grounded in source-text line numbers:

- **P1** form-equivalence revert across §3 / §4 / §5 (extractor used
  `### Term` headings where source uses `- **Term**:` bullets)
- **P1** drop extractor-added descriptive subtitles in §4
  ("90-day Operational Record floor" etc. — not in source)
- **P1** frontmatter `category: "regulatory"` → `"internal-policy"`
  (source self-describes as "Internal — Reference Material")
- **P2** R-3 `applies_to_field` add `operational_records` (compound
  scope)
- **P2** R-4 `applies_to_field` add `audit_records` (R-5 inheritance)
- **P2** Erasure term add `applies_to_field` (currently absent)
- **P2** `derived_from` add `EC-RUNBOOK-IR-001` (R-1 SHALL rationale)

These survive into the promoted chunk. The knowledge-graph chunk store
will carry them forward into every downstream query, citation edge,
and reference traversal until a corrective extraction lands.

## Why it matters

The current gate semantics are binary: PASS → promote-as-is; BLOCK →
retain only. There is no intermediate verdict for "PASS but with
advisory corrections."

For the 2026-05-15 PBJ pilot, this means:

1. Operators reading the promoted chunk via knowledge-graph queries
   will see the under-corrected version unless they also read the
   gate-result.md → conversus-deliberation/summary/final.md →
   arbiter/resolution.md chain. Three indirections.
2. The validator-pilot feedback will mix two failure classes that
   should be distinguished: "the gate caught nothing" (true gate
   miss) vs. "the gate caught it but didn't apply the fix" (gate
   semantics misalignment). The current shape leaks (2) into (1).
3. Operators who do read gate-result.md will see the verdict
   `PASS` and may stop reading there, missing the synthesizer's
   17-recommendation P1/P2/P3 list buried in `summary/final.md`.

## Possible shapes

Three options, in declining invasiveness:

**A. PASS-with-concerns intermediate verdict** (gate-semantics change,
post-launch). Add a third verdict `PASS_WITH_CONCERNS` triggered when
`surviving_disputes=0` BUT `synthesis.actionable_spec_changes.P1.length > 0`.
On `PASS_WITH_CONCERNS`: promote the artifact AND surface the P1 list
into a `<cite_id>.concerns.md` audit file alongside the promoted chunk;
chunk frontmatter gains `tier_2_concerns: <count>` for graph-query
filtering. Big change; lands as M036b/P09 (operator-facing scale UX).

**B. Synthesizer-output extraction** (mechanical change, before-pilot
achievable). Extend `extract_tier_2_promote_or_retain` to also copy
`summary/final.md` → `<log_dir>/<cite_id>.advisories.md` on PASS,
and write `tier_2_advisories: <path>` into the chunk frontmatter.
Operators get one indirection to advisories instead of three. No
verdict-shape change; preserves CON-3 closure. ~30 LOC change in the
gate helper. Reversible.

**C. Operator-runbook addendum only** (no code change, ship today).
Update `tests/fixtures/m036-live-llm-smoke/README.md` and the M036b
operator runbook to call out: "PASS does not mean the extraction is
complete; always read `gate-result.md` + `summary/final.md` before
treating the promoted chunk as authoritative." Cheapest fix; relies on
operator discipline.

## Recommendation

**B for before-pilot, A as M036b post-launch slot, C as the absolute
floor if B can't make 2026-05-15.**

B is achievable today: add ~30 LOC to
`scripts/knowledge/lib/extract-tier-2-gate.sh:extract_tier_2_promote_or_retain`
to copy synthesis advisories into the log dir on PASS. Frontmatter
gains one optional field. The smoke harness needs no change. The
acceptance battery needs an additional shape verifier. Reversible if
calibration shows advisory-routing creates noise.

A is the right long-term shape but couples to graph-query work that
M036b/P09 already owns. Defer.

C is operator discipline; should ship regardless of A/B because the
README is currently misleading on this point.

## Effort estimate

- **A**: 1–2 days (verdict shape + helper + graph filter + tests).
  Land in M036b/P09.
- **B**: ~2 hours (helper + verifier + EVIDENCE update). Land
  before-pilot if approved.
- **C**: ~30 minutes (README + runbook diff). Land regardless.

## Decision required from operator

1. Is C alone sufficient before 2026-05-15? If yes, ship C, defer
   A+B to M036b.
2. If B is preferred, is the chunk-frontmatter
   `tier_2_advisories:` field acceptable as the operator-discoverable
   surface, or should it route into the graph schema as a new node
   type? (Frontmatter is faster; graph-node is more queryable.)
3. Is there appetite for the A verdict-shape change in M036b/P09, or
   should advisories stay as audit-trail only?

## References

- Evidence:
  `.orchestrator/milestones/M036/M036-ACCEPTANCE-EVIDENCE.md` § "Issues Surfaced — C1"
- Today's deliberation:
  `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/conversus-deliberation/summary/final.md`
- Gate helper: `scripts/knowledge/lib/extract-tier-2-gate.sh:54-81`
  (the `extract_tier_2_promote_or_retain` function — the natural home
  for shape B)

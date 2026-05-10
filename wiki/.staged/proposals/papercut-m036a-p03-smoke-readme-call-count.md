---
schema_version: "1.0"
type: papercut-proposal
id: "papercut-m036a-p03-smoke-readme-call-count"
captured_at: "2026-05-07"
captured_from: ".orchestrator/milestones/M036/M036-ACCEPTANCE-EVIDENCE.md (caveat C2)"
related_milestone: "M036 (M036a documentation hygiene)"
priority: "before-pilot — operators planning around the README budget will under-estimate"
---

# Paper-cut — M036a P03: README under-counts conversus deliberation calls by ~3.3×

## What I observed

`tests/fixtures/m036-live-llm-smoke/README.md` lines 91–93:

> **Cost.** Each run consumes real LLM tokens through conversus. The
> tier-2-fidelity preset deliberates with two agents + an arbiter, so
> expect ~3 model calls per run. Skip if budget-constrained.

The 2026-05-07 smoke run completed 6 phases with **10** model calls,
all `claude-sonnet-4-20250514`:

| Phase         | Calls | Wall (cumulative) |
|---------------|-------|-------------------|
| review        | 2     | ~2 min            |
| cross-review  | 2     | ~5 min            |
| revision      | 2     | ~7 min            |
| disputes      | 2     | ~12 min           |
| synthesis     | 1     | ~18 min           |
| arbitration   | 1     | ~21 min           |
| **Total**     | **10**| **~21 min**       |

The README's "two agents + an arbiter, ~3 model calls" framing
matches a one-shot evaluator-with-arbitration shape, not the
6-phase cooperative-deliberation shape that `tier-2-fidelity.yml`
actually configures.

## Why it matters

For the 2026-05-15 PBJ pilot:

1. Operators planning a budget around "~3 calls × $X each" will
   under-estimate by ~3.3×. If the cohort runs 10 fixtures, the
   under-estimate compounds.
2. Operators who run a smoke and watch it sit at "phase: review"
   for 2 minutes may assume something hung when in fact it's
   working as designed.
3. The README's wall-clock claim ("~6 min on direct anthropic")
   is also stale relative to the 6-phase shape — actual today
   was 21 min on `claude-code` provider (the README does say
   claude-code is "~3-4× slower"; 6 min × 3.5 = 21 min, so that
   estimate is internally consistent if you read carefully, but
   the headline "3 calls" claim is wrong).

## Possible shapes

**A. Update README cost section to reflect 6-phase shape** (5 minute
diff). Replace the "two agents + an arbiter, ~3 model calls"
framing with the actual phase table above. Add an "expect ~21
minutes wall-clock on `claude-code` provider" note.

**B. Same as A, plus add a `--dry-run` flag** to the smoke harness
that emits the expected call count + estimated wall-clock without
spending tokens. Higher effort, more durable.

## Recommendation

**A.** No code change. Diff the README, ship before pilot. B is nice
but the dry-run logic would itself need to model conversus internals
that may shift between conversus releases — fragile.

## Effort estimate

- **A**: ~10 minutes (README edit + acceptance-evidence link refresh).
- **B**: ~3 hours (harness flag + conversus-shape introspection +
  test). Defer.

## Decision required from operator

None — A is purely-additive documentation hygiene. Ship as part of
the M036a-paper-cuts cleanup before 2026-05-15.

## References

- Evidence:
  [`.orchestrator/milestones/M036/M036-ACCEPTANCE-EVIDENCE.md`](../milestones/M036/M036-ACCEPTANCE-EVIDENCE.md) § "Issues Surfaced — C2"
- Smoke log timestamps:
  `/tmp/m036-live-smoke-2026-05-07.log` (lines 12:44:52..13:05:59)
- README to amend:
  `tests/fixtures/m036-live-llm-smoke/README.md:88-104`
- Conversus preset: `templates/conversus-presets/tier-2-fidelity.yml`
  (the actual phase shape lives here)

---
schema_version: "1.0"
type: papercut-proposal
id: "papercut-m036a-p03-smoke-hardcoded-model"
captured_at: "2026-05-07"
captured_from: ".orchestrator/milestones/M036/M036-ACCEPTANCE-EVIDENCE.md (caveat C3)"
related_milestone: "M036 (M036a observability hygiene)"
priority: "before-pilot — observability mis-attribution leaks into M019 unit_close stream"
---

# Paper-cut — M036a P03: hardcoded `model: claude-opus-4-7` in `unit_close` mis-attributes deliberation authorship

## What I observed

The 2026-05-07 smoke harness emitted this `unit_close` JSONL:

```json
{"event":"unit_close","task_type":"extraction","cite_id":"live-smoke-policy-01","model":"claude-opus-4-7","tokens_in":1296,"tokens_out":1317,"cost_usd":0.0,"quality_score":0.95,"timestamp":"2026-05-07T17:06:00Z","source":"runtime"}
```

The `model: "claude-opus-4-7"` is the orchestrating Claude Code
session's model (the one performing the in-session extraction step).
But the conversus deliberation — which is what consumes the bulk of
the tokens — ran on **`claude-sonnet-4-20250514`** for all 10 calls.
The unit_close field misattributes the work.

The hardcoding lives at
`tests/m036-acceptance/live-llm-smoke/run-smoke.sh:134`:

```bash
MODEL="${SMOKE_MODEL:-claude-opus-4-7}"     # this session's model by default
```

The default is the orchestrating session's model, not the deliberation
provider's model. There is no path that reads back the actual model
conversus used ([M030](../milestones/M030/index.md) routing decides at deliberation time; the
selection isn't surfaced back to the harness).

**Self-evidence**: the deliberation itself flagged this exact issue.
Fidelity-advocate Recommendation FA-6 in today's `summary/final.md`
(P3 list, item 6):

> Verify `extracted_by` field matches actual model used. Per
> CLAUDE.md, this is the first real-LLM run of the M036a live-smoke-
> test pipeline; if the model identity was hardcoded rather than
> programmatically injected, the field may silently misattribute
> authorship, undermining the extraction audit trail.

The gate caught it. The harness emits it anyway.

## Why it matters

For the 2026-05-15 PBJ pilot:

1. The [M019](../milestones/M019/index.md) Tier 1 JSONL stream is the cost-rollup oracle for
   `orchestrator:cost`. Mis-attributed `model:` fields will
   under-count Sonnet usage and over-count Opus usage in cost
   retros. Cost-spike triage will look at the wrong model.
2. The reference-corpus chunk frontmatter `extracted_by:` field
   carries the same mis-attribution into the knowledge graph. Any
   downstream query of the form "which chunks were authored by
   model X?" returns wrong answers.
3. M030 adaptive-model-selection observability depends on
   knowing which model actually ran — for the shadow-corpus
   threshold check, for the FR-9 programmatic flip-gate, for the
   per-task-type accuracy histograms. Hardcoded values poison the
   shadow corpus.

## Possible shapes

**A. Surface conversus's selected model back to the harness**
(correct fix; medium effort). The conversus run already records
the model per-agent in the deliberation transcripts. Add a
`conversus.sh parse-model <run-output-dir>` subcommand (parallels
the existing `parse-verdict <gate-result-path>` shape) that emits
`model=<id>` from the deliberation metadata. Wire the harness to
read it after the gate completes and pass it into
`extract_tier_2_emit_unit_close`.

**B. Two-model unit_close** (same data, less coupling). Emit
`extraction_model:` (the in-session session's model — Opus) AND
`gate_model:` (the deliberation provider's model — Sonnet). The
unit_close shape gains one field; the M019 cost rollup gains
finer-grained attribution. Future-proofs against the reality that
extraction and gate may use different models permanently.

**C. Read the model from `arbiter/resolution.md` frontmatter**
(narrowest fix). The arbiter's resolution.md may already record
the model — if so, parse it. If not, this collapses into A.

## Recommendation

**B** is the right long-term shape — extraction and gate are
genuinely different surfaces that may route to different models
under M030. But B requires a unit_close schema extension that
would benefit from one cycle through the M030 acceptance-battery
to confirm no consumers break.

**A** is the right before-pilot shape — minimum surface-area
change, fixes the misattribution today. ~1 hour effort. Land before
2026-05-15.

## Decision (2026-05-07)

**Adopted: variant of A — "conversus-deliberation" Floor.**

When `parse-model` was prototyped against the 2026-05-07 baseline
artifacts, the paper-cut's premise turned out to be wrong: conversus
does **not** record the model per-agent in deliberation transcripts.
Verified via grep across `regression-2026-05-07/conversus-deliberation/`
(review.md, cross-reviews/, revision.md, disputes.md, arbiter/resolution.md,
summary/final.md, conversus.yml — none carry a `model:` field). The
`claude_code` provider's `DEFAULT_MODEL = "sonnet"` alias
(`engine/execution/providers/claude_code.py:55`) is consumed by
`claude -p --model sonnet` but never serialized. `modelUsage` data
exists on the result envelope (lines 266-274) but is not persisted.

Without on-disk model metadata, A as proposed (parse-model subcommand
parallel to parse-verdict) would either need to (1) hardcode the
default alias resolution — same failure class as today, just a
different misattributed string — or (2) capture conversus stdout
during the run and grep the model from progress lines (fragile,
requires a ~21min smoke to verify).

The Floor avoids the false-precision trap: `model: "conversus-deliberation"`
is structurally accurate at the right granularity (the unit *is* the
deliberation, not a single model call). When upstream conversus
surfaces per-call metadata, the harness can pivot to per-call
attribution and historical records remain interpretable.

**Land shape (~10 min, shipped 2026-05-07):**

- `tests/m036-acceptance/live-llm-smoke/run-smoke.sh:134` — strip the
  hardcoded `claude-opus-4-7` default. Emit
  `model: "conversus-deliberation"`. `SMOKE_MODEL=<id>` still wins
  (operator escape hatch).
- `tests/fixtures/m036-live-llm-smoke/README.md` — add a Model
  attribution operator note pointing at this paper-cut.

**Deferred (M036b or upstream conversus):**

- B (two-model unit_close `extraction_model:` + `gate_model:`) — depends
  on an upstream conversus change emitting per-call model metadata.
  Without that upstream surface, B can't fill `gate_model:` honestly
  either. Re-open when conversus ships metadata persistence.

## Effort estimate

- **A**: ~1 hour (`conversus.sh parse-model` + harness wiring +
  one shape verifier).
- **B**: ~3 hours (schema extension + M019 consumer audit +
  acceptance-battery extension + migration of historical records
  if any).
- **C**: ~30 minutes if arbiter records model; otherwise
  collapses into A.

## Decision required from operator

1. Is A acceptable before-pilot, with B deferred to M036b
   observability hygiene? Recommend yes.
2. If B is preferred, should the schema extension land as M036b
   P09 (operator-facing scale UX) or M030 follow-up
   (cost-attribution accuracy)? They overlap.

## References

- Evidence:
  [`.orchestrator/milestones/M036/M036-ACCEPTANCE-EVIDENCE.md`](../milestones/M036/M036-ACCEPTANCE-EVIDENCE.md) § "Issues Surfaced — C3"
- Hardcoded site:
  `tests/m036-acceptance/live-llm-smoke/run-smoke.sh:134`
- Self-evidence in deliberation:
  `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/conversus-deliberation/summary/final.md`
  ("Actionable Spec Changes — P2 — Should implement — item 6")
- M030 SSOT: `templates/model-routing.yml`
- Conversus adapter: `scripts/dispatch/adapters/tool/conversus.sh`
  (host for the proposed `parse-model` subcommand)

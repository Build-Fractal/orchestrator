---
schema_version: "1.0"
type: acceptance-evidence
milestone: "M036"
generated_at: "2026-05-07T17:10:00Z"
scope: "M036a P03 live-LLM pre-pilot smoke (operational follow-up; not a phase verdict)"
verdict: "YELLOW"
verdict_summary: "Pipeline works end-to-end. Three operator-facing caveats worth resolving before 2026-05-15 pilot."
git_sha: "b772a242"
---

# M036 — Acceptance Evidence Ledger

This document captures the M036a P03 live-LLM pre-pilot smoke evidence
called out in CLAUDE.md as the one outstanding pre-launch follow-up
("M036a P03 live-LLM smoke test before 2026-05-08"). It mirrors the
M032 `M032-ACCEPTANCE-EVIDENCE.md` shape and serves as the deferred-
validation audit trail for the otherwise-closed M036a milestone.

M036a was closed 2026-05-02 with full P00–P07 cross-phase regression
green and CI exercising the Tier 2 path through stubs only
(`EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block` and `CONVERSUS_STUB=1`
per CON-3). The smoke documented here is the first end-to-end run
through real LLMs against a representative fixture.

## Smoke-Test Invocation

Exact commands at run time:

```bash
git rev-parse --short HEAD     # b772a242
CONVERSUS_PROVIDER=claude-code \
  bash tests/m036-acceptance/live-llm-smoke/run-smoke.sh
```

The orchestrating session reused the prior in-session extraction at
`tests/fixtures/m036-live-llm-smoke/extracted-structured.md` (extraction
step is a Phase 1 surface; Phase 2 — the conversus fidelity gate — is
the architecturally fragile part the smoke is designed to exercise).
The harness writes a fresh capture dir under
`tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/`.

## Fixture

| Field            | Value                                                   |
|------------------|---------------------------------------------------------|
| Path             | `tests/fixtures/m036-live-llm-smoke/policy-data-retention.md` |
| Size             | 3,584 bytes (~70 lines markdown)                        |
| Source           | Synthetic (EXAMPLE-CORP data-retention policy)          |
| sha256           | `336534b02275d2dc0e0ba9df2f421dfd5a9f5ab36162e21c014bf9c6b751dfbf` |
| In-session extraction | 5,268 bytes (yesterday's, sha256 implicit via gate's `source_hash`) |
| Gate `source_hash` | `de019c380a6045d4f5e8cf60f8c5d113c17fc112123a34e7b5c5a41af6352c16` |

The fixture exercises every M036a graph primitive — definitions →
`spec/term`; numbered requirements (R-1..R-5) → `spec/requirement`;
exceptions (E-1, E-2) → `spec/constraint`; references → `cites`
edges; `applies_to_field` hooks across `operational_records`,
`audit_records`, `personal_data`. See
`tests/fixtures/m036-live-llm-smoke/README.md` for the full rationale.

## Per-Tier Output Samples

Captured artifacts (relative to repo root):

| Artifact                         | Path                                                                                          |
|----------------------------------|-----------------------------------------------------------------------------------------------|
| In-session structured extraction | `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/extracted-structured.md`            |
| Gate verdict file                | `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/gate-result.md`                     |
| Promoted chunk (PASS only)       | `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/promoted-structured.md`             |
| Pass log                         | `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/live-smoke-policy-01.pass.md`       |
| `unit_close` JSONL               | `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/execution-log.jsonl`                |
| Full deliberation transcripts    | `tests/fixtures/m036-live-llm-smoke/regression-2026-05-07/conversus-deliberation/`            |

The deliberation tree contains per-agent `review.md`, `cross-reviews/`,
`revision.md`, `disputes.md` for both `extractor-advocate` and
`fidelity-advocate`, plus `summary/final.md`,
`arbiter/resolution.md`, and the resolved `conversus.yml` config —
forensics-complete.

Tier 0 (manifest + binary preservation) and Tier 1 (deterministic
plain-text adapters for PDF/DOCX/XLSX/MD) are not exercised by this
smoke; the source is markdown and the extraction is in-session.
P05/P06/P07 cross-phase regression spreads exercise those tiers
through stubs at CI time.

## Cost + Duration

| Metric                | Value                                                          |
|-----------------------|----------------------------------------------------------------|
| Wall-clock duration   | ~21 minutes (12:44:52 → 13:05:59 local)                        |
| Conversus phases      | 6 (review, cross-review, revision, disputes, synthesis, arbitration) |
| Total LLM calls       | 10 (2×review + 2×cross-review + 2×revision + 2×disputes + 1×synthesis + 1×arbitration) |
| Model used (deliberation) | `claude-sonnet-4-20250514` for all 10 calls                |
| Provider              | `claude-code` (OAuth subscription per project memory)         |
| `tokens_in` (extraction-record approximation)  | 1,296                                |
| `tokens_out` (extraction-record approximation) | 1,317                                |
| `cost_usd`            | 0.0 (subscription-absorbed; harness lacks subscription-token introspection) |
| Quality score (PASS)  | 0.95 (harness-assigned per verdict)                            |

The unit_close emit:

```json
{"event":"unit_close","task_type":"extraction","cite_id":"live-smoke-policy-01","model":"claude-opus-4-7","tokens_in":1296,"tokens_out":1317,"cost_usd":0.0,"quality_score":0.95,"timestamp":"2026-05-07T17:06:00Z","source":"runtime"}
```

(Note: `model: "claude-opus-4-7"` is hardcoded in the harness — see
caveat C3 below. The actual deliberation ran on Sonnet 4.)

## Verdict

**Verdict: PASS** — `surviving_disputes=0` after Phase 4 (disputes).

```
verdict: "PASS"
disputes: 0
rationale: "verdict=PASS derived from surviving_disputes=0 in cooperative deliberation"
preset: "tier-2-fidelity"
```

Synthesizer headline: "Revert §3 Definitions to bold-bullet-list form."

Verdict variance is expected: yesterday's run on the same input
produced **BLOCK** (3 surviving disputes). The README warns
explicitly — "PASS/BLOCK is non-deterministic; rely on artifacts being
well-formed and verdict being explainable, not on a specific verdict."
Both runs satisfy that criterion.

## Fidelity Assessment (Hand Review)

I read the deliberation `summary/final.md` end-to-end. The deliberation
caught real, substantive extraction-quality issues — not noise:

**P1 (would-be-blocking under stricter calibration; advisory under current):**

1. §3 Definitions, §4 Retention Requirements, §5 Exceptions all use
   `### [Term]` / `### R-N: [Title]` / `### E-N` heading promotions
   where the source is flat bold-bullet-list. The form-equivalence
   invariant is violated.
2. §4 has extractor-added descriptive subtitles
   ("90-day Operational Record floor," "7-year Audit Record floor,"
   etc.) with no source counterpart. Adds content not in source.
3. Frontmatter `category: "regulatory"` misclassifies the document —
   source self-describes as "Internal — Reference Material" (L4).

**P2:**

4. R-3 `applies_to_field: personal_data` should be
   `[operational_records, personal_data]` (compound scope).
5. R-4 `applies_to_field: operational_records` should also include
   `audit_records` via R-5's explicit "inherits R-2" inheritance chain.
6. Erasure term carries `[type: spec/term]` with no `applies_to_field`
   — should be `[operational_records, audit_records, personal_data]`.
7. `derived_from` missing EC-RUNBOOK-IR-001 (cited as R-1 SHALL
   rationale authority).

**P3 (deferred pending schema authorization):**

8. Inline `[source: EC-*]` markers in §4 prose — proposed but the
   arbiter ruled (citing Constitution Principle XI / XIII / XIV) that
   schema must define the inline annotation grammar before applying.

**Fidelity-gate calibration assessment:** the gate is calibrated to
"did the advocates converge?" not "is the extraction perfect?" — both
verdicts (yesterday's BLOCK, today's PASS) are explainable from the
deliberation evidence. Today's PASS reflects that all 17 surviving P1+P2
recommendations achieved bilateral or unanimous convergence in Phase 3,
and the 2 remaining Phase 4 disputes were resolved by the synthesizer +
arbiter. Yesterday's BLOCK reflects 3 disputes that didn't converge.
Same input → different verdict is intrinsic to the deliberation
algorithm.

**Hallucination signals:** None detected. The deliberation grounded
every recommendation in source-text line numbers (verifiable). The
extractor-advocate and fidelity-advocate independently flagged the
same gaps from different charter angles in several cases (Erasure
`applies_to_field`, R-4 inheritance) — strong epistemic signal.

## Issues Surfaced

### C1 (caveat — operator-facing): PASS verdict promotes artifact unchanged despite 17 advisory corrections

The gate's promote-or-retain logic is binary: PASS → `mv tmp.structured.md
final.structured.md` as-is; BLOCK → retain only `block.md`. There is no
"PASS-with-concerns" middle path. Today's run produced PASS but the
deliberation proposed 7 P1/P2 corrections that would meaningfully
improve fidelity (form-equivalence revert, frontmatter `category` fix,
3 `applies_to_field` fixes, `derived_from` fix). Operators consuming
the promoted chunk via standard knowledge-graph queries will not see
these advisories unless they read `gate-result.md` →
`conversus-deliberation/summary/final.md` first.

**Diff confirmation:**
```bash
diff regression-2026-05-07/extracted-structured.md \
     regression-2026-05-07/promoted-structured.md
# (empty diff — promoted == extracted)
```

Paper-cut filed: `.orchestrator/proposals/papercut-m036a-p03-smoke-pass-with-concerns.md`

### C2 (caveat — documentation drift): README cost expectation 3× under-counts actual call count

`tests/fixtures/m036-live-llm-smoke/README.md` line 91-93 states:
> "The tier-2-fidelity preset deliberates with two agents + an arbiter,
>  so expect ~3 model calls per run."

Actual: **10 calls** (review×2 + cross-review×2 + revision×2 +
disputes×2 + synthesis×1 + arbiter×1). Operators planning around the
README's "3 calls" budget will under-estimate by ~3.3×. Wall-clock and
cost surprise both flow from this.

Paper-cut filed: `.orchestrator/proposals/papercut-m036a-p03-smoke-readme-call-count.md`

### C3 (caveat — observability accuracy): hardcoded `model: claude-opus-4-7` in `unit_close` despite deliberation running on Sonnet 4

The harness emits `model: "claude-opus-4-7"` (the orchestrating session's
model), but the deliberation ran on `claude-sonnet-4-20250514` for all
10 calls. Fidelity-advocate Recommendation FA-6 in today's deliberation
flagged this exact issue: "Verify `extracted_by` field matches actual
model used... if the model identity was hardcoded rather than
programmatically injected, the field may silently misattribute
authorship, undermining the extraction audit trail." Same root cause.

The hardcoding lives at `tests/m036-acceptance/live-llm-smoke/run-smoke.sh:134`
(`MODEL="${SMOKE_MODEL:-claude-opus-4-7}"`).

Paper-cut filed: `.orchestrator/proposals/papercut-m036a-p03-smoke-hardcoded-model.md`

### C4 (informational — yesterday's run only): 2026-05-06 deliberation transcripts unrecoverable

Yesterday's `regression-2026-05-06/` directory has no
`conversus-deliberation/` subdir even though the harness for-loop tries
to copy `extractor-advocate fidelity-advocate summary arbiter`
subdirectories from `$WS`. Today's run captured all four. The most
likely explanation: yesterday's BLOCK verdict came from a deliberation
that exited at a phase before all four subdirs existed (or from a
`conversus run` invocation that wrote to a non-`$WS` path). Today's
PASS run shows the harness code path is correct in steady state.

Not raised as a paper-cut (capture worked today; yesterday is
unrecoverable; no clear corrective without root-cause data).

## Verdict — overall: **YELLOW**

The pipeline is pilot-ready: all six conversus phases ran, both
advocates engaged substantively with grounded source citations, the
gate produced a defensible verdict, the promote-or-retain logic
fired, the unit_close JSONL emitted, the deliberation transcripts
were captured for forensics, and the wall-clock + cost stayed inside
the 60–90 minute / $2 budget set by the smoke brief.

Three caveats remain before the 2026-05-15 PBJ pilot:

- **C1** (highest impact): operator guidance or gate semantics for
  PASS-with-advisory-corrections (paper-cut filed).
- **C2**: README cost expectation off by ~3.3× (paper-cut filed).
- **C3**: hardcoded model identity in unit_close (paper-cut filed).

If C1 is addressed before pilot (either by operator-runbook update or
by a PASS-with-concerns intermediate verdict), this becomes GREEN.
The smoke does not surface any RED-class issue (no panic, no empty
output, no false-PASS or false-BLOCK calibration error, no harness
abort).

## Pre-pilot follow-ups shipped (2026-05-07)

Operational follow-ups landed against the M036a deferred-validation
banner per `launch-sequencing-amendment-2026-05-03.md` Q-1 (M036a P03
live-LLM smoke before 2026-05-08). M036a remains closed; these are
not phase verdicts.

- **C2** — `tests/fixtures/m036-live-llm-smoke/README.md` Operator
  notes block now reflects the actual 6-phase / 10-call shape with
  the per-phase wall-clock table from this baseline. Replaces the
  prior "two agents + an arbiter, ~3 model calls" framing that
  under-counted by ~3.3×. See `papercut-m036a-p03-smoke-readme-call-count.md`.
- **C3 Floor** — `run-smoke.sh:134` strips the hardcoded
  `claude-opus-4-7` default; `unit_close` now emits
  `model: "conversus-deliberation"` (the unit IS the deliberation, not
  a single model call). `SMOKE_MODEL=<id>` remains as the operator
  escape hatch. Paper-cut Decision section records that the original
  parse-model proposal premise was wrong (conversus does not persist
  per-call model metadata to deliberation transcripts; verified via
  grep across `regression-2026-05-07/conversus-deliberation/`).
  See `papercut-m036a-p03-smoke-hardcoded-model.md`.
- **C1 (C+B)** — both shipped. C: README operator-notes bullet
  warning that PASS does not mean the extraction is complete; always
  read both `gate-result.md` AND `summary/final.md`. B:
  `extract_tier_2_promote_or_retain` now copies
  `<conversus_output_dir>/summary/final.md` to
  `<log_dir>/<cite_id>.advisories.md` on PASS via the new
  `_t2g_copy_advisories` helper, and `extract-reference.sh` exposes
  the file via `tier_2_advisories: "<cite_id>.advisories.md"` in
  chunk frontmatter. Operators reach the synthesis via single
  indirection (chunk → advisories.md) instead of three (chunk →
  gate-result → summary → arbiter). Stub mode silently no-ops
  (no `conversus_output_dir` in fixture frontmatter). Verifier:
  `tools/verify/m036-p03-tier-2-pass-advisories-shape.sh` (3 shape
  checks + 2 behavioral checks; all green; existing P03 phase-suite
  14/14 still green). The `PASS_WITH_CONCERNS` verdict shape (option
  A in the paper-cut) is deferred to M036b/P09 alongside the
  graph-projection work that owns chunk-frontmatter
  `tier_2_concerns:` queryability. See
  `papercut-m036a-p03-smoke-pass-with-concerns.md`.

With all three caveats addressed, the smoke verdict moves toward
GREEN for the 2026-05-15 PBJ pilot. The remaining post-pilot
follow-up is upstream conversus surfacing per-call model metadata,
at which point C3 can flip from the literal Floor to per-call
attribution.

## Reproducibility

To replay today's smoke from a fresh checkout at git SHA `b772a242`:

```bash
git checkout b772a242
ls tests/fixtures/m036-live-llm-smoke/policy-data-retention.md \
   tests/fixtures/m036-live-llm-smoke/extracted-structured.md   # both must exist

CONVERSUS_PROVIDER=claude-code \
  bash tests/m036-acceptance/live-llm-smoke/run-smoke.sh

# verdict will vary (PASS|BLOCK) — README documents this
ls tests/fixtures/m036-live-llm-smoke/regression-$(date -u +%Y-%m-%d)/
```

Today's `regression-2026-05-07/` directory is checked in as the
canonical PASS-leg baseline. Yesterday's `regression-2026-05-06/` is
the canonical BLOCK-leg baseline (deliberation transcripts missing —
see C4).

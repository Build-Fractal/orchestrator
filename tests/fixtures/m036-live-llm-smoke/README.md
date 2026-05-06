# M036a P03 Live-LLM Smoke Fixture

A synthetic data-retention policy used to exercise the Tier 2 LLM
extraction → conversus fidelity gate pipeline against **real LLM
calls** (no stubs). Lives outside CI; operator-only.

## Purpose

Two things this fixture buys the project:

1. **Pre-pilot smoke insurance.** Occasional manual runs against real
   LLMs confirm the production conversus fidelity gate (a two-agent
   deliberation under M030 routing) still produces a meaningful PASS /
   BLOCK verdict against real input. Deliberation-shaped LLM code is
   the architecturally fragile part of M036a; mocked tests can pass
   while the live path silently breaks.
2. **Reference artifacts.** The captured extraction + gate-result +
   promoted-chunk + execution-log JSONL become regression baselines
   for future shell-to-LLM bridge work (the production live: branch
   in `scripts/knowledge/lib/extract-tier-2-llm.sh` is currently
   unimplemented under CON-3).

## Why this fixture shape?

The reference-corpus pipeline targets **regulatory / training /
glossary** materials. The existing in-tree fixture
(`tests/fixtures/m036-p03-tier-2/sample.md`) is PBJ-staffing-flavored
glossary content, deliberately kept minimal for CI determinism. The
live-smoke fixture lives outside CI, so it can be richer — and it
should be, because the smoke only catches what the fixture exercises.

A synthetic data-retention policy hits the right tradeoffs:

- **Domain-neutral.** Data retention applies to every team (PBJ-shaped,
  GDPR-shaped, fintech-shaped, healthcare-shaped). Future projects
  using the orchestrator can read this fixture and immediately know
  how to author their own reference inputs.
- **Exercises every M036a graph primitive.** Definitions section →
  `spec/term`-shape extraction. Numbered requirements (R-1..R-5) →
  `spec/requirement`-shape extraction. Exceptions (E-1, E-2) →
  `spec/constraint`-shape extraction. References section → `cites`
  edge type. `applies_to_field` hooks (operational_records,
  audit_records, personal_data) → `applies_to_field` edge type.
- **Right-sized.** ~70 lines markdown. Big enough that the LLM does
  real structural work; small enough that reruns stay cheap.
- **Stable.** No live dates in body, no LLM-drift content, no external
  links that decay. Regression artifacts stay meaningful run-over-run.
- **Synthetic but realistic.** Fictional `EXAMPLE-CORP` company,
  invented document IDs (`EC-POL-DR-001`, `EC-REG-2024-07`) — no
  real-world copyright/compliance entanglement, but the shape mirrors
  what real regulatory documents look like.

## How to re-run

```bash
# From the repo root. Requires conversus binary on PATH, OAuth set up
# at ~/.conversus/auth.json (or ANTHROPIC_API_KEY exported), and an
# orchestrating Claude Code session to perform the in-session
# extraction step (see "Phase 1: extraction" below).

# Phase 1: extraction (in-session, by the orchestrating Claude Code
# agent). Read policy-data-retention.md and the prompt template at
# templates/extraction-prompts/tier-2-structured-md.md, then write
# the extracted structured Markdown to:
#   tests/fixtures/m036-live-llm-smoke/extracted-structured.md

# Phase 2: live gate + promote + emit (production shell pipeline).
CONVERSUS_PROVIDER=claude-code \
  bash tests/m036-acceptance/live-llm-smoke/run-smoke.sh
```

The harness exports a tmp `ORCHESTRATOR_ROOT` so it never pollutes
repo state. On exit it copies all artifacts into a dated capture dir
under `tests/fixtures/m036-live-llm-smoke/regression-<YYYY-MM-DD>/`.

## Captured artifacts (per run)

```
regression-<YYYY-MM-DD>/
├── extracted-structured.md          (the in-session LLM extraction)
├── gate-result.md                   (conversus tier-2-fidelity verdict)
├── promoted-structured.md           (PASS only — final chunk-store form)
├── live-smoke-policy-01.pass.md     (PASS only — log file)
├── live-smoke-policy-01.block.md    (BLOCK only — log file)
└── execution-log.jsonl              (one unit_close record)
```

## Operator notes

- **Cost.** Each run consumes real LLM tokens through conversus. The
  tier-2-fidelity preset deliberates with two agents + an arbiter, so
  expect ~3 model calls per run. Skip if budget-constrained.
- **Verdict variance.** PASS/BLOCK is non-deterministic. Don't rely
  on a specific verdict in regression — rely on the artifacts being
  well-formed and on the verdict being explainable from the dispute
  list in `gate-result.md`.
- **Smoke does NOT exercise the production live: branch.** That
  branch (`extract_tier_2_dispatch live`) in
  `scripts/knowledge/lib/extract-tier-2-llm.sh` is unimplemented per
  CON-3. The smoke does the LLM extraction in-session via the
  orchestrating agent, then exercises the production gate + promote
  + emit shell paths. See the proposal for the shell-to-LLM bridge
  (the future production live: branch implementation) at
  `.orchestrator/proposals/shell-to-llm-bridge-extraction.md`.

## Related

- Production stub fixtures (CI): `tests/fixtures/m036-p03-tier-2/`
- P03 plan: `.orchestrator/milestones/M036/phases/P03/P03-PLAN.md`
- Conversus fidelity preset:
  `templates/conversus-presets/tier-2-fidelity.yml`
- Extraction prompt template:
  `templates/extraction-prompts/tier-2-structured-md.md`
- Future ticket (option A — shell-to-LLM bridge):
  `.orchestrator/proposals/shell-to-llm-bridge-extraction.md`

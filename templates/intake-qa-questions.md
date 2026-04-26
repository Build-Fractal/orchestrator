---
schema_version: "1.0"
type: intake-qa-questions
---

# Intake Q&A — Static 5-Question Template (M024/P05)

This template is consumed by `scripts/intake/qa-loop.sh` when an operator
invokes `orchestrator:evaluate` with neither `--input` nor `--spec-path`.
The qa-loop reads questions in order by `### Q<N>` heading number, presents
each prompt to the operator (or the line-mode answers file in tests), and
captures the answer for embedding under `## Q&A` in the emitted proposal.

The operator may answer any subset and short-circuit at any point with
the literal token `enough`. The cap is 5 turns (FR-5).

### Q1 — Goal

**Prompt**: What outcome do you want this work to produce?

**Guidance**: One sentence. A target state ("status command caches the
last result") rather than an action ("add caching"). This drives the
input_shape rationale and the scope_tier evidence for the proposal.

### Q2 — Scope

**Prompt**: Is this a single fix, a single feature, or a milestone-sized body of work?

**Guidance**: One of `single-task`, `single-feature`, or
`milestone`. Single-task is a one-script bug fix or doc edit;
single-feature is one phase of work; milestone is multi-phase. This
drives the decomposition axis.

### Q3 — Visible surface

**Prompt**: What surface does the change touch — code, docs, config, workflow, or UI?

**Guidance**: One or more of `code`, `docs`, `config`, `workflow`,
`ui`. UI-touching work hints at a design-gate recommendation; the
other surfaces typically do not. This drives the design_gate signal.

### Q4 — Adversarial review

**Prompt**: Does the change touch security, correctness, or contested design?

**Guidance**: `yes` or `no`. Yes-answers escalate the conversus_gate
axis to `recommended`; no-answers leave it at `none`. This drives the
conversus_gate signal.

### Q5 — Time-boxing

**Prompt**: Roughly how long should this take — Quick (≤30 minutes), Standard (≤2 hours), or Full (multi-session)?

**Guidance**: One of `Quick`, `Standard`, or `Full`. The answer
feeds the intensity axis directly (the proposal-emit may still
override via `intensity-recommend.sh` if the input description
warrants).

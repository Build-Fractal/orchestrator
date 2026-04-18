---
schema_version: "1.0"
type: evaluation
milestone: "M020"
feature_ref: "020-cutover-content-sweep"
feature_spec: "specs/020-cutover-content-sweep/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-16T18:00:00Z"
---

# M020 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: orchestrator:discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 7 |
| Acceptance scenarios | 18 |
| Functional requirements | 0 (captured as Success Criteria SC-1..SC-8) |
| Estimated SDD flows | 3+ (4 planned phases spanning gate scaffolding, runtime-path restoration, content sweep + governance, and locked-down validation) |

## Reasoning

M020 closes the four P0 mitigations and two of the six P1 mitigations from the
`conversus-oss/deliberations/spec-kit-orc-audit/` blind-arbiter ruling. The work
decomposes into distinct SDD flows with hard sequencing:

1. **Gate scaffolding (P01)** must land before any fix, so each fix's landing
   produces a measurable FAIL → PASS gate transition (AD-1). The gates are
   expected to fail against HEAD — that is the baseline, not a regression.
2. **Runtime-path restoration (P02)** — the missing `orchestrator:init` skill
   file and the `commands/auto.md` decommissioned-identifier fix — must land
   before any allow-list deletion. AD-2 establishes the load-bearing ordering:
   `auto.md` fix first, then `.claude/settings.json` speckit allow-list
   deletion (P03).
3. **Content sweep + governance (P03)** — template sweep, settings deletion,
   `migrate.md` rewrite, `DECISIONS.md` D007 (FR-013 retirement) + D008
   (content-layer governance rule). D008 is the structural fix that prevents
   recurrence — without it, M020 closes the current drift but does not close
   the underlying process gap that allowed the drift to accumulate.
4. **Summary reconciliation + locked-down re-run (P04)** — `CLAUDE.md` 7→15
   principle sync, test-count doc sweep, `M016-SUMMARY.md` zero-prompt scope
   narrowing, and a fresh-clone zero-prompt dogfood on a locked-down settings
   posture. The re-run is the empirical bound on the narrowed attestation
   claim (AD-4, AD-6).

Three signals push this firmly into Tier C rather than B:

1. **Cross-phase artifact consumption**: P02 consumes P01's gate scaffolding
   to prove its fixes work; P03 consumes both (gates + P02's auto.md fix);
   P04 consumes all three plus runs a dogfood. Each phase produces
   artifacts consumed by the next — this is a structured DAG, not a task
   list.
2. **Knowledge consolidation value**: D008 — the content-layer DECISIONS
   governance rule — compounds into future milestones. Capturing it as a
   recorded decision (rather than a best-effort note) requires the Tier C
   consolidation pass.
3. **Validation requires autonomous execution**: SC-7 (locked-down zero
   prompt re-run) can only be proven by running `orchestrator:auto` end-to-end
   from a fresh clone with minimal settings. Tier B does not invoke auto mode;
   classifying lower would make the milestone unverifiable by its own
   success criteria.

## Complexity Factors

- **Self-referential validation**: the six new gates must themselves be
  Bash-3.2-compatible, must self-exclude their own banned-token fixtures
  (`scripts/verify/fixtures/legacy-tokens.txt` is a catalog of tokens the
  gate must flag elsewhere but must not flag in the fixture itself), and
  must not flag the arbitration or deliberation transcripts (which contain
  extensive quoted drift tokens by necessity).
- **Hard ordering between P02 and P03** (AD-2): the intermediate window
  between `auto.md` fix and `.claude/settings.json` deletion must be
  closed within a single PR-and-merge cycle, or the crash-recovery UX
  breaks for any user on the intermediate state. PR ordering is part of
  the phase's acceptance.
- **Deliberation evidence lives in a sibling repo**
  (`conversus-oss/deliberations/spec-kit-orc-audit/`). The spec references
  it as evidence but the evidence is outside this repo's git tree. P01
  must either copy the arbiter's key rulings into a local evidence file
  (e.g., `phases/P01/evidence/arbiter-rulings.md`) or establish a stable
  relative reference. Preferred: copy the bindings inline; the sibling
  repo is not guaranteed to remain at this commit.
- **Locked-down dogfood on fresh clone**: P04's zero-prompt re-run must
  run from a fresh clone, not the developer's working tree, to avoid
  state bleed from uncommitted changes. Evidence capture requires a
  reproducible script; ad-hoc manual runs do not meet the attestation
  bar the arbiter's Dispute 5 ruling demands.
- **D008 governance is cultural, not technical**: the rule "content-layer
  drifts require a DECISIONS entry" binds only if contributors internalize
  it. P03 lands the rule text; lasting enforcement requires that the
  next content-layer change (whoever makes it) honors the rule. This is
  a known limitation — the rule is a floor, not a ceiling.

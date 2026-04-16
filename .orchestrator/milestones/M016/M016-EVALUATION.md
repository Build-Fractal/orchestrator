---
schema_version: "1.0"
type: evaluation
milestone: "M016"
feature_ref: "016-autonomous-hardening"
feature_spec: "specs/016-autonomous-hardening/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-16T00:47:49Z"
---

# M016 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 3 |
| Acceptance scenarios | 11 |
| Functional requirements | 0 (captured as Success Criteria SC-1..SC-6) |
| Estimated SDD flows | 2+ (4 planned phases spanning script-API, wrapper, guardrail, and audit flows) |

## Reasoning

M016 eliminates the prompt-generating patterns that block `orchestrator:auto` from
running end-to-end. The work is cohesive but decomposes into distinct SDD flows
with hard sequencing: a script-API redesign (P01) must land before dispatch
payload guardrails can reference the new sentinel (P03); a verify-suite wrapper
(P02) must exist before templates and linter rules can point to it (P03); and a
final audit + settings promotion (P04) closes the loop by dogfooding
`orchestrator:auto` on this very milestone. The dogfood requirement is
load-bearing — the credibility of the fix depends on demonstrating a
prompt-free auto run, which is the Tier C entry point.

Three signals push this firmly into Tier C rather than B:

1. **Cross-phase API rippling**: P01 changes the `write-summary.sh` contract;
   P02 adds a new wrapper; P03 encodes both into the dispatch payload template
   and a linter; P04 validates the combined surface. Each phase produces
   artifacts consumed by the next — this is not a simple task-list.
2. **Knowledge consolidation value**: the anti-pattern catalog produced here
   compounds into future milestones. Capturing it via orchestrator knowledge
   (rather than ad-hoc docs) requires the Tier C consolidation pass.
3. **Validation requires autonomous execution**: SC-1 (zero prompts) can only
   be proven by running `orchestrator:auto`. Tier B does not invoke auto mode;
   classifying lower would make the milestone unverifiable by its own success
   criteria.

## Complexity Factors

- **Dogfooding**: milestone validates itself via `orchestrator:auto`, meaning
  each phase's implementation is partially constrained by the need for the next
  phase to run autonomously under the same guardrails being introduced.
- **Hard pre-M009 deadline**: the autonomy claim is load-bearing for M009's
  launch narrative. Phase decomposition must produce shippable state at each
  phase boundary so the milestone can be paused and resumed cleanly.
- **Class A vs Class B vs Class C prompt sources**: three distinct fix
  mechanisms are required (code redesign, allow-list promotion, guardrail
  enforcement). Conflating them risks incomplete coverage — the roadmap must
  preserve the tri-partite split.
- **Bash 3.2 compatibility constraint**: new wrapper and linter scripts must
  honor constitution principle VIII and the project's existing `no-compound
  bash in auto mode` rule; this narrows the implementation space.
- **Self-referential testing**: the anti-pattern linter must not flag its own
  regex sources as violations — deliberate test fixtures and a stable
  ignore/marker convention are required.

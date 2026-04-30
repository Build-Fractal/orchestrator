---
schema_version: "1.0"
type: task-plan
task: "T95"
phase: "P99"
milestone: "M999"
name: "P04 fixture: plan-novel-class (novel body, partial-flip routing demo)"
---

# Fixture plan: novel-character demo input

This plan is a fixture input for `tools/verify/p04-partial-flip-routing.sh`
(T03 deliverable). The body has the novel-classifier signature: the
`## Goal` section uses words like `explore`, `design alternatives`,
`evaluate alternatives` — high-precision novel lexicon hits — and
intentionally has NO concrete `## Steps` block with file-touch verifiers.
The classifier therefore returns `character=novel`.

In the partial-flip-routing scenario (D-A3 safety), the live-mode
override-resolution path treats the `novel` class as the WITHHELD class
when the corpus verdict is `partially_ready`. With novel withheld, the
routing-table default for novel (smart) prevails and the dispatch routes
to the smart tier — the conservative outcome that D-A3 enshrines as the
safety property of the partial-flip path.

Do NOT edit the embedded `M999`/`P99`/`T95` markers; they tag this plan
as the novel-class demo input.

## Goal

Explore alternative architectures for the live-routing flip-gate. Evaluate
alternatives between per-class verdict caching and on-demand re-evaluation,
and design alternatives for the operator-facing knob shape governing
partial-flip authorization windows. Investigate options for the corpus-
freshness staleness metric and the associated automatic-block thresholds.

The deliverable is a design judgment expressed as a recommendation memo;
no concrete file targets, no executable verifiers, no enumerated steps.
This is exploratory design work — exactly the shape the classifier should
recognize as novel.

## Verification

```bash
bash tools/verify/p04-partial-flip-routing.sh
```

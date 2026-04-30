---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M030"
provides:
  - "templates/model-routing.yml SSOT (routing+resolution+cost_rates) + references/model-routing.md operator docs (5 sections, concrete stability-metric numerics 0.10/N=20/50) + tools/verify/p01-routing-table-shape.sh + tools/verify/p01-model-routing-doc-shape.sh"
requires:
  - "from:T02 what:scripts/dispatch/classify-task.sh emits closed-enum character/confidence; from:P00 what:tests/fixtures/m030-classifier-corpus/labels.yml"
affects:
  - "P01/T04,P02,P05"
key_files:
  - "templates/model-routing.yml,references/model-routing.md,tools/verify/p01-routing-table-shape.sh,tools/verify/p01-model-routing-doc-shape.sh"
key_decisions:
  - "CON-3-closure-invariant-model-IDs-only-in-resolution; D-A6-cost_rates-SSOT; classifier-confidence-stability-metric-pinned-0.10-N=20-50-dispatches; CC-only-launch-other-runtimes-inherit"
patterns_established:
  - "declarative-routing-table-with-symbolic-tier-indirection; awk-section-walker-for-YAML-closure-check-no-jq-dependency; doc-shape-verifier-grep-asserts-concrete-numerics-as-load-bearing-downstream-contract"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P01/tasks/T03-routing-table-and-docs-PLAN.md"
duration: "60m"
verification_result: "pass"
completed_at: "2026-04-30T12:10:48Z"
---

T03 ships the M030 routing-table SSOT and operator docs. templates/model-routing.yml has three top-level sections: routing (character->symbolic-tier per runtime), resolution (symbolic-tier->concrete model ID, the only place hardcoded IDs live per CON-3), cost_rates (per-tier USD/Mtok consumed by P05 metrics-rollup --by-model). references/model-routing.md has the five required sections (Routing Table, Per-Runtime Resolution, Cost Rates SSOT, Aggressive Overlay, Classifier-Confidence Stability Metric) and pins the stability metric to concrete numerics: variance threshold 0.10 (high=1.0/medium=0.5/low=0.0 mapping), rolling window N=20, per-class coverage floor 50 dispatches. P02 shadow-compare.sh consumes these verbatim. Two new verifiers under tools/verify/: p01-routing-table-shape.sh (8 checks including symbolic-tier closure routing->resolution and cost_rates->resolution, closed-enum character vocabulary, closed-enum tier vocabulary, cost_rates entry shape) and p01-model-routing-doc-shape.sh (5 section-presence + 3 numeric-threshold checks). Both pass=8 fail=0. p01-d-a4-timeline.sh re-run Mode B: pass=1 fail=0 (labels.yml predates classify-task.sh on git timeline). CC-only launch posture preserved: codex-cli/cursor resolve to 'inherit' across routing+resolution; M009 post-launch will revisit.

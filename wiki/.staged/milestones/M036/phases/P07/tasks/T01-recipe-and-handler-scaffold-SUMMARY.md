---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P07"
milestone: "M036"
provides:
  - "templates/context-recipe.yaml extended with reference: section block (source: reference, priority: optional, order: 45, filter: scope, cache_hint: semi-static) + top-level reference: block declaring default_token_budget: 4000 (M036/P07 plan); scripts/dispatch/lib/section-handlers.sh extended with handle_reference() T01-stub function (signature mirrors handle_spec_context: orch_root/milestone/phase/task; returns 0 with empty stdout — body filled by T02 with budget governor + relevance ranker invocations) + dispatcher case-arm reference) routing source: reference to handle_reference; two new shape verifiers under tools/verify/ (m036-p07-recipe-shape.sh — 5 token-presence checks on recipe shape; m036-p07-handler-shape.sh — 4 token-presence checks on handler defn + dispatcher routing + T01 stub-comment marker)"
requires:
  - "from:M036/P00 what:references/reference-frontmatter-contract.md (topic_tags + applies_to_field field declarations); from:M036/P04 what:scripts/knowledge/ingest-reference.sh + knowledge/reference/**/REF-*.md chunk store (T02 will consume); from:M036/P05 what:scripts/dispatch/scope-filter.sh --tag '[source:<cite_id>]' literal-match + new edge types (T02 will consume); from:M011/M020 what:scripts/dispatch/lib/section-handlers.sh handle_spec_context() canonical pattern + dispatch_section_handler() source-router; from:M011/M020 what:templates/context-recipe.yaml section schema (source/priority/order/filter/cache_hint)"
affects:
  - "M036/P07/T02 (handle_reference body fill — budget governor + relevance ranker; consumes the case-arm + function defn landed here); M036/P07/T03 (build-context.sh dispatcher map edits — display-order/name/priority/volatility maps each gain a reference slot); M036/P07/T04 (acceptance harness consuming default_token_budget recipe field)"
key_files:
  - "templates/context-recipe.yaml,scripts/dispatch/lib/section-handlers.sh,tools/verify/m036-p07-recipe-shape.sh,tools/verify/m036-p07-handler-shape.sh"
key_decisions:
  - "none"
patterns_established:
  - "T01 empty-stub scaffold pattern: when adding a new dispatch section across multiple tasks, T01 lands the recipe declaration + handler-function signature + dispatcher case-arm with an empty-stub body that returns 0 with no stdout — leverages build-context.sh's existing omit-empty-section discipline (carried from handle_spec_context) so payload behavior is byte-identical pre/post T01. CON-1 / SC-7 byte-equality is preserved automatically because priority: optional + empty stdout combine to drop the section header + manifest row + body entirely. T02 then fills the function body without further dispatcher edits; T03 wires the build-context maps. This staging order isolates pure-data (T01 declaration) from pure-logic (T02 governor) from pure-routing (T03 maps); inserted-AFTER-spec_context anchor pattern: new section blocks use spec_context as the anchor — both the recipe section block and the dispatcher case-arm. Convention: 'append after spec_context' is the canonical insertion point for new compressible/optional sections in the post-M020 dispatch surface; M036 verifier conventions inherited intact (milestone-prefixed slug m036-p07-*, AD-19 single-script-file shape, grep -qF -e leading-dash-safe token-loops, set -eu strict, ROOT resolution via ORCHESTRATOR_ROOT-or-pwd, structured PASS:/FAIL:/SUMMARY: stdout per MEM001)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P07/tasks/T01-recipe-and-handler-scaffold-PAYLOAD.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-05-02T18:34:55Z"
---

T01 of M036/P07 lands the recipe declaration + empty-stub handler scaffold for the new reference: dispatch section. Three surgical edits + two shape verifiers, all green.

What changed:

1. templates/context-recipe.yaml: added reference: section block under sections: map immediately after spec_context: (source: reference, priority: optional, order: 45, filter: scope, cache_hint: semi-static) and appended a new top-level reference: block at end of file declaring default_token_budget: 4000, with leading comment block citing FR-8 chunk-level dropping mandate + at-least-one-chunk invariant.

2. scripts/dispatch/lib/section-handlers.sh: added handle_reference() empty-stub function definition immediately after handle_spec_context()'s closing brace (line ~622). Function signature mirrors handle_spec_context: orch_root/milestone/phase/task. Body returns 0 with no stdout — T01 stub. Multi-line comment block above declares T02 will fill body with reference_apply_budget + reference_rank invocations and that empty stdout is honored by build-context.sh's omit-empty-section discipline. Then added reference) case-arm to dispatch_section_handler() in same file, immediately after spec_context) arm and before *.md) arm — verbatim invocation handle_reference "$orch_root" "$milestone" "$phase" "$task".

3. Two shape verifiers under tools/verify/:
   - m036-p07-recipe-shape.sh: 5 token-presence checks (reference: section key, source: reference, priority: optional, order: 45, default_token_budget: 4000).
   - m036-p07-handler-shape.sh: 4 token-presence checks (handle_reference() defn, reference) case-arm, dispatcher invocation 'handle_reference "$orch_root"', T01 stub comment marker).

Verification result: 2/2 verifiers PASS first-try.

- bash tools/verify/m036-p07-recipe-shape.sh -> SUMMARY: m036-p07-recipe-shape.sh pass=5 fail=0
- bash tools/verify/m036-p07-handler-shape.sh -> SUMMARY: m036-p07-handler-shape.sh pass=4 fail=0

CON-1 / SC-7 posture: byte-identical pre-feature payloads are preserved automatically. The new reference: section is priority: optional and the handler returns empty stdout — build-context.sh's existing omit-empty-section gating (line ~1995, carried from handle_spec_context) drops the entire ## Reference header, manifest row, and section body. The full SC-7 byte-identical golden-baseline assertion is T03's responsibility (captured immediately before T03's display-order/name/priority/volatility map edits, since those map edits are the only changes that COULD perturb the manifest table ordering — T01+T02 produce zero payload delta on no-scope task plans).

Cross-task ordering note: T01's verifiers do not assert the build-context.sh dispatcher map edits — those are T03's deliverable. The phase Must-Have m036-p07-dispatcher-routes-reference.sh verifier lands in T03; per the M036 canonical pattern surfaced across P02/P03/P04, cross-task-ordering deferrals are explicit and do not constitute a fail at the T01 verification gate. T01 ships clean with both T01-scoped verifiers green.

Forward-pointing notes:

- T02 fills handle_reference() body with topic_tags + applies_to_field intersection against ingested REF-*.md chunks, ranks via reference_rank (new lib scripts/dispatch/lib/reference-relevance.sh), governs by reference_apply_budget (new lib scripts/dispatch/lib/reference-budget.sh), and emits ## Reference markdown body.
- T03 wires build-context.sh: adds reference slot to display-order / name / priority / volatility maps; captures SC-7 golden baseline before edits.
- T04 authors acceptance harness + phase-suite aggregator + cross-phase regression verifiers (P02/P03/P04/P05).

Phase-suite aggregator (m036-p07-phase-suite.sh): not authored by T01 — later-task / phase-close deliverable per the M036 P00–P05 precedent.

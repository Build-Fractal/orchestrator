---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M036"
goal: "Wire reference chunks into dispatch payloads under a chunk-level token-budget governor; preserve byte-identical pre-feature payloads when no topic_tags / applies_to_field declared."
demo_sentence: "Operator dispatches a synthetic task whose plan declares topic_tags: [pbj-staffing] and reference_token_budget: 4000; the dispatched payload's reference: section is ≤4000 tokens, contains ≥1 chunk, and chunks are dropped at chunk-level granularity when over budget (SC-3). A task plan with no topic_tags and no applies_to_field produces a payload byte-identical to the pre-feature payload (SC-7 golden-baseline diff)."
risk: "high"
depends_on: ["P04", "P05"]
---

# P07 — Dispatch context-builder injection + token-budget governor

## Goal

Add a declarative `reference:` section to the dispatch context recipe (`templates/context-recipe.yaml`) and a paired `handle_reference` section-handler in `scripts/dispatch/lib/section-handlers.sh` that pulls task-scoped reference chunks (P04 ingested REF-* chunks) under a chunk-level token-budget governor (FR-3, FR-7, FR-8, CON-7). Wire the dispatcher in `scripts/dispatch/build-context.sh` to recognize the new section. Preserve CON-1 / SC-7 byte-identical pre-feature payloads when a task plan declares neither `topic_tags` nor `applies_to_field`.

This is the load-bearing M036a phase — the validator-pilot dispatch path — and carries the only backwards-compatibility hard gate in M036a (SC-7 golden-baseline diff).

## Demo

> Operator dispatches a synthetic task whose plan declares `topic_tags: [pbj-staffing]` and `reference_token_budget: 4000`; the dispatched payload's `reference:` section is ≤4000 tokens, contains ≥1 chunk, and chunks are dropped at chunk-level granularity when over budget (SC-3). A task plan with no `topic_tags` and no `applies_to_field` produces a payload byte-identical to the pre-feature payload (SC-7 golden-baseline diff).

## Boundary Map

**Produces** (this phase writes / amends):

- `templates/context-recipe.yaml` (modify) — adds a new `reference:` section declaration (source: `reference`, priority: `optional`, order: `45`, filter: `none`, cache_hint: `semi-static`) per Principle X / Principle XIII. Declared default `reference_token_budget: 4000` under a new top-level `reference:` recipe block.
- `scripts/dispatch/lib/section-handlers.sh` (modify) — adds `handle_reference` (mirrors `handle_spec_context` shape; reads task-plan `topic_tags` + `applies_to_field` frontmatter; resolves matching `knowledge/reference/**/REF-*.md` chunks via `scripts/dispatch/scope-filter.sh`; applies the governor; emits `## Reference` markdown body or empty stdout if no matches / no declared scope).
- `scripts/dispatch/lib/reference-budget.sh` (create) — pure-lib MEM004 token-budget governor exposing `reference_apply_budget(chunk_id_list, budget_tokens) -> stdout: chunk-IDs in declared-priority order, total ≤ budget`. Chunk-level granularity (FR-3, FR-7) — never mid-chunk truncation. At-least-one-chunk invariant (FR-8 + Edge Case "smallest-chunk-larger-than-budget").
- `scripts/dispatch/lib/reference-relevance.sh` (create) — pure-lib MEM004 relevance-ordering helper exposing `reference_rank(topic_tags, applies_to_field) -> stdout: chunk-IDs sorted by priority`. Resolves Open Question #Q-2 with a hybrid signal: (a) topic-tag overlap count (descending) → (b) `applies_to_field` overlap count (descending) → (c) `published` recency (descending) → (d) lexicographic chunk_id (deterministic tie-break). All-deterministic; no BFS-walk per dispatch (BFS handled by the existing scope-filter graph mode).
- `scripts/dispatch/build-context.sh` (modify) — extends `dispatch_section_handler` routing to recognize `source: reference` (single-line case branch) plus the omit-empty-section discipline carried from `spec_context` (skip section entirely if handler returns empty stdout). Display-order map gains a `reference) echo 4 ;;` slot (after `spec_context`); display-name gains `reference) echo "Reference" ;;`; display-priority gains `reference) echo "filtered" ;;`. Volatility classifier gains `"Reference") echo "stable" ;;` per the M019/P00/L2 boundary.
- `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md` (create) — synthetic task plan declaring `topic_tags: [pbj-staffing]` and `reference_token_budget: 4000` for SC-3.
- `tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md` (create) — synthetic task plan declaring no `topic_tags` and no `applies_to_field` (SC-7 golden-baseline subject).
- `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` (create) — pre-feature golden payload baseline captured BEFORE T03's dispatcher edits land. The CON-5 / SC-7 byte-equality contract.
- `tests/test-reference-dispatch-injection.sh` (create) — SC-3 acceptance harness; runs build-context.sh against the topic-tags fixture; asserts payload contains `## Reference`, ≥1 REF-* chunk, total reference-section tokens ≤ 4000, and chunk-level dropping when budget exceeded. Emits `BATTERY: pass=N fail=N skip=N` last line.
- `tests/test-reference-backwards-compat-golden.sh` (create) — SC-7 acceptance harness (M030 SC-11 shape); runs build-context.sh against the no-scope fixture; asserts byte-equality against the captured pre-feature baseline. Emits `BATTERY: pass=N fail=N skip=N` last line.
- `tools/verify/m036-p07-recipe-shape.sh` (create) — T01 token-presence verifier on `templates/context-recipe.yaml` for the new `reference:` section + default budget.
- `tools/verify/m036-p07-handler-shape.sh` (create) — T01 token-presence verifier on `scripts/dispatch/lib/section-handlers.sh` for `handle_reference()` definition + dispatcher case-branch.
- `tools/verify/m036-p07-budget-lib-shape.sh` (create) — T02 token-presence verifier on `scripts/dispatch/lib/reference-budget.sh` for `reference_apply_budget()` + chunk-level granularity comment + at-least-one-chunk invariant.
- `tools/verify/m036-p07-relevance-lib-shape.sh` (create) — T02 token-presence verifier on `scripts/dispatch/lib/reference-relevance.sh` for `reference_rank()` + the four-key tie-break ordering.
- `tools/verify/m036-p07-budget-chunk-level-granularity.sh` (create) — T02 behavioral verifier: stages a fixture chunk-list summing 12k tokens against budget=4000, asserts output total ≤ 4000 AND no chunk_id appears partially (set comparison: each emitted chunk_id is one of the input chunk_ids in full).
- `tools/verify/m036-p07-budget-at-least-one-chunk.sh` (create) — T02 behavioral verifier: budget=10 (smaller than smallest chunk); asserts `reference_apply_budget` emits exactly one chunk_id (FR-8 invariant).
- `tools/verify/m036-p07-relevance-deterministic.sh` (create) — T02 behavioral verifier: invokes `reference_rank` twice on the same input and asserts stdout is byte-identical; asserts the four-key tie-break order on a hand-crafted fixture.
- `tools/verify/m036-p07-dispatcher-routes-reference.sh` (create) — T03 token-presence + behavioral hybrid: asserts `dispatch_section_handler` source-case for `reference` exists and `build-context.sh` display-order/name/priority/volatility maps each contain a `reference` slot.
- `tools/verify/m036-p07-omit-empty-section.sh` (create) — T03 behavioral verifier: drives build-context.sh against a task plan declaring `topic_tags: [does-not-match-anything]`, asserts payload contains NO `## Reference` header (omit-empty discipline carried from spec_context).
- `tools/verify/m036-p07-fixture-task-plans-shape.sh` (create) — T03 token-presence verifier on the two synthetic task-plan fixtures.
- `tools/verify/m036-p07-baseline-captured.sh` (create) — T03 sanity verifier asserting the baseline file exists, is non-empty, and contains a recognizable manifest header (`## Manifest` or equivalent canonical pre-feature artifact).
- `tools/verify/m036-p07-p02-regression-pass.sh` (create) — T03 cross-phase regression: re-runs `tools/verify/m036-p02-phase-suite.sh` excluding `m036-p02-tier-2-deferred-error.sh` (P03-flipped semantics). Selective-gate-list pattern carried verbatim from M036/P03/T03 + M036/P04/T04.
- `tools/verify/m036-p07-p03-regression-pass.sh` (create) — T03 cross-phase regression: re-runs `tools/verify/m036-p03-phase-suite.sh`; asserts `pass=14 fail=0`. No semantics flip — full pass-through.
- `tools/verify/m036-p07-p04-regression-pass.sh` (create) — T03 cross-phase regression: re-runs `tools/verify/m036-p04-phase-suite.sh`; asserts `pass=13 fail=0`. No semantics flip.
- `tools/verify/m036-p07-p05-regression-pass.sh` (create) — T03 cross-phase regression: re-runs `tools/verify/m036-p05-phase-suite.sh`; asserts `pass=8 fail=0`. P05's CON-5 default-mode baselines (`traverse-relates-to.expected.txt` + `scope-filter-default.expected.txt`) are byte-equality checks; P07 does not edit those scripts so these MUST still pass — load-bearing assertion that P07 did not perturb the shared `scripts/dispatch/scope-filter.sh` or `scripts/knowledge/traverse-graph.sh` consumed in T02.
- `tools/verify/m036-p07-test-harness.sh` (create) — T04 permissive harness-shape verifier (rc≤1 acceptable; harness must emit BATTERY last line) for both SC-3 and SC-7 harnesses.
- `tools/verify/m036-p07-acceptance-harness-passes.sh` (create) — T04 strict pass-rate gate (rc=0 specifically) for both SC-3 and SC-7 harnesses. Permissive+strict split per M036-canonical M036/P02..P04 acceptance-harness pattern.
- `tools/verify/m036-p07-phase-suite.sh` (create) — T04 17-gate phase-suite aggregator wiring all P07 sub-gates. Filename milestone-prefixed per Plan-Time Discipline rule 6. (Sub-gate count: T01=2 + T02=5 + T03=8 + T04=2 = 17 sub-gates.)

**Consumes** (read but not modified):

- P04 ingested REF-* chunks under `tests/fixtures/m036-p04-reference-corpus/` — re-used as the matched-corpus for SC-3. Each carries `topic_tags: [pbj-staffing, cms-section-483-20]` and `applies_to_field: [staff_count, census]` matching the demo task plan.
- P04 `scripts/knowledge/rebuild-index.sh` extension — registers REF-* chunks in `KNOWLEDGE-INDEX.md`. P07 reads the index via existing scope-filter mechanics; does not re-rebuild.
- P05 `scripts/dispatch/scope-filter.sh --tag '[source:<cite_id>]'` literal-match — used by `handle_reference` to enumerate chunks matching `topic_tags` (filtered later by `reference_rank`). P07 calls scope-filter; does not modify it.
- P05 `scripts/knowledge/traverse-graph.sh --edge-types applies_to_field` — optional secondary lookup if `applies_to_field` declared on the task plan; resolves field-name → chunk-id matches via the new edge type. P07 calls; does not modify.
- M031 `scripts/dispatch/build-context.sh` restoration (Quick intensity now invokes build-context.sh — load-bearing). P07 amends the dispatcher locally but MUST NOT perturb the M031 restoration semantics. Verified by the P03 / P04 / P05 regression checks AND by the SC-7 golden-baseline diff (the strongest possible CON-1 guard).
- Existing `scripts/dispatch/lib/section-handlers.sh::handle_spec_context` — read as the canonical pattern for `handle_reference`; not modified.
- Existing tokenizer access — `scripts/dispatch/build-context.sh` already includes a `(_section_chars + 3) / 4` token-estimation helper at the manifest-builder layer (M018 compression-tier). `reference_apply_budget` re-uses the same per-chunk token estimate (counts characters, divides by 4) for consistency. No new tokenizer dependency.

## Cross-Task Ordering (M036-canonical disclosure)

Three load-bearing ordering nuances disclosed up-front (M036-canonical convention; misses produce false-passes or path-discipline violations):

1. **T03 baseline-capture sequencing is the load-bearing CON-1/SC-7 contract.** The pre-feature payload baseline at `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` MUST be captured BEFORE T03 edits `scripts/dispatch/build-context.sh`'s display-order / name / priority / volatility maps. If captured after, the SC-7 byte-equality check becomes a tautology (it would compare the post-edit payload against itself). Pattern carried verbatim from M036/P05 (`tests/fixtures/m036-p05-baseline/`) and from the M030 SC-11 golden-baseline shape. T03 task plan's `## Steps` Step 1 is `bash scripts/dispatch/build-context.sh` against the no-scope fixture INTO the baseline file, before any other edit. T01's recipe addition (the new `reference:` section with `priority: optional`) does NOT change the no-scope payload because `optional`-priority sections that produce empty output are dropped at the omit-empty-section gate (carried from `spec_context`); T01 is therefore safe to land first.

2. **P05's `--tag '[source:<cite_id>]'` literal-match path is operator-asserted, not topic-tag-driven.** `handle_reference` does NOT call `scope-filter.sh --tag '[source:...]'` to enumerate matches by `topic_tags` (that tag namespace is per-source-citation, not per-topic). Instead, `handle_reference` iterates `KNOWLEDGE-INDEX.md` REF-* entries directly, reads each chunk's frontmatter `topic_tags` + `applies_to_field`, and intersects against the task-plan's declared scope. The `[source:...]` namespace remains available for explicit operator-asserted source scoping (declared on a task plan as `scope_tags: [source:cms-pbj-2024-q3]`); P07 honors it as an additional union-clause but the primary scope match is `topic_tags` ∩ `applies_to_field`. This avoids re-reading the spec where #Q-7 (tag-namespace-collision-policy) lands.

3. **Selective-gate-list cross-phase regression pattern is M036-canonical.** P02's `m036-p02-tier-2-deferred-error.sh` semantics flipped at P03 close; future regression checks targeting the P02 phase-suite MUST exclude that one gate. Pattern is carried verbatim into `tools/verify/m036-p07-p02-regression-pass.sh`. P03/P04/P05 phase-suites have no flipped sub-gates that affect P07 (P07 does not edit any path P03/P04/P05 verifiers exercise except `scripts/dispatch/build-context.sh` and `scripts/dispatch/lib/section-handlers.sh`, neither of which is verifier-targeted in those phases). Full pass-through is correct for P03/P04/P05.

## Plan-Time Path-Collision Check

Confirmed at plan-authoring time (commands/plan-phase.md Plan-Time Discipline rule 6):

| Path declared `create` | Pre-existing? |
|---|---|
| `scripts/dispatch/lib/reference-budget.sh` | NO |
| `scripts/dispatch/lib/reference-relevance.sh` | NO |
| `tests/fixtures/m036-p07-task-plans/*` | NO (directory does not exist) |
| `tests/fixtures/m036-p07-baseline/*` | NO (directory does not exist) |
| `tests/test-reference-dispatch-injection.sh` | NO |
| `tests/test-reference-backwards-compat-golden.sh` | NO |
| `tools/verify/m036-p07-*.sh` (15 files) | NO (no `m036-p07-*` files in `tools/verify/`) |
| `.orchestrator/milestones/M036/phases/P07/tasks/T0[1-4]-*-PLAN.md` | NO (tasks dir freshly created) |

Modify-not-create paths (declared `modify` not `create`):

- `templates/context-recipe.yaml` — exists; T01 amends additively.
- `scripts/dispatch/lib/section-handlers.sh` — exists; T01 adds `handle_reference` + dispatcher case branch additively.
- `scripts/dispatch/build-context.sh` — exists; T03 amends display-order / name / priority / volatility maps additively (single new case-arm each).

No collisions. No silent-clobber risk.

## Plan-Time Verifier-Slug Uniqueness Check

Every P07 verifier filename starts with the milestone-prefixed slug `m036-p07-` (Plan-Time Discipline rule 6 + M036-canonical convention from M036/P00 phase-summary). No `m036-p07-*` files exist in `tools/verify/` today (confirmed above). All 16 declared verifier filenames (15 sub-gates + the phase-suite aggregator) are unique within `tools/verify/`. No cross-milestone collisions (M030 / M031 use `p##-*` and `m030-*` / `m031-*` prefixes respectively; no overlap).

## Must-Haves

### Truths

- The default context recipe declares a `reference:` section with `source: reference`, `priority: optional`, `order: 45`, `filter: none`, `cache_hint: semi-static`, and a top-level `reference:` block declaring `default_token_budget: 4000`.
  - Check: `bash tools/verify/m036-p07-recipe-shape.sh`
- `scripts/dispatch/lib/section-handlers.sh` defines `handle_reference()` and the dispatcher routes `source: reference` to it.
  - Check: `bash tools/verify/m036-p07-handler-shape.sh`
- `scripts/dispatch/lib/reference-budget.sh` defines `reference_apply_budget()` with chunk-level granularity (no mid-chunk truncation) and the at-least-one-chunk invariant.
  - Check: `bash tools/verify/m036-p07-budget-lib-shape.sh`
- `scripts/dispatch/lib/reference-relevance.sh` defines `reference_rank()` with the documented hybrid four-key sort (topic-tag overlap → applies_to_field overlap → published recency → lexicographic chunk_id).
  - Check: `bash tools/verify/m036-p07-relevance-lib-shape.sh`
- The token-budget governor drops chunks at chunk-level granularity (FR-3, FR-7) — no chunk_id is emitted partially when total exceeds budget.
  - Check: `bash tools/verify/m036-p07-budget-chunk-level-granularity.sh`
- The token-budget governor satisfies FR-8 at-least-one-chunk invariant — when budget < smallest matched chunk, exactly one chunk is still emitted.
  - Check: `bash tools/verify/m036-p07-budget-at-least-one-chunk.sh`
- `reference_rank` is deterministic — invoking twice on the same input produces byte-identical stdout; the four-key tie-break order is honored.
  - Check: `bash tools/verify/m036-p07-relevance-deterministic.sh`
- `scripts/dispatch/build-context.sh` recognizes the new `reference` source — the dispatcher case-branch + display-order / name / priority / volatility maps each contain a `reference` slot.
  - Check: `bash tools/verify/m036-p07-dispatcher-routes-reference.sh`
- A task plan declaring `topic_tags` that match no chunks produces a payload with NO `## Reference` header (omit-empty-section discipline).
  - Check: `bash tools/verify/m036-p07-omit-empty-section.sh`
- The two synthetic task-plan fixtures and the pre-feature payload baseline exist on disk with the expected shape.
  - Check: `bash tools/verify/m036-p07-fixture-task-plans-shape.sh`
- The pre-feature payload baseline file exists, is non-empty, and was captured before T03's dispatcher edits.
  - Check: `bash tools/verify/m036-p07-baseline-captured.sh`
- M036/P02 phase-suite (selective 14 of 15 sub-gates excluding the P03-flipped `m036-p02-tier-2-deferred-error.sh`) still passes after P07 lands.
  - Check: `bash tools/verify/m036-p07-p02-regression-pass.sh`
- M036/P03 phase-suite (14 sub-gates) still passes after P07 lands.
  - Check: `bash tools/verify/m036-p07-p03-regression-pass.sh`
- M036/P04 phase-suite (13 sub-gates) still passes after P07 lands.
  - Check: `bash tools/verify/m036-p07-p04-regression-pass.sh`
- M036/P05 phase-suite (8 sub-gates including default-mode CON-5 byte-equality baselines) still passes after P07 lands.
  - Check: `bash tools/verify/m036-p07-p05-regression-pass.sh`
- The SC-3 and SC-7 acceptance harnesses are well-formed (emit BATTERY last line; rc≤1 acceptable for shape).
  - Check: `bash tools/verify/m036-p07-test-harness.sh`
- The SC-3 and SC-7 acceptance harnesses pass (rc=0 specifically — strict pass-rate gate).
  - Check: `bash tools/verify/m036-p07-acceptance-harness-passes.sh`
- The 17-gate P07 phase-suite aggregator reports `pass=17 fail=0`.
  - Check: `bash tools/verify/m036-p07-phase-suite.sh`

### Artifacts

- `templates/context-recipe.yaml` (min 110 lines, contains "reference:")
- `scripts/dispatch/lib/section-handlers.sh` (min 700 lines, contains "handle_reference")
- `scripts/dispatch/lib/reference-budget.sh` (min 50 lines, contains "reference_apply_budget")
- `scripts/dispatch/lib/reference-relevance.sh` (min 50 lines, contains "reference_rank")
- `scripts/dispatch/build-context.sh` (min 2000 lines, contains "reference")
- `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md` (min 10 lines, contains "topic_tags")
- `tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md` (min 5 lines, contains "scope_tags")
- `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` (min 1 lines, contains "Manifest")
- `tests/test-reference-dispatch-injection.sh` (min 50 lines, contains "BATTERY")
- `tests/test-reference-backwards-compat-golden.sh` (min 30 lines, contains "BATTERY")
- `tools/verify/m036-p07-recipe-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-handler-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-budget-lib-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-relevance-lib-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-budget-chunk-level-granularity.sh` (min 20 lines, contains "PASS:")
- `tools/verify/m036-p07-budget-at-least-one-chunk.sh` (min 15 lines, contains "PASS:")
- `tools/verify/m036-p07-relevance-deterministic.sh` (min 20 lines, contains "PASS:")
- `tools/verify/m036-p07-dispatcher-routes-reference.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-omit-empty-section.sh` (min 20 lines, contains "PASS:")
- `tools/verify/m036-p07-fixture-task-plans-shape.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-baseline-captured.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-p02-regression-pass.sh` (min 15 lines, contains "PASS:")
- `tools/verify/m036-p07-p03-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-p04-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-p05-regression-pass.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-test-harness.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-acceptance-harness-passes.sh` (min 10 lines, contains "PASS:")
- `tools/verify/m036-p07-phase-suite.sh` (min 30 lines, contains "SUMMARY:")

### Key Links

- `templates/context-recipe.yaml` → `section-handlers.sh` (the new `source: reference` declaration must be routed by the dispatcher's case-branch — verifier asserts the recipe's `source: reference` token is matched by a `reference)` arm in section-handlers.sh).
- `scripts/dispatch/lib/section-handlers.sh` → `reference-budget.sh` (`handle_reference` must source / invoke the budget governor).
- `scripts/dispatch/lib/section-handlers.sh` → `reference-relevance.sh` (`handle_reference` must source / invoke the relevance ranker).
- `scripts/dispatch/build-context.sh` → `section-handlers.sh` (the dispatcher case-branch routing `source: reference` must reach the section-handlers library — verifier asserts `reference` appears in both files).
- `tests/test-reference-dispatch-injection.sh` → `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md` (SC-3 harness drives the topic-tags fixture).
- `tests/test-reference-backwards-compat-golden.sh` → `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` (SC-7 harness compares against the captured baseline).
- `tools/verify/m036-p07-phase-suite.sh` → all 13 P07 sub-gate verifiers (aggregator wires them).

## Files Likely Touched

- `templates/context-recipe.yaml` (modify)
- `scripts/dispatch/lib/section-handlers.sh` (modify)
- `scripts/dispatch/lib/reference-budget.sh` (create)
- `scripts/dispatch/lib/reference-relevance.sh` (create)
- `scripts/dispatch/build-context.sh` (modify)
- `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md` (create)
- `tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md` (create)
- `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` (create)
- `tests/test-reference-dispatch-injection.sh` (create)
- `tests/test-reference-backwards-compat-golden.sh` (create)
- `tools/verify/m036-p07-recipe-shape.sh` (create)
- `tools/verify/m036-p07-handler-shape.sh` (create)
- `tools/verify/m036-p07-budget-lib-shape.sh` (create)
- `tools/verify/m036-p07-relevance-lib-shape.sh` (create)
- `tools/verify/m036-p07-budget-chunk-level-granularity.sh` (create)
- `tools/verify/m036-p07-budget-at-least-one-chunk.sh` (create)
- `tools/verify/m036-p07-relevance-deterministic.sh` (create)
- `tools/verify/m036-p07-dispatcher-routes-reference.sh` (create)
- `tools/verify/m036-p07-omit-empty-section.sh` (create)
- `tools/verify/m036-p07-fixture-task-plans-shape.sh` (create)
- `tools/verify/m036-p07-baseline-captured.sh` (create)
- `tools/verify/m036-p07-p02-regression-pass.sh` (create)
- `tools/verify/m036-p07-p03-regression-pass.sh` (create)
- `tools/verify/m036-p07-p04-regression-pass.sh` (create)
- `tools/verify/m036-p07-p05-regression-pass.sh` (create)
- `tools/verify/m036-p07-test-harness.sh` (create)
- `tools/verify/m036-p07-acceptance-harness-passes.sh` (create)
- `tools/verify/m036-p07-phase-suite.sh` (create)

## Task Decomposition (4 tasks)

Ordered by dependency. Each task fits in one fresh-context window.

- **T01 — Recipe extension + handle_reference scaffold + shape verifiers** (depends: P04/P05). Adds the `reference:` section + `default_token_budget` to `templates/context-recipe.yaml`. Authors `handle_reference` in `scripts/dispatch/lib/section-handlers.sh` mirroring `handle_spec_context` shape, but stubs the body to return empty (no chunks emitted) so this task lands without changing payload shape. Adds the dispatcher case-branch routing `source: reference` to the stub. Two T01 shape verifiers: `m036-p07-recipe-shape.sh` + `m036-p07-handler-shape.sh`. Lands first because (a) the recipe addition with `priority: optional` + empty handler body produces zero payload delta (CON-1 preserved from T01 onwards), (b) T02 needs the handler skeleton in place to wire the budget governor into.

- **T02 — Token-budget governor + relevance ranker + behavioral verifiers** (depends: T01). Authors `scripts/dispatch/lib/reference-budget.sh` and `scripts/dispatch/lib/reference-relevance.sh` (both pure-lib MEM004; no top-level execution; sourceable). Wires the two libs into `handle_reference`'s body so it now actually pulls + ranks + budget-governs REF-* chunks from `KNOWLEDGE-INDEX.md`. Five T02 verifiers: shape × 2 (budget-lib + relevance-lib) + behavioral × 3 (chunk-level granularity, at-least-one-chunk, deterministic ordering).

- **T03 — Dispatcher integration + fixtures + baseline + cross-phase regressions** (depends: T02). Edits `scripts/dispatch/build-context.sh`'s display-order / name / priority / volatility maps to slot `reference` between `spec_context` (4) and `scope` (5). The omit-empty-section discipline carried from `spec_context` ensures empty-result task plans drop the `## Reference` header entirely. Authors the two synthetic task-plan fixtures and CAPTURES the pre-feature payload baseline as Step 1 (BEFORE editing build-context.sh — load-bearing CON-1/SC-7 sequencing). Authors six T03 verifiers: dispatcher-routes-reference + omit-empty-section + fixture-task-plans-shape + baseline-captured + four cross-phase regression checks (P02 selective + P03 + P04 + P05 full pass-through).

- **T04 — SC-3 + SC-7 acceptance harnesses + phase-suite aggregator** (depends: T03). Authors `tests/test-reference-dispatch-injection.sh` (SC-3 — drives build-context.sh against the topic-tags fixture; asserts ≥1 REF-* chunk present, total reference-section tokens ≤ 4000, and chunk-level dropping; emits `BATTERY:` last line). Authors `tests/test-reference-backwards-compat-golden.sh` (SC-7 — drives build-context.sh against the no-scope fixture; asserts byte-equality against the captured baseline; emits `BATTERY:`). Authors three T04 verifiers: permissive `test-harness.sh` (rc≤1 OK; harness shape only) + strict `acceptance-harness-passes.sh` (rc=0 only) + the 17-gate `phase-suite.sh` aggregator wiring all P07 sub-gates (T01=2 + T02=5 + T03=8 + T04=2).

## Risk Notes

**HIGH RISK — load-bearing backwards-compat gate.** P07 is the only M036a phase that touches the dispatch payload assembly path. CON-1 / SC-7 byte-identical pre-feature payload is the strongest possible regression guard but it is *only* sound if the baseline is captured before T03's dispatcher edits land. The baseline-capture sequencing is called out explicitly in T03's task plan and asserted by `m036-p07-baseline-captured.sh`.

P05's CON-5 default-mode baselines (`tests/fixtures/m036-p05-baseline/{traverse-relates-to.expected.txt,scope-filter-default.expected.txt}`) are byte-equality fixtures that exercise `scripts/knowledge/traverse-graph.sh` + `scripts/dispatch/scope-filter.sh`. P07 *consumes* both unchanged. The `m036-p07-p05-regression-pass.sh` regression check is the load-bearing assertion that P07 did not perturb either; if it ever fails post-P07, the failure points directly at one of P07's deliverables touching one of those scripts (which it should not).

**MEDIUM RISK — Open Question #Q-2 resolution embedded in code.** The plan resolves #Q-2 (relevance ordering) with a hybrid four-key sort (topic-tag overlap → applies_to_field overlap → published recency → chunk_id lex). The decision is captured in `scripts/dispatch/lib/reference-relevance.sh`'s opening header comment; future re-litigation requires editing that file. No DECISIONS.md entry is added — the rationale lives at the implementation site (matches M036's `key_decisions: none` posture across P02/P03/P04/P05; reusable conventions, not architectural commitments).

**LOW RISK — host-tool absence.** No new external tools required. The token-estimation helper is already in `build-context.sh` (M018 character-count / 4 estimate). The governor is pure shell. The acceptance harnesses are pure shell + `cmp -s` for byte-equality.

## Verification

Phase verification runs the aggregator:

```bash
bash tools/verify/m036-p07-phase-suite.sh
```

Expected output (last line): `SUMMARY: m036-p07-phase-suite.sh pass=17 fail=0`.

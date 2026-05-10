---
schema_version: "1.0"
type: task-summary
task: "T02"
phase: "P01"
milestone: "M037"
name: "Stub version: → title: projection + Typeset evaluation gate + nav generator pass-through"
---

## Typeset Evaluation Gate Outcome

**Verdict**: Typeset does NOT subsume FR-5. Proceeding with full FR-5 scope.

**Justification**: WebFetch of <https://squidfunk.github.io/mkdocs-material/plugins/typeset/>
confirms the plugin operates on rendered HTML heading-text formatting — its
input is the page's headlines (preserving `<code>`, `<em>`, icons, etc. that
MkDocs would otherwise drop when extracting plain text for nav/TOC). It does
NOT project frontmatter fields like `version:` into the navigation title.
FR-5 requires reading source-chunk frontmatter and writing projected stub
frontmatter — a different layer of the pipeline. Gate falls through; full
FR-5 + FR-6 + MIT-01/MIT-02 implementation lands in this task.

Doc URL: <https://squidfunk.github.io/mkdocs-material/plugins/typeset/>

## What changed

- `scripts/wiki/wiki-generate-stubs.sh` — added three helpers:
  `read_frontmatter_field` (POSIX-sh + awk single-field reader),
  `derive_stub_title` (FR-5 projector: `version:` → `title:` with slug
  fallback and `WIKI_DEBUG=1` diagnostic), and
  `existing_stub_is_protected` (MIT-01 P0 escape-hatch detector). Wired
  the projection into `write_stub`, `write_stub_extra_with_sibling`, and
  `write_stub_extra_metadata_only`. Wired the escape-hatch gate at the
  top of all three write functions AND in `clean_phase` (so re-runs do
  not wipe operator-edited stubs before the write-time gate fires).
- `scripts/wiki/wiki-generate-nav.sh` — added `read_stub_title` helper
  and `emit_leaf_prefer_stub_title` variant of `emit_leaf` (FR-6).
  Switched the `extra:*` and `knowledge-flat` leaf emitters to the
  variant. Milestone-artifact emitters keep the legacy `emit_leaf` so
  per-shape labels (Plan, Summary, Tasks) do not regress to slug-titles.
- `tests/fixtures/m037-version-projection/` — five-file corpus:
  `chunk-a.md` (plain version), `chunk-b.md` (markdown-active version),
  `chunk-c.md` (no version), `chunk-d-escape-hatch.md` (companion source
  for MIT-02), `preexisting-stub.md` (operator-edited stub staged before
  the run).
- `tools/verify/m037-p01-version-to-title.sh` — Truth #2 verifier
  (5 assertions covering helpers + wiring + FR-6 nav variant).
- `tools/verify/m037-p01-auto-generated-escape-hatch.sh` — Truth #3
  verifier (4 assertions covering helper + marker + write-time gates +
  clean-time gate).
- `tests/m037-acceptance/p01-version-to-nav-title.sh` — SC-2 acceptance
  test (220 lines, contains the `auto_generated: false` literal). Stages
  a temp project root with the fixture chunks under a synthetic
  `refs-corpus/` extra_dir, runs the stub generator twice, asserts each
  emitted stub's `title:` matches expected, and asserts MIT-02
  byte-identical preservation across re-runs.

## Verification

```bash
bash tools/verify/m037-p01-version-to-title.sh
# pass=5 fail=0  -> exit 0  -> "PASS: m037-p01-version-to-title"

bash tools/verify/m037-p01-auto-generated-escape-hatch.sh
# pass=4 fail=0  -> exit 0  -> "PASS: m037-p01-auto-generated-escape-hatch"

bash tests/m037-acceptance/p01-version-to-nav-title.sh
# pass=7 fail=0  -> exit 0  -> "PASS: p01-version-to-nav-title (4/4 fixtures)"
```

T01's verifier and acceptance tests still pass after this change
(`m037-p01-card-grid` 4/4; `p01-card-grid-homepage` 15/15) — no
regression in the T01 surface.

## Surfaces / decisions

- **Surface B (frontmatter-reader helper)**: chose option (a) — extracted
  a new `read_frontmatter_field` helper rather than inlining awk in
  `derive_stub_title` (option b) or reshaping the existing whole-block
  helpers (option c). Reasoning: the helper is reused by
  `existing_stub_is_protected` (reads `auto_generated`) and the parallel
  `read_stub_title` helper in the nav generator follows the same shape.
  Inlining awk three times would duplicate the same 11 lines; the helper
  is the smaller surface. The existing whole-block helpers
  (`emit_frontmatter_metadata_table`, `body_is_empty`) target different
  output shapes and would be churned to no benefit.

- **Surface E (clean_phase ordering)**: confirmed the operator briefing's
  concern. `clean_phase` runs BEFORE the main loop and would wipe
  protected stubs before any `write_stub*` could fire its gate. Both
  gates are required: `clean_phase` skips protected stubs to preserve
  them across re-runs; `write_stub*` skips them to preserve them when
  the source chunk would re-derive the title. Verifier #4 (clean-time
  gate) explicitly checks the `STUB-PRESERVED ... clean_phase` log line
  to ensure a future refactor cannot silently drop the clean-time
  preservation.

- **Surface (nav-generator selectivity)**: FR-6 spec text says
  "wiki-generate-nav.sh MUST honor stub `title:`" without qualification.
  A naive implementation (override emit_leaf unconditionally to read
  every stub's `title:`) would regress milestone-artifact nav: today the
  generator emits `- Plan: P01-PLAN.md`; with the naive override the
  stub `title: "P01-PLAN"` would replace "Plan", which is worse UX. The
  per-shape labels (`milestone_artifact_label`, `phase_artifact_label`)
  are MORE human-friendly than the source-H1-derived stub titles for
  milestone artifacts. Solution: introduce `emit_leaf_prefer_stub_title`
  as a sibling of `emit_leaf` and switch only the reference-corpus
  surfaces (`extra:*`, `knowledge-flat`) — those are exactly the
  surfaces US-2 targets ("70+ entries titled REF-cms-rule-..."). The
  milestone surface is unaffected.

- **Surface D (real-corpus version: assertion)**: the orchestrator's own
  reference corpus is empty in this repo (no `references/` chunks carry
  `version:` frontmatter; `references/*.md` are author-shaped reference
  docs, not extracted chunks). The acceptance test uses synthetic
  fixtures so this is non-blocking, but operators verifying FR-5 against
  PBJ-central's corpus must confirm M036a Tier 0/1/2 chunks carry
  `version:` end-to-end before declaring SC-2 closed in production.

## Notes for downstream

- **T05 plugin enable list**: T01 surfaced that emoji shortcodes
  (`:fontawesome-solid-X:`, `:octicons-arrow-right-24:`) render as
  literal text without `pymdownx.emoji` enabled. T05's plan currently
  lists `pymdownx.details` + `pymdownx.tasklist` but does NOT list
  `pymdownx.emoji`. Whoever runs T05 should add `pymdownx.emoji` to the
  enable list (or confirm it is implicitly enabled by Material defaults
  in the target template). T01's final card-grid output uses
  `:octicons-arrow-right-24:` and `:fontawesome-solid-*:` shortcodes;
  validating that they render correctly is part of T05's mkdocs.yml
  template polish.

- **T03 (DR-### heading shape)** is independent of T02 and operates on
  source-side authoring (heading shape in `DECISIONS.md`), not on the
  projection layer. No interaction.

- **T04 (mkdocs.yml template polish — navigation.tabs, toc_depth,
  edit_uri)** is independent of T02. The
  `navigation.tabs` config will benefit from FR-5+FR-6 because the
  reference-corpus tab will read as human strings rather than slug-soup,
  but the wiring is independent.

- **T06 (install-template config.yml clobber fix)** is independent of T02.

- **For T02-downstream operators running against real PBJ-central
  corpus**: confirm M036a chunks carry `version:` frontmatter on Tier
  0/1/2 outputs end-to-end. This is asserted by spec A2 and unblocked at
  M036a closure (2026-05-02), but worth a smoke check before declaring
  SC-2 closed in production. The acceptance test uses synthetic fixtures
  per the plan; production behavior depends on the real corpus shape.

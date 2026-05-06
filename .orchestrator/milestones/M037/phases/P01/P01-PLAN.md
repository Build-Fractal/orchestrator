---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M037"
goal: "Wiki team-feedback-ready ship-it minimum"
demo_sentence: "A non-author reader (PBJ domain SME) opens an orchestrator-managed wiki and lands on a card-grid homepage, scans a reference nav of human-readable strings (not slug-soup), reads a decisions TOC of human concepts (not codes), sees top-level sections in a sticky tab header with a 2-level TOC and an edit-this-page affordance, and the operator's `wiki:` block in `.orchestrator/config.yml` survives `orchestrator:update` byte-identical."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- Card-grid template emits a mkdocs-material grid-cards block per declared `wiki.landing_cards:` schema entry (FR-1, FR-2, FR-4)
  - Check: `bash tools/verify/m037-p01-card-grid.sh`
- Stub generator reads source-chunk `version:` frontmatter and emits stub `title:` (FR-5)
  - Check: `bash tools/verify/m037-p01-version-to-title.sh`
- Stub generator preserves `auto_generated: false` operator escape hatch — pre-existing operator-edited stubs survive byte-identical across re-runs (FR-5 / MIT-01 P0)
  - Check: `bash tools/verify/m037-p01-auto-generated-escape-hatch.sh`
- `.orchestrator/DECISIONS.md` matches new heading-shape regex; no row matches the legacy 7-column-table shape; every legacy `#dr-code-nnn`-shaped permalink anchor in cross-referencing files (specs/, phase plans, proposals) resolves (FR-7)
  - Check: `bash scripts/verify/decisions-shape-lint.sh .orchestrator/DECISIONS.md`
- mkdocs.yml template (orchestrator dogfood `wiki/mkdocs.yml` AND install-bundle equivalent) carries the polish bundle: `navigation.tabs` + `navigation.tabs.sticky` + `navigation.prune` in `theme.features`, `toc_depth: 2` under `toc:`, `pymdownx.details` + `pymdownx.tasklist (custom_checkbox: true)` in `markdown_extensions`, `content.action.edit` + `content.action.view` in `theme.features`, `edit_uri:` derived from `repo_url:` (FR-9)
  - Check: `bash tools/verify/m037-p01-mkdocs-polish-bundle.sh`
- Install-template refresh of `.orchestrator/config.yml` and `mkdocs.yml` preserves operator-authored top-level keys byte-identical and merges only orchestrator-managed namespace keys (FR-10, CON-3, MIT-03 P0)
  - Check: `bash tools/verify/m037-p01-config-clobber-fix.sh`
- Install-template refresh fails closed on malformed YAML — aborts with diagnostic, writes nothing (FR-11)
  - Check: `bash tools/verify/m037-p01-malformed-yaml-fail-closed.sh`
- `references/authoring-conventions.md` exists and covers (a) DR/BG/AN/MEM/Q-### code conventions with the new heading shape and (b) already-enabled mkdocs-material features authors should leverage (FR-8 + theme-leverage amendment)
  - Check: `bash tools/verify/m037-p01-authoring-conventions-doc.sh`
- `commands/dispatch.md` payload-guidance section references `references/authoring-conventions.md` so future LLM-dispatched task agents emit decision-log entries in the new shape (FR-8)
  - Check: `bash tools/verify/m037-p01-dispatch-references-conventions.sh`

### Artifacts

- templates/wiki-index-cards.md.tmpl (min 5 lines, contains "grid cards")
- references/authoring-conventions.md (min 100 lines, contains "DR-CODE-NNN", "navigation.prune", "pymdownx.details", "Mermaid")
- scripts/lib/yaml-merge.sh (min 30 lines, contains "managed_namespaces")
- scripts/wiki/resolve-default-branch.sh (min 15 lines, contains "symbolic-ref")
- scripts/verify/decisions-shape-lint.sh (min 20 lines, contains "{ #")
- tests/m037-acceptance/run-acceptance-battery.sh (min 20 lines, contains "BATTERY: pass=")
- tests/m037-acceptance/p01-card-grid-homepage.sh (min 20 lines)
- tests/m037-acceptance/p01-version-to-nav-title.sh (min 30 lines, contains "auto_generated: false")
- tests/m037-acceptance/p01-dr-heading-shape.sh (min 20 lines)
- tests/m037-acceptance/p01-mkdocs-polish-bundle.sh (min 20 lines, contains "navigation.prune")
- tests/m037-acceptance/p01-config-clobber-fix.sh (min 30 lines, contains "_orchestrator_managed")

### Key Links

- commands/dispatch.md → references/authoring-conventions.md (payload-guidance reference per FR-8)
- references/authoring-conventions.md → .orchestrator/DECISIONS.md (heading-shape exemplar per FR-7/FR-8)
- scripts/lib/yaml-merge.sh → packaging/install/install-claude-code.sh (consumer of merge primitive per FR-10)
- scripts/wiki/wiki-generate-stubs.sh → templates/wiki-index-cards.md.tmpl (consumer of card-grid template per FR-4)

## Tasks

### T01: Card-grid surface end-to-end (FR-1 + FR-2 + FR-3 + FR-4)

See `tasks/T01-card-grid-surface-PLAN.md`.

### T02: Stub `version:` → `title:` projection + Typeset evaluation gate + nav generator pass-through (FR-5 + FR-6 + MIT-01/MIT-02 P0 escape hatch)

See `tasks/T02-version-to-title-projection-PLAN.md`.

### T03: DR-### heading-shape pivot for this repo (FR-7) + shape-lint verifier (#Q-7 resolved)

See `tasks/T03-decisions-shape-pivot-PLAN.md`.

### T04: Authoring conventions doc (FR-8 + theme-leverage extension)

See `tasks/T04-authoring-conventions-doc-PLAN.md`.

### T05: CON-4 default-branch helper + mkdocs.yml polish bundle (FR-9)

See `tasks/T05-mkdocs-polish-bundle-PLAN.md`.

### T06: Shared YAML-merge primitive + install-template emission for config.yml + mkdocs.yml + acceptance battery aggregator scaffold (FR-10 + FR-11 + SC-12)

See `tasks/T06-yaml-merge-and-install-emission-PLAN.md`.

## Task Dependencies

```
T01  (card-grid template + schema + projection)
T02  (version: → title: + Typeset gate + nav pass-through)
T03  (DECISIONS.md restructure + decisions-shape-lint.sh)
T04  ──depends-on──> T03  (authoring conventions doc names the new heading shape)
T05  (resolve-default-branch.sh + mkdocs.yml polish bundle)
T06  ──depends-on──> T01, T05
       (yaml-merge.sh consumes the wiki.landing_cards: schema added by T01;
        T05 ships mkdocs.yml polish that T06 must preserve operator-authored
        keys against — T06 verifier exercises round-trip refresh.)
```

T01, T02, T03, T05 can be planned/executed in parallel — no inter-task file dependencies. T04 reads T03's restructured DECISIONS.md to author exemplar excerpts. T06 consumes T01's `wiki.landing_cards:` schema entry in `templates/orchestrator-config-default.yml` and T05's polish-bundle additions to `wiki/mkdocs.yml` for the round-trip refresh fixture.

## Files Likely Touched

- templates/wiki-index-cards.md.tmpl (create)
- templates/orchestrator-config-default.yml (modify — add `wiki:` block with `landing_cards:` empty list)
- scripts/wiki/wiki-generate-stubs.sh (modify — add card-grid projection + `version:` → `title:` + auto_generated escape hatch)
- scripts/wiki/wiki-generate-nav.sh (modify — honor stub `title:` if it does not already)
- scripts/wiki/resolve-default-branch.sh (create)
- wiki/docs/index.md (modify — projected from card-grid template)
- wiki/mkdocs.yml (modify — polish bundle additions)
- .orchestrator/DECISIONS.md (modify — restructure from 7-column markdown table to `### Title { #dr-code-nnn }` heading entries with code-chip body markup)
- references/authoring-conventions.md (create)
- commands/dispatch.md (modify — payload-guidance reference to authoring-conventions doc)
- scripts/lib/yaml-merge.sh (create)
- scripts/verify/decisions-shape-lint.sh (create)
- packaging/install/install-claude-code.sh (modify — replace cfg_target write block with yaml-merge.sh invocation)
- packaging/install/install-codex.sh (modify — same as install-claude-code.sh for parity)
- packaging/install/install-cursor.sh (modify — same as install-claude-code.sh for parity)
- scripts/lifecycle/wiki-init.sh (modify — apply yaml-merge.sh to `mkdocs.yml` template-emit path on refresh per CON-3)
- tests/m037-acceptance/run-acceptance-battery.sh (create)
- tests/m037-acceptance/p01-card-grid-homepage.sh (create)
- tests/m037-acceptance/p01-version-to-nav-title.sh (create)
- tests/m037-acceptance/p01-dr-heading-shape.sh (create)
- tests/m037-acceptance/p01-mkdocs-polish-bundle.sh (create)
- tests/m037-acceptance/p01-config-clobber-fix.sh (create)
- tests/fixtures/m037-version-projection/ (create — chunk corpus for T02)
- tests/fixtures/m037-config-merge/ (create — config-merge fixture for T06)
- tools/verify/m037-p01-card-grid.sh (create — Truth #1 verifier)
- tools/verify/m037-p01-version-to-title.sh (create — Truth #2 verifier)
- tools/verify/m037-p01-auto-generated-escape-hatch.sh (create — Truth #3 verifier)
- tools/verify/m037-p01-mkdocs-polish-bundle.sh (create — Truth #5 verifier)
- tools/verify/m037-p01-config-clobber-fix.sh (create — Truth #6 verifier)
- tools/verify/m037-p01-malformed-yaml-fail-closed.sh (create — Truth #7 verifier)
- tools/verify/m037-p01-authoring-conventions-doc.sh (create — Truth #8 verifier)
- tools/verify/m037-p01-dispatch-references-conventions.sh (create — Truth #9 verifier)
- tools/verify/m037-p01-phase-suite.sh (create — phase-suite aggregator that invokes every Truth Check + invokes `scripts/verify/decisions-shape-lint.sh .orchestrator/DECISIONS.md`)
- tools/verify/m037-p01-scope-guard.sh (create — flags any modifications outside the declared "Files Likely Touched" surface)

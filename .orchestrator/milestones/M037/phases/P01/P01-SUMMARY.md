---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M037"
milestone: "M037"
provides:
  - "templates/wiki-index-cards.md.tmpl + wiki.landing_cards: schema in templates/orchestrator-config-default.yml + render_landing_cards in scripts/wiki/wiki-generate-stubs.sh + wiki/docs/index.md grid-cards block (FR-1/FR-2/FR-3/FR-4),wiki-generate-stubs.sh derive_stub_title() reading version: from frontmatter + write_stub projecting to title: + wiki-generate-nav.sh emit_leaf_prefer_stub_title() + auto_generated: false escape hatch (FR-5/FR-6/MIT-01/MIT-02),.orchestrator/DECISIONS.md restructured from 7-column markdown table (28 D### rows) to 28 ### Title { #dr-code-NNN } heading entries with attr_list anchors + body chips + framework-owned shape-lint at scripts/verify/decisions-shape-lint.sh + tools/verify/m037-p01-decisions-shape.sh wrapper (FR-7),references/authoring-conventions.md (278 lines) covering DR/BG/AN/MEM/Q-### code conventions + already-enabled mkdocs-material features (Mermaid, pymdownx.details, navigation.prune, content tabs, attr_list status chips) + commands/dispatch.md ## Payload Guidance section referencing it + wiki/docs/stylesheets/code-chips.css plug-in-free pill styling + extra_css: declaration in wiki/mkdocs.yml (FR-8 + theme-leverage),scripts/wiki/resolve-default-branch.sh CON-4 helper + wiki/mkdocs.yml polish bundle (theme.features navigation.tabs/sticky/prune + content.action.edit/view, toc_depth: 2, markdown_extensions pymdownx.details + pymdownx.tasklist with custom_checkbox: true, top-level edit_uri: derived from repo_url:) + scripts/lifecycle/wiki-init.sh fifth-field substitution for edit_uri: (FR-9 + CON-4),scripts/lib/yaml-merge.sh shared YAML-merge primitive (sed/awk only, fail-closed on malformed YAML) + 3-installer cfg_target write block migration (install-claude-code.sh / install-codex.sh / install-cursor.sh) + wiki-init.sh post-sed yaml-merge invocation for mkdocs.yml refresh + tests/m037-acceptance/run-acceptance-battery.sh aggregator (BATTERY: pass=N skip=M fail=K) + tests/fixtures/m037-config-merge/ corpus + Truth #6/#7 verifiers (FR-10/FR-11/CON-3/MIT-03/MIT-03 P0),tools/verify/m037-p01-phase-suite.sh straight-line aggregator (9 gates, OK at 9/9 PASS)"
requires:
  - "none"
affects:
  - "M037 P02 — round 3.5 polish (F1.2 tag-driven nav subgrouping + F2 GitHub source-link + F5 knowledge card grid + 3 plugins). Demand-driven; ships after first PBJ feedback signal lands."
  - "M035 P02–P06 — packaging & distribution. P01's yaml-merge primitive becomes the canonical install-template refresh path; M035 must address packaging/bundle/config/orchestrator.default.yml stub divergence (see paper-cut)."
key_files:
  - "templates/wiki-index-cards.md.tmpl,templates/orchestrator-config-default.yml,scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/resolve-default-branch.sh,wiki/docs/index.md,wiki/docs/stylesheets/code-chips.css,wiki/mkdocs.yml,.orchestrator/DECISIONS.md,references/authoring-conventions.md,commands/dispatch.md,scripts/verify/decisions-shape-lint.sh,scripts/lib/yaml-merge.sh,scripts/lifecycle/wiki-init.sh,packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tests/m037-acceptance/run-acceptance-battery.sh,tests/m037-acceptance/p01-card-grid-homepage.sh,tests/m037-acceptance/p01-version-to-nav-title.sh,tests/m037-acceptance/p01-dr-heading-shape.sh,tests/m037-acceptance/p01-mkdocs-polish-bundle.sh,tests/m037-acceptance/p01-config-clobber-fix.sh,tests/fixtures/m037-config-merge/,tools/verify/m037-p01-card-grid.sh,tools/verify/m037-p01-version-to-title.sh,tools/verify/m037-p01-auto-generated-escape-hatch.sh,tools/verify/m037-p01-decisions-shape.sh,tools/verify/m037-p01-authoring-conventions-doc.sh,tools/verify/m037-p01-dispatch-references-conventions.sh,tools/verify/m037-p01-mkdocs-polish-bundle.sh,tools/verify/m037-p01-config-clobber-fix.sh,tools/verify/m037-p01-malformed-yaml-fail-closed.sh,tools/verify/m037-p01-phase-suite.sh"
key_decisions:
  - "FR-1,FR-2,FR-3,FR-4,FR-5,FR-6,FR-7,FR-8,FR-9,FR-10,FR-11,MIT-01,MIT-02,MIT-03,CON-1,CON-3,CON-4,AD-19,DISP-1,Q-3,Q-4,Q-7,Surface-E-Option-B,SC-1,SC-2,SC-3,SC-4,SC-5"
patterns_established:
  - "Body-chip pattern for code-anchored entries: `<span class=\"md-tag md-tag-icon md-tag--<class>\">CODE</span>` with `{: .code-chip-row }` attr_list + plugin-free CSS at wiki/docs/stylesheets/code-chips.css; reusable across DR/BG/AN/MEM/Q-### prefixes; framework-owned shape-lint at scripts/verify/decisions-shape-lint.sh enforces heading regex + anchor uniqueness + zero-legacy-row invariant,Sentinel-bracketed mkdocs.yml additions: # >>> M0##-P##-T## <key> ... # <<< M0##-P##-T## end pattern (mirrors existing M012-P03 Giscus convention) — survives yaml-merge round-trip via per-top-level-key replacement under managed namespaces,Line-oriented YAML-merge primitive (bash 3.2 + POSIX sh + sed/awk only, NO yq/python): top-level keys detected via ^[a-zA-Z_][a-zA-Z0-9_-]*: regex; per-key dispatch on managed-vs-operator classification; sub-key-aware merge for managed namespaces with sub-keys (preserves operator content byte-identical, adds new framework sub-keys); fail-closed on YAML parse error (exit 4 + diagnostic + no write); reusable across config.yml + mkdocs.yml + future YAML targets,CON-4 fail-back-to-main default-branch helper: scripts/wiki/resolve-default-branch.sh always exits 0 with a usable branch name (real or 'main' fallback) — downstream consumers can rely on non-empty stdout. Reusable by P02's FR-13 GitHub source-link rewrite,Synthetic-git-remote test fixture: mktemp -d + git init + git remote add origin <fake-url> + manual git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main — resolves CON-4 helper without network access. Reusable for any acceptance test exercising remote-aware paths,Phase-suite aggregator with straight-line invocation per AD-19 — no loops, no compound chains; 9 gates × 'bash <verifier>' + accumulator; emits canonical SUMMARY: pass=N fail=M line; mirrors m029-p01-phase-suite.sh shape"
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P01/tasks/T01-card-grid-surface-PLAN.md (no SUMMARY — committed pre-orchestrator-loop), .orchestrator/milestones/M037/phases/P01/tasks/T02-version-to-title-projection-SUMMARY.md, .orchestrator/milestones/M037/phases/P01/tasks/T03-decisions-shape-pivot-SUMMARY.md, .orchestrator/milestones/M037/phases/P01/tasks/T04-authoring-conventions-doc-SUMMARY.md, .orchestrator/milestones/M037/phases/P01/tasks/T05-mkdocs-polish-bundle-SUMMARY.md, .orchestrator/milestones/M037/phases/P01/tasks/T06-yaml-merge-and-install-emission-SUMMARY.md"
duration: "≈ 4h (T03-T06 wall-clock; T01/T02 pre-orchestrator-loop)"
verification_result: "pass"
completed_at: "2026-05-06T20:30:00Z"
observability_surfaces:
  - "tests/m037-acceptance/run-acceptance-battery.sh (BATTERY: pass=5 skip=0 fail=0)"
  - "tools/verify/m037-p01-phase-suite.sh (SUMMARY: pass=9 fail=0)"
---

## What Shipped

P01 ships the **wiki team-feedback-ready ship-it minimum** for M037 — six task tranches landing the seven Truths the M037 brief named load-bearing for opening the wiki to the PBJ-central team this week. Goal verbatim from the phase plan: "A non-author reader (PBJ domain SME) opens an orchestrator-managed wiki and lands on a card-grid homepage, scans a reference nav of human-readable strings (not slug-soup), reads a decisions TOC of human concepts (not codes), sees top-level sections in a sticky tab header with a 2-level TOC and an edit-this-page affordance, and the operator's `wiki:` block in `.orchestrator/config.yml` survives `orchestrator:update` byte-identical."

The six task tranches:

1. **T01 — Card-grid surface end-to-end (FR-1/2/3/4, commit `deef3e96`)**: ships `templates/wiki-index-cards.md.tmpl`, the `wiki.landing_cards:` schema entry in `templates/orchestrator-config-default.yml`, the `render_landing_cards` function in `scripts/wiki/wiki-generate-stubs.sh`, and the rendered grid-cards block in `wiki/docs/index.md`.

2. **T02 — `version:` → `title:` projection + auto_generated escape hatch (FR-5/6 + MIT-01/02, commit `8f77d453`)**: ships `derive_stub_title()` and `existing_stub_is_protected()` helpers in `scripts/wiki/wiki-generate-stubs.sh`, `emit_leaf_prefer_stub_title()` in `scripts/wiki/wiki-generate-nav.sh`. Operator-edited stubs declaring `auto_generated: false` survive byte-identical across re-runs.

3. **T03 — DECISIONS.md heading-shape pivot + framework-owned shape-lint (FR-7, commit `e3b8696c`)**: restructures `.orchestrator/DECISIONS.md` from a 7-column markdown table (28 `| Dnnn |` rows, D001–D028) into 28 `### Title { #dr-code-NNN }` heading entries with `attr_list` anchors and body chips. Framework-owned `scripts/verify/decisions-shape-lint.sh` enforces the heading-shape regex + anchor uniqueness + zero-legacy-row invariant. One inbound permalink rewrite landed (`specs/022-spec-wiki/spec.md` `#d009` → `#dr-code-009`); below the 50-ref blast-radius surface threshold.

4. **T04 — Authoring conventions doc + dispatch payload-guidance + Surface E code-chip CSS (FR-8 + theme-leverage, commit `2031a9af`)**: ships `references/authoring-conventions.md` (278 lines) covering (a) DR/BG/AN/MEM/Q-### code conventions with the new heading-shape and body-chip pattern (verbatim D003 before/after exemplar), and (b) already-enabled mkdocs-material features authors should leverage (Mermaid, content reuse, admonitions, attr_list status chips, content tabs, plus T05's incoming pymdownx.details + pymdownx.tasklist + navigation.prune polish-bundle additions). `commands/dispatch.md` gains a `## Payload Guidance` section referencing the doc. **T03 Surface E follow-up folded in (Option B)**: `wiki/docs/stylesheets/code-chips.css` (~33 lines, plugin-free pill styling for code chips) + `extra_css:` declaration in `wiki/mkdocs.yml`. Plugin-free per CON-1; reversible if a future milestone adopts Material's `tags:` plugin.

5. **T05 — CON-4 default-branch helper + mkdocs.yml polish bundle (FR-9 + CON-4, commit `a4ea4cd6`)**: ships `scripts/wiki/resolve-default-branch.sh` (CON-4 helper, falls back to `main` on any failure mode, always exits 0). `wiki/mkdocs.yml` gains nine polish-bundle additions: `theme.features` adds `navigation.tabs` / `navigation.tabs.sticky` / `navigation.prune` (top of list) + `content.action.edit` / `content.action.view` (bottom); `markdown_extensions` modifies the `toc:` block to add `toc_depth: 2` and appends `pymdownx.details` + `pymdownx.tasklist:` (with `custom_checkbox: true`); a top-level `edit_uri:` is derived from `repo_url:` at template-emit time. `scripts/lifecycle/wiki-init.sh` extends the four-field substitution block to a fifth field (`edit_uri:`); US-4 AS-4 edge case (operator unset `repo_url:`) skips `edit_uri:` injection with a diagnostic. `pymdownx.details` and `pymdownx.tasklist` are built into the existing `pymdown-extensions` package — no `wiki/requirements.txt` change required (CON-1).

6. **T06 — Shared YAML-merge primitive + 3-installer config emission + acceptance battery scaffold + Truth #6/#7 (FR-10/11 + CON-3 + MIT-03 P0, commit `702c8dbf`)**: ships `scripts/lib/yaml-merge.sh` (shared YAML-merge primitive — bash 3.2 + POSIX sh + sed/awk only, NO `yq`/`python`; subcommand interface `merge --target <file> --framework-default <file> --managed-namespaces <comma-list> [--dry-run]`; per-top-level-key dispatch on managed-vs-operator classification; sub-key-aware merge for managed namespaces with sub-keys; fail-closed on YAML parse error with exit 4). All three installers (`install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`) replace their pre-M037 "skip if exists / overwrite with --force" `cfg_target` write block with a `yaml-merge.sh merge` invocation. `wiki-init.sh` invokes `yaml-merge.sh` against the staged `mkdocs.yml` after the field-line rewrite to preserve operator-authored top-level keys. `tests/m037-acceptance/run-acceptance-battery.sh` aggregates SC-1..SC-5; expected output `BATTERY: pass=5 skip=0 fail=0` after T01..T06 land. `tests/fixtures/m037-config-merge/` corpus exercises operator-authored key preservation (`pbj_team_dashboard_url:` + 3-entry `wiki.landing_cards:`). Truth #6 + Truth #7 verifiers + SC-5 acceptance test all green.

## Verification Results

`tools/verify/m037-p01-phase-suite.sh`: **PASS — 9/9 gates green**:

```
OK: m037-p01-card-grid.sh
OK: m037-p01-version-to-title.sh
OK: m037-p01-auto-generated-escape-hatch.sh
OK: m037-p01-decisions-shape.sh
OK: m037-p01-authoring-conventions-doc.sh
OK: m037-p01-dispatch-references-conventions.sh
OK: m037-p01-mkdocs-polish-bundle.sh
OK: m037-p01-config-clobber-fix.sh
OK: m037-p01-malformed-yaml-fail-closed.sh
SUMMARY: m037-p01-phase-suite.sh pass=9 fail=0
```

`tests/m037-acceptance/run-acceptance-battery.sh`: **BATTERY: pass=5 skip=0 fail=0** (SC-1..SC-5 covered in P01; SC-6..SC-12 ride P02 + milestone close).

## Key Decisions

- **Surface E Option B (T04 fold-in, plugin-free CSS)**: `wiki/docs/stylesheets/code-chips.css` + `extra_css:` declaration over Material's `tags:` plugin (Option A) or deferral (Option C). Rationale: plugin-free preserves CON-1; doesn't entangle with T05's in-flight `markdown_extensions:` polish bundle; reversible if a future milestone adopts the `tags:` plugin (chip classes pick up Material's built-in pill styling automatically).
- **`extra_css` namespace classification (T06 executor-time addendum)**: classified as orchestrator-managed in T06's `wiki-init.sh` MKDOCS_MANAGED list. T04 added the namespace AFTER T06's plan was authored, so the plan's mkdocs.yml managed-namespace table didn't list it. Sub-key-aware merge preserves any operator-authored extra `- stylesheets/*.css` entries while ensuring the framework-supplied `- stylesheets/code-chips.css` always renders.
- **Plan §33 vs §145 yaml-merge semantics resolution (T06)**: managed namespaces with sub-keys use sub-key-aware merge (preserves operator content byte-identical, adds new framework sub-keys); managed flat scalars/lists use framework-wins. Resolves SC-5 verifier requirement: operator's 3-entry `wiki.landing_cards:` survives byte-identical AND framework can introduce `wiki.nav_buckets:` on schema evolution.
- **DISP-1 PBJ-central cross-reference deferred**: PBJ-central's `.orchestrator/config.yml` not accessible from the executor at dispatch time. Per plan §143-147 fallback, the 15-key cross-reference table in T06's plan is the authoritative classification. Fail-closed design (operator-only keys preserved byte-identical at original relative position) makes silent re-classification structurally impossible.

## Patterns Established

- **Body-chip pattern for code-anchored entries**: `<span class="md-tag md-tag-icon md-tag--<class>">CODE</span>` with `{: .code-chip-row }` attr_list, plugin-free CSS at `wiki/docs/stylesheets/code-chips.css`. Reusable across DR/BG/AN/MEM/Q-### prefixes; framework-owned shape-lint enforces heading regex + anchor uniqueness + zero-legacy-row invariant.
- **Sentinel-bracketed mkdocs.yml additions**: `# >>> M0##-P##-T## <key> ... # <<< M0##-P##-T## end` (mirrors existing M012-P03 Giscus convention). Survives yaml-merge round-trip via per-top-level-key replacement under managed namespaces.
- **Line-oriented YAML-merge primitive** (bash 3.2 + POSIX sh + sed/awk only, NO `yq`/`python`): per-top-level-key dispatch on managed-vs-operator classification; sub-key-aware merge for managed namespaces with sub-keys; fail-closed on YAML parse error. Reusable across `config.yml` + `mkdocs.yml` + future YAML targets.
- **CON-4 fail-back-to-`main` default-branch helper**: `scripts/wiki/resolve-default-branch.sh` always exits 0 with a usable branch name. Downstream consumers rely on non-empty stdout; reusable by P02's FR-13 GitHub source-link rewrite.
- **Synthetic-git-remote test fixture**: `mktemp -d` + `git init` + `git remote add origin <fake-url>` + manual `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main`. Resolves CON-4 helper without network access; reusable for any acceptance test exercising remote-aware paths.
- **Phase-suite aggregator with straight-line invocation per AD-19**: 9 gates × `bash <verifier>` + accumulator; emits canonical `SUMMARY: pass=N fail=M` line; mirrors `m029-p01-phase-suite.sh` shape.

## Affects Downstream

- **M037 P02 (round 3.5 polish, demand-driven)** — consumes T01's `wiki.landing_cards:` schema for F5 knowledge card grid, T03's heading-shape exemplar for F1.2 tag-driven nav subgrouping conventions, T05's CON-4 default-branch helper for F2 GitHub source-link rewrite, and T06's yaml-merge primitive for any P02 schema additions. Ships after first PBJ feedback signal lands.
- **M035 P02–P06 (packaging & distribution, blocked by P02)** — consumes T06's yaml-merge primitive as the canonical install-template refresh path. **Blocking finding**: `packaging/bundle/config/orchestrator.default.yml` is a 12-line stub, not a copy/symlink of the canonical 175-line `templates/orchestrator-config-default.yml`. T01's `wiki: landing_cards: []` schema does not reach consumer projects via the install bundle today. Captured as paper-cut at `.orchestrator/proposals/papercut-bundle-config-stub-divergence.md`; M035 must address before launch.

## Deferred / Out-of-Scope

- **`tools/verify/m037-p01-scope-guard.sh`** — listed in plan's "Files Likely Touched" surface (line 133) but not built. Scope-guard requires a baseline-ref capture and is mostly forward-looking (catches future drift). Verification surface is fully covered by the 9-gate phase-suite + 5-test acceptance battery for P01 close. Can be added pre-M035 if desired; not blocking PBJ-team ship.
- **`tools/verify/m037-p01-phase-suite-scope-guard.sh`** combined check — same rationale; deferred.

## Pre-Existing Drift Notes

- **`wiki/docs/**` auto-nav drift** — predates this session. Includes regenerated stubs for M032/M033/M029 milestones, new `proposals/` nav block, M032 acceptance evidence stubs. Untouched by P01 task work; will be picked up by the next `wiki-generate-nav.sh` run. Recommend a separate "wiki regen sync" commit before PBJ-team ship so the dogfood wiki reflects current state.
- **`packaging/bundle/config/orchestrator.default.yml` 12-line stub vs canonical 175-line template** — see paper-cut at `.orchestrator/proposals/papercut-bundle-config-stub-divergence.md`. Pre-existing condition, surfaced by T06's path-resolution check; documented for M035 pre-launch.

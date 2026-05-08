---
schema_version: "1.0"
type: milestone-summary
id: "M037"
parent: "038-wiki-team-feedback-ready"
milestone: "M037"
provides:
  - "Wiki team-feedback-ready surface (P01) — homepage card grid + wiki.landing_cards: config schema (FR-1) + version: → nav title via stub generator (FR-5) + DR-### heading-shape pivot + authoring convention (FR-6) + navigation.tabs + toc_depth:2 + content.action.edit (FR-7..FR-9) + install-template config.yml clobber fix (FR-10/FR-11). Publishing-robustness paper-cut bundle (P02) — feedback:* routing arm in stub generator (FR-18) + workflow-based Pages publishing scaffold + wiki-deploy.sh demote to pre-push validation (FR-19/FR-20) + private-repo site_url visibility branch (FR-21) + OUT-OF-SCOPE diagnostic-budget collapse with --verbose escape hatch (FR-22a) + org-level discussions redirect callout in wiki/README.md (FR-22b). PBJ-feedback polish series (P03 round-3.5 / round-3.5-sync / round-4 / round-5) — pymdownx.emoji material.icons generator (P1.1) + render_landing_cards orphan-card pre-filter (P1.2) + wiki-init.sh final-step stubs+nav regen (P1.3) + glossary include-wrapper idempotent stub-replacement (P1.4) + frontmatter version: projection + published:-desc sort (P2.1) + file:// → repo_url/blob/main/ projection in metadata tables (P2.2 partial slice of FR-13) + [unknown] suffix dropped on proposals (P2.3) + wiki/overrides/main.html breadcrumb shim absorbed from PBJ verbatim (P3.1) + file-feedback affordance banner above Comments (P3.2) + framework-managed wiki/overrides/ refresh step in wiki-init.sh (round-4) + dropped navigation.sections from theme.features for collapsible-drawer left-nav (round-5)."
requires:
  - "M032 (wiki distribution + init integration — wiki-init.sh + project_assets surface); M036a (reference-corpus chunks for nav routing); papercut-sweep R1+R2 (pre-M037 wiki diagnostics + install-template fixes)"
affects:
  - "M035 (packaging & distribution — pre-launch wiki polish no longer contaminates launch validation loop); post-launch wiki-ux-deep + external-tool-adapters proposal (FR-12..FR-17 absorbed via M037-fr-12-17-deferred-scope.md); post-launch yaml-merge list-element-preservation fix (round-5 surfaced gap, deferred)"
key_files:
  - "wiki/mkdocs.yml,wiki/overrides/main.html,wiki/overrides/partials/comments.html,wiki/glossary.md,wiki/README.md,scripts/lifecycle/wiki-init.sh,scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-deploy.sh,scripts/diagnostics/wiki-link-check.sh,templates/wiki-index-cards.md.tmpl,scripts/lib/yaml-merge.sh,tests/m037-acceptance/run-acceptance-battery.sh,tests/m037-acceptance/p01-card-grid-homepage.sh,tests/m037-acceptance/p01-feedback-routing.sh,tests/m037-acceptance/p01-out-of-scope-collapse.sh,tests/m037-acceptance/p01-discussions-callout.sh,tests/test-wiki-init-workflow-mode.sh,tests/test-wiki-init-private-site-url.sh,tools/verify/m037-p01-phase-suite.sh,tools/verify/m037-p02-phase-suite.sh,tools/verify/m037-p02-feedback-routing.sh,tools/verify/m037-p02-workflow-pages-publishing.sh,tools/verify/m037-p02-private-site-url.sh,tools/verify/m037-p02-out-of-scope-collapse.sh,tools/verify/m037-p02-discussions-callout.sh,.orchestrator/milestones/M037/M037-SUMMARY.md,.orchestrator/milestones/M037/M037-ACCEPTANCE-EVIDENCE.md,.orchestrator/milestones/M037/M037-VALIDATED,.orchestrator/milestones/M037/execution-log.jsonl,.orchestrator/proposals/M037-fr-12-17-deferred-scope.md"
key_decisions:
  - "FR-1,FR-5,FR-6,FR-7,FR-8,FR-9,FR-10,FR-11,FR-18,FR-19,FR-20,FR-21,FR-22a,FR-22b,US-10,US-11,US-12,US-13,US-14,SC-13,SC-14,SC-15,SC-16,SC-17,Q-6,F8,F9-superseded,F10,F11,F12,F13,B5,MIT-01,MIT-02,MIT-03,AD-19,CON-2,CON-3,CON-4,P03-de-facto-narrowing,FR-12-deferred,FR-13-partial,FR-14-deferred,FR-15-deferred,FR-16-deferred,FR-17-deferred,navigation.sections-dropped,yaml-merge-list-element-gap-deferred"
patterns_established:
  - "Iterative polish loop under live dogfood signal (P03): each round = (1) PBJ install+observe+file defects, (2) tactical bundle commit, (3) push+SHA-range-ping, (4) PBJ retest. Loop terminates on satisfaction signal. Trade-off: faster turnaround on visible-defect remediation; weaker artifact trail (round commits, no per-round task plan) — closure pays the artifact cost retroactively. Pattern reusable when a phase's success contract is dogfood-acceptance rather than mechanical FR coverage,Cross-bundle staging-gap detection: if a bundle change ships content (round-3.5 wiki/overrides/) but install/init paths short-circuit on the surface (operator-owned oracle + PRE_STAGE_NO_OP), the change reaches greenfield only — existing projects need a framework-managed refresh step. Round-4 added that step explicitly for wiki/overrides/. Reusable diagnosis-and-fix pattern for any bundle-staged content type,yaml-merge list-element preservation gap (round-5 discovery): managed top-level key with present sub-key whose value is a YAML list — yaml-merge preserves target's list byte-identical (operator-wins-byte-identical at the sub-key level). Dropping a list element from the framework default does not propagate to existing projects. Pattern: any framework-default change that drops/replaces list elements requires either (a) operator-side manual edit + diagnostic, or (b) yaml-merge primitive extension to support list-managed-namespace semantics. Deferred post-launch,Retroactive plan/summary authoring at closure (P03): when a phase ships as direct commits without going through orchestrator:plan-phase + dispatch, the closure step authors P0X-PLAN.md + P0X-SUMMARY.md retroactively documenting actually-shipped scope. Acceptable when (a) phase scope was de-facto narrowed by external signal mid-flight, (b) the rounds were small enough that per-round task plans would have added overhead without much insight, and (c) the demo sentence is satisfied by an external acceptance signal. NOT acceptable as a default,Card-grid template primitive established in P01 (templates/wiki-index-cards.md.tmpl) — config-only customization via wiki.landing_cards: schema. P03 reuse for /knowledge/ deferred via FR-14 to post-launch but the primitive is in place,Workflow-based Pages publishing handoff-doc-verbatim pattern: P02 emit_pages_workflow() copies .github/workflows/pages.yml byte-identical from PBJ commit e7a722e reference impl. CON-3 no-clobber on pre-existing workflow file. Single-quoted heredoc preserves ${{ ... }} interpolation. Reusable pattern for any future install-template-emitted GitHub Actions workflow,wiki-deploy.sh demote pattern: legacy live-deploy primitive demoted to pre-push validation only — gates 1-4 retained, gate 5 (mkdocs gh-deploy --force) removed, replaced with OWNER/REPO resolver + post-gate report printing 'OK pre-deploy gates PASS. Push to main to trigger workflow deploy: git push origin main' + workflow URL + exit 0 cleanly. Cross-milestone touch on M032's wiki/README.md First-deploy checklist sections rewritten to git-push-triggers-workflow flow (M032 closed, but the closure-set is FR-20-scoped done-definition, not a milestone reopen),OUT-OF-SCOPE diagnostic-budget collapse pattern: two-pass walker writes findings to FINDINGS_FILE then post-pass splits into OOS-vs-non-OOS via grep + per-target tally + emit-or-collapse via awk; THRESHOLD=5 high-fanout collapse (collapsed) marker + BUDGET=5 small-fanout per-occurrence cap (collapsed,budget) marker preserves diagnostic distinction; --verbose escape hatch as bypass-mechanism cat-the-buffer-verbatim path; defaults stay clean for production deploys"
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M037/phases/P02/P02-SUMMARY.md,.orchestrator/milestones/M037/phases/P03/P03-PLAN.md,.orchestrator/milestones/M037/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M037/M037-ACCEPTANCE-EVIDENCE.md,.orchestrator/proposals/M037-fr-12-17-deferred-scope.md"
duration: "spec-amended-twice + three-phases ~36h spec-to-close"
verification_result: "pass"
completed_at: "2026-05-07T20:30:00Z"
observability_surfaces:
  - "tests/m037-acceptance/run-acceptance-battery.sh BATTERY: pass=11 skip=0 fail=0; scripts/verify/wiki-strict-build.sh PASS; scripts/verify/validate-milestone.sh M037 → 71/71; PBJ-central live-dogfood satisfaction signal 2026-05-07 (operator-confirmed)"
---

M037 (wiki team-feedback-ready) closes the orchestrator's pre-launch wiki
readability + discoverability + publishing-robustness gaps that PBJ-central
surfaced during the live dogfood loop opened 2026-05-06. Three phases
(P01 ship-it minimum + P02 publishing-robustness paper-cut bundle + P03
PBJ-feedback polish series) shipped over ~36 hours of spec-amend-and-execute
work, terminating on PBJ-central's live satisfaction signal.

**Three phases, all green** (P01 closed 2026-05-06, P02 closed 2026-05-07,
P03 closed 2026-05-07; acceptance battery `pass=11 skip=0 fail=0`,
validate-milestone 71/71, wiki-strict-build PASS, PBJ live-dogfood signal
positive).

## Phase Rollup

- **P01 (Wiki team-feedback-ready ship-it minimum)** — homepage card grid +
  `wiki.landing_cards:` config schema (FR-1, card-grid template primitive
  established at `templates/wiki-index-cards.md.tmpl`); `version:` → nav
  title via stub generator (FR-5); DR-### heading-shape pivot + authoring
  convention (FR-6); `navigation.tabs` + `navigation.tabs.sticky` +
  `navigation.prune` + `toc_depth: 2` + `content.action.edit` (FR-7..FR-9);
  install-template `config.yml` clobber fix (FR-10/FR-11). Phase-suite
  `pass=9 fail=0`. Closed 2026-05-06 commit `b0fe3588`.

- **P02 (Publishing-robustness paper-cut bundle)** — `feedback:*` routing
  arm in `scripts/wiki/wiki-generate-stubs.sh` mirroring `proposals:*`
  shape (FR-18 / US-10 / SC-13 / B5); workflow-based Pages publishing
  scaffold (FR-19 / US-11 / SC-14, F12 HIGH-severity) — `emit_pages_workflow()`
  + `flip_pages_build_type()` in `wiki-init.sh` emit `.github/workflows/pages.yml`
  verbatim from handoff doc + `gh api -X PUT build_type=workflow`;
  `wiki-deploy.sh` demoted from live-deploy to pre-push validation only
  (FR-20 / US-11) — gates 1-4 retained, gate 5 removed, replaced with
  OWNER/REPO resolver + post-gate report; private-repo `site_url:`
  visibility branch (FR-21 / US-12 / SC-15); OUT-OF-SCOPE diagnostic-budget
  collapse with `--verbose` escape hatch (FR-22a / US-13 / SC-16);
  org-level discussions redirect callout in `wiki/README.md` (FR-22b /
  US-14 / SC-17). Phase-suite `pass=5 fail=0`, acceptance battery
  `pass=10 skip=0 fail=0`. Closed 2026-05-07 commit `d395870d`.

- **P03 (PBJ-feedback polish series — round-3.5 / round-3.5-sync / round-4 / round-5)** —
  De-facto narrowed from formal FR-12..FR-17 scope to a PBJ-driven tactical
  bundle. **Round-3.5** (8 fixes, commit `79b0f7a9`): pymdownx.emoji material.icons
  generator (P1.1); orphan-card pre-filter in `render_landing_cards` (P1.2);
  `wiki-init.sh` final-step stubs+nav regen (P1.3); glossary include-wrapper
  idempotent stub-replacement (P1.4); frontmatter `version:` projection +
  `published:`-desc sort (P2.1); `file://` → `repo_url/blob/main/` projection
  in metadata tables (P2.2, partial slice of FR-13); `[unknown]` suffix
  dropped on proposals (P2.3); `wiki/overrides/main.html` breadcrumb shim
  absorbed from PBJ verbatim (P3.1); file-feedback affordance banner above
  Comments (P3.2). **Round-3.5-sync** (commit `6919bdb9`): wiki regen sync
  projecting round-3.5 polish into the orchestrator's own dogfood wiki tree.
  **Round-4** (commit `19be603d`): framework-managed `wiki/overrides/`
  refresh step in `wiki-init.sh` closing the round-3.5 staging gap where
  `wiki/overrides/main.html` + `partials/comments.html` shipped in the
  bundle but never reached existing projects (operator-owned oracle on
  `wiki/` + `PRE_STAGE_NO_OP` short-circuit). **Round-5** (commit `b81b9334`):
  dropped `- navigation.sections` from `wiki/mkdocs.yml` `theme.features:`
  to restore default Material collapsible-drawer rendering for top-level
  groups (`Reference — CMS rules`, `Milestones`, etc.); `navigation.indexes`
  preserved; yaml-merge no-op gotcha for existing projects documented in
  re-engagement ping. Acceptance battery `pass=11 skip=0 fail=0`;
  wiki-strict-build PASS; PBJ live-dogfood satisfaction signal 2026-05-07.
  FR-12..FR-17 deferred to post-launch via
  `.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`. Closed
  2026-05-07.

## Cross-Phase Inheritance

- **YAML-merge primitive (`scripts/lib/yaml-merge.sh`)** — established at
  P01, consumed by P02 for `site_url:` mutation, and consumed by P03's
  round-5 (where the list-element preservation gap surfaced). The primitive
  is now load-bearing across three M037 phases plus M032 (where it
  originated as a borrow from constitutional design pattern). Round-5
  follow-up: extend with list-managed-namespace semantics or ship
  `--replace-list-keys` flag — deferred post-launch.
- **Card-grid template primitive (`templates/wiki-index-cards.md.tmpl`)** —
  established at P01 (FR-1), reused by P03 round-3.5's
  `render_landing_cards()` orphan-card pre-filter (P1.2). Future FR-14
  `/knowledge/` card grid (deferred post-launch) will reuse the same
  primitive — config-only customization via the `wiki.landing_cards:` (or
  scoped `wiki.knowledge_cards:`) schema.
- **CON-3 (operator-content preservation across orchestrator:update)** —
  honored across all three phases. P01 established the shared YAML-key-preservation
  merge primitive. P02 reused for `site_url:` mutation + `.github/workflows/pages.yml`
  whole-file managed namespace + `wiki/requirements.txt` template-emit-if-absent.
  P03 round-3.5 + round-4 + round-5 honored CON-3 for `wiki/overrides/`
  + `wiki/mkdocs.yml` (with the round-5-surfaced list-element-preservation
  gap noted as a deferred follow-up).
- **CON-2 (projection-not-source-mutation)** — honored across all phases.
  P01's `version:` → stub `title:` operates at projection time (source
  frontmatter unchanged). P03 round-3.5's `file://` rewrite (P2.2) and
  P02's `feedback/<basename>.md` stubs both operate at projection time;
  source files remain authoritative.
- **CON-4 (default-branch fallback to `main`)** — honored across P01 (FR-9
  `edit_uri:`), P02 (FR-19 workflow YAML branch references — currently
  `main` hard-coded per handoff reference impl), and P03 round-3.5 P2.2
  `file://` rewrite. Single helper script `scripts/wiki/resolve-default-branch.sh`
  shipped in P01.

## Verification at Close

- **Acceptance battery** (`tests/m037-acceptance/run-acceptance-battery.sh`):
  `BATTERY: pass=11 skip=0 fail=0` (no skips; no fails).
- **`validate-milestone.sh`**: `VALIDATE: PASS — 71/71 checks passed`.
- **`wiki-strict-build.sh`**: `PASS: wiki-strict-build (0 errors, 0 warnings)`.
- **PBJ-central live-dogfood satisfaction signal**: confirmed 2026-05-07
  after round-5 ("pbj is looking good in the wiki now"). Load-bearing
  acceptance signal for P03's demo sentence under the de-facto narrowing.
- **Per-phase phase-suite**: P01 `pass=9 fail=0`, P02 `pass=5 fail=0`.
  P03 has no formal phase-suite (shipped as direct commits); its
  acceptance signal is the milestone-grain acceptance battery + PBJ
  live-dogfood signal.

## Forward-Pointing Notes

**FR-12..FR-17 deferred to post-launch (`.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`)**

The original P03 scope at `M037-ROADMAP.md:32` (tag-driven nav buckets,
GitHub source-link rewrite Tier 1 pass, `/knowledge/` card grid, plugins,
optional Material `social`+`meta`) was de-facto narrowed by the round-3.5
PBJ-feedback signal. Captured as a post-launch fast-follow. Parent
absorber proposal: `post-launch-wiki-ux-and-adapters.md`. Unblocked when
real PBJ-team navigation-or-section-shape feedback against the live
wiki supplies bucket taxonomy + prioritization signal.

**yaml-merge list-element preservation gap (round-5 discovery, deferred post-launch)**

Surface area: `scripts/lib/yaml-merge.sh`. Two paths forward:
(a) extend the primitive with list-managed-namespace semantics (framework-replace
whole list when sub-key is in managed namespace), or (b) ship a
`--replace-list-keys` flag for opt-in list replacement. Touches the merge
primitive load-bearing for both `mkdocs.yml` and
`orchestrator-config-default.yml`, so requires careful regression coverage.
Existing operators (PBJ-central) received manual-edit guidance in the
round-5 re-engagement ping; not blocking M037 closure.

**M035 (packaging & distribution) unblocked**

M037's pre-launch role was to make the wiki team-feedback-ready so that
wiki-quality noise wouldn't contaminate the M035-launch validation loop.
With M037 closed and PBJ live-dogfood satisfaction confirmed, M035 P00+P01
can enter as the next pre-launch milestone (`--mode=symlink` install +
`orchestrator:status` version-drift warning), followed by M035 P02–P06
which IS the launch event (npm + homebrew + curl-pipe-bash publishing
pipelines).

**Parallel pre-launch operational follow-ups**

- **M033 friendly-tester pass before 2026-05-12** — protocol at
  `tests/m033-acceptance/friendly-tester-pass/protocol.md`. 5 days out.
  Recommend slotting between M035 entry and M035 P00+P01 close.
- **M036a P03 live-LLM smoke** — closed 2026-05-07 commit `c03efcc4`
  (extract-side risk retired via real `claude -p` invocation through
  `extract_tier_2_dispatch` `live` mode against synthetic
  representative-of-PBJ fixture).

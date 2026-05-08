---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M037"
milestone: "M037"
authoring_mode: "retroactive"
provides:
  - "PBJ-feedback-driven polish bundle (round-3.5 / round-3.5-sync / round-4 / round-5; commits 79b0f7a9, 6919bdb9, 19be603d, b81b9334). Round-3.5 (8 fixes): pymdownx.emoji material.icons generator (P1.1) + render_landing_cards orphan-card pre-filter (P1.2) + wiki-init.sh final-step stubs+nav regen (P1.3) + glossary include-wrapper idempotent stub-replacement (P1.4) + frontmatter version: projection + published:-desc sort (P2.1) + file:// → repo_url/blob/main/ projection in metadata tables (P2.2) + [unknown] suffix dropped on proposals (P2.3) + wiki/overrides/main.html breadcrumb shim absorbed from PBJ verbatim (P3.1) + file-feedback affordance banner above Comments (P3.2). Round-4: framework-managed wiki/overrides/ refresh step in wiki-init.sh closing the staging gap where round-3.5's main.html + comments.html shipped in the bundle but never reached existing projects (operator-owned oracle on wiki/ + PRE_STAGE_NO_OP short-circuit on existing wiki/mkdocs.yml). Round-5: dropped navigation.sections from wiki/mkdocs.yml theme.features, restoring default Material collapsible-drawer rendering for top-level groups (Reference — CMS rules, Milestones, etc.); navigation.indexes preserved; yaml-merge no-op gotcha for existing projects documented in re-engagement ping (manual-edit one line)."
requires:
  - "P01 (homepage card grid + version: title + DR-### heading shape + nav.tabs/toc_depth/edit_uri); P02 (workflow-based Pages publishing + private-repo site_url + feedback:* routing + OOS collapse + discussions callout)"
affects:
  - "M037 closure (PBJ live-dogfood satisfaction signal); post-launch wiki-ux-deep + external-tool-adapters proposal (FR-12..FR-17 absorbed); M035 (unblocks pre-launch dev-ergonomics + launch-event packaging — wiki polish no longer contaminates pre-launch validation loop)"
key_files:
  - "wiki/mkdocs.yml,scripts/wiki/wiki-generate-stubs.sh,scripts/wiki/wiki-generate-nav.sh,scripts/lifecycle/wiki-init.sh,wiki/overrides/main.html,wiki/overrides/partials/comments.html,wiki/glossary.md,.orchestrator/proposals/M037-fr-12-17-deferred-scope.md"
key_decisions:
  - "P03-de-facto-narrowing,PBJ-feedback-driven-scope,FR-12-deferred,FR-13-partial-only,FR-14-deferred,FR-15-deferred,FR-16-deferred,FR-17-deferred,navigation.sections-dropped,yaml-merge-list-element-gap-deferred,Round-5-PBJ-satisfaction-signal,CON-2-respected,CON-3-respected,CON-4-respected"
patterns_established:
  - "Iterative-polish-loop pattern under live dogfood signal: each round = (1) PBJ install+observe+file defects, (2) tactical bundle commit, (3) push+SHA-range-ping, (4) PBJ retest. Loop terminates on satisfaction signal. Trade-off vs. plan-execute-verify cycle: faster turnaround on visible-defect remediation; weaker artifact trail (round commits, no per-round task plan) — closure pays the artifact cost retroactively. Pattern reusable when a phase's success contract is dogfood-acceptance rather than mechanical FR coverage,Cross-bundle staging-gap detection: if a bundle change ships content (round-3.5 wiki/overrides/) but install/init paths short-circuit on the surface (operator-owned oracle + PRE_STAGE_NO_OP), the change reaches greenfield only — existing projects need a framework-managed refresh step. Round-4 added that step explicitly for wiki/overrides/. Reusable diagnosis-and-fix pattern for any bundle-staged content type,yaml-merge list-element preservation gap surfaced in round-5: managed top-level key with present sub-key whose value is a YAML list — yaml-merge preserves target's list byte-identical (operator-wins-byte-identical at the sub-key level). Dropping a list element from the framework default does not propagate to existing projects. Deferred to post-launch as a separate yaml-merge fix; round-5 ping to PBJ included manual-edit instruction. Pattern: any framework-default change that drops/replaces list elements requires either (a) operator-side manual edit + diagnostic, or (b) yaml-merge primitive extension to support list-managed-namespace semantics,Retroactive plan/summary authoring at closure: when a phase ships as direct commits without going through orchestrator:plan-phase + dispatch, the closure step authors P03-PLAN.md + P03-SUMMARY.md retroactively documenting actually-shipped scope. Acceptable when (a) phase scope was de-facto narrowed by external signal mid-flight, (b) the rounds were small enough that per-round task plans would have added overhead without much insight, and (c) the demo sentence is satisfied by an external acceptance signal (PBJ confirmation here). NOT acceptable as a default — formal phase plans remain the standard for phases with internal milestone-shape scope"
drill_down_paths:
  - ".orchestrator/proposals/M037-fr-12-17-deferred-scope.md (formal scope deferral); commits 79b0f7a9 + 6919bdb9 + 19be603d + b81b9334 (round commits with full message bodies); .orchestrator/milestones/M037/phases/P03/P03-PLAN.md (round-by-round narrative)"
duration: "round-3.5: ~8h commit-to-pbj-retest; round-4: ~1h; round-5: ~30min — total wall-clock dominated by PBJ-retest latency, not authoring time"
verification_result: "pass"
completed_at: "2026-05-07T20:00:00Z"
observability_surfaces:
  - "tests/m037-acceptance/run-acceptance-battery.sh BATTERY: pass=11 skip=0 fail=0 (full battery green); scripts/verify/wiki-strict-build.sh PASS (0 errors, 0 warnings); PBJ-central live-dogfood satisfaction signal 2026-05-07 (operator-confirmed)"
---

# M037 P03 — PBJ-Feedback Polish Series (Retroactive Summary)

**Authoring note:** P03 shipped as a series of direct commits driven by
PBJ-central live dogfood feedback rather than through the formal
`orchestrator:plan-phase` + `dispatch` cycle. This summary is authored
**retroactively at M037 closure** (2026-05-07) so the milestone artifact
trail is complete. See `P03-PLAN.md` for the round-by-round narrative.

## Phase narrative

P03 became an iterative dogfood loop with PBJ-central as the reader-
satisfaction signal. The original P03 scope at `M037-ROADMAP.md:32`
(FR-12..FR-17 — tag-driven nav, GitHub source-link rewrite, knowledge
card grid, 3 plugins, optional Material `social`/`meta`) was de-facto
narrowed at round-3.5 commit time to a "PBJ-driven 8-fix tactical bundle"
addressing visibly-broken-on-greenfield + reference-corpus reading-experience
+ orientation-primitive defects. The narrowing held through round-4 +
round-5. PBJ confirmed satisfaction after round-5 ("pbj is looking good
in the wiki now", 2026-05-07).

FR-12..FR-17 deferred to post-launch via
`.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`. The post-launch
parent proposal (`post-launch-wiki-ux-and-adapters.md`) absorbs this scope.

## Rounds shipped

| Round | Commit | Date | Scope |
|-------|--------|------|-------|
| 3.5 | `79b0f7a9` | 2026-05-07T16:22 | 8-fix bundle: P1.1–P1.4 visibly-broken-on-greenfield + P2.1–P2.3 reference-corpus reading + P3.1–P3.2 orientation primitives |
| 3.5-sync | `6919bdb9` | 2026-05-07 | wiki regen sync — projects round-3.5 polish into orchestrator's own wiki tree |
| 4 | `19be603d` | 2026-05-07T17:35 | `wiki/overrides/` refresh in `wiki-init.sh` — closes round-3.5 staging gap |
| 5 | `b81b9334` | 2026-05-07T19:43 | drop `navigation.sections` from `wiki/mkdocs.yml` — restores collapsible-drawer left-nav |

## Verification at close

- **Acceptance battery** (`tests/m037-acceptance/run-acceptance-battery.sh`):
  `BATTERY: pass=11 skip=0 fail=0`. Full battery green; no skips.
- **wiki-strict-build** (`scripts/verify/wiki-strict-build.sh`):
  `PASS: wiki-strict-build (0 errors, 0 warnings)`.
- **PBJ-central live dogfood satisfaction signal**: confirmed 2026-05-07
  after round-5 ("pbj is looking good in the wiki now"). This is the
  load-bearing acceptance signal for P03's demo sentence.
- **No regressions** on P01 phase-suite (`pass=9 fail=0`) or P02
  phase-suite (`pass=5 fail=0`).

## yaml-merge no-op gotcha (round-5 follow-up)

Round-5 surfaced a yaml-merge limitation: managed top-level key with
present sub-key whose value is a YAML list — yaml-merge preserves
target's list byte-identical (operator-wins-byte-identical at the
sub-key level). Dropping a list element from the framework default
(round-5 dropped `navigation.sections` from `theme.features:`) does
not propagate to existing projects. The fix shipped in the bundle
covers greenfield correctly; existing projects (PBJ-central) require
a manual one-line edit after `wiki-init.sh`.

This list-replacement gap in yaml-merge is captured as a deferred
post-launch fix. Surface area: `scripts/lib/yaml-merge.sh`. Pattern:
either (a) extend the primitive with list-managed-namespace semantics
(framework-replace whole list), or (b) ship a `--replace-list-keys`
flag on yaml-merge for opt-in list replacement. Deferred because it
touches the merge primitive load-bearing for both `mkdocs.yml` and
`orchestrator-config-default.yml`.

## What was NOT shipped (formal scope deferred)

FR-12, FR-13 (full Tier 1 pass), FR-14, FR-15, FR-16, FR-17 — all
deferred per `.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`.
The round-3.5 P2.2 metadata-only `file://` rewrite is a **partial slice**
of FR-13 surface area but does not satisfy FR-13's Tier 1 chunk-projection
pass requirement.

## Affects M037 closure

P03 closure satisfies the M037 demo sentence ("non-author SME team gives
positive wiki signal"). M037 closes with:

- Three phases all green (P01 + P02 + P03; phase-suites and acceptance
  battery all pass).
- PBJ-central live-dogfood signal confirming reader satisfaction.
- Formal FR-12..FR-17 scope captured as a post-launch proposal so the
  audit trail is preserved.
- Operator-side parallel pre-launch follow-ups remain (M033 friendly-tester
  pass before 2026-05-12; M036a P03 live-LLM smoke retired 2026-05-07
  commit `c03efcc4`).

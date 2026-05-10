---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M037"
goal: "Publishing-robustness paper-cut bundle: workflow-based Pages publishing supersedes the legacy `mkdocs gh-deploy` builder, private-repo `site_url:` keeps 404 pages styled, `KNOWLEDGE.md` cross-links to `.orchestrator/feedback/*.md` resolve via a `feedback/` routing arm, `wiki-deploy.sh` collapses repeated OUT-OF-SCOPE noise, and `wiki/README.md` carries the org-level-discussions-redirect callout."
demo_sentence: "After P02 lands, an operator pushing a wiki content change to main triggers a `Deploy wiki to Pages` Actions workflow run within ~10s that completes within ~2 min, the live PBJ wiki reflects the change end-to-end without `mkdocs gh-deploy` invocation, private-repo dogfood projects render styled 404 pages (relative-asset-path mode), `wiki-deploy.sh` summarizes OUT-OF-SCOPE noise to ≤5 unique lines instead of 178, `KNOWLEDGE.md` cross-links to `.orchestrator/feedback/*.md` resolve via a `feedback/` routing arm in stub generation, and `wiki/README.md` carries the org-level-discussions-redirect recovery callout."
risk: "high"
depends_on: ["P01"]
---

## Phase Context (load-bearing for executors)

P01 closed 2026-05-07T00:54Z; P02 absorbs the publishing-robustness paper-cut bundle that landed in the spec via the 2026-05-07 amendment AFTER P01 close. F12 (FR-19+FR-20) is HIGH severity — a 7-day stuck `pages-build-deployment` run wedged the PBJ-central dogfood project before the legacy builder was abandoned. PBJ team opens the wiki this week; P02 closure unblocks the live dogfood signal for the entire orchestrator process.

**Authoritative inputs:**
- Spec: `specs/038-wiki-team-feedback-ready/spec.md` (US-10..US-14, FR-18..FR-22, SC-13..SC-17, edge cases at lines 300-307)
- Roadmap P02 boundary map: [`.orchestrator/milestones/M037/M037-ROADMAP.md`](../../../../milestones/M037/M037-ROADMAP.md)
- Verbatim workflow YAML reference impl + verbatim regression-test scaffolds: [`.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md`](../../../../proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md) (carries F12/F13 sources from PBJ-central commit `e7a722e`)
- F8/F10/F11 fix shapes + acceptance: [`.orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md`](../../../../proposals/papercut-sweep-wiki-deploy-2026-05-07.md)
- P01-SUMMARY: [`.orchestrator/milestones/M037/phases/P01/P01-SUMMARY.md`](../../../../milestones/M037/phases/P01/P01-SUMMARY.md)

**Critical reminders folded into task scoping:**

1. **F12 ships as one task cluster (T02), not four tasks.** FR-19 + FR-20 share surfaces (`wiki-init.sh` workflow scaffold + `wiki-deploy.sh` demote + `wiki/README.md` "Running the deploy wrapper" rewrite + `wiki/requirements.txt` confirmation). Splitting risks a half-state where the workflow exists but the legacy live-deploy path still runs — exactly the failure mode that wedged PBJ-central for 7 days.
2. **F12 cross-milestone touch is part of FR-20 done-definition.** The M032-shipped `wiki/README.md` "First-deploy checklist" + "Running the deploy wrapper" sections MUST be updated to reflect "git push triggers deploy" — no remaining `bash scripts/wiki/wiki-deploy.sh` invocations as the live-deploy path. [M032](../../../../milestones/M032/index.md) stays closed; M037 owns the docs update via T02.
3. **F9 is SUPERSEDED — no acceptance criterion derived.** F9's operator-confidence intent transfers to F12 via Actions observability (cancel/rerun/logs). No truth or artifact in this plan corresponds to F9.
4. **DISP-1 plan-time gate extends to two new managed namespaces.** P01 closed with a 15-key cross-reference table for `.orchestrator/config.yml` + an mkdocs.yml managed-namespace list. P02 extends this with two new template-emit surfaces:
   - `.github/workflows/pages.yml` — **whole-file managed**: pre-existing operator-authored workflow → diagnostic + no clobber, no per-key merge. (CON-3 preservation contract honored at file-level rather than key-level.)
   - `wiki/requirements.txt` — **managed flat list**: framework-default pinned deps emit when absent; pre-existing file → diagnostic + no clobber for P02 (same fail-closed shape as workflow file). Operator-pinned package overrides survive byte-identical via the no-clobber rule. Future schema-evolution to per-line merge is deferred (no operator demand signal).
   - `wiki/mkdocs.yml` `site_url:` mutation: rides P01 yaml-merge primitive (already in `MKDOCS_MANAGED` namespace list — `extra_css,nav,...` + addition of `site_url` happens via the existing field-line rewrite block in `wiki-init.sh:368-396`, NOT via yaml-merge primitive — `site_url` is a managed scalar that the field-rewrite block already mutates; FR-21 changes the source value, not the merge mechanism). Cross-reference table stays consistent with P01.

   Per #Q-4 resolution, the marker-bracketed YAML pattern applies to BOTH `.orchestrator/config.yml` AND `wiki/mkdocs.yml`. `.github/workflows/pages.yml` and `wiki/requirements.txt` use file-level CON-3 preservation (no marker-bracketed merge — they're managed at coarser granularity).
5. **Handoff doc has verbatim test scaffolds — port, do not re-author.** `tests/test-wiki-init-workflow-mode.sh` (SC-14) and `tests/test-wiki-init-private-site-url.sh` (SC-15) are committed verbatim in the handoff doc. Port byte-identical (modulo path adjustments for this repo's layout) and wire to the M037 acceptance battery aggregator. Target output `BATTERY: pass=10 fail=0` after P02 close (5 P01 + 5 P02 tests; the two top-level scaffolds are explicitly named in the aggregator's extension block, not glob-matched).
6. **MIT-01/02 escape-hatch pattern extends to FR-18.** P01/T02 established the `auto_generated: false` conditional-overwrite escape hatch via `existing_stub_is_protected()` in `scripts/wiki/wiki-generate-stubs.sh`. T01 below MUST reuse the helper, NOT fork it — operator-edited feedback stubs survive byte-identical across re-runs.
7. **CON-4 default-branch helper inheritance.** P02 FR-19 hard-codes `main` in the workflow YAML reference impl per the handoff doc (PBJ-central uses `main`; reference impl is verbatim from commit `e7a722e`). This is acceptable for P02 ship; flag as a P03 follow-up if any consumer surfaces a non-`main` default branch via PBJ feedback.

## Must-Haves

### Truths

- T1 — `scripts/wiki/wiki-generate-stubs.sh` carries a new `feedback:<basename>` routing arm mirroring the existing `proposals:*` arm; stubs land at `wiki/docs/feedback/<basename>.md` with fragment-only passthrough; title derives from H1 with humanized-basename fallback. (FR-18, US-10)
  - Check: `bash tools/verify/m037-p02-feedback-routing.sh`
- T2 — `scripts/wiki/wiki-scan-sources.sh` emits `feedback:<basename>` records for every `.orchestrator/feedback/*.md` source file (parallel to the proposals enumeration block at lines 322-337). (FR-18)
  - Check: `bash tools/verify/m037-p02-feedback-routing.sh`
- T3 — Operator-edited feedback stubs declaring `auto_generated: false` survive byte-identical across re-runs (MIT-01/02 escape-hatch pattern reused from P01/T02 — `existing_stub_is_protected()` helper consumed, NOT forked). (FR-18, MIT-01/02 inheritance)
  - Check: `bash tools/verify/m037-p02-feedback-routing.sh`
- T4 — `scripts/lifecycle/wiki-init.sh` emits `.github/workflows/pages.yml` carrying the four-component verbatim shape (`actions/configure-pages@v5` + `actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`, two-job build+deploy topology, Python 3.12 + pip-cache on `wiki/requirements.txt`, `concurrency: pages cancel-in-progress: false`, `permissions: contents:read pages:write id-token:write`, `push: branches: [main]` + `workflow_dispatch` triggers). (FR-19, US-11)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T5 — `scripts/lifecycle/wiki-init.sh` invokes `gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow` with manual-fallback diagnostic on `gh` unavailable / unauthenticated (verbatim command surfaced in the diagnostic so the operator can run it manually). (FR-19)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T6 — Pre-existing `.github/workflows/pages.yml` is NOT clobbered by `wiki-init.sh`; CON-3 preservation honored via diagnostic-only emit (no per-key merge). (FR-19, CON-3)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T7 — `scripts/wiki/wiki-deploy.sh` keeps gates 1-4 (giscus-config-check + mkdocs build + link-check + giscus-smoke) and drops gate 5 (`mkdocs gh-deploy --force`). The script prints `OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:` followed by `git push origin main` and the workflow URL, then exits 0. No `mkdocs gh-deploy` invocation remains on the live path. (FR-20, US-11)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T8 — `wiki/README.md` "Running the deploy wrapper" + "First-deploy checklist" sections updated: no remaining `bash scripts/wiki/wiki-deploy.sh` invocation as the live-deploy primitive; replaced with `git push origin main` + workflow URL pattern. M032-shipped quickstart docs reflect the new flow (cross-milestone touch owned by M037). (FR-20 done-definition, cross-milestone)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T9 — `scripts/lifecycle/wiki-init.sh` repo-visibility branch via `gh api "repos/$OWNER/$REPO" --jq .visibility 2>/dev/null` with fallback to `public` on `gh` unavailable. For `private`: rendered `wiki/mkdocs.yml` carries `site_url: ""` (or omits the line) with inline comment noting the private-pages relative-path rationale. For `public`: existing `site_url: "https://<owner>.github.io/<repo>/"` shape preserved (no regression). (FR-21, US-12)
  - Check: `bash tools/verify/m037-p02-private-site-url.sh`
- T10 — Verbatim regression scaffold `tests/test-wiki-init-workflow-mode.sh` ports byte-identical from the handoff doc (modulo `$ROOT` path adjustment) and exits 0 against this repo's installed bundle. (SC-14, verbatim-from-handoff contract)
  - Check: `bash tools/verify/m037-p02-workflow-pages-publishing.sh`
- T11 — Verbatim regression scaffold `tests/test-wiki-init-private-site-url.sh` ports byte-identical from the handoff doc and exits 0 against both visibility branches via `GH_VISIBILITY_OVERRIDE` env-var mock. (SC-15, verbatim-from-handoff contract)
  - Check: `bash tools/verify/m037-p02-private-site-url.sh`
- T12 — `scripts/diagnostics/wiki-link-check.sh` (the OUT-OF-SCOPE line emitter consumed by `wiki-deploy.sh` gate 3) collapses repeated OUT-OF-SCOPE patterns above a 5-occurrence threshold to a single summary line `OUT-OF-SCOPE: <N> pages -> <url> [external <descriptor>]`. The first 3-5 unique OUT-OF-SCOPE targets emit full lines for diagnostic context; remaining repeats collapse. `--verbose` flag (also exposed via `wiki-deploy.sh --verbose` passthrough) restores per-occurrence emission. Zero-OUT-OF-SCOPE fixture emits no summary line (no false positive). (FR-22a, US-13)
  - Check: `bash tools/verify/m037-p02-out-of-scope-collapse.sh`
- T13 — `wiki/README.md` § "First-deploy checklist" (or sibling section depending on T08's restructure) contains an org-level-discussions-redirect callout naming both the symptom (`<Org>/<Repo>/discussions` 302s to `orgs/<Org>/discussions`) AND the recovery path (`<Org>/<Repo>/discussions/categories` direct URL). Pre-existing checklist items byte-preserved; only the new callout is added. (FR-22b, US-14)
  - Check: `bash tools/verify/m037-p02-discussions-callout.sh`
- T14 — `tests/m037-acceptance/run-acceptance-battery.sh` extension iterates the five P02 acceptance tests AND explicitly invokes the two top-level handoff-doc scaffolds (`tests/test-wiki-init-workflow-mode.sh`, `tests/test-wiki-init-private-site-url.sh`) in addition to the existing `p01-*.sh` glob; emits `BATTERY: pass=10 skip=0 fail=0` summary line at successful close. (SC-12 extension, SC-13..SC-17 wired in)
  - Check: `bash tools/verify/m037-p02-phase-suite.sh`
- T15 — `tools/verify/m037-p02-phase-suite.sh` aggregates the five P02 verifiers per AD-19 straight-line shape; emits canonical `SUMMARY: m037-p02-phase-suite.sh pass=N fail=M` line at end; mirrors `tools/verify/m037-p01-phase-suite.sh` shape. (Phase-close gate)
  - Check: `bash tools/verify/m037-p02-phase-suite.sh`

### Artifacts

- [`.orchestrator/milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md) (min 80 lines, contains "feedback:")
- [`.orchestrator/milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md) (min 120 lines, contains "actions/deploy-pages")
- [`.orchestrator/milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md) (min 60 lines, contains "visibility")
- [`.orchestrator/milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md) (min 50 lines, contains "OUT-OF-SCOPE")
- [`.orchestrator/milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md) (min 50 lines, contains "discussions/categories")
- `tests/m037-acceptance/p01-feedback-routing.sh` (create, min 30 lines, contains "auto_generated")
- `tests/m037-acceptance/p01-out-of-scope-collapse.sh` (create, min 30 lines, contains "OUT-OF-SCOPE")
- `tests/m037-acceptance/p01-discussions-callout.sh` (create, min 20 lines, contains "discussions/categories")
- `tests/test-wiki-init-workflow-mode.sh` (create, min 25 lines, contains "actions/deploy-pages")
- `tests/test-wiki-init-private-site-url.sh` (create, min 30 lines, contains "GH_VISIBILITY_OVERRIDE")
- `tools/verify/m037-p02-feedback-routing.sh` (create, min 25 lines, contains "feedback:")
- `tools/verify/m037-p02-workflow-pages-publishing.sh` (create, min 30 lines, contains "actions/deploy-pages")
- `tools/verify/m037-p02-private-site-url.sh` (create, min 25 lines, contains "site_url")
- `tools/verify/m037-p02-out-of-scope-collapse.sh` (create, min 25 lines, contains "OUT-OF-SCOPE")
- `tools/verify/m037-p02-discussions-callout.sh` (create, min 20 lines, contains "discussions/categories")
- `tools/verify/m037-p02-phase-suite.sh` (create, min 60 lines, contains "SUMMARY: m037-p02-phase-suite.sh")
- `scripts/wiki/wiki-generate-stubs.sh` (modify, contains "feedback:")
- `scripts/wiki/wiki-scan-sources.sh` (modify, contains "feedback:")
- `scripts/lifecycle/wiki-init.sh` (modify, contains "actions/deploy-pages" AND "build_type=workflow" AND ".visibility")
- `scripts/wiki/wiki-deploy.sh` (modify, NOT contains literal `mkdocs gh-deploy --force` outside comments — replaced by `git push origin main` print)
- `scripts/diagnostics/wiki-link-check.sh` (modify, contains "OUT-OF-SCOPE" AND "--verbose")
- `wiki/README.md` (modify, contains "git push origin main" AND "discussions/categories")
- `tests/m037-acceptance/run-acceptance-battery.sh` (modify, contains "test-wiki-init-workflow-mode")

### Key Links

- [`.orchestrator/milestones/M037/phases/P02/P02-PLAN.md`](../../../../milestones/M037/phases/P02/P02-PLAN.md) → `specs/038-wiki-team-feedback-ready/spec.md` (FR-18..FR-22 + SC-13..SC-17 source-of-truth)
- [`.orchestrator/milestones/M037/phases/P02/P02-PLAN.md`](../../../../milestones/M037/phases/P02/P02-PLAN.md) → `papercut-handoff-wiki-publishing-robustness-2026-05-07.md` (verbatim workflow YAML + test scaffolds)
- `tools/verify/m037-p02-phase-suite.sh` → `tools/verify/m037-p01-phase-suite.sh` (shape mirror per AD-19)
- `tests/m037-acceptance/run-acceptance-battery.sh` → `tests/test-wiki-init-workflow-mode.sh` (aggregator extension explicit invocation)
- `scripts/wiki/wiki-generate-stubs.sh` → `scripts/wiki/wiki-scan-sources.sh` (`feedback:` record consumer)
- `wiki/README.md` → `scripts/wiki/wiki-deploy.sh` (M032 cross-milestone docs update target)

## Tasks

### T01: Feedback routing arm in stub generator + scan-sources enumeration

See `tasks/T01-feedback-routing-arm-PLAN.md`. Adds `feedback:<basename>` routing arm mirroring the existing `proposals:*` arm. Inputs: `.orchestrator/feedback/*.md`. Outputs: `wiki/docs/feedback/<basename>.md` stubs with fragment-only passthrough. Title derivation: H1 of source file with humanized-basename fallback. MIT-01/02 escape-hatch reused via P01's `existing_stub_is_protected()` helper. Idempotent removal verified.

### T02: F12 publishing cluster — workflow scaffold + wiki-init build_type flip + wiki-deploy.sh demote + wiki/README.md cross-milestone update

See `tasks/T02-workflow-publishing-cluster-PLAN.md`. Single tightly-coupled task cluster per critical reminder #1. Surfaces:
1. `scripts/lifecycle/wiki-init.sh` heredoc-emits `.github/workflows/pages.yml` (verbatim from handoff commit `e7a722e`); CON-3 preserve pre-existing file with diagnostic.
2. `scripts/lifecycle/wiki-init.sh` invokes `gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow` with manual-fallback diagnostic.
3. `wiki/requirements.txt` confirmation (already shipped in this repo at 8 lines; the install pipeline stages it via the existing `wiki/` manifest entry — no manifest change needed; the task verifies the staging path ships requirements.txt to consumers).
4. `scripts/wiki/wiki-deploy.sh` demote: drop gate 5 `mkdocs gh-deploy --force` block (lines 212-225); replace with the `OK: pre-deploy gates PASS...` print + `git push origin main` instruction + workflow URL pattern.
5. `wiki/README.md` "Running the deploy wrapper" (line 401+) and "First-deploy checklist" step 3 (line 318+) rewrite: replace `bash scripts/wiki/wiki-deploy.sh` live-deploy invocations with `git push origin main` + workflow URL. Pre-existing checklist items + manual-recovery `<details>` block preserved.
6. Port `tests/test-wiki-init-workflow-mode.sh` verbatim from handoff doc.

### T03: Private-repo `site_url:` visibility branch

See `tasks/T03-private-site-url-PLAN.md`. `scripts/lifecycle/wiki-init.sh` adds visibility-detection branch via `gh api "repos/$OWNER/$REPO" --jq .visibility`. Empty `site_url:` for private; existing public shape preserved. Port `tests/test-wiki-init-private-site-url.sh` verbatim from handoff doc.

### T04: OUT-OF-SCOPE diagnostic-budget collapse

See `tasks/T04-out-of-scope-collapse-PLAN.md`. `scripts/diagnostics/wiki-link-check.sh` adds collapse logic with 3-5-target diagnostic budget + `--verbose` flag passthrough from `wiki-deploy.sh`.

### T05: Discussions-redirect README callout + acceptance battery extension + phase-suite aggregator

See `tasks/T05-discussions-callout-and-phase-suite-PLAN.md`. `wiki/README.md` First-deploy-checklist callout. `tests/m037-acceptance/run-acceptance-battery.sh` extension. `tools/verify/m037-p02-phase-suite.sh` straight-line aggregator emitting canonical SUMMARY line.

## Task Dependencies

```
T01 ──┐
T02 ──┤
T03 ──┼──> T05  (T01-T04 produce verifiers consumed by T05's phase-suite aggregator
T04 ──┘         + battery extension; T05 also touches wiki/README.md which T02
                already restructured, so T05 lands its callout on top of T02's edit)
```

T01 / T02 / T03 / T04 are independent in source-tree surface area (T01 = stub generator + scan-sources; T02 = wiki-init.sh + wiki-deploy.sh + wiki/README.md "Running the deploy wrapper" sections; T03 = wiki-init.sh visibility branch; T04 = wiki-link-check.sh). T02 and T03 BOTH modify `wiki-init.sh` — they must run sequentially under `orchestrator:auto` to avoid merge churn (T02 → T03 ordering preferred since T02's CON-3-preserve scaffold is the load-bearing surface). T05 depends on T01-T04 verifiers existing and on T02's wiki/README.md restructure landing first (T05 adds a callout on top of T02's edits).

Recommended dispatch order: T01 → T02 → T03 → T04 → T05. No concurrent execution lanes.

## Files Likely Touched

- [`.orchestrator/milestones/M037/phases/P02/P02-PLAN.md`](../../../../milestones/M037/phases/P02/P02-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T04-out-of-scope-collapse-PLAN.md) (create)
- [`.orchestrator/milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md`](../../../../milestones/M037/phases/P02/tasks/T05-discussions-callout-and-phase-suite-PLAN.md) (create)
- `scripts/wiki/wiki-generate-stubs.sh` (modify — T01)
- `scripts/wiki/wiki-scan-sources.sh` (modify — T01)
- `scripts/lifecycle/wiki-init.sh` (modify — T02 + T03)
- `scripts/wiki/wiki-deploy.sh` (modify — T02 + T04)
- `scripts/diagnostics/wiki-link-check.sh` (modify — T04)
- `wiki/README.md` (modify — T02 + T05)
- `tests/m037-acceptance/run-acceptance-battery.sh` (modify — T05)
- `tests/m037-acceptance/p01-feedback-routing.sh` (create — T01)
- `tests/m037-acceptance/p01-out-of-scope-collapse.sh` (create — T04)
- `tests/m037-acceptance/p01-discussions-callout.sh` (create — T05)
- `tests/test-wiki-init-workflow-mode.sh` (create — T02, verbatim from handoff)
- `tests/test-wiki-init-private-site-url.sh` (create — T03, verbatim from handoff)
- `tests/fixtures/m037-feedback-routing/` (create — T01 fixture corpus, three .md files)
- `tools/verify/m037-p02-feedback-routing.sh` (create — T01)
- `tools/verify/m037-p02-workflow-pages-publishing.sh` (create — T02)
- `tools/verify/m037-p02-private-site-url.sh` (create — T03)
- `tools/verify/m037-p02-out-of-scope-collapse.sh` (create — T04)
- `tools/verify/m037-p02-discussions-callout.sh` (create — T05)
- `tools/verify/m037-p02-phase-suite.sh` (create — T05)

## DISP-1 Plan-Time Managed-Namespace Cross-Reference Extension

P01 closed with a 15-key cross-reference table for `.orchestrator/config.yml` (T06 plan §143-147) plus an mkdocs.yml managed-namespace list (`docs_dir,site_dir,theme,plugins,markdown_extensions,extra_css,nav`). P02 extends the cross-reference with two new template-emit surfaces:

| Path | Granularity | Managed by | Operator-customization survival |
|---|---|---|---|
| `.github/workflows/pages.yml` | whole-file | M037/P02/T02 (FR-19) | Pre-existing file → diagnostic + no clobber. Operator-authored workflows preserved byte-identical. No per-key merge. |
| `wiki/requirements.txt` | whole-file | M032 (existing wiki/ bundle stage; M037/P02/T02 confirms) | Pre-existing file → no clobber via P01 install-collision-check.sh path. Operator-pinned pkg overrides survive byte-identical. Future per-line merge deferred until demand. |

`wiki/mkdocs.yml` `site_url:` mutation (FR-21) rides the EXISTING field-line rewrite block in `wiki-init.sh:368-396` (managed scalar, mutates in-place); does NOT introduce a new managed namespace. The yaml-merge primitive is invoked AFTER field-line rewrite (`wiki-init.sh:404-433`) and preserves operator-authored top-level keys per existing P01 contract. P02 changes the CONTENT written by the field-line rewrite (visibility-branched), not the managed-namespace classification.

`.orchestrator/config.yml` managed-namespace table is unchanged in P02 (no new top-level keys introduced). P03 will revisit when `wiki.nav_buckets:` and `wiki.knowledge_cards:` (or scoped `wiki.landing_cards:`) schemas land.

PBJ-central live cross-reference: per P01 deferral, executor cannot access PBJ-central's `.orchestrator/config.yml` from this repo. Fail-closed design (operator-only files preserved byte-identical via no-clobber rule) makes silent re-classification structurally impossible for P02's two new managed surfaces. Re-cross-reference would only matter if PBJ-central operators had pre-existing `.github/workflows/pages.yml` or `wiki/requirements.txt` files at install time — both no-clobber by design, so the result is the same regardless of cross-reference outcome.

## Validation Checks Performed at Plan-Authoring Time

- **Path-collision check (rule 6)**: every declared `create` path verified absent on disk via `ls`. All paths free.
- **Prerequisite-existence verification (rule 1)**: every script and file referenced in `Inputs` / `Prerequisites` of task plans verified present on disk.
- **Verifier-availability cross-check (rule 2)**: each task authors its own verifier inside the task; T05's phase-suite aggregator references T01-T04 verifiers, all of which are scheduled as task deliverables BEFORE T05 dispatches.
- **`run-probe.sh` scope discipline (rule 4)**: zero references to `run-probe.sh` in this plan; all verifier invocations use direct `bash tools/verify/...` form.
- **Real-DB verification (rule 5)**: NOT APPLICABLE — P02 introduces no new SQL reads, schema migrations, or DB-bound integration code.
- **Classifier-shape pre-validation (rule 3)**: All Truth `Check:` commands use single-script-file shape per AD-19. Verifier scripts will internally use compound shell — that runs at verifier-execution time, not at harness-dispatch time, and is governed by `set -u` + AD-19 internal compliance documented in each verifier's header. The truth-check INVOCATIONS themselves are single-script-file shape, which is what the harness heuristic gates.

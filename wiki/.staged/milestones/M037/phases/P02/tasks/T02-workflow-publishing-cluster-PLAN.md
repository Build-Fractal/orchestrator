---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M037"
name: "F12 publishing cluster — workflow scaffold + wiki-init build_type flip + wiki-deploy.sh demote + wiki/README.md cross-milestone update"
depends_on: ["T01"]
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists (verified at plan-authoring time, ~776 lines, contains `MKDOCS_TARGET="$PROJECT_DIR/wiki/mkdocs.yml"` substitution block at lines 305-432, `gh api PATCH /repos` invocation at line 643, `gh api ... /pages` invocation at lines 701+/738).
- `scripts/wiki/wiki-deploy.sh` exists (verified at plan-authoring time, 225 lines, contains gates 1-4 at lines 156-210, `mkdocs gh-deploy --force` live-deploy block at lines 212-225, `--dry-run` flag handling).
- `wiki/README.md` exists (verified at plan-authoring time, ~450+ lines, contains "First-deploy checklist" at line 280, "Running the deploy wrapper" at line 401, references to `bash scripts/wiki/wiki-deploy.sh` at lines 321, 390, 403).
- `wiki/requirements.txt` exists in this repo (verified at plan-authoring time, 8 lines, pinned mkdocs + mkdocs-material + plugin deps); shipped to consumer projects via the existing `packaging/bundle/manifest.yml` `wiki/` source/target entry. **No new manifest entry required**: requirements.txt is staged as part of the wiki/ wholesale copy. T02 verifies the staging path; does NOT add a new project_assets entry.
- `.github/workflows/pages.yml` does NOT exist (verified at plan-authoring time — only `.github/ISSUE_TEMPLATE/uat-bug.yml` is present). Path is free for T02 to create at consumer-install time via `wiki-init.sh` heredoc emit.
- [`.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md`](../../../../../proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md) exists (verified at plan-authoring time, 573 lines, carries the verbatim YAML reference impl at lines 134-178 and the verbatim test scaffold at lines 240-269).

## Description

Lands FR-19 + FR-20 per US-11 and SC-14 as a single tightly-coupled task cluster. Per critical reminder #1 in the phase plan, splitting risks shipping a half-state where the workflow exists but the legacy live-deploy path still runs — exactly the failure mode that wedged the PBJ-central dogfood project for 7 days (stuck `pages-build-deployment` run `25145703975`, irrecoverable via documented APIs). Source: `papercut-handoff-wiki-publishing-robustness-2026-05-07.md` Gap 1.

Six surfaces ship together:
1. `scripts/lifecycle/wiki-init.sh` heredoc-emits `.github/workflows/pages.yml` with the four-component verbatim shape (CON-3 preserve pre-existing file via diagnostic + no clobber).
2. `scripts/lifecycle/wiki-init.sh` invokes `gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow` with manual-fallback diagnostic on `gh` unavailable / unauthenticated.
3. `wiki/requirements.txt` confirmation — the file already ships via the existing `wiki/` manifest entry; T02 verifies staging via the install-collision-check.sh path (existing operator file → no clobber).
4. `scripts/wiki/wiki-deploy.sh` demote: drop gate 5 (`mkdocs gh-deploy --force` block at lines 212-225); replace with print of workflow URL + `git push origin main` instruction; exit 0 cleanly.
5. `wiki/README.md` "Running the deploy wrapper" + "First-deploy checklist" sections rewrite — replace `bash scripts/wiki/wiki-deploy.sh` live-deploy invocations with `git push origin main` + workflow URL pattern. Pre-existing checklist items + manual-recovery `<details>` block byte-preserved. Cross-milestone touch owned by M037.
6. Port `tests/test-wiki-init-workflow-mode.sh` byte-identical from the handoff doc.

**F9 supersession**: F12 absorbs F9's operator-confidence intent via Actions observability (cancel/rerun/logs). No truth or test asset corresponds to F9 in this task.

## Steps

1. **Author the workflow YAML emit block in `scripts/lifecycle/wiki-init.sh`**. Insert a new function near the existing template-emit logic (after the `mkdocs.yml` field-line rewrite block, ~line 434):

   ```bash
   # ---- FR-19 (M037/P02/T02) — GitHub Pages workflow scaffold ---------------
   # Emit .github/workflows/pages.yml with the verbatim four-component shape
   # from papercut-handoff-wiki-publishing-robustness-2026-05-07.md (PBJ-central
   # commit e7a722e). CON-3: pre-existing operator-authored workflow → diagnostic
   # + no clobber, no per-key merge. Whole-file managed.
   emit_pages_workflow() {
     PAGES_WF_TARGET="$PROJECT_DIR/.github/workflows/pages.yml"
     if [ -f "$PAGES_WF_TARGET" ]; then
       echo "wiki-init: .github/workflows/pages.yml already present at $PAGES_WF_TARGET — preserving operator-authored workflow (CON-3); reference impl in $REPO_ROOT/.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md if reconciliation desired" >&2
       return 0
     fi
     mkdir -p "$(dirname "$PAGES_WF_TARGET")"
     cat > "$PAGES_WF_TARGET" <<'PAGES_WORKFLOW_EOF'
   name: Deploy wiki to Pages

   on:
     push:
       branches: [main]
     workflow_dispatch:

   permissions:
     contents: read
     pages: write
     id-token: write

   concurrency:
     group: pages
     cancel-in-progress: false

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-python@v5
           with:
             python-version: "3.12"
             cache: pip
             cache-dependency-path: wiki/requirements.txt
         - run: pip install -r wiki/requirements.txt
         - run: mkdocs build -f wiki/mkdocs.yml
         - uses: actions/configure-pages@v5
         - uses: actions/upload-pages-artifact@v3
           with:
             path: wiki/site

     deploy:
       needs: build
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - id: deployment
           uses: actions/deploy-pages@v4
   PAGES_WORKFLOW_EOF
     echo "wiki-init: emitted $PAGES_WF_TARGET (build_type=workflow scaffold per FR-19)"
   }
   ```

   **Note on heredoc shape**: the `<<'PAGES_WORKFLOW_EOF'` (single-quoted delimiter) prevents shell expansion of `${{ ... }}` GitHub Actions interpolation. The literal `${{ steps.deployment.outputs.page_url }}` MUST survive byte-identical to the file. Verify by rendering in a fresh fixture and grepping for `${{ steps.deployment` after emit.

2. **Add `gh api -X PUT build_type=workflow` invocation** in `scripts/lifecycle/wiki-init.sh`. Insert AFTER the `emit_pages_workflow` function and AFTER the existing `gh api PATCH /repos` discussions block (~line 643). The invocation runs ONCE per init, gated on `gh` availability:

   ```bash
   # ---- FR-19 (M037/P02/T02) — flip Pages config to build_type=workflow -----
   # After the workflow file is emitted, set the repo's Pages build_type to
   # workflow so the deploy-pages action can publish. Idempotent — flipping
   # an already-workflow repo is a no-op upstream.
   flip_pages_build_type() {
     [ -n "${OWNER:-}" ] || return 0
     [ -n "${REPO:-}" ] || return 0
     if ! command -v gh >/dev/null 2>&1; then
       echo "wiki-init: gh CLI not on PATH; skipping FR-19 build_type flip. Run manually after install:" >&2
       echo "    gh api -X PUT \"repos/$OWNER/$REPO/pages\" -f build_type=workflow" >&2
       return 0
     fi
     if ! gh auth status >/dev/null 2>&1; then
       echo "wiki-init: gh not authenticated; skipping FR-19 build_type flip. Run manually after gh auth login:" >&2
       echo "    gh api -X PUT \"repos/$OWNER/$REPO/pages\" -f build_type=workflow" >&2
       return 0
     fi
     if gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow >/dev/null 2>&1; then
       echo "wiki-init: FR-19 build_type=workflow set on repos/$OWNER/$REPO/pages"
     else
       _flip_rc=$?
       echo "wiki-init: gh api -X PUT repos/$OWNER/$REPO/pages -f build_type=workflow exited $_flip_rc; run manually if needed" >&2
     fi
   }
   ```

   Wire the two functions into the main init flow at the appropriate point — after `mkdocs.yml` is finalized and BEFORE the `--deploy` block (which will be revised in a separate task to remove the legacy gh-pages branch creation). The wiring lines:

   ```bash
   # FR-19 (M037/P02/T02) — workflow-based Pages publishing scaffold
   emit_pages_workflow
   flip_pages_build_type
   ```

3. **Demote `scripts/wiki/wiki-deploy.sh` live path**. Replace lines 212-225 (the current `# -------- deploy (live path only) --------` block):

   ```bash
   # -------- post-gate report (M037/P02/T02 FR-20) --------
   # F12 supersedes the legacy mkdocs gh-deploy live path. Pre-push gates 1-4
   # remain as local validation; live deploy now flows through the workflow
   # at .github/workflows/pages.yml triggered by `git push origin main`.
   if [ "$DRY_RUN" -eq 1 ]; then
     printf 'DRY-RUN: gates PASS; would print push instruction\n'
     exit 0
   fi

   printf 'OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:\n'
   printf '    git push origin main\n'
   printf '\n'
   if [ -n "${OWNER:-}" ] && [ -n "${REPO:-}" ]; then
     printf 'Workflow run: https://github.com/%s/%s/actions/workflows/pages.yml\n' "$OWNER" "$REPO"
   else
     printf 'Workflow run: https://github.com/<owner>/<repo>/actions/workflows/pages.yml (set OWNER/REPO env vars for repo-specific URL)\n'
   fi
   exit 0
   ```

   The `OWNER`/`REPO` resolution: read from `git config --get remote.origin.url` and parse `<owner>/<repo>` from the URL. If the script does not currently expose `OWNER`/`REPO` near the deploy block, add a small resolver block at top:

   ```bash
   # OWNER/REPO resolution for FR-20 workflow URL print
   if [ -z "${OWNER:-}" ] || [ -z "${REPO:-}" ]; then
     _origin_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
     # parse git@github.com:owner/repo.git OR https://github.com/owner/repo(.git)
     case "$_origin_url" in
       git@github.com:*)
         _owner_repo=${_origin_url#git@github.com:}
         _owner_repo=${_owner_repo%.git}
         ;;
       https://github.com/*)
         _owner_repo=${_origin_url#https://github.com/}
         _owner_repo=${_owner_repo%.git}
         ;;
       *)
         _owner_repo=""
         ;;
     esac
     if [ -n "$_owner_repo" ]; then
       OWNER=${_owner_repo%/*}
       REPO=${_owner_repo#*/}
     fi
   fi
   ```

   Update the script's header comment block (lines 1-30) to reflect the new behavior — drop "Then, on live path: mkdocs gh-deploy --force" and replace with "Then prints workflow URL + git-push instruction."

   Update the help block (lines 35-50) similarly: replace any "Then (live path only): mkdocs gh-deploy --force ..." reference with the new flow.

4. **Update `wiki/README.md`**:

   - **§ "First-deploy checklist" → step 3 "Run the deploy wrapper" (line 318+)**: Rewrite as:
     ```markdown
     ### 3. Run the pre-deploy gates and push to main

     ```
     bash scripts/wiki/wiki-deploy.sh
     ```

     The wrapper sources `<path>/.env` automatically before gate 1, runs the
     four pre-deploy gates (giscus-config-check + mkdocs build + link-check
     + giscus-smoke), and on success prints `OK: pre-deploy gates PASS.
     Push to main to trigger workflow deploy:` followed by `git push origin
     main` and the workflow URL. Push the change yourself; the workflow at
     `.github/workflows/pages.yml` builds and deploys via
     `actions/deploy-pages@v4` (typical timing: ~50s build + ~10s deploy,
     total ~1 min from push to live). On any gate failure the wrapper
     aborts before printing the push instruction and emits a `FAIL:` line
     naming which gate failed.

     > **Why workflow-based publishing?** F12 (M037/P02) replaces the legacy
     > `mkdocs gh-deploy --force` live path because GitHub's
     > `pages-build-deployment` builder has a known wedged-`queued` failure
     > mode with no documented recovery API (PBJ-central dogfood lost 7
     > days to it before abandoning the legacy builder). Workflow-based
     > deploys are normal Actions runs — fully observable, fully
     > cancellable, fully rerunnable. See
     > [`.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md`](../../../../../proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md)
     > for the full discovery surface.
     ```

   - **§ "First-deploy checklist" → manual-recovery `<details>` block (line 357+)**: Update step 4 (currently the gh-pages-branch-enable instruction) to remove the gh-pages-branch language. Replace step 4 with:
     ```markdown
     4. Enable GitHub Pages with `build_type: workflow`: Settings → Pages
        → Source → **GitHub Actions**. (`wiki-init --with-giscus` calls
        `gh api -X PUT repos/.../pages -f build_type=workflow` automatically
        when `gh` is authenticated.)
     ```
     Update step 6 to:
     ```markdown
     6. Run `bash scripts/wiki/wiki-deploy.sh`; on PASS, `git push origin main`.
     ```

   - **§ "Running the deploy wrapper" (line 401+)**: Rewrite the `Pipeline` and `Exit codes` subsections:
     - Remove `mkdocs gh-deploy --force` references throughout (lines 405, 418, 423-424, 445-446).
     - Rewrite the pipeline summary as: "Chains the four pre-deploy gates in order. On all PASS, prints the workflow URL and `git push origin main` instruction. On any FAIL, aborts before printing the push instruction."
     - Exit codes: `0` — every gate PASS (replaces the live-deploy success criterion). `1` — any gate FAIL or build fail.

   - **§ "First-deploy checklist" → step 5 "Smoke-test the deployed URL" (line 339+)**: No change — the smoke-test step is workflow-agnostic.

   Pre-existing checklist items, the giscus install/setup language, and the Private-repo callout (line 286-292) are byte-preserved. Only the deploy-mechanism language is rewritten.

5. **Port `tests/test-wiki-init-workflow-mode.sh` verbatim from the handoff doc**:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   ROOT="$(cd "$HERE/.." && pwd)"
   WORK="$(mktemp -d)"
   trap 'rm -rf "$WORK"' EXIT

   cd "$WORK"
   git init -q
   git remote add origin git@github.com:Test-Org/test-repo.git
   bash "$ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null
   bash scripts/lifecycle/wiki-init.sh --project-dir . >/dev/null

   test -f .github/workflows/pages.yml || { echo "FAIL: pages.yml not scaffolded"; exit 1; }
   grep -q "actions/deploy-pages" .github/workflows/pages.yml || \
     { echo "FAIL: workflow does not use actions/deploy-pages"; exit 1; }
   grep -q "actions/upload-pages-artifact" .github/workflows/pages.yml || \
     { echo "FAIL: workflow does not use upload-pages-artifact"; exit 1; }

   if grep -q "mkdocs gh-deploy" scripts/wiki/wiki-deploy.sh; then
     grep -q "DRY_RUN\|--dry-run\|local-only" scripts/wiki/wiki-deploy.sh || \
       { echo "FAIL: wiki-deploy.sh still has unguarded mkdocs gh-deploy"; exit 1; }
   fi

   echo "PASS: wiki-init scaffolds workflow-based publishing"
   ```

   Path adjustment from handoff: `$ROOT` resolves to this repo's root (parent of `tests/`). The `--force` flag on `install-claude-code.sh` is unchanged; `wiki-init.sh --project-dir .` runs in the temp dir context.

6. **Author `tools/verify/m037-p02-workflow-pages-publishing.sh`**. Aggregates all FR-19 + FR-20 surfaces:

   - Greps `scripts/lifecycle/wiki-init.sh` for: `actions/deploy-pages` (workflow YAML emit block), `build_type=workflow` (gh api invocation), `cache-dependency-path: wiki/requirements.txt` (workflow YAML cache shape), `cancel-in-progress: false` (concurrency block).
   - Greps `scripts/wiki/wiki-deploy.sh` for absence of `mkdocs gh-deploy --force` outside comments. Implementation: `grep -v '^#' scripts/wiki/wiki-deploy.sh | grep -q 'mkdocs gh-deploy --force'` MUST exit non-zero (no live invocation).
   - Greps `scripts/wiki/wiki-deploy.sh` for presence of literal `git push origin main` AND the workflow URL pattern `actions/workflows/pages.yml`.
   - Greps `wiki/README.md` for: `git push origin main` (at least one occurrence in the deploy-flow section), `build_type` or `GitHub Actions` (in the manual-recovery block), absence of `mkdocs gh-deploy --force` as the live-deploy primitive (occurrences in historical / cross-reference language are acceptable; the cross-reference test should grep for the SHAPE `bash scripts/wiki/wiki-deploy.sh` followed within 5 lines by `mkdocs gh-deploy` — there should be NO such adjacency).
   - Invokes `bash tests/test-wiki-init-workflow-mode.sh` and propagates exit code.
   - Emits `SUMMARY: m037-p02-workflow-pages-publishing pass=N fail=M` on completion.

## Must-Haves

- T4 (FR-19 workflow YAML emit) — phase plan.
- T5 (FR-19 build_type=workflow flip with manual fallback) — phase plan.
- T6 (CON-3 preserve pre-existing workflow file) — phase plan.
- T7 (FR-20 wiki-deploy.sh demote) — phase plan.
- T8 (FR-20 wiki/README.md cross-milestone update) — phase plan.
- T10 (verbatim test scaffold port) — phase plan.

## Verification

```bash
bash tools/verify/m037-p02-workflow-pages-publishing.sh
```

```bash
bash tests/test-wiki-init-workflow-mode.sh
```

## Inputs

### From Previous Tasks

- T01 (M037/P02/T01) — feedback routing arm. T02 does not consume T01 directly; ordering is dispatch-sequencing only (both modify wiki/ tooling and benefit from sequential commit history).

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` — extends with two new functions (`emit_pages_workflow`, `flip_pages_build_type`) plus wiring lines.
  - Existing API to consume: `OWNER`, `REPO`, `PROJECT_DIR`, `REPO_ROOT` env vars resolved earlier in the script (verified at plan-authoring time at lines ~120-180; the `--deploy` block at line 643+ already references `$OWNER`/`$REPO`, so the variables are in scope).
  - Existing API to consume: `MKDOCS_TARGET` resolution at line ~301.
- `scripts/wiki/wiki-deploy.sh` — replace the live-deploy block at lines 212-225; add OWNER/REPO resolver at top.
- `wiki/README.md` — update the named sections (line offsets in step 4 above).
- [`.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md`](../../../../../proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md) — verbatim YAML reference impl at lines 134-178; verbatim test scaffold at lines 240-269.
- `packaging/bundle/manifest.yml` — confirms `wiki/` is staged wholesale (line 61-63); `wiki/requirements.txt` rides the existing entry. NO modification needed.
- `wiki/requirements.txt` — pre-existing (8 lines). NO modification needed.

## Constraints

- AD-19: all `Check:` commands single-script-file shape.
- Bash 3.2 + POSIX sh in script additions. Match surrounding-code shape.
- CON-3 preservation: pre-existing `.github/workflows/pages.yml` MUST NOT be clobbered. Diagnostic-only emit; operator reconciles manually if desired.
- CON-4: workflow YAML hard-codes `branches: [main]` per the handoff verbatim shape. Acceptable for P02 ship (PBJ-central uses main); flag as P03 follow-up if a consumer surfaces non-main usage. NO automated default-branch substitution in T02 — the handoff's verbatim contract is byte-identical preservation.
- [M032](../../../../../milestones/M032/index.md) quickstart docs update is part of FR-20's done-definition (cross-milestone touch owned by M037; M032 stays closed).
- The verbatim test scaffold MUST port byte-identical (modulo `$ROOT` path resolution which is already correct in the handoff source). Do not "improve" the test — verbatim is the contract.
- `mkdocs gh-deploy` may still appear in `wiki/README.md` and `scripts/wiki/wiki-deploy.sh` ONLY as historical context inside comments / explanatory prose (e.g., "F12 supersedes the legacy mkdocs gh-deploy live path"). It MUST NOT appear as the live-deploy primitive on any code path. The verifier's grep test enforces this distinction by checking for the SHAPE `mkdocs gh-deploy --force` outside comment lines.

## Expected Output

After T02 ships:
- A fresh install in a clean fixture emits `.github/workflows/pages.yml` with the verbatim four-component shape; `gh api -X PUT ... build_type=workflow` runs once during init (or prints the manual-fallback diagnostic if gh unavailable).
- `bash scripts/wiki/wiki-deploy.sh` runs the four pre-deploy gates and on PASS prints `OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:` + `git push origin main` + workflow URL; exit 0. NO `mkdocs gh-deploy` invocation.
- `wiki/README.md` § "First-deploy checklist" + § "Running the deploy wrapper" reflect "git push triggers deploy"; pre-existing operator content byte-preserved.
- `bash tests/test-wiki-init-workflow-mode.sh` exits 0; `bash tools/verify/m037-p02-workflow-pages-publishing.sh` reports `SUMMARY: m037-p02-workflow-pages-publishing pass=N fail=0`.

## Notes

- **End-to-end live-LLM smoke evidence (manual)**: SC-14 calls for one-shot manual evidence that a push to main triggers a workflow run within ~10s and completes within ~2 min total, with no `pages-build-deployment` legacy run created. This is captured in `M037-ACCEPTANCE-EVIDENCE.md` at phase close, NOT inside the automated test (the test cannot trigger a real GitHub workflow run). T02 ships the automation that enables the manual smoke; the smoke evidence itself is operator-recorded outside the automated battery. Real-app smoke test pending — confirm after first PBJ-central re-deploy with the new pipeline.

- **`gh-pages` branch zombie**: per handoff "Other concerns" #1, the legacy `pages-build-deployment` zombie can persist after switching to workflow mode. Cosmetic only — does not affect new workflow-based deploys. T02 does NOT attempt to clear the zombie; it's documented as a known gap in the spec edge cases.

- **DISP-1 cross-reference extension**: T02 adds `.github/workflows/pages.yml` (whole-file managed) to the managed-namespace cross-reference per the phase plan. Operator-confirmation flag fires only if a consumer project has a pre-existing operator-authored workflow at that path; the diagnostic-only emit (no clobber) makes silent overwrite structurally impossible.

- **The OWNER/REPO resolver in `wiki-deploy.sh`** mirrors the existing pattern in `wiki-init.sh` for git-remote URL parsing. Matching shapes keeps maintenance cost low. Verify by inspecting `wiki-init.sh` for the existing parser and reuse the same case-statement structure.

- **The `cat > "$PAGES_WF_TARGET" <<'PAGES_WORKFLOW_EOF'` heredoc**: single-quoted delimiter (`'PAGES_WORKFLOW_EOF'`) prevents shell expansion. Critical for preserving `${{ steps.deployment.outputs.page_url }}` byte-identical. Verify via direct grep after emit, not via shell expansion test.

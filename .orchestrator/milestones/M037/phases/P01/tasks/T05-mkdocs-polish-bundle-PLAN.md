---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M037"
name: "CON-4 default-branch helper + mkdocs.yml polish bundle"
depends_on: []
---

## Prerequisites

- `wiki/mkdocs.yml` exists (verified at plan-authoring time, 2448 lines, contains `theme.features:`, `markdown_extensions:`, `plugins:`).
- `scripts/lifecycle/wiki-init.sh` exists (verified at plan-authoring time, contains `MKDOCS_TARGET="$PROJECT_DIR/wiki/mkdocs.yml"` placeholder substitution at lines 279-327).
- `scripts/wiki/` directory exists (verified at plan-authoring time).

## Description

Lands FR-9 (mkdocs.yml polish bundle) plus the CON-4 default-branch helper consumed by FR-9's `edit_uri:` derivation and reusable by P02's FR-13 GitHub source-link rewrite. Two artifacts ship together because they share the same downstream consumer (`wiki-init.sh`'s template-emit logic) and the same fail-back path (`main` on `git symbolic-ref` failure).

The polish bundle adds eight surfaces to `wiki/mkdocs.yml` (orchestrator dogfood) AND to the install-bundle equivalent (the staged `wiki/mkdocs.yml` in `packaging/bundle/wiki/mkdocs.yml` if separate from `wiki/mkdocs.yml`, or the same file if the orchestrator dogfoods directly):

1. `theme.features: navigation.tabs`
2. `theme.features: navigation.tabs.sticky`
3. `theme.features: navigation.prune` (theme-leverage amendment — ~33% rendered HTML reduction at PBJ-central scale)
4. `theme.features: content.action.edit`
5. `theme.features: content.action.view`
6. `markdown_extensions: pymdownx.details` (theme-leverage amendment)
7. `markdown_extensions: pymdownx.tasklist` with `custom_checkbox: true` (theme-leverage amendment)
8. `markdown_extensions: toc.toc_depth: 2` (modify existing toc: block from default to 2)
9. Top-level `edit_uri:` derived from `repo_url:` at template-emit time via the new helper.

## Steps

1. **Author `scripts/wiki/resolve-default-branch.sh`** (CON-4 helper). Single-script-file shape per AD-19, bash 3.2 + POSIX sh per MEM001. The script:
   - Accepts an optional first arg: project dir (defaults to CWD).
   - Reads `git -C <project-dir> symbolic-ref refs/remotes/origin/HEAD` and extracts the trailing branch name.
   - On success: prints the branch name to stdout, exits 0.
   - On failure (detached, no remote, shallow clone): prints `main` to stdout, emits a debug-level diagnostic to stderr ONLY when `WIKI_DEBUG=1` is set, exits 0 (NOT a failure — falling back is by-design per CON-4 / AD-7).
   - Min 15 lines, contains the literal string `symbolic-ref` (per phase-plan artifact contract).

2. **Modify `wiki/mkdocs.yml`** (orchestrator dogfood). Apply the polish bundle additions:

   - Under `theme.features:` (currently lines 22-30), insert at the top of the list:
     ```yaml
         - navigation.tabs
         - navigation.tabs.sticky
         - navigation.prune
     ```
     and insert at the bottom of the existing features list:
     ```yaml
         - content.action.edit
         - content.action.view
     ```

   - Under `markdown_extensions:` (currently lines 38-52), modify the existing `toc:` block from:
     ```yaml
       - toc:
           permalink: true
     ```
     to:
     ```yaml
       - toc:
           permalink: true
           toc_depth: 2
     ```
     and append two new extensions:
     ```yaml
       - pymdownx.details
       - pymdownx.tasklist:
           custom_checkbox: true
     ```

   - At the top level (alongside `site_name:`, `site_url:`, `repo_url:`), add:
     ```yaml
     edit_uri: edit/<default-branch>/wiki/docs/
     ```
     where `<default-branch>` is computed at template-emit time by the helper from step 1. For the orchestrator's own dogfood file (which is byte-identical to the bundle template), the helper resolves to `main` against this repo's actual remote.

3. **Modify `scripts/lifecycle/wiki-init.sh`** to apply `edit_uri:` substitution at template-emit time. Find the existing field-line rewrite block at lines 305-326. Add a fifth desired-line:
   - Compute `default_branch="$(bash "$REPO_ROOT/scripts/wiki/resolve-default-branch.sh" "$PROJECT_DIR")"`.
   - Compute `edit_uri="edit/${default_branch}/wiki/docs/"`.
   - Add to the desired-lines match-count loop:
     ```bash
     desired_edit_uri='edit_uri: "'"$edit_uri"'"'
     if grep -qxF "$desired_edit_uri" "$MKDOCS_TARGET"; then
       match_count=$((match_count + 1))
     fi
     ```
     and bump the success branch to `match_count -eq 5`.
   - Add a fifth `sed -e` clause to the rewrite:
     ```bash
     -e "s|^edit_uri:.*|edit_uri: \"${s_edit_uri}\"|" \
     ```
     after escaping `edit_uri` via the existing `escape_sed` helper.
   - When `repo_url:` is unset in the staged mkdocs.yml (US-4 AS-4 edge case): skip the `edit_uri:` injection and emit a diagnostic suggesting the operator set `repo_url:`. Detection: grep `^repo_url:` returning empty / placeholder.

4. **Author `tools/verify/m037-p01-mkdocs-polish-bundle.sh`** (Truth #5 verifier). Asserts against `wiki/mkdocs.yml`:
   - Contains `- navigation.tabs` under `theme.features:`.
   - Contains `- navigation.tabs.sticky`.
   - Contains `- navigation.prune` (artifact-pattern requirement; phase plan checks for "navigation.prune" literally).
   - Contains `- content.action.edit`.
   - Contains `- content.action.view`.
   - Contains `toc_depth: 2` under `toc:`.
   - Contains `- pymdownx.details`.
   - Contains `- pymdownx.tasklist:` followed by `custom_checkbox: true`.
   - Contains `edit_uri:` at top-level.

5. **Author `tests/m037-acceptance/p01-mkdocs-polish-bundle.sh`** (acceptance test, SC-4). Stages a fresh fixture under a temp dir with a synthetic git remote (uses `git init` + `git remote add origin <fixture-url>` to construct a remote without requiring network), invokes `bash scripts/lifecycle/wiki-init.sh --project-dir <fixture>`, asserts the rendered `<fixture>/wiki/mkdocs.yml` carries all eight polish-bundle additions and that `edit_uri:` resolves to `edit/<default-branch>/wiki/docs/` derived from the fixture's git remote default branch.

## Must-Haves

- Truth #5 (mkdocs.yml template carries polish bundle).
- Phase artifacts: `scripts/wiki/resolve-default-branch.sh` (min 15 lines, contains "symbolic-ref"), `tests/m037-acceptance/p01-mkdocs-polish-bundle.sh` (min 20 lines, contains "navigation.prune").
- SC-4 acceptance test passes.

## Verification

```bash
bash scripts/wiki/resolve-default-branch.sh
bash tools/verify/m037-p01-mkdocs-polish-bundle.sh
bash tests/m037-acceptance/p01-mkdocs-polish-bundle.sh
```

## Notes

- Expected output of `bash scripts/wiki/resolve-default-branch.sh` (this repo): the string `main` (or whatever this repo's default branch is — confirm by running the bare command).
- Expected output of `tools/verify/m037-p01-mkdocs-polish-bundle.sh`: `PASS: m037-p01-mkdocs-polish-bundle (9/9)`.
- Expected output of `tests/m037-acceptance/p01-mkdocs-polish-bundle.sh`: `PASS: p01-mkdocs-polish-bundle`.
- The `wiki-init.sh` modification at step 3 must keep the existing four-field substitution working byte-identical when the operator passes a fixture without a configured remote (US-4 AS-4 — `edit_uri:` omitted, no broken affordance, diagnostic suggests `repo_url:`).
- T06 will round-trip this `wiki/mkdocs.yml` through the yaml-merge primitive's CON-3 preservation contract; T05 does NOT need to integrate with yaml-merge directly — T06 owns that.

## Inputs

### From Previous Tasks

(none — T05 has no upstream task dependencies)

### From Disk (Pre-existing)

- `wiki/mkdocs.yml` — modified in place. Existing `theme.features:`, `markdown_extensions:`, `plugins:`, and top-level keys preserved byte-identical except for the targeted additions/modifications.
- `scripts/lifecycle/wiki-init.sh` — modified to add `edit_uri:` substitution to the existing field-line rewrite block at lines 279-327. Existing four-field substitution (site_name, site_description, site_url, repo_url) preserved byte-identical; the new edit_uri is a fifth field-line.
- `scripts/wiki/` — read+write; new `resolve-default-branch.sh` joins the existing wiki-* scripts.

## Constraints

- **CON-1 — Zero new mkdocs plugin dependencies in P01**: `pymdownx.details` and `pymdownx.tasklist` are both BUILT INTO the existing `pymdown-extensions` package (already pulled in via `pymdownx.highlight` / `pymdownx.snippets` etc.). No `wiki/requirements.txt` change required. Confirm at execution time by running `pip show pymdown-extensions` against the repo's existing virtualenv.
- **CON-3 — Operator-authored keys survive every template-emit path**: T05 ships the polish-bundle additions as orchestrator-managed defaults. T06 ensures the merge primitive preserves operator-authored top-level keys when the bundle is refreshed. T05 does NOT itself implement merge semantics — it just declares which keys are orchestrator-managed.
- **CON-4 — Default-branch fallback to `main`**: `scripts/wiki/resolve-default-branch.sh` ALWAYS exits 0 with a usable branch name (real or `main` fallback). No fail-closed semantics; downstream consumers can rely on a non-empty stdout.
- **MEM001 — bash 3.2 + POSIX sh** in `resolve-default-branch.sh` and the modifications to `wiki-init.sh`.
- **AD-19 — Verifier shape**: `tools/verify/m037-p01-mkdocs-polish-bundle.sh` is project-owned, milestone-prefixed, single-script-file shape.

## Expected Output

- `scripts/wiki/resolve-default-branch.sh` exists, ≥ 15 lines, contains `symbolic-ref`, exits 0 with a branch name on stdout against this repo.
- `wiki/mkdocs.yml` carries all eight polish-bundle additions plus `edit_uri:`.
- `scripts/lifecycle/wiki-init.sh` substitutes `edit_uri:` at template-emit time using the helper.
- `tools/verify/m037-p01-mkdocs-polish-bundle.sh` exits 0.
- `tests/m037-acceptance/p01-mkdocs-polish-bundle.sh` exits 0.

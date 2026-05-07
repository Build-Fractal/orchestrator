---
schema_version: "1.0"
type: task-summary
task: "T05"
phase: "P01"
milestone: "M037"
---

# T05 — CON-4 default-branch helper + mkdocs.yml polish bundle

## What changed

- **`scripts/wiki/resolve-default-branch.sh`** — new 60-line helper (CON-4).
  Reads `git -C <project-dir> symbolic-ref refs/remotes/origin/HEAD` and
  strips the `refs/remotes/origin/` prefix to extract the bare branch name.
  Falls back to `main` on any failure (no remote, empty ref, prefix-strip
  miss, project dir missing). Always exits 0 with a usable branch name on
  stdout per CON-4 / AD-7. Stderr diagnostic emitted only when
  `WIKI_DEBUG=1`. Single-script-file shape (AD-19), bash 3.2 + POSIX sh
  (MEM001), contains literal `symbolic-ref` per phase plan artifact
  contract.

- **`wiki/mkdocs.yml`** — eight polish-bundle additions plus top-level
  `edit_uri:` (FR-9). Sentinel-bracketed under
  `# >>> M037-P01-T05 polish-bundle <category> ... # <<< M037-P01-T05 polish-bundle <category>`.
  Three categories of edits:
  - **Top-level**: new `edit_uri: "edit/main/wiki/docs/"` line, alongside
    the existing `site_name:` / `site_url:` / `repo_url:` keys.
  - **`theme.features:`**: prepend `navigation.tabs`, `navigation.tabs.sticky`,
    `navigation.prune`; append `content.action.edit`, `content.action.view`.
  - **`markdown_extensions:`**: modify existing `toc:` block to add
    `toc_depth: 2`; append `pymdownx.details` and
    `pymdownx.tasklist:` with `custom_checkbox: true`.

- **`scripts/lifecycle/wiki-init.sh`** — extends the four-field
  substitution block (FR-6) at lines 270-327 to a fifth field (`edit_uri:`).
  Computes `DEFAULT_BRANCH` via the new CON-4 helper and derives
  `EDIT_URI="edit/${DEFAULT_BRANCH}/wiki/docs/"` at template-emit time.
  Five-field idempotency gate (`match_count -eq required_matches` where
  `required_matches=5` normally, `=4` under the US-4 AS-4 skip path).
  Five-clause sed rewrite when edit_uri injection is active; falls back to
  the original four-clause rewrite when the skip path fires.
  - **US-4 AS-4 edge case**: when `repo_url:` is unset / empty / `{{...}}`
    placeholder in the staged mkdocs.yml, `EDIT_URI_SKIP=1` fires and the
    `edit_uri:` injection is skipped with a stderr diagnostic suggesting
    the operator set `repo_url:` to enable the wiki Edit/View action
    affordances. Preserves the byte-identical behavior of the existing
    four-field substitution path on operator-unconfigured remotes.

- **`tools/verify/m037-p01-mkdocs-polish-bundle.sh`** — new Truth #5
  verifier (single-script-file per AD-19, bash 3.2 + POSIX sh per MEM001).
  Nine checks against `wiki/mkdocs.yml`:
  1. `- navigation.tabs` under theme.features
  2. `- navigation.tabs.sticky`
  3. `- navigation.prune`
  4. `- content.action.edit`
  5. `- content.action.view`
  6. `toc_depth: 2` under toc:
  7. `- pymdownx.details`
  8. `- pymdownx.tasklist:` followed by `custom_checkbox: true`
     (asserted via awk ordering check)
  9. top-level `edit_uri:` key
  Emits `PASS: m037-p01-mkdocs-polish-bundle (9/9)` on full pass.

- **`tests/m037-acceptance/p01-mkdocs-polish-bundle.sh`** — new SC-4
  acceptance test (≥ 20 lines, contains literal `navigation.prune` per
  phase plan artifact contract, bash 3.2 + POSIX sh). Stages a fresh
  fixture under `mktemp -d`, copies this repo's polish-bundle-bearing
  `wiki/mkdocs.yml` as the fixture's pre-staged template (triggers
  `wiki-init.sh`'s `PRE_STAGE_NO_OP` branch — avoids invoking the bundle
  staging loop against a non-bundle fixture), `git init` + adds a fake
  origin URL, then **manually installs `refs/remotes/origin/HEAD` via
  `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main`**
  to make the resolver return `main` without touching the network.
  Invokes `bash wiki-init.sh --project-dir <fixture>` and asserts the
  rendered fixture mkdocs.yml carries all eight polish-bundle additions
  PLUS `edit_uri: "edit/main/wiki/docs/"` PLUS the regression-coverage
  `repo_url:` substitution. Emits `PASS: p01-mkdocs-polish-bundle` on full
  pass (13/13).

## CON-1 plugin discipline

`pymdownx.details` and `pymdownx.tasklist` are both built into the existing
`pymdown-extensions` package (already pulled in via `pymdownx.highlight`,
`pymdownx.snippets`, `pymdownx.superfences`, `pymdownx.tabbed`). **No
`wiki/requirements.txt` change** required; CON-1 plugin discipline
preserved.

## T04 coordination

T04 (commit `2031a9af`) added an `extra_css:` block under sentinel
`# >>> M037-P01-T04 extra_css ... # <<< M037-P01-T04 extra_css end` at
`wiki/mkdocs.yml` lines 54-57 (pre-T05). T05 does not touch that block;
post-T05 it lives unchanged at lines 70-73 (just shifted by T05's earlier
additions). Confirmed byte-identical via post-edit read.

## T06 coordination note

T06 (yaml-merge-and-install-emission) is unblocked. T06's install-template
emit path needs to (a) ship the new sentinel-bracketed polish-bundle blocks
in the install-template `mkdocs.yml`, AND (b) wire the `edit_uri:`
substitution into the install-template emission flow (or rely on
`wiki-init.sh`'s post-stage substitution to apply it — the simpler path
since wiki-init.sh already runs as a post-install step under `--with-wiki`).

## Verifier output

```
$ bash scripts/wiki/resolve-default-branch.sh
main

$ bash tools/verify/m037-p01-mkdocs-polish-bundle.sh
CHECK PASS: theme.features: - navigation.tabs
CHECK PASS: theme.features: - navigation.tabs.sticky
CHECK PASS: theme.features: - navigation.prune
CHECK PASS: theme.features: - content.action.edit
CHECK PASS: theme.features: - content.action.view
CHECK PASS: markdown_extensions: toc_depth: 2
CHECK PASS: markdown_extensions: - pymdownx.details
CHECK PASS: markdown_extensions: - pymdownx.tasklist: with custom_checkbox: true
CHECK PASS: top-level edit_uri: key present
SUMMARY: m037-p01-mkdocs-polish-bundle pass=9 fail=0
PASS: m037-p01-mkdocs-polish-bundle (9/9)

$ bash tests/m037-acceptance/p01-mkdocs-polish-bundle.sh
PASS: resolver returns 'main' against fixture remote
PASS: wiki-init.sh exited 0
PASS: fixture has - navigation.tabs
PASS: fixture has - navigation.tabs.sticky
PASS: fixture has - navigation.prune
PASS: fixture has - content.action.edit
PASS: fixture has - content.action.view
PASS: fixture has toc_depth: 2
PASS: fixture has - pymdownx.details
PASS: fixture has - pymdownx.tasklist:
PASS: fixture has custom_checkbox: true
PASS: fixture edit_uri: derives 'edit/main/wiki/docs/' from origin HEAD
PASS: fixture repo_url: substituted from fixture origin remote
SUMMARY: p01-mkdocs-polish-bundle pass=13 fail=0
PASS: p01-mkdocs-polish-bundle
```

## Regression checks

All three pre-existing P01 verifiers still PASS post-T05:

```
$ bash scripts/verify/decisions-shape-lint.sh
PASS: decisions-shape-lint .orchestrator/DECISIONS.md (28 entries, all anchors unique)

$ bash tools/verify/m037-p01-authoring-conventions-doc.sh
... PASS: m037-p01-authoring-conventions-doc (5/5)

$ bash tools/verify/m037-p01-dispatch-references-conventions.sh
PASS: m037-p01-dispatch-references-conventions

$ bash tools/verify/m037-p01-card-grid.sh
... PASS: m037-p01-card-grid (4/4)
```

## Must-haves (from T05 plan)

- [x] Truth #5 — `wiki/mkdocs.yml` template carries the polish bundle.
- [x] Phase artifact: `scripts/wiki/resolve-default-branch.sh`
      (60 lines ≥ 15, contains `symbolic-ref`).
- [x] Phase artifact: `tests/m037-acceptance/p01-mkdocs-polish-bundle.sh`
      (≥ 20 lines, contains `navigation.prune`).
- [x] SC-4 acceptance test passes (13/13).

## Notes

- `packaging/bundle/wiki/` does **not** exist as a separate file — the
  orchestrator dogfoods directly against `wiki/mkdocs.yml`. Per the T05
  plan's surfacing guidance ("the same file if the orchestrator dogfoods
  directly"), the polish bundle was applied to `wiki/mkdocs.yml` only.
  T06 will own the install-template emission path.
- The fixture's `git symbolic-ref refs/remotes/origin/HEAD
  refs/remotes/origin/main` setup is the network-free shortcut for
  `git remote set-head origin --auto`. Validated against the resolver
  helper before invoking wiki-init.sh.
- T06 (yaml-merge-and-install-emission) remains unblocked.

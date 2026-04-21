---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M012"
name: "Material comments-partial override + mkdocs.yml extra.giscus block"
depends_on: []
---

## Prerequisites

- P01 complete: `wiki/mkdocs.yml` exists with `theme.name: material`, `plugins: search + include-markdown`, `markdown_extensions`, and a marker-bounded `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` nav block. P02 may also have landed (knowledge-stubs + link-checker); none of P02's output is consumed by this task.
- `wiki/overrides/` does not yet exist.
- No `extra:` top-level block exists in `wiki/mkdocs.yml`.

## Description

Wire Giscus into the site via MkDocs Material's **comments-partial override** mechanism. Per the Material docs, the theme looks for a `partials/comments.html` file under the directory named by `theme.custom_dir`; any content in that partial is rendered at the bottom of every page (below the main content, above the footer). This is the AD-3-compliant injection point: the theme reads artifact bodies unchanged (via `include-markdown`) and the comment surface is appended by the theme at render time — no body-copy, no per-page authoring, no duplication.

Configuration values (repo, repo_id, category, category_id, mapping) are exposed to the partial via MkDocs' `extra:` block. Material's Jinja2 rendering context makes `config.extra.giscus.*` readable from within the partial. Values are env-interpolated (`!ENV` YAML tag) so production IDs are **not** committed — each operator supplies them at build time.

Out-of-scope for this task: pre-build loud-fail gate (T02), smoke test (T03), remap script (T04), verify scripts (T05).

## Steps

1. **Create `wiki/overrides/partials/comments.html`** — the Material theme override:

   ```html
   {% if page and page.meta and page.meta.comments == false %}
     {# Per-page opt-out: set `comments: false` in a page's YAML frontmatter
        to suppress Giscus on that page. Used nowhere in P03; reserved for
        future (e.g., an archive index that shouldn't collect comments). #}
   {% else %}
     <h2 id="__comments">Comments</h2>
     <script
       src="https://giscus.app/client.js"
       data-repo="{{ config.extra.giscus.repo }}"
       data-repo-id="{{ config.extra.giscus.repo_id }}"
       data-category="{{ config.extra.giscus.category }}"
       data-category-id="{{ config.extra.giscus.category_id }}"
       data-mapping="{{ config.extra.giscus.mapping }}"
       data-strict="1"
       data-reactions-enabled="1"
       data-emit-metadata="0"
       data-input-position="top"
       data-theme="preferred_color_scheme"
       data-lang="en"
       data-loading="lazy"
       crossorigin="anonymous"
       async
     ></script>
     <noscript>
       Please enable JavaScript to view the
       <a href="https://github.com/{{ config.extra.giscus.repo }}/discussions"
          rel="external nofollow noopener">comments powered by Giscus</a>.
     </noscript>
   {% endif %}
   ```

   File must contain the literal string `giscus.app/client.js` so the smoke script (T03) can grep for it in rendered HTML without Jinja interpolation ambiguity.

2. **Extend `wiki/mkdocs.yml`** with two additions. Do **not** modify the P01-owned marker-bounded nav block.

   a. Under the existing `theme:` stanza, add `custom_dir: overrides`:

   ```yaml
   theme:
     name: material
     custom_dir: overrides          # <-- added in M012/P03/T01
     features:
       - navigation.sections
       # ... existing features unchanged ...
   ```

   b. Append a top-level `extra:` block (above the P01 nav markers, conventionally after `markdown_extensions:`):

   ```yaml
   # >>> M012-P03 extra (Giscus wiring — T01)
   extra:
     giscus:
       repo:        !ENV [GISCUS_REPO,        ""]
       repo_id:     !ENV [GISCUS_REPO_ID,     ""]
       category:    !ENV [GISCUS_CATEGORY,    ""]
       category_id: !ENV [GISCUS_CATEGORY_ID, ""]
       mapping:     "pathname"
   # <<< M012-P03 extra end
   ```

   - `mapping: pathname` is a literal string — deterministic across operators. This is the AD-5 / SC-7 mapping choice; its tradeoff (breaks on rename, fixable by the remap script in T04) is documented in `wiki/README.md` by T04.
   - The `!ENV` YAML tag is supplied by MkDocs itself (it is not a custom extension). Default value is the empty string `""` — which is what T02's config-check gate trips on when an env var is unset.
   - Marker comments (`# >>> M012-P03 extra` / `# <<< M012-P03 extra end`) mirror the P01 nav-marker pattern so future regeneration / audit tooling can locate the block deterministically.

3. **Do not touch** the existing `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` block. The P01 generator writes it from scratch on every run; any P03 edit inside that region would be overwritten.

4. **Smoke-verify manually** (not wired as a Check):

   - `python3 -c "import yaml; yaml.safe_load(open('wiki/mkdocs.yml'))"` — YAML parses clean.
   - `grep -n 'custom_dir: overrides' wiki/mkdocs.yml` — one match.
   - `grep -n 'giscus.app/client.js' wiki/overrides/partials/comments.html` — at least one match.

## Must-Haves

- `wiki/overrides/partials/comments.html` exists, is ≥ 25 lines, and contains the literal `giscus.app/client.js`.
- `wiki/mkdocs.yml` contains `custom_dir: overrides` under `theme:`.
- `wiki/mkdocs.yml` contains an `extra.giscus` block with the five keys (`repo`, `repo_id`, `category`, `category_id`, `mapping`).
- Four of those keys use `!ENV [<NAME>, ""]` interpolation; `mapping` is the literal `"pathname"`.
- The P01-owned `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` region is byte-identical before and after this task's edits.
- The file `wiki/mkdocs.yml` still parses as valid YAML (no broken anchors, no tab/space mixing that breaks the Material loader).

## Verification

- `bash scripts/verify/m012-p03-comments-partial.sh` — PASS (T05 gate).
- `bash scripts/verify/m012-p03-mkdocs-giscus-config.sh` — PASS (T05 gate).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — artifact patterns + line counts satisfied for `wiki/overrides/partials/comments.html` and `wiki/mkdocs.yml`.

## Inputs

### From Previous Tasks

- None. T01 is the phase root.

### From Disk (Pre-existing)

- `wiki/mkdocs.yml` (P01 output) — base config with `theme.name: material`, `plugins: search + include-markdown`, `markdown_extensions`, and the marker-bounded P01 nav block.
  - Key invariant: the `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` region is owned by `scripts/wiki/wiki-generate-nav.sh`. Do not edit it.
- MkDocs Material theme override contract (external): a directory named by `theme.custom_dir` may contain `partials/<name>.html` files that override the theme's built-in partials. `partials/comments.html` is the designated comment-thread slot.
- `!ENV [<NAME>, <default>]` YAML tag (external): built into MkDocs' config loader; resolves to the named environment variable or the default at build time.

## Constraints

- **AD-3 SSOT** — comments are appended by the theme override, not by rewriting `.orchestrator/**.md` bodies. No per-page `<!-- giscus -->` markers in canonical artifacts.
- **No hardcoded production IDs** — the four ID env vars default to `""` so a config-less build surfaces the issue at T02's gate.
- **Bash 3.2 N/A** — this task ships no shell scripts; the compat gate trips only on files under `scripts/diagnostics/wiki-giscus-*.sh` and `scripts/verify/m012-p03-*.sh`, which land in T02–T05.
- **P01 boundary** — the P01 nav marker region is byte-stable across this task.
- **No new plugins** — Giscus integrates via a theme partial; no additional PyPI dependency is pulled. `wiki/requirements.txt` is not modified.
- **Marker-comment discipline** — the `# >>> M012-P03 extra` / `# <<< M012-P03 extra end` pair mirrors the P01 convention so future automation can locate the block.

## Expected Output

- `wiki/overrides/partials/comments.html` exists and contains the Giscus loader script.
- `wiki/mkdocs.yml` carries:
  - `theme.custom_dir: overrides`
  - `extra.giscus.repo`, `.repo_id`, `.category`, `.category_id` — all `!ENV` interpolated
  - `extra.giscus.mapping: "pathname"`
- The P01 nav region is unchanged.
- Running `mkdocs build` from `wiki/` (with the env vars set) produces HTML pages that include the Giscus script tag — this is verified end-to-end by T03's smoke script.

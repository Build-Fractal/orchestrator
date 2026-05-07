# spec-kit-orchestrator wiki (M012)

Dogfood-only MkDocs site that renders `.orchestrator/` artifacts.

## Install

```
cd wiki
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

Pinned versions are authoritative; do not upgrade without a paired commit
documenting why. See the inline note in `requirements.txt` for the
`pygments<2.19` constraint (works around a `filename=None` regression
in `pymdown-extensions==10.14.3`).

## Preview

From the repo root:

```
bash scripts/wiki/wiki-serve.sh
```

This runs `mkdocs serve -f wiki/mkdocs.yml` and binds a local port.

For a headless config-validation probe (used by auto-mode verify):

```
bash scripts/wiki/wiki-serve.sh --probe
```

## Regenerate

After any `.orchestrator/` change:

```
bash scripts/wiki/wiki-generate-stubs.sh
bash scripts/wiki/wiki-generate-nav.sh
```

Source of truth: `.orchestrator/**.md`. Stubs never carry body content;
they only `include-markdown` from the canonical path (M012 AD-3).

## Scope

See `.orchestrator/milestones/M012/M012-CONTEXT.md` for the binding
scope boundaries. Archive inclusion: all (AD-4). Giscus: added in P03.
Deploy: `mkdocs gh-deploy --force` (wired in P04).

## Link resolution

The dogfood wiki renders orchestrator artifacts from their canonical locations
under `.orchestrator/` (and the granular knowledge entries from `knowledge/`).
Internal markdown links inside those canonical files are rewritten at build
time so clicks on the rendered site land on the rendered target page — not on
the raw markdown and not on a broken path.

### In-scope link targets

A link is **in-scope** if its resolved destination is one of:

- Another `.orchestrator/**.md` artifact rendered as a stub under
  `wiki/docs/**` (the full scanner enumeration — see
  `scripts/wiki/wiki-scan-sources.sh`).
- A `knowledge/**/MEM*.md` entry rendered as a stub under
  `wiki/docs/knowledge/<category>/MEM###.md` (added in M012/P02/T02).
- An in-page anchor (`#section-id`) on the same rendered page.
- The consolidated `.orchestrator/KNOWLEDGE.md` page, including anchors of
  the form `#mem-NNNN` — these resolve when the consolidated file happens
  to carry a matching heading. Authors are encouraged to link to the
  granular entry (`knowledge/<cat>/MEM###.md`) by file path rather than to
  the consolidated-file anchor — the granular entry is the canonical cross-
  reference target per AD-1 (D011 criterion (a)).

The include-markdown plugin's `rewrite_relative_urls: true` option (set in
`wiki/mkdocs.yml`) handles the rewriting. Relative links inside an included
body (e.g., a reference to `milestones/M011/M011-SUMMARY.md` inside the
included `.orchestrator/DECISIONS.md` text) resolve against the stub's
rendered URL rather than against the canonical source path.

### Out-of-scope link targets

A link is **out-of-scope** if it is:

- An absolute URL: `http://`, `https://`, `mailto:`, `tel:`, or `ftp:`.
- A repo-root-relative path that escapes the site tree: `scripts/**`,
  `tests/**`, `commands/**`, `templates/**`, `references/**`, `docs/**`,
  `packaging/**`, or any other path outside `.orchestrator/` and
  `knowledge/`. Repo-root files such as `README.md` and `CHANGELOG.md`
  are likewise out-of-scope.

Out-of-scope links are flagged and enumerated by the link-checker but do not
fail the build. They are not rewritten; they render as literal paths. Authors
who want an external link to resolve on the rendered site should point it at
the GitHub source URL rather than at a repo-relative path.

A future enhancement (out of scope for M012) could auto-rewrite repo-root-
relative out-of-scope paths to `https://github.com/<org>/<repo>/blob/main/<path>`.
Until that ships, authors are responsible for writing absolute URLs when an
external link is desired.

### Broken link handling

If an in-scope link does not resolve — the target stub is missing, a
renamed artifact was not picked up by the generators, an anchor was typed
incorrectly — the link-checker emits a `BROKEN:` line and exits non-zero.
See "Running the link checker" below.

## Running the link checker

The link checker is `scripts/diagnostics/wiki-link-check.sh`. It walks an
already-built MkDocs site directory; it does not invoke mkdocs itself.

### Typical local workflow

From the repo root:

```
(cd wiki && mkdocs build)
bash scripts/diagnostics/wiki-link-check.sh --site wiki/site
```

Expected output on success:

```
PASS: 0 broken in-scope links (<N> pages, <M> in-scope ok, <K> out-of-scope)
```

Expected output on failure:

```
BROKEN: wiki/site/decisions/index.html -> ../missing-target.html [file missing: ...]
FAIL: 1 broken in-scope link(s) across <N> source pages (<M> ok, <K> out-of-scope)
```

Exit codes:

- `0` — zero broken in-scope links.
- `1` — one or more broken in-scope links.
- `2` — usage error (missing site directory, no HTML files found).

### Flags

- `--site <dir>` — point at an alternative built-site directory (useful
  when using `wiki-serve.sh --probe`, which builds under `/tmp/`).
- `--root <dir>` — override project root (default: invocation cwd).
- `--strict` — treat path-escape out-of-scope findings as broken (stricter
  mode for CI; default remains enumerate-only).
- `--help` — print usage and exit.

### Interpreting out-of-scope output

Every `OUT-OF-SCOPE:` line is informational. A high volume of out-of-scope
lines is expected — the canonical artifacts routinely reference
`scripts/**`, `templates/**`, etc. If the count grows unexpectedly, scan
for new canonical references that ought to be rewritten; most often, the
fix is to cite a file by its `.orchestrator/` or `knowledge/` path rather
than by a repo-root-relative path to source code.

## Pre-deploy integration (P04)

M012/P04 (deploy pipeline) wires two pre-build hooks before `mkdocs
gh-deploy`:

1. `scripts/diagnostics/wiki-link-check.sh` — this checker, run against the
   freshly built site. Non-zero exit aborts the deploy.
2. `scripts/diagnostics/wiki-giscus-smoke.sh` — the Giscus smoke test (P03
   deliverable). Non-zero exit aborts the deploy.

The hooks are intentionally kept as separate scripts — not a monolithic
pre-deploy script — so operators can invoke each one independently during
development. The deploy wrapper P04 ships chains them; the individual
scripts remain directly callable. T04 (this task) documents the contract
only; no hooks are wired here — P04 owns the pipeline.

### `mkdocs build --strict` alignment

Running `mkdocs build --strict -f wiki/mkdocs.yml` fails the build on:

- Pages that are not referenced from the nav.
- Internal markdown links whose target files are missing.

Both checks overlap partially with `wiki-link-check.sh`. The distinction:

- `mkdocs build --strict` operates on markdown source and on nav structure
  — it catches structural misalignments (nav entries pointing at nothing,
  orphaned pages).
- `wiki-link-check.sh` operates on the generated HTML — it catches
  rendered-output issues (rewritten link targets, anchor resolution, query
  string handling) that the markdown-source check cannot see.

Both are run in P04. Neither subsumes the other. If the local environment
has mkdocs installed, running both before every deploy is the documented
workflow.

## Giscus mapping

Giscus uses `mapping: pathname` — each rendered page maps to a GitHub
Discussion whose title equals the page's URL path. The strategy is
configured in `wiki/mkdocs.yml` under `extra.giscus.mapping`.

### Tradeoffs

- **Simple and deterministic.** A page at `/decisions/` has a
  Discussion titled `/decisions/`. No metadata injection, no per-page
  authoring cost.
- **Breaks on rename.** If an artifact is moved (e.g., consolidated
  under `.orchestrator/archive/`), its rendered URL changes. Giscus
  sees a new pathname and creates a fresh empty thread, orphaning the
  prior comments. The fix is the remap script below.
- **Survives content edits.** Editing an artifact's body does not
  change its URL — comments stay attached.
- **Survives theme / partial changes.** The mapping is keyed at the
  page URL level; reshuffling the theme override does not orphan
  threads.

The smoke script (`scripts/diagnostics/wiki-giscus-smoke.sh`) verifies
that every rendered HTML page carries the Giscus loader. It does NOT
verify thread continuity across renames — that's what the remap script
handles.

## Remapping threads after consolidation

When an artifact is consolidated (moved or renamed), its rendered URL
changes. Run the remap script from the repo root to relabel the
corresponding Discussion so Giscus' pathname-matcher reconnects the
thread at the new URL on next page load:

```
bash scripts/diagnostics/wiki-giscus-remap.sh /old/path/ /new/path/
```

Dry-run mode (no GitHub API calls — prints planned operations):

```
bash scripts/diagnostics/wiki-giscus-remap.sh --dry-run /old/path/ /new/path/
```

Env vars `GISCUS_REPO` and `GISCUS_CATEGORY` default the target; pass
`--repo` and `--category` to override. `gh` must be on PATH for
non-dry-run mode. The script is idempotent — rerunning after a
successful remap prints `NOOP:` for every already-migrated pair.

Multiple pairs are supported in a single invocation:

```
bash scripts/diagnostics/wiki-giscus-remap.sh /old/a/ /new/a/ /old/b/ /new/b/
```

Output lines (one per pair): `DRY-RUN:`, `OK:`, `NOOP:`, or `FAIL:`.
No quiet success. Ambiguous-match safety: if two Discussions carry the
same old title, the script fails closed (exit 1) on that pair without
attempting a rename, so human judgment is required.

After a remap, rebuild the wiki and run the smoke script to confirm
the page still renders the Giscus loader:

```
(cd wiki && mkdocs build)
bash scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site
```

Pre-build env-var check (companion to this flow — confirms
`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`
are set before `mkdocs build`):

```
bash scripts/diagnostics/wiki-giscus-config-check.sh
```

### Exit codes

- `0` — all pairs resolved (dry-run, rename succeeded, or already-migrated `NOOP`).
- `1` — at least one pair failed (ambiguous match, id-extract failure, or `gh` mutation error).
- `2` — usage error (unknown flag, odd positional-arg count, or missing `--repo`/`--category`/`gh` in non-dry-run).

## First-deploy checklist

Run this exactly once when standing up the dogfood wiki on a fresh
GitHub Pages deployment. Subsequent deploys use the "Running the
deploy wrapper" section below.

> **Private-repo note:** the giscus.app setup tool validates that the
> target repo is public and will refuse to generate config for private
> repos. This is a false-positive for the internal-team case — the
> underlying giscus GitHub App + client.js work fine on private repos
> for authenticated team members who have repo read access. Skip
> giscus.app entirely; install the App directly (step 1) and let
> `wiki-init --with-giscus` fetch the four IDs via `gh`.

### 1. Install the giscus GitHub App + enable Discussions

Operator-UI work, not scriptable:

- Open <https://github.com/apps/giscus> → **Install** → pick the
  target org → **Only select repositories** → your repo.
- Settings → General → Features → check **Discussions**, then go to
  the Discussions tab and create a category named `Wiki Comments`
  (any name works — just note it for step 2).

### 2. Run `wiki-init --with-giscus`

```
bash scripts/lifecycle/wiki-init.sh \
  --project-dir <path> \
  --with-giscus --repo <org>/<repo> --category "Wiki Comments"
```

This fetches the four `GISCUS_*` IDs via `gh`, substitutes them into
`wiki/overrides/partials/comments.html`, and persists them to
`<path>/.env` under a `# >>> orchestrator-managed: giscus >>>` marker
block. The marker block is replaced in place on re-run, so it is
safe to re-invoke when IDs change.

### 3. Run the deploy wrapper

```
bash scripts/wiki/wiki-deploy.sh
```

The wrapper sources `<path>/.env` automatically before gate 1, so
the four `GISCUS_*` values written by step 2 are picked up without
the operator needing to source the file in their shell. On success
the last two lines read `DEPLOY: pushing to gh-pages` and `OK:
deployed to https://<org>.github.io/<repo>/`. On any gate failure
the wrapper aborts before pushing and emits a `FAIL:` line naming
which gate failed.

> **Why `.env` is gitignored**: the four `GISCUS_*` values include
> the repo+category IDs giscus uses to authorize comment posts. The
> orchestrator's root `.gitignore` already lists `.env`. If your
> consumer project's `.gitignore` does not yet ignore `.env`, step 2
> emits a `WARN:` line — add `.env` to your project's `.gitignore`
> before committing.

### 4. Smoke-test the deployed URL

Open the deployed URL. Confirm:

- The home page carries the four orientation sections (What this
  site is / How to navigate / Where to comment / Audience scope).
- Every rendered page carries a Giscus thread at the bottom.
- The search box returns hits for at least one term from every
  top-level section (Constitution, Decisions, Knowledge, Milestones).
- Sign in with GitHub, post a test comment on any page, reload the
  page — the comment persists (US2 / SC-5).

### 5. Record the deploy

Copy the deploy URL and commit SHA into
`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`. That
file's schema is asserted by `scripts/verify/m012-p04-deploy-record.sh`.

<details>
<summary>Manual recovery (if <code>wiki-init --with-giscus</code> is unavailable)</summary>

Older bundles, sandboxed environments without `gh` auth, or operators
who want to understand the underlying flow can run the original
8-step recovery directly:

1. Install the giscus GitHub App and enable Discussions (as in
   step 1 above).
2. Fetch the four `GISCUS_*` values directly via the helper:

   ```
   bash scripts/diagnostics/giscus-ids-from-gh.sh \
     --repo <org>/<repo> --category "Wiki Comments"
   ```

3. Paste the four `export` lines it prints into your shell, OR
   into `<path>/.env` under a marker block:

   ```
   # >>> orchestrator-managed: giscus >>>
   export GISCUS_REPO="..."
   export GISCUS_REPO_ID="..."
   export GISCUS_CATEGORY="..."
   export GISCUS_CATEGORY_ID="..."
   # <<< orchestrator-managed: giscus <<<
   ```

4. Enable GitHub Pages: Settings → Pages → Source → **Deploy from
   a branch** → Branch: `gh-pages` → `/ (root)`. On the very first
   deploy the branch does not yet exist; the wrapper creates it.
5. Ensure `gh` is on PATH for any future Giscus consolidation
   (`scripts/diagnostics/wiki-giscus-remap.sh`).
6. Run `bash scripts/wiki/wiki-deploy.sh`.
7. Record the deploy URL + SHA into the deploy record (as in step
   5 above).
8. Smoke-test the URL (as in step 4 above).

A missing or empty `GISCUS_*` value trips the pre-build config-check
gate with a diagnostic line naming the missing var — see
`scripts/diagnostics/wiki-giscus-config-check.sh`.

</details>

## Running the deploy wrapper

`scripts/wiki/wiki-deploy.sh` is the single documented command
for deploying or redeploying the dogfood wiki. It chains four
gate-shaped invocations before invoking `mkdocs gh-deploy --force`
and aborts on the first failure.

### Pipeline

1. `scripts/diagnostics/wiki-giscus-config-check.sh` — verifies
   every `GISCUS_*` env var is set.
2. `mkdocs build -f wiki/mkdocs.yml` — renders `wiki/site/`.
3. `scripts/diagnostics/wiki-link-check.sh --site wiki/site` — walks
   the built HTML, flags broken in-scope links.
4. `scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site` —
   asserts every page carries the Giscus loader.

Then, on success: `mkdocs gh-deploy --force -f wiki/mkdocs.yml`
pushes `wiki/site/` to the `gh-pages` branch.

### Flags

- `--dry-run` — run all four gates, skip the final `mkdocs
  gh-deploy`, print `DRY-RUN: would deploy` and exit 0.
- `--help` — print the usage block naming each gate and each
  supported flag, then exit 0.
- `--root <dir>` — override the project root (default: invocation
  cwd).
- `--skip-smoke` — skip gate (4) only. Not recommended for
  production deploys; useful during P04 development before the
  fixture site contains Giscus-configured pages.

### Output lines

- `GATE: <name> PASS|FAIL` — one per gate.
- `BUILD: ok|fail` — `mkdocs build` result.
- `DEPLOY: pushing to gh-pages` — pre-push announcement on the
  live path.
- `DRY-RUN: would deploy` — terminator on `--dry-run` success.
- `OK: deployed to <url>` — terminator on live-path success.
- `FAIL: <gate> <diagnostic>` — terminator on any gate failure.

### Exit codes

- `0` — every gate PASS and (live path) `mkdocs gh-deploy` exit 0.
- `1` — any gate FAIL, `mkdocs build` fail, or `mkdocs gh-deploy`
  fail.
- `2` — usage error (unknown flag, missing argument, invalid
  `--root`).

### Failure triage

- `GATE: giscus-config FAIL` — one or more `GISCUS_*` env vars is
  unset. Re-export per the first-deploy checklist step 3.
- `BUILD: fail` — `mkdocs build` emitted errors (often a nav entry
  pointing at a non-existent page). Regenerate stubs + nav:
  `bash scripts/wiki/wiki-generate-stubs.sh && bash scripts/wiki/wiki-generate-nav.sh`,
  then rerun the wrapper.
- `GATE: link-check FAIL` — the built site contains a broken
  in-scope link. Inspect the `BROKEN:` lines in the gate output;
  the usual fix is a missing stub (regenerate) or a typoed
  anchor in a canonical artifact.
- `GATE: giscus-smoke FAIL` — a rendered HTML page is missing the
  Giscus loader. Check `wiki/overrides/partials/comments.html` is
  present and `wiki/mkdocs.yml` still carries `theme.custom_dir: overrides`.

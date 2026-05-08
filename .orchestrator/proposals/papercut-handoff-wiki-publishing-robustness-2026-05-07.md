---
schema_version: "1.0"
type: proposal
status: pending
priority: high (PBJ this week — Gap 1 was a 7-day outage in the dogfood project)
captured_at: "2026-05-07"
captured_by: "PBJ-central M037 P01 wiki-deploy second-deploy session (upstream patch handoff)"
folds_into: |
  Both gaps absorb into M037 P01 (wiki team-feedback-ready) as
  F12 (workflow-based publishing) and F13 (private-repo site_url
  visibility branch). F9 (added earlier same day) is SUPERSEDED
  by F12 — the legacy-builder Pages-rebuild poll has nothing to
  verify once we stop using the legacy builder. Captured here as
  the canonical record so the handoff's reference impl + acceptance
  criteria + test scaffolds don't get lost when the M037 P01 plan
  enters specify/roadmap.
---

# Paper-Cut Handoff — wiki publishing pipeline robustness (2026-05-07)

## Why a handoff doc (not a sweep)

This came in as a **self-contained upstream-patch handoff** authored
from the PBJ-central dogfood project, not as a session paper-cut list.
The handoff carries verbatim reference implementations (workflow YAML,
visibility-detection bash), test scaffolds, and a done-definition the
upstream patch must satisfy. Preserving it as a single doc keeps the
reference material intact for whoever ships M037 P01.

The handoff itself recommends two single-commit branches
(`papercut/wiki-publish-via-actions` + `papercut/wiki-private-pages-
site-url`) or one combined `papercut/wiki-publishing-robustness`
branch. Either is compatible with M037 P01 absorption — the planning
brief just needs to know both shapes exist.

## Disposition

| # | Gap | Severity | Disposition |
|---|---|---|---|
| 1 | `mkdocs gh-deploy` against gh-pages branch is fragile (legacy `pages-build-deployment` builder can wedge into unrecoverable `queued` state — 7-day stuck deploy in dogfood) | HIGH | M037 P01 (F12 in brief) — **supersedes F9** (Pages-rebuild poll) |
| 2 | Scaffolded `site_url` breaks 404 page styling on private repos (mkdocs-material 404.html uses absolute asset paths derived from `site_url`; private-pages random subdomain has no path prefix) | medium-high | M037 P01 (F13 in brief) |

## F9 supersession

**Before this handoff** (sweep on 2026-05-07 morning), F9 added a
Pages-rebuild poll to `wiki-deploy.sh`: after `git push origin
gh-pages`, poll `gh api .../pages/builds/latest` for ~60s waiting for
a fresh `created_at`. The intent was operator confidence that the
legacy builder actually rebuilt.

**After this handoff**: F12 stops using the legacy builder entirely
(`mkdocs gh-deploy` removed from `wiki-deploy.sh` live path; deploys
flow through `actions/deploy-pages` workflow triggered by push to
main). There is no longer a gh-pages branch push to verify; there
is no longer a legacy `pages-build-deployment` run to poll. **F9 has
nothing to verify and is obsolete.**

F9's operator-confidence intent transfers to F12: the new
`wiki-deploy.sh` print-and-exit replacement surfaces the workflow
URL, and operators get full Actions observability (cancel, rerun,
logs) instead of the unobservable legacy builder.

When M037 P01 enters specify/roadmap, the F9 entry should be removed
from the brief (or kept as a SUPERSEDED note for historical context),
and the P01 acceptance criterion derived from F9 should be replaced
with F12's workflow-mode acceptance.

---

## Gap 1 — Workflow-based publishing scaffold

### Symptom

Operator follows the M032 wiki-deploy quickstart, ships once
successfully via `bash scripts/wiki/wiki-deploy.sh`, then days later
pushes a content change and runs the same script. Gates pass,
`mkdocs gh-deploy` reports success, gh-pages branch updates — but
the live site never changes. Investigation:

```
$ gh run list --limit 5
queued       pages build and deployment    pages-build-deployment    gh-pages    25145703975    7d ago
completed    success    pages build and deployment    pages-build-deployment    gh-pages    25145555341    7d ago
```

Earlier run is stuck `queued`. New pushes deduplicate against it.
Every recovery endpoint refuses:

```
$ gh run cancel 25145703975
Cannot cancel a workflow run that is completed
$ gh api -X POST repos/.../actions/runs/25145703975/force-cancel
{"message":"Cannot cancel a workflow re-run that has not yet queued.","status":"409"}
$ gh api -X DELETE repos/.../actions/runs/25145703975
{"message":"Could not delete the workflow run","status":"403"}
$ gh api -X DELETE repos/.../pages
{"message":"Deactivating GitHub pages for this repository is not allowed.","status":"422"}
```

Toggling `build_type: legacy → workflow → legacy` doesn't unstick
it. Dogfood project lived with the outage 7 days before giving up
on the legacy builder.

### Root cause

`scripts/wiki/wiki-deploy.sh` (scaffold-emitted) calls `mkdocs
gh-deploy --force -f wiki/mkdocs.yml` on the live-deploy path.
`gh-deploy` builds the site, force-pushes `wiki/site/` to the
`gh-pages` branch, and relies on GitHub's legacy `pages-build-
deployment` workflow — which has known robustness issues:

1. Stuck `queued` runs cannot be force-cancelled, deleted, or
   rerun via any documented API.
2. New events to the same branch dedupe against the stuck run.
3. `DELETE /repos/.../pages` is gated by org-level policy on
   Enterprise plans, blocking the "turn it off and on again"
   recovery for many setups.
4. Toggling `build_type` between `legacy` and `workflow` doesn't
   clear the stuck state.

The modern path is workflow-based publishing:
`actions/configure-pages` + `actions/upload-pages-artifact` +
`actions/deploy-pages`, with `build_type: workflow`. Bypasses the
legacy builder entirely; deploys are normal Actions runs, fully
observable, fully cancellable, fully rerunnable.

### Fix shape (F12 in M037 P01)

Four sub-patches that ship together:

**1. Scaffold `.github/workflows/pages.yml`** — `wiki-init.sh` (or
the relevant init-flow module) emits the workflow file. Reference
implementation from dogfood project commit `e7a722e`:

```yaml
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
```

End-to-end timing in dogfood: build ~50s, deploy ~10s, total ~1
min from push to live.

**2. Set `build_type: workflow` during init** — after the workflow
file is staged, call:

```bash
gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow
```

If `gh` is unavailable or unauthenticated, print a clear manual
fallback with the same command for the operator to run later.

**3. Demote `wiki-deploy.sh` live path** — keep gates 1-4 (giscus-
config-check + mkdocs build + link-check + giscus-smoke) as local
pre-push validation. Drop gate 5 (`mkdocs gh-deploy --force`).
Replace with print:

```bash
echo "OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:"
echo "    git push origin main"
echo ""
echo "Workflow run: https://github.com/$OWNER/$REPO/actions/workflows/pages.yml"
```

Or convert to a `--dry-run`-only tool by removing the live path
entirely. M032 wiki-deploy quickstart docs need updating either way.

**4. Confirm `wiki/requirements.txt`** — the workflow's `pip install
-r wiki/requirements.txt` line uses it. Dogfood project already has
it (5 lines, mkdocs + mkdocs-material + plugins). If the scaffold
doesn't already emit it, add one with the same pinned deps the
existing tooling uses.

### Acceptance

From a clean shell, fresh project install:

```bash
mkdir /tmp/wiki-publish-test && cd /tmp/wiki-publish-test && git init
git remote add origin git@github.com:Test-Org/test-repo.git
bash /path/to/orchestrator/packaging/install/install-claude-code.sh \
  --project-dir . --force
bash scripts/lifecycle/wiki-init.sh --project-dir . [...giscus flags...]
```

Should leave the project with:
- `.github/workflows/pages.yml` present and committable.
- Repo's Pages config showing `build_type: workflow` (verify:
  `gh api repos/Test-Org/test-repo/pages | jq .build_type`).
- `scripts/wiki/wiki-deploy.sh` either gated to dry-run-only or
  printing "use git push" instead of running gh-deploy.

After committing scaffold + a sample doc and pushing to main:
- A `Deploy wiki to Pages` workflow run starts within ~10s.
- Run completes within ~2 min (build + deploy).
- Site is live at the URL `actions/deploy-pages` reports.
- No `pages-build-deployment` legacy runs are created.

### Test coverage

`tests/test-wiki-init-workflow-mode.sh`:

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

Wire into the test runner. Will fail before the patch (current
scaffold uses gh-deploy on live path) and pass after.

---

## Gap 2 — Private-repo `site_url` visibility branch

### Symptom

Operator successfully ships their wiki via the workflow-based deploy.
Real pages render fine. Operator clicks a nav entry whose backing
file doesn't exist (common — see M037 P02 corpus-surface work, or
any repo with stub-emission gaps). Browser navigates to a URL like
`https://<random>.pages.github.io/some-broken-link.md` and renders a
column of giant unstyled SVG icons (book, hamburger, magnifier,
back-arrow). No copy. No theme. No layout.

Looks like a CSS deployment failure. Isn't.

DevTools network panel: 404 on every CSS file. Asset paths are all
`https://<random>.pages.github.io/<repo-name>/assets/stylesheets/...`.
The `<repo-name>/` path prefix doesn't exist on the random
subdomain.

### Root cause

mkdocs-material builds two kinds of pages:

- **Regular doc pages** (e.g., `/foo/bar/`): asset references use
  **relative paths** (`../../assets/stylesheets/main.css`). Depth-
  independent; works at any URL.
- **`404.html`**: asset references use **absolute paths derived from
  `site_url`** (e.g., `/<repo-name>/assets/stylesheets/main.css`).
  mkdocs doesn't know what depth the unknown URL was at, so relative
  paths can't resolve correctly. Falls back to absolute.

The scaffolded `wiki/mkdocs.yml` sets:

```yaml
site_url: "https://<org>.github.io/<repo>/"
repo_url: "https://github.com/<org>/<repo>"
```

Correct for **public** repos: GitHub Pages serves them at
`https://<org>.github.io/<repo>/` and the path prefix matches.

For **private** repos (Pro/Team/Enterprise plans, including the
dogfood project), GitHub Pages serves at a randomized access-
controlled `https://<random>.pages.github.io/` URL **without the
`/<repo>/` prefix**. Real pages still render (relative asset paths).
404.html breaks (absolute paths point at a non-existent prefix on
the random subdomain).

The scaffold doesn't detect repo visibility and unconditionally
writes the public-shaped `site_url`.

### Fix shape (F13 in M037 P01)

**Recommended option: detect visibility at init, write `site_url`
accordingly.**

`scripts/lifecycle/wiki-init.sh` already calls `gh` for repo
metadata. Add:

```bash
VISIBILITY="$(gh api "repos/$OWNER/$REPO" --jq .visibility 2>/dev/null || echo public)"

if [ "$VISIBILITY" = "private" ]; then
  # Private repos serve at randomized <random>.pages.github.io/
  # without path prefix. Empty site_url makes mkdocs-material fall
  # back to relative-only paths, including in 404.html.
  SITE_URL=""
  PRIVATE_NOTE="# Private repo: site_url empty so 404.html uses relative paths."
else
  SITE_URL="https://$OWNER.github.io/$REPO/"
  PRIVATE_NOTE=""
fi
```

Template `mkdocs.yml`:

```yaml
$PRIVATE_NOTE
site_url: "$SITE_URL"
```

Verification: `mkdocs build` with empty `site_url` produces a
`site/404.html` whose `<link rel="stylesheet">` href is relative
(`../assets/...`) instead of absolute. mkdocs-material handles this
gracefully — confirmed in dogfood project testing
(mkdocs-material 9.5.49).

**Alternative options considered (deferred):**

- **Option 2 — workflow-time `site_url` override** via env var
  (`site_url: !ENV [SITE_URL, ""]` + `actions/configure-pages`
  `base_url` output). More moving parts; assumes the action's output
  surface stays stable. Good follow-up if operators ever need
  per-environment `site_url`s (preview vs. prod).
- **Option 3 — ship `wiki/docs/overrides/404.html`** with hand-
  written relative-path template. Documented mkdocs-material
  extension point but ongoing maintenance burden as 404.html
  evolves upstream.

Smallest scaffold delta + matches existing wiki-init "detect repo
state, write conf accordingly" pattern → Option 1 is the choice.

### Acceptance

Private repo, fresh install:

```bash
gh repo create Test-Org/test-private-wiki --private
cd $(mktemp -d) && git init
git remote add origin git@github.com:Test-Org/test-private-wiki.git
bash /path/to/orchestrator/packaging/install/install-claude-code.sh \
  --project-dir . --force
bash scripts/lifecycle/wiki-init.sh --project-dir . [flags]

grep '^site_url:' wiki/mkdocs.yml
# Expected: site_url: "" (or missing entirely)

bash scripts/wiki/wiki-deploy.sh --dry-run     # should still pass gates
mkdocs build -f wiki/mkdocs.yml
grep -E '<link.*stylesheet' wiki/site/404.html
# Expected: relative href ("../assets/..." or "assets/..."),
# NOT absolute ("/test-private-wiki/assets/...")
```

Then push, wait for the workflow to deploy, visit
`https://<random>.pages.github.io/some-broken-path` in a browser.
The 404 page should render with full theming.

Public repo regression check:

```bash
gh repo create Test-Org/test-public-wiki --public
# ... same flow ...
grep '^site_url:' wiki/mkdocs.yml
# Expected: site_url: "https://Test-Org.github.io/test-public-wiki/"
```

Existing public-repo behavior must not regress.

### Test coverage

`tests/test-wiki-init-private-site-url.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# Mock `gh api .../repos/X --jq .visibility` to return "private" then "public".
# (test harness pattern — adapt to upstream test conventions)

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; cd "$WORK"
git init -q
git remote add origin git@github.com:Test-Org/test-repo.git

# Case 1: private
GH_VISIBILITY_OVERRIDE=private bash "$ROOT/scripts/lifecycle/wiki-init.sh" \
  --project-dir . [flags]
SITE_URL_LINE="$(grep '^site_url:' wiki/mkdocs.yml || echo MISSING)"
case "$SITE_URL_LINE" in
  *'""'*|MISSING) ;;
  *) echo "FAIL: private repo got non-empty site_url: $SITE_URL_LINE"; exit 1 ;;
esac

# Case 2: public
rm -rf wiki .github
GH_VISIBILITY_OVERRIDE=public bash "$ROOT/scripts/lifecycle/wiki-init.sh" \
  --project-dir . [flags]
grep -q '^site_url: "https://Test-Org.github.io/test-repo/"' wiki/mkdocs.yml || \
  { echo "FAIL: public repo got wrong site_url"; exit 1; }

echo "PASS: site_url branches on repo visibility"
```

Mock-`gh` mechanism depends on upstream test conventions; adapt
accordingly.

---

## Other concerns surfaced (worth knowing, not blocking)

1. **The legacy `pages-build-deployment` zombie can persist after
   switching to workflow mode.** Switching `build_type` to `workflow`
   doesn't clear the stuck legacy run; it just stops dedupe-blocking
   new pushes. The zombie sits in `gh run list` indefinitely.
   Cosmetic only — doesn't affect new workflow-based deploys — but
   it's confusing. No fix recommended unless GitHub adds a clearance
   API.

2. **`/pages/builds` API returns `[]` while runs are stuck.** During
   the dogfood incident, the API returned an empty array even
   though `gh run list` showed a stuck `pages-build-deployment`.
   Suggests these are tracked in different GitHub-internal systems
   and don't reconcile. Diagnostic note for future operators.

3. **Private-pages random URLs may rotate.** The
   `<random>.pages.github.io/` subdomain is generated when Pages is
   first enabled on a private repo. If Pages is disabled and
   re-enabled, the subdomain may change. Documentation-side concern;
   not a code patch.

4. **`site_url` and giscus can drift.** giscus's mapping config (in
   `mkdocs.yml`'s `extra:` block) references `pathname`. On a
   private-pages random subdomain, pathname behavior is the same as
   public — no special handling needed today. But if a future patch
   uses giscus's `url` mapping mode, it'd interact with the
   `site_url` decision.

---

## Done definition (carried verbatim from the handoff)

Upstream patches done when ALL of:

- [ ] **Gap 1**: `scripts/lifecycle/wiki-init.sh` (or relevant init-
      flow module) emits `.github/workflows/pages.yml` with the
      workflow-based publishing pipeline shown above.
- [ ] **Gap 1**: init flow calls `gh api -X PUT repos/.../pages -f
      build_type=workflow` (or prints fallback instruction).
- [ ] **Gap 1**: `scripts/wiki/wiki-deploy.sh`'s live `mkdocs
      gh-deploy` step removed or gated to a non-default mode.
- [ ] **Gap 1 test**: `tests/test-wiki-init-workflow-mode.sh` added;
      fails before patch, passes after.
- [ ] **Gap 2**: `scripts/lifecycle/wiki-init.sh` detects repo
      visibility via `gh api .../repos/{OWNER}/{REPO} --jq .visibility`
      and writes empty `site_url` for private, full URL for public.
- [ ] **Gap 2 test**: `tests/test-wiki-init-private-site-url.sh`
      added; covers both branches; fails before patch, passes after.
- [ ] M032 wiki-deploy quickstart updated to reflect "git push
      triggers deploy" flow (no more `bash scripts/wiki/wiki-deploy.sh`
      for live deploys).
- [ ] All pre-existing tests still pass.
- [ ] Commit message(s) reference this handoff and the dogfood
      project's M037 P01 second-deploy session as the discovery
      surface.
- [ ] **F9 cleanup**: M037 P01 brief and any acceptance criteria
      derived from F9 updated/removed (F9 supersession block above).

## What this unblocks downstream

After M037 P01 lands both patches:

```bash
# Private repo (e.g., enterprise-internal docs):
gh repo create Acme-Internal/docs --private
cd $(mktemp -d) && git init
git remote add origin git@github.com:Acme-Internal/docs.git
bash /path/to/orchestrator/packaging/install/install-claude-code.sh \
  --project-dir . --force
bash scripts/lifecycle/wiki-init.sh --project-dir . [flags]
git add . && git commit -m "scaffold wiki" && git push -u origin main

# ~1 min later: workflow deploys. Site live at <random>.pages.github.io/.
# 404 pages render styled. Real pages render styled. No legacy-builder
# dependency.
```

Same flow on public repos (`site_url` branches automatically; Pages
serves at `<org>.github.io/<repo>/`). Publishing pipeline is robust
to GitHub legacy-builder failures, which were the dogfood project's
single largest source of deploy-pipeline downtime.

## Cross-references

- `.orchestrator/proposals/M037-wiki-team-feedback-ready.md` —
  absorbs both gaps as F12 (workflow-based publishing) and F13
  (private-repo `site_url` visibility branch); supersedes F9.
- `.orchestrator/proposals/papercut-sweep-wiki-deploy-2026-05-07.md`
  — sibling sweep filed earlier same day; F9 source. F1/F5/F7 there
  are unrelated and stay valid.
- `.orchestrator/proposals/papercut-wiki-deploy-env-loader.md` —
  giscus secrets paper-cut; same `wiki-init.sh` surface area.
- Dogfood discovery surface: M037 P01 wiki-deploy second-deploy
  session, 2026-05-07 (`/Users/brettkellgren/Sites/pbj-central-mono-repo`).
- Reference workflow implementation: `.github/workflows/pages.yml`
  at commit `e7a722e` in `pbj-central-mono-repo`.
- Pages config flip command (executed during dogfood remediation):
  `gh api -X PUT 'repos/PBJ-Central/pbj-central-mono-repo/pages' -f
  build_type=workflow`.
- Stuck legacy run that triggered the investigation: `25145703975`
  (`pages-build-deployment` on `gh-pages`, queued 7 days,
  irrecoverable via documented APIs).
- mkdocs-material 404 absolute-path behavior: confirmed against
  `mkdocs-material==9.5.49`.

## What this handoff is NOT

- NOT a new milestone. Both gaps absorb into M037 P01.
- NOT M037 P02 scope. M037 P02 covers corpus extra_dirs / `clean_phase`
  issues (`.orchestrator/feedback/M037-P02-pbj-round-3.5-input.md` —
  separate code paths, separate reviewers).
- NOT a redesign of the wiki tooling. F12 swaps the deploy primitive
  (legacy builder → workflow); F13 is a one-line conditional. The
  surrounding wiki-init / wiki-deploy / mkdocs.yml architecture is
  unchanged.
- NOT M035 territory. Both gaps are wiki-tooling, not packaging /
  distribution.

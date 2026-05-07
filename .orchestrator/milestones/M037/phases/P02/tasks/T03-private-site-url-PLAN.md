---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M037"
name: "Private-repo `site_url:` visibility branch"
depends_on: ["T02"]
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists (verified at plan-authoring time, ~776 lines, contains `MKDOCS_TARGET="$PROJECT_DIR/wiki/mkdocs.yml"` substitution at lines 305-326, `SITE_URL` variable resolution earlier in the script, sed-rewrite block at lines 376-396 that mutates `^site_url:.*` line in `mkdocs.yml`).
- T02 has shipped (FR-19 workflow scaffold + FR-20 wiki-deploy.sh demote in `wiki-init.sh`); T03's visibility branch is added to the SAME `wiki-init.sh` script. Sequential ordering avoids merge churn between concurrent edits to the same file.
- `scripts/lib/yaml-merge.sh` exists (verified at plan-authoring time, P01/T06 deliverable; the `MKDOCS_MANAGED` namespace list at line 423 includes `extra_css,nav` etc. — `site_url` is NOT in that list because it's a managed scalar handled by the field-line rewrite block, not by yaml-merge).
- `.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md` Gap 2 carries the verbatim visibility-detection bash and the verbatim test scaffold (lines 327-449).

## Description

Lands FR-21 per US-12 and SC-15. mkdocs-material's `404.html` uses absolute asset paths derived from `site_url:`. Public repos serve at `<org>.github.io/<repo>/` and the absolute paths resolve. Private repos (Pro/Team/Enterprise plans, including PBJ-central as the dogfood project) serve at randomized `<random>.pages.github.io/` URLs without the `/<repo>/` prefix — absolute paths break and the 404 page renders as a column of unstyled SVG icons. Real pages render fine (relative asset paths); only the 404 breaks. Operators hit 404s often during stub-emission gaps; the unstyled 404 reads as "deploy is broken" when actually only the asset paths are wrong. Source: `papercut-handoff-wiki-publishing-robustness-2026-05-07.md` Gap 2.

Add a visibility-detection branch to `wiki-init.sh`:
- For visibility=`private`: write empty `site_url:` (or omit the line) so mkdocs-material falls back to relative-only paths in 404.html (confirmed against `mkdocs-material==9.5.49`).
- For visibility=`public`: write the existing `https://<owner>.github.io/<repo>/` shape.
- On `gh` unavailable / unauthenticated: fall back to `public` with a diagnostic naming the missing capability.

Port `tests/test-wiki-init-private-site-url.sh` byte-identical from the handoff doc.

## Steps

1. **Add the visibility-detection branch to `scripts/lifecycle/wiki-init.sh`**. Find the existing `SITE_URL` resolution block (immediately before the field-line rewrite block at line ~326). Insert visibility logic that overrides `SITE_URL` for private repos. The shape (verbatim from handoff with the `GH_VISIBILITY_OVERRIDE` test escape hatch added):

   ```bash
   # ---- FR-21 (M037/P02/T03) — repo-visibility branch for site_url: ---------
   # mkdocs-material's 404.html uses absolute asset paths derived from
   # site_url:. Private repos (Pro/Team/Enterprise) serve at randomized
   # <random>.pages.github.io/ subdomains without the /<repo>/ path prefix —
   # absolute paths break, 404.html renders unstyled. Branch SITE_URL on
   # repo visibility:
   #   - private  → empty site_url (mkdocs-material falls back to relative
   #                paths in 404.html; confirmed mkdocs-material==9.5.49)
   #   - public   → existing https://<owner>.github.io/<repo>/ shape
   # On gh unavailable / unauthenticated → fall back to public (default
   # behavior; operator manually flips site_url: "" if they hit the
   # unstyled-404 symptom).
   #
   # Test escape hatch: GH_VISIBILITY_OVERRIDE=private|public bypasses gh
   # for the verbatim test scaffold (tests/test-wiki-init-private-site-url.sh).
   resolve_site_url_for_visibility() {
     # Inputs: $OWNER, $REPO, $SITE_URL (currently set to the public shape).
     # Output: mutates $SITE_URL in caller scope.
     if [ -n "${GH_VISIBILITY_OVERRIDE:-}" ]; then
       VISIBILITY="$GH_VISIBILITY_OVERRIDE"
     elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
       VISIBILITY=$(gh api "repos/$OWNER/$REPO" --jq .visibility 2>/dev/null || echo "public")
       [ -n "$VISIBILITY" ] || VISIBILITY="public"
     else
       VISIBILITY="public"
       echo "wiki-init: gh unavailable / unauthenticated; assuming public visibility for site_url. If the repo is actually private and the 404 page renders unstyled, manually edit wiki/mkdocs.yml to set: site_url: \"\"" >&2
     fi
     if [ "$VISIBILITY" = "private" ]; then
       SITE_URL=""
       echo "wiki-init: FR-21 private repo detected; site_url set empty so 404.html uses relative asset paths"
     else
       echo "wiki-init: FR-21 public repo (or fallback); site_url=$SITE_URL preserved"
     fi
   }
   ```

   Wire the call into the existing flow IMMEDIATELY BEFORE the field-line rewrite block (line ~326, after `SITE_URL` is initially resolved from `repo_url:` parsing):

   ```bash
   # FR-21 (M037/P02/T03) — branch SITE_URL on repo visibility
   resolve_site_url_for_visibility
   ```

   The downstream sed-rewrite block at lines 376-396 ALREADY mutates the `^site_url:.*` line in `mkdocs.yml`; it consumes the new (possibly empty) `SITE_URL` value and writes it. NO change to the sed block itself is needed — the empty-string case produces `site_url: ""`, which mkdocs-material handles correctly (falls back to relative paths in 404.html).

2. **Verify private-mode round-trip via direct mkdocs build** in the verifier (step 4 below). The contract: with `site_url: ""`, `mkdocs build -f wiki/mkdocs.yml` produces a `wiki/site/404.html` whose `<link rel="stylesheet">` href is relative (`../assets/...` or `assets/...`), NOT absolute (`/<repo>/assets/...`).

3. **Port `tests/test-wiki-init-private-site-url.sh` verbatim from the handoff doc**:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   ROOT="$(cd "$HERE/.." && pwd)"

   # Mock gh visibility via GH_VISIBILITY_OVERRIDE env var (escape hatch added
   # by FR-21 implementation). Both private and public branches exercised.

   WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT; cd "$WORK"
   git init -q
   git remote add origin git@github.com:Test-Org/test-repo.git
   bash "$ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null

   # Case 1: private
   GH_VISIBILITY_OVERRIDE=private bash "$ROOT/scripts/lifecycle/wiki-init.sh" \
     --project-dir . >/dev/null
   SITE_URL_LINE="$(grep '^site_url:' wiki/mkdocs.yml || echo MISSING)"
   case "$SITE_URL_LINE" in
     *'""'*|MISSING) ;;
     *) echo "FAIL: private repo got non-empty site_url: $SITE_URL_LINE"; exit 1 ;;
   esac

   # Case 2: public
   rm -rf wiki .github
   bash "$ROOT/packaging/install/install-claude-code.sh" --project-dir . --force >/dev/null
   GH_VISIBILITY_OVERRIDE=public bash "$ROOT/scripts/lifecycle/wiki-init.sh" \
     --project-dir . >/dev/null
   grep -q '^site_url: "https://Test-Org.github.io/test-repo/"' wiki/mkdocs.yml || \
     { echo "FAIL: public repo got wrong site_url"; exit 1; }

   echo "PASS: site_url branches on repo visibility"
   ```

   Path adjustment from handoff: minor — the handoff version omits the second `install-claude-code.sh` invocation between cases. Adding it ensures Case 2 has a clean wiki/mkdocs.yml to mutate (the `rm -rf wiki .github` removes Case 1's emitted files but the install needs to re-stage them). This is a verbatim-spirit port; the test contract (private → empty site_url; public → preserved shape) is unchanged.

4. **Author `tools/verify/m037-p02-private-site-url.sh`**:

   - Greps `scripts/lifecycle/wiki-init.sh` for: `.visibility` (the `gh api ... --jq .visibility` invocation), `GH_VISIBILITY_OVERRIDE` (the test escape hatch), `resolve_site_url_for_visibility` (the function name).
   - Invokes `bash tests/test-wiki-init-private-site-url.sh` and propagates exit code.
   - Optionally (gated on `mkdocs` availability): runs the private-mode 404.html-href smoke test:
     - `mktemp -d` + `git init` + `git remote add origin git@github.com:Test-Org/test-repo.git` + install + `GH_VISIBILITY_OVERRIDE=private wiki-init.sh --project-dir .` + `mkdocs build -f wiki/mkdocs.yml` + grep `wiki/site/404.html` for `<link.*stylesheet` and assert href is relative (does NOT start with `/test-repo/`). Skip with diagnostic if `mkdocs` not on PATH.
   - Emits `SUMMARY: m037-p02-private-site-url pass=N fail=M` on completion.

## Must-Haves

- T9 (FR-21 visibility branch + private/public site_url shape) — phase plan.
- T11 (verbatim test scaffold port) — phase plan.

## Verification

```bash
bash tools/verify/m037-p02-private-site-url.sh
```

```bash
bash tests/test-wiki-init-private-site-url.sh
```

## Inputs

### From Previous Tasks

- T02 (M037/P02/T02) — workflow publishing cluster. T03 modifies the SAME `wiki-init.sh` script. T03's `resolve_site_url_for_visibility` function is added in a new function block; T02's `emit_pages_workflow` and `flip_pages_build_type` functions are independent. No API consumption; sequencing only.

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` — extends with one new function (`resolve_site_url_for_visibility`) plus one wiring line.
  - Existing API to consume: `OWNER`, `REPO`, `SITE_URL` env vars (resolved at lines ~120-180; `SITE_URL` derived from `REPO_URL` parse, currently always public-shape).
  - Existing API to consume: the sed-rewrite block at lines 376-396 already mutates `^site_url:.*` line in `mkdocs.yml`; it consumes the (possibly empty) `SITE_URL` without modification.
- `.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md` Gap 2 — verbatim visibility-detection bash at lines 335-348; verbatim test scaffold at lines 419-449.

## Constraints

- AD-19: all `Check:` commands single-script-file shape.
- Bash 3.2 + POSIX sh in script additions.
- CON-3 preservation: `site_url:` is an orchestrator-managed scalar (existing P01 contract). FR-21 changes the WRITE VALUE branched on visibility; it does NOT change the managed-namespace classification. Operator-authored sibling `mkdocs.yml` keys preserved by the existing yaml-merge primitive AT LINE 422-433 (P01/T06 deliverable).
- CON-4: visibility-detection has its own fail-back (gh unavailable → public). NOT default-branch territory; CON-4 helper not consumed.
- The `GH_VISIBILITY_OVERRIDE` env var is a TEST-ONLY escape hatch. Document it in the function comment block; do NOT promote to a CLI flag.
- Public→private transition (rare): handled by next `orchestrator:update` re-run. The yaml-merge primitive preserves operator-authored sibling keys; the field-line rewrite block re-derives `SITE_URL` via the visibility branch and writes the new (empty) value. No special transition handling needed beyond re-run idempotency.

## Expected Output

After T03 ships:
- A fresh install on a private repo (`gh api ... --jq .visibility` returns `private`) emits `wiki/mkdocs.yml` with `site_url: ""` (or no site_url: line). `mkdocs build` produces a `404.html` with relative-path stylesheet hrefs. The 404 page renders styled.
- A fresh install on a public repo emits `wiki/mkdocs.yml` with `site_url: "https://<owner>.github.io/<repo>/"` (existing public-repo behavior preserved — no regression).
- `gh` unavailable / unauthenticated → falls back to public with a single-line diagnostic.
- `bash tests/test-wiki-init-private-site-url.sh` exits 0 against both branches; `bash tools/verify/m037-p02-private-site-url.sh` reports `SUMMARY: m037-p02-private-site-url pass=N fail=0`.

## Notes

- **Private-pages random URL rotation** (per spec edge case): the `<random>.pages.github.io/` subdomain is generated at first-enable and may change on re-enable. F13's empty-`site_url` strategy is rotation-agnostic — relative paths work at any URL. No programmatic fix; documentation-only edge case in the spec.

- **giscus interaction** (per handoff "Other concerns" #4): giscus's mapping config in `mkdocs.yml`'s `extra:` block references `pathname`. On a private-pages random subdomain, pathname behavior is the same as public — no special handling needed today. If a future patch uses giscus's `url` mapping mode, that future task would interact with FR-21's decision.

- **Real-app smoke test pending**: T03 ships verifier-level coverage. SC-15 calls for end-to-end browser verification on a real private-pages URL (404 renders styled). This is operator-recorded in `M037-ACCEPTANCE-EVIDENCE.md` at phase close, NOT inside the automated test (no headless browser is wired into the orchestrator's test stack).

- **Plan-Time Discipline rule 5** (real-DB verification for SQL-bound code): NOT APPLICABLE. T03 introduces no SQL reads, schema migrations, or DB-bound integration code.

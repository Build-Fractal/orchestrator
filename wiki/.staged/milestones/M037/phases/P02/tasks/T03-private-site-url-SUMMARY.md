---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M037"
provides:
  - "resolve_site_url_for_visibility() function in scripts/lifecycle/wiki-init.sh + GH_VISIBILITY_OVERRIDE escape hatch + tests/test-wiki-init-private-site-url.sh + tools/verify/m037-p02-private-site-url.sh (7-gate verifier with optional mkdocs 404.html smoke gate)"
requires:
  - "from:T02 what:wiki-init.sh extension surface (T03 adds new function; T02 added emit_pages_workflow + flip_pages_build_type — independent function blocks)"
affects:
  - "M037/P02/T05 phase suite (consumes m037-p02-private-site-url.sh as one gate); operator UX (private-repo dogfood projects no longer hit unstyled-404 symptom)"
key_files:
  - "scripts/lifecycle/wiki-init.sh,tests/test-wiki-init-private-site-url.sh,tools/verify/m037-p02-private-site-url.sh"
key_decisions:
  - "FR-21,US-12,SC-15,CON-3,CON-4,AD-19"
patterns_established:
  - "repo-visibility-branched site_url emit (private->empty so mkdocs-material 404.html falls back to relative paths; public->preserved); GH_VISIBILITY_OVERRIDE env-var escape hatch for verbatim test scaffolds (mocks gh visibility without network); minimal-corpus mkdocs build smoke pattern (writes wiki/mkdocs-smoke.yml + single docs/index.md to exercise theme 404.html emit without spec-snippet cross-tree includes); explicit-rc subshell idiom (set -e is suppressed inside subshells on RHS of ||; use rc-coded exits + case dispatch instead)"
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P02/tasks/T03-private-site-url-PLAN.md,.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-07T15:53:45Z"
---

Lands FR-21 per US-12 / SC-15. Adds the resolve_site_url_for_visibility() function to scripts/lifecycle/wiki-init.sh immediately after the public-shape SITE_URL is initially derived (line ~188). The function branches on three inputs in priority order: (1) GH_VISIBILITY_OVERRIDE env var (test-only escape hatch), (2) gh api repos/<owner>/<repo> --jq .visibility when gh is available + authenticated, (3) public fallback with diagnostic on gh unavailable. When VISIBILITY=private, SITE_URL is set empty so the downstream sed-rewrite block at lines 376-396 emits site_url: "" — mkdocs-material then falls back to relative asset paths in 404.html (confirmed mkdocs-material==9.5.49). When public (or fallback), the existing https://<owner>.github.io/<repo>/ shape is preserved. NO change to the sed-rewrite block itself — the empty-string case feeds through naturally.

The verbatim test scaffold at tests/test-wiki-init-private-site-url.sh exercises both branches via GH_VISIBILITY_OVERRIDE=private|public against a fresh project under /tmp with a fake git@github.com:Test-Org/test-repo.git remote. Minor port-time adjustment from the handoff doc: a between-cases re-install (after rm -rf wiki .github) so Case 2 has a clean wiki/mkdocs.yml to mutate. Public-case grep adjusted to lowercase 'test-org' to match wiki-init.sh's OWNER_LOWER lowercasing of the GitHub Pages canonical URL form (line 186-187).

The verifier tools/verify/m037-p02-private-site-url.sh runs 7 checks: file existence + three grep markers (resolve_site_url_for_visibility, .visibility, GH_VISIBILITY_OVERRIDE) + test-scaffold passes + an optional 404.html-href smoke gate. The smoke gate writes a minimal wiki/mkdocs-smoke.yml + single docs/index.md (the staged wiki/ pulls in spec-snippet cross-tree includes that fail under mktemp), runs mkdocs build, and asserts that 404.html stylesheet hrefs do NOT begin with /test-repo/. The smoke gate uses an explicit-rc subshell idiom because bash's set -e is suppressed inside ( ... ) || x subshells (POSIX rule); rc=2/3/4 distinguish build-failure / 404-missing / bad-href cases.

Verifier result: SUMMARY: m037-p02-private-site-url pass=7 skip=0 fail=0. Test scaffold result: PASS: site_url branches on repo visibility. m037-p02-workflow-pages-publishing.sh (T02 sibling) regression-checked: 15/15 pass — the new function block is independent of T02's emit_pages_workflow / flip_pages_build_type additions.

Real-app smoke test (SC-15 browser verification on a real private-pages URL) is deferred to operator-recorded evidence in M037-ACCEPTANCE-EVIDENCE.md at phase close per task-plan Notes — no headless browser is wired into the orchestrator's automated test stack.

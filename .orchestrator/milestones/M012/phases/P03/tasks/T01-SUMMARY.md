---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M012"
provides:
  - "wiki/overrides/partials/comments.html Material comments-partial override (Giscus <script> block driven by config.extra.giscus.*); wiki/mkdocs.yml theme.custom_dir: overrides + top-level extra.giscus block (repo/repo_id/category/category_id via !ENV with empty-string defaults, mapping: pathname literal) marker-bounded by # >>> M012-P03 extra / # <<< M012-P03 extra end"
requires:
  - "from:M012/P01/T01 what:wiki/mkdocs.yml base with theme.name material + plugins + markdown_extensions; from:M012/P01/T04 what:# >>> M012-P01 nav / # <<< M012-P01 nav end marker-bounded region that must remain byte-identical"
affects:
  - "M012/P03/T02 (pre-build config-check gate greps extra.giscus keys and detects empty-string env defaults), M012/P03/T03 (mkdocs build + smoke walker greps rendered HTML for giscus.app/client.js which comes from this partial), M012/P03/T04 (remap script updates pathname-mapped discussions), M012/P03/T05 (verify gates assert on these artifacts)"
key_files:
  - "wiki/overrides/partials/comments.html,wiki/mkdocs.yml"
key_decisions:
  - "AD-3 SSOT (comments injected via theme partial at render time; no .orchestrator/**.md body rewriting),AD-5/SC-7 mapping choice (pathname literal; rename tradeoff handled by T04 remap script),marker-bounded additive edits (mirror P01 nav-marker convention for future automation),!ENV empty-string defaults (no production IDs committed; T02 gate trips on unset env vars)"
patterns_established:
  - "theme override as AD-3-compliant injection surface (append-at-render vs body-rewrite); marker-comment discipline for additive multi-phase mkdocs.yml edits (# >>> M012-P## <scope> / # <<< M012-P## <scope> end); byte-identity verification of upstream marker-bounded regions via shasum of sed-extracted line range before and after edits; YAML-validity check via multi-constructor SafeLoader when !ENV custom tag is present (MkDocs supplies the tag; repo linters must tolerate it)"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P03/tasks/T01-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-21T02:45:23Z"
---

Landed the Giscus Material-theme override and mkdocs.yml extra.giscus wiring — the AD-3-compliant comment injection surface for the dogfood wiki. Zero canonical artifact bodies were modified; Giscus is appended by the theme at render time via config.extra.giscus.* reads. Four ID env vars (GISCUS_REPO, GISCUS_REPO_ID, GISCUS_CATEGORY, GISCUS_CATEGORY_ID) use MkDocs' !ENV tag with "" defaults so a config-less build surfaces the issue at T02's loud-fail gate; mapping is the literal "pathname" (deterministic across operators, rename-fragile — that tradeoff is documented in wiki/README.md by T04). The P01-owned # >>> M012-P01 nav / # <<< M012-P01 nav end region is byte-identical before and after (shasum 3844ca51...bdd9a over the 1171-line block both pre- and post-edit). mkdocs.yml parses as valid YAML under a multi-constructor SafeLoader (native safe_load rejects !ENV because MkDocs owns that tag — expected). comments.html is 45 lines (≥25 must-have) and contains the literal giscus.app/client.js that T03's smoke walker will grep. No shell scripts shipped (T01 scope); Bash 3.2 compat gate is a T02–T05 concern. Out of scope and deferred: pre-build config-check gate (T02), rendered-HTML smoke walker (T03), discussion remap script (T04), six-gate verify suite (T05).

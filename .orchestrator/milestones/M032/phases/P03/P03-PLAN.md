---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M032"
goal: "Land the two remote-state-mutation wiki-init scopes on top of P02's default-scope foundation: ship FR-7 + FR-8 (`--with-giscus --repo <owner>/<repo> --category <name>`) which substitutes the four `{{giscus_*}}` placeholders in `wiki/overrides/partials/comments.html` from `scripts/diagnostics/giscus-ids-from-gh.sh` output and runs `wiki-giscus-config-check.sh` as a post-step verifier failing closed on bad config; ship FR-9 + FR-10 + MIT-007 + MIT-008 (`--deploy`) implementing the four-step ordered sequence (`gh api PATCH /repos` Discussions → `wiki-deploy.sh` with the FR-10 cwd-vs-`repo_url:` sanity gate / Finding J counter-pattern → MIT-007 read-before-write Pages guard via `gh api GET /repos/<owner>/<repo>/pages` with explicit fail-closed-on-incompatible-source diagnostic and `--force-pages-reconfigure` escape hatch → `gh api PUT /repos/<owner>/<repo>/pages` for compatible-or-absent state → live URL print) and the MIT-008 structured `wiki-deploy-mutation` JSONL audit-trail record appended to `.orchestrator/execution-log.jsonl` BEFORE the live URL prints to stdout (Constitution VI on-disk-truth gate); ship FR-14 + MIT-005 (custom-nav region split via `# >>> auto-nav` ... `# <<< auto-nav end` regenerated and `# >>> custom-nav` ... `# <<< custom-nav end` byte-preserved) including the non-empty-legacy-content migration branch that moves operator-hand-added entries between legacy `# >>> M012-P01 nav` markers verbatim into the new `# >>> custom-nav` region (counter-pattern to silent data loss for the named PBJ pilot population, Finding I); ship FR-13 progressive-opt-in flag-pattern documentation block in `references/installation.md` declaring the `--with-<feature>` precedent (default-off, independently composable; e.g. future `--with-github-integration`, `--with-design-layer`); land `tests/m032-acceptance/throwaway-fixture-protocol.md` per AD-7 / CON-5 documenting the explicit `gh repo create <ts>-m032-fixture --private` + `gh repo delete <ts>-m032-fixture --yes` teardown protocol (no-orphan-branches + no-leaked-`.orchestrator/`-files invariants) before SC-5 considered shippable; land the SC-4 + SC-5 + SC-6 acceptance scripts at `tests/m032-acceptance/p02-wiki-init-with-giscus.sh`, `tests/m032-acceptance/p03-wiki-init-deploy-live.sh`, and `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (using the spec-mandated filenames per SC-4/SC-5/SC-6); the SC-5 acceptance script implements the three-category exit-code semantics per MIT-001 (exit 0 = pass, exit 77 = SKIP_REASON for unauthenticated `gh` in CI, other non-zero = fail); preserve P02's byte-identical install behavior at default `mode: copy` and respect FR-22's collision invariant; land `tools/verify/m032-p03-phase-suite.sh` aggregator and `tools/verify/m032-p03-scope-guard.sh` enforcing P03-only-touches-declared-files."
demo_sentence: "An operator on a fresh project (using the P01 `tests/fixtures/m032-fresh-project-fixture/` shared fixture which has already been P02-`wiki-init`'d so its `<fixture>/wiki/mkdocs.yml` is templated and `<fixture>/wiki/overrides/partials/comments.html` carries the four `{{giscus_*}}` placeholder tokens) runs `bash scripts/lifecycle/wiki-init.sh --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' --project-dir tests/fixtures/m032-fresh-project-fixture/` (with `scripts/diagnostics/giscus-ids-from-gh.sh` mocked via `M032_GISCUS_IDS_FROM_GH_STUB=1` env-var emitting deterministic fixture IDs `fixture-owner/fixture-repo` / `R_kgDOFixture` / `Wiki Comments` / `DIC_kwDOFixture` to avoid GraphQL rate-limit dependence in CI per Edge Cases) and observes (a) `<fixture>/wiki/overrides/partials/comments.html` carrying the four fixture IDs (no orchestrator values remain — the `{{giscus_repo}}` / `{{giscus_repo_id}}` / `{{giscus_category}}` / `{{giscus_category_id}}` placeholders all sed-substituted), (b) `bash scripts/diagnostics/wiki-giscus-config-check.sh --project-dir tests/fixtures/m032-fresh-project-fixture/` exits 0 (post-step verifier), (c) re-running the same command with different `--repo`/`--category` overwrites the partial with new IDs (US-3 AS-3 documented re-run behavior); against an invalid `--repo` flag (or `M032_GISCUS_IDS_FROM_GH_STUB=fail`), the command exits non-zero with `integration-giscus-config-failed: <reason>` diagnostic on stderr and the partial is left in placeholder state with no sed-substitution (US-3 AS-2). The operator runs `bash scripts/lifecycle/wiki-init.sh --with-wiki --with-giscus --deploy --project-dir tests/fixtures/m032-fresh-project-fixture/ --repo <ts>-m032-fixture` against a throwaway GH repo (created via `gh repo create <ts>-m032-fixture --private`, deleted via `gh repo delete <ts>-m032-fixture --yes` per `tests/m032-acceptance/throwaway-fixture-protocol.md`) and observes (a) `gh api PATCH /repos/<owner>/<ts>-m032-fixture` enables Discussions, (b) `bash <fixture>/scripts/wiki/wiki-deploy.sh` runs the FR-10 cwd-vs-`repo_url:` sanity gate (`cd \"$PROJECT_ROOT\"` first; compares `repo_url:` parsed from `<project>/wiki/mkdocs.yml` against `git -C $cwd remote get-url origin`; fails closed on mismatch with cross-project-hazard diagnostic per Finding J), (c) the MIT-007 read-before-write Pages guard `gh api GET /repos/<owner>/<ts>-m032-fixture/pages` inspects `.source.branch` and `.source.path`: if the response is a 404 (no Pages configured) OR `source.branch == 'gh-pages'` AND `source.path == '/'` then the PUT proceeds (or no-ops on the equality case); otherwise exits non-zero with `Repository has an existing Pages deployment from a different source (<current-source>). This source will be overwritten. Pass --force-pages-reconfigure to proceed, or reconfigure Pages manually before running --deploy.` (US-4 AS-3), (d) `gh api PUT /repos/<owner>/<ts>-m032-fixture/pages` sets `source: { branch: gh-pages, path: / }`, (e) the live URL `https://<owner>.github.io/<ts>-m032-fixture/` is printed to stdout AFTER (f) a structured `{event_type: 'wiki-deploy-mutation', timestamp: '<ISO8601Z>', repo: '<owner>/<ts>-m032-fixture', mutations: [{type: 'discussions_enabled'}, {type: 'gh_pages_branch_created', ref: 'gh-pages'}, {type: 'pages_source_configured', source: {branch: 'gh-pages', path: '/'}}], result: 'success'}` JSON record is appended to `.orchestrator/execution-log.jsonl` per MIT-008 (one line, NDJSON shape, jq-parseable: `jq '.[] | select(.event_type == \"wiki-deploy-mutation\")' .orchestrator/execution-log.jsonl` returns ≥ 1 record), (g) `curl -fsS \"https://<owner>.github.io/<ts>-m032-fixture/\"` returns 200 within `M032_DEPLOY_PROPAGATION_TIMEOUT` seconds (default 90s, GH Pages propagation accommodation) with served HTML containing `data-repo=\"<owner>/<ts>-m032-fixture\"` (proves the partial templating loop closed end-to-end through to live), (h) `gh repo delete <ts>-m032-fixture --yes` teardown leaves no orphan branches in the orchestrator repo and no leaked `.orchestrator/` files in the fixture (no-orphan-state invariant per CON-5). The operator runs `bash scripts/wiki/wiki-generate-nav.sh --root .` against an `mkdocs.yml` with both `# >>> auto-nav` and `# >>> custom-nav` regions populated and observes the auto-nav region rewritten and the custom-nav region byte-identical (US-5 AS-1); against an `mkdocs.yml` migrating from legacy `# >>> M012-P01 nav` markers WITH non-empty content between markers (named PBJ pilot population), the migration moves that content verbatim into the new `# >>> custom-nav` region per MIT-005 and emits a stdout diagnostic naming the count of preserved entries (e.g. `Migrated 3 custom nav entries from legacy markers to custom-nav region`); against legacy markers with empty content, the migration is a zero-behavior-change rename (US-5 AS-2); against an mkdocs.yml with `custom-nav` markers manually removed, the generator self-heals by re-creating an empty custom-nav region (US-5 AS-3). `references/installation.md` declares the `--with-<feature>` progressive-opt-in flag pattern as the precedent for future flags (default-off, independently composable). `bash tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (SC-4) and `bash tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (SC-6) exit 0; `bash tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (SC-5) exits 0 OR exits 77 with `SKIP_REASON: gh unauthenticated` if `gh auth status` fails in CI (POSIX skip-code per MIT-001, distinct from pass exit 0 and from fail exit non-zero); `bash tools/verify/m032-p03-phase-suite.sh` emits `SUMMARY: m032-p03-phase-suite.sh pass=N fail=0`; `bash tools/verify/m032-p03-scope-guard.sh` emits `PASS: m032-p03 scope-guard ...` confirming P03 modifies only the files declared in this phase's `Files Likely Touched` list."
risk: "high"
depends_on: ["P02"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/ with
     m032-p03-* prefix to avoid collision with M030/M031/M032 P00–P02
     existing verifiers in the shared tools/verify/ tree. Verifier scripts
     are co-authored alongside their corresponding artifact within the
     SAME task per plan-time discipline rule 2. -->

### Truths

- `wiki/overrides/partials/comments.html` has its four hardcoded Giscus
  `data-*` attribute interpolation expressions amended to also accept the
  M032-spec-mandated `{{giscus_repo}}` / `{{giscus_repo_id}}` /
  `{{giscus_category}}` / `{{giscus_category_id}}` placeholder tokens per
  FR-7. The placeholder tokens are the load-bearing surface that
  `wiki-init.sh --with-giscus` substitutes against; the existing
  `{{ config.extra.giscus.repo }}` Jinja interpolations (which read from
  `mkdocs.yml`'s `extra.giscus.*` `!ENV [GISCUS_*, "" ]` block) remain in
  place as the live runtime path. The two interpolation paths coexist:
  the spec placeholders are the static-file template surface that
  `--with-giscus` rewrites; the Jinja+`!ENV` interpolations remain the
  build-time mkdocs path. The bundle-staged copy of `comments.html`
  carries the placeholder tokens verbatim so a fresh `wiki-init` writes
  to a clean template; on `--with-giscus` invocation the script
  sed-substitutes the four placeholders into literal repo IDs (defeating
  the `!ENV` indirection for partial-side rendering — Discussions IDs
  embed directly as static HTML attribute values rather than being
  resolved at mkdocs-build time). The orchestrator-repo-local
  `wiki/overrides/partials/comments.html` continues to use the existing
  `!ENV` Jinja interpolations (no change to this repo's Giscus wiring).
  - Check: `bash tools/verify/m032-p03-giscus-templating.sh`

- `scripts/lifecycle/wiki-init.sh` accepts `--with-giscus --repo <owner>/<repo>
  --category <name>` (FR-8). When invoked with `--with-giscus`: (a) the
  `--repo` and `--category` flags are required; missing either exits
  non-zero with usage diagnostic; (b) the script invokes
  `scripts/diagnostics/giscus-ids-from-gh.sh --repo <owner>/<repo>
  --category <name>` and parses the four `export GISCUS_*` lines from its
  stdout (`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`,
  `GISCUS_CATEGORY_ID`); (c) on `giscus-ids-from-gh.sh` non-zero exit,
  `wiki-init.sh` exits non-zero with `integration-giscus-config-failed:
  <reason>` on stderr and the partial under
  `<PROJECT_DIR>/wiki/overrides/partials/comments.html` is left in
  placeholder state (US-3 AS-2 — no partial sed-substitution on upstream
  failure); (d) on success, the script sed-substitutes the four
  `{{giscus_repo}}` / `{{giscus_repo_id}}` / `{{giscus_category}}` /
  `{{giscus_category_id}}` placeholder tokens with the parsed IDs in
  `<PROJECT_DIR>/wiki/overrides/partials/comments.html`; (e) as a
  post-step, the script invokes `scripts/diagnostics/wiki-giscus-config-check.sh
  --project-dir <PROJECT_DIR>` as the FR-8 post-step verifier; non-zero
  exit from the check propagates through `wiki-init.sh` as exit code 8
  with `integration-giscus-config-check-failed` diagnostic; (f)
  re-running with different `--repo`/`--category` overwrites the partial
  with new IDs (US-3 AS-3 — overwrite is the documented re-run
  behavior). Test-only failure injection: `M032_GISCUS_IDS_FROM_GH_STUB=1`
  env-var (per the M026/MEM030 `<TOOL>_*` env-var convention) makes the
  script bypass the live `gh api` call and emit deterministic fixture
  IDs (`fixture-owner/fixture-repo` / `R_kgDOFixture` / `<category>` /
  `DIC_kwDOFixture`); `M032_GISCUS_IDS_FROM_GH_STUB=fail` simulates
  upstream failure for the integration-giscus-config-failed branch
  coverage.
  - Check: `bash tools/verify/m032-p03-with-giscus-scope.sh`

- `scripts/lifecycle/wiki-init.sh` accepts `--deploy` (or
  `--with-wiki --with-giscus --deploy` chained from `init-project.sh`'s
  P02/T02 passthrough) and implements the FR-9 + MIT-007 + MIT-008
  ordered four-step sequence with the FR-10 sanity gate. Step ordering
  (mandatory): (1) `gh api --method PATCH /repos/<owner>/<repo>` with
  `has_discussions=true` (idempotent — already-on returns 200, no-op);
  (2) `bash <PROJECT_DIR>/scripts/wiki/wiki-deploy.sh` (T02-amended with
  the FR-10 cwd-vs-`repo_url:` sanity gate); (3) MIT-007 read-before-write
  Pages guard — `gh api GET /repos/<owner>/<repo>/pages` inspects the
  response: HTTP 404 / `Not Found` (no Pages configured) → proceed to
  PUT; HTTP 200 with `source.branch == "gh-pages"` AND `source.path == "/"`
  → no-op (true idempotent skip-PUT — print `pages-already-configured`
  diagnostic and skip step 4); HTTP 200 with any other `source` shape →
  exit non-zero with the documented diagnostic `Repository has an
  existing Pages deployment from a different source (<current-source>).
  This source will be overwritten. Pass --force-pages-reconfigure to
  proceed, or reconfigure Pages manually before running --deploy.`
  unless `--force-pages-reconfigure` was passed (in which case the PUT
  proceeds with a stderr warning naming the overwritten source); (4)
  `gh api --method PUT /repos/<owner>/<repo>/pages` with
  `source: { branch: gh-pages, path: / }`. After step 4 (or after a
  step-3 no-op skip): (5) MIT-008 audit-trail — append a single
  newline-delimited JSON record to
  `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` (or the orchestrator
  repo's log when `--project-dir .` self-application) BEFORE printing
  the live URL, with shape `{"event_type": "wiki-deploy-mutation",
  "timestamp": "<ISO8601 UTC>", "repo": "<owner>/<repo>", "mutations":
  [<one entry per step that fired>], "result": "success"}` where each
  mutation entry is one of `{"type": "discussions_enabled"}`,
  `{"type": "gh_pages_branch_created", "ref": "gh-pages"}`,
  `{"type": "pages_source_configured", "source": {"branch": "gh-pages",
  "path": "/"}}` (mutations array MUST reflect the actual subset of
  steps that fired — Discussions-already-on omits the discussions
  entry; pages-already-configured omits the pages entry; etc.). Then
  (6) print the live URL `https://<owner_lower>.github.io/<repo>/` to
  stdout. Failure mode: any step that exits non-zero appends a separate
  failure record `{"event_type": "wiki-deploy-mutation", "timestamp":
  "<ISO8601 UTC>", "repo": "<owner>/<repo>", "mutations": [<steps that
  succeeded before the failure>], "result": "failure", "error":
  "<failed-step-name>: <stderr-tail>"}` and exits non-zero (no live URL
  print on partial failure). Re-runs are idempotent for compatible
  state per step-3 no-op branch. The script honors a
  `M032_DEPLOY_PROPAGATION_TIMEOUT` env-var (default 90s, deliberate
  GH-Pages-propagation accommodation per Assumption A-2) used by the
  SC-5 acceptance script's `curl` retry loop — `wiki-init.sh --deploy`
  itself does NOT poll the live URL, only prints it; the polling is
  the acceptance script's responsibility. Test-only failure injection:
  `M032_DEPLOY_GH_API_STUB=1` env-var bypasses the four `gh api` calls
  and writes deterministic stub responses to a `M032_DEPLOY_GH_API_STUB_DIR`
  for unit-level coverage of the MIT-007 branches without live-network
  dependency.
  - Check: `bash tools/verify/m032-p03-deploy-scope.sh`

- `scripts/wiki/wiki-deploy.sh` is amended to (a) `cd "$PROJECT_ROOT"`
  before invoking the deploy step (already partially honors the `--root`
  flag in its existing P02-baseline shape; T02 makes the cwd discipline
  mandatory and unconditional under `--deploy` invocation from
  `wiki-init.sh`), and (b) implement the FR-10 cwd-vs-`repo_url:` sanity
  gate as a hard precondition: parse the `repo_url:` field from
  `<PROJECT_ROOT>/wiki/mkdocs.yml`, parse `git -C "$PROJECT_ROOT" remote
  get-url origin`, normalize both to canonical `<owner>/<repo>` form
  (strip `.git`, strip `https://github.com/`, strip `git@github.com:`,
  case-preserved on repo-name, case-lowered on owner per
  `wiki-init.sh`'s P02 owner-lowering convention), and exit non-zero
  with the diagnostic `wiki-deploy: cross-project hazard — mkdocs.yml
  repo_url=<X> does not match git remote origin=<Y>; aborting before
  gh-deploy. cwd: <PROJECT_ROOT>` if the two do not match. This is the
  Finding J counter-pattern: a `mkdocs gh-deploy -f wiki/mkdocs.yml`
  invocation from the wrong cwd silently force-pushes one project's
  built site into another project's `gh-pages` branch (high blast-radius
  bug observed in 2026-04-28 PBJ session). The sanity gate fires BEFORE
  the existing P02-baseline gates (giscus-config-check, mkdocs build,
  link-check, giscus-smoke). Test-only override:
  `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` env-var bypasses the gate for
  unit-level coverage where the fixture has no real git remote. Used
  ONLY by the SC-6/SC-5 acceptance scripts and the `m032-p03-deploy-scope.sh`
  verifier; the operator-facing surface never honors this env-var
  unset path implicitly.
  - Check: `bash tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`

- `scripts/wiki/wiki-generate-nav.sh` is amended to split the existing
  `# >>> M012-P01 nav (auto-generated — do not edit by hand)` /
  `# <<< M012-P01 nav end` marker pair into two regions per FR-14:
  `# >>> auto-nav (auto-generated — do not edit by hand)` /
  `# <<< auto-nav end` (regenerated wholly by the generator on every
  invocation — Constitution, Decisions, Knowledge, Glossary, Milestones,
  Proposals, Archive, etc.) and `# >>> custom-nav` /
  `# <<< custom-nav end` (preserved verbatim across regenerates —
  operator-owned space for project-specific top-level entries). The
  custom-nav region's contents are byte-identical between any two
  successive regenerate runs (US-5 AS-1). First regenerate against an
  `mkdocs.yml` carrying the legacy `# >>> M012-P01 nav` markers triggers
  the migration branch: (a) if the legacy block is empty (zero non-blank
  non-comment lines between markers), the migration renames the markers
  in-place to `# >>> auto-nav` / `# <<< auto-nav end` and appends an
  empty `# >>> custom-nav` / `# <<< custom-nav end` block immediately
  after — zero behavior change at empty-legacy (US-5 AS-2); (b) if the
  legacy block is NON-empty (per MIT-005 — the named PBJ pilot
  population case), the non-empty legacy content is moved verbatim into
  the new `# >>> custom-nav` region (NOT discarded), the
  `# >>> auto-nav` markers receive a freshly-generated nav block, and a
  stdout diagnostic of the form `Migrated <N> custom nav entries from
  legacy markers to custom-nav region` is emitted naming the count of
  preserved entries (definition of `<N>`: count of non-blank-non-comment
  lines between the legacy markers prior to migration). The `<N>` count
  is load-bearing — silent migration without operator visibility is
  the failure mode MIT-005 was written to prevent. Self-healing for
  US-5 AS-3: if the operator deletes the `# >>> custom-nav` markers
  entirely, the next regenerate detects the absence and re-creates an
  empty `# >>> custom-nav` / `# <<< custom-nav end` block at the same
  insertion point (immediately after `# <<< auto-nav end`).
  - Check: `bash tools/verify/m032-p03-custom-nav-region.sh`

- `references/installation.md` (existing baseline) gains a new
  `## --with-<feature> Progressive Opt-In Flag Pattern` section per
  FR-13 documenting the convention precedent: each `--with-<feature>`
  flag MUST be default-off; each is independently composable with
  every other `--with-` flag (not stateful — order does not matter,
  presence of one does not change semantics of another); the flag
  pattern is the precedent for future flags
  (`--with-github-integration` for M013/M014 progressive-opt-in;
  `--with-design-layer` for M023; etc.). The section names the M032
  contribution (`--with-wiki`, `--with-giscus`, `--deploy`) explicitly
  as the canonical prior art and provides a one-paragraph rationale
  (consumers never receive opt-in surface always-on; opt-in is an
  operator decision, not an installer default; this is Constitution I
  — Context Minimization — applied to the consumer-facing surface).
  - Check: `bash tools/verify/m032-p03-with-feature-pattern-doc.sh`

- `tests/m032-acceptance/throwaway-fixture-protocol.md` exists per
  AD-7 / CON-5 documenting the explicit `gh repo create
  <ts>-m032-fixture --private` + `gh repo delete <ts>-m032-fixture
  --yes` teardown protocol. The protocol document MUST specify: the
  timestamp-prefix naming convention (`<ts>-m032-fixture` where
  `<ts>` is the unix-seconds timestamp at fixture creation, ensuring
  no fixture-name collisions across parallel CI invocations); the
  `--private` flag (CON-5 — fixtures are private to avoid public
  test artifact pollution); the four no-orphan-state invariants the
  teardown MUST verify (no `<ts>-m032-fixture` branch in the
  orchestrator repo's `gh-pages` namespace, no `<ts>-m032-fixture`
  directory in `tests/fixtures/`, no `<ts>-m032-fixture` references
  in `.orchestrator/execution-log.jsonl` outside the
  `wiki-deploy-mutation` records authored during the test run, no
  leaked GitHub repo if `gh repo delete` failed mid-run); the
  recovery protocol on partial-failure teardown (manual
  `gh repo delete` + manual orphan-branch cleanup); the trap-EXIT
  pattern the SC-5 acceptance script uses to ensure teardown runs
  even on test-script failure. The protocol is M032's spec-side
  amendment of the M013/M014 cautionary tale (those tests only ran
  against synthetic stubs and missed the walker-contract dogfood
  blocker). M032 SHALL NOT repeat that failure mode (CON-5).
  - Check: `bash tools/verify/m032-p03-throwaway-protocol-shape.sh`

- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (SC-4) exists,
  is executable, and exits 0 against the P01 shared fixture
  `tests/fixtures/m032-fresh-project-fixture/`. Asserts: (a) FR-7
  surface — `<fixture>/wiki/overrides/partials/comments.html` carries
  the four `{{giscus_*}}` placeholder tokens BEFORE
  `--with-giscus` runs; (b) FR-8 happy path — running
  `bash scripts/lifecycle/wiki-init.sh --with-giscus --repo
  fixture-owner/fixture-repo --category 'Wiki Comments'
  --project-dir <fixture>` with `M032_GISCUS_IDS_FROM_GH_STUB=1`
  exported (deterministic fixture IDs) substitutes the four
  placeholders with the four fixture IDs (`fixture-owner/fixture-repo`
  / `R_kgDOFixture` / `Wiki Comments` / `DIC_kwDOFixture`) in
  `<fixture>/wiki/overrides/partials/comments.html`; (c) FR-8
  post-step verifier — `bash scripts/diagnostics/wiki-giscus-config-check.sh
  --project-dir <fixture>` exits 0 after the substitution; (d) FR-8
  failure mode — running with `M032_GISCUS_IDS_FROM_GH_STUB=fail`
  exits non-zero, emits `integration-giscus-config-failed: <reason>`
  on stderr, and leaves the partial in placeholder state (no
  partial sed-substitution); (e) FR-8 re-run idempotency — running
  the happy path twice with the same `--repo`/`--category` produces
  byte-identical partial state on second run; (f) overwrite mode —
  running the happy path with different `--repo`/`--category` (e.g.
  `fixture-owner-2/fixture-repo-2` + `Different Category`) substitutes
  the new IDs without erroring (US-3 AS-3).
  - Check: `bash tools/verify/m032-p03-acceptance-shape-sc4.sh`

- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (SC-5) exists,
  is executable, and exits 0 against a live throwaway GH repo
  created and deleted within the test per
  `tests/m032-acceptance/throwaway-fixture-protocol.md` — OR exits 77
  with `SKIP_REASON: gh unauthenticated` on stdout if `gh auth status`
  exits non-zero in CI (POSIX skip-code convention per MIT-001;
  exit 77 is distinct from pass exit 0 and from fail other-non-zero,
  honored by the SC-12 battery's `pass=N skip=M fail=K` three-category
  output). Asserts (against live throwaway repo when authenticated):
  (a) `gh auth status` exits 0 (precondition; on non-zero, emit
  SKIP_REASON and exit 77); (b) timestamped fixture repo created via
  `gh repo create <ts>-m032-fixture --private --add-readme` (the
  `--add-readme` flag ensures the default branch exists for the
  `gh api PUT /pages` call); (c) `bash scripts/lifecycle/wiki-init.sh
  --with-wiki --with-giscus --deploy --project-dir
  tests/fixtures/m032-fresh-project-fixture/ --repo
  <owner>/<ts>-m032-fixture --category 'Wiki Comments'` invocation
  succeeds (exit 0); (d) the live URL printed to stdout responds 200
  via `curl -fsS` within `M032_DEPLOY_PROPAGATION_TIMEOUT` seconds
  (default 90s — retry loop with exponential backoff bounded by
  timeout); (e) the served HTML contains `data-repo="<owner>/<ts>-m032-fixture"`
  attribute (proves the partial templating loop closed end-to-end
  through to live render — Giscus partial fixture IDs survived all
  the way through `wiki-init` substitution → `mkdocs build` →
  `mkdocs gh-deploy` push → GH Pages render); (f) the
  `.orchestrator/execution-log.jsonl` of the fixture project (or
  the orchestrator repo when `--project-dir` resolves to it) contains
  ≥ 1 `wiki-deploy-mutation` record with `result: "success"` per
  MIT-008 audit-trail invariant; (g) trap-EXIT teardown via
  `gh repo delete <ts>-m032-fixture --yes` runs even on test-script
  failure mid-run; (h) post-teardown, no `<ts>-m032-fixture` GitHub
  repo exists (verified via `gh repo view <owner>/<ts>-m032-fixture
  --json name 2>/dev/null` returning non-zero) and no leaked
  `<ts>-m032-fixture` references remain in `tests/fixtures/` or
  the orchestrator's `.git/refs/`. SKIP_REASON branch coverage:
  if `gh auth status` exits non-zero, the script prints
  `SKIP_REASON: gh unauthenticated` to stdout and exits 77 without
  attempting any of (b) through (h).
  - Check: `bash tools/verify/m032-p03-acceptance-shape-sc5.sh`

- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh`
  (SC-6) exists, is executable, and exits 0 against the orchestrator's
  own `wiki/mkdocs.yml` (which P03/T03 amends to carry the new
  `# >>> auto-nav` / `# >>> custom-nav` markers). Asserts: (a) FR-14
  AS-1 — populate the `# >>> custom-nav` region of a temp-copy
  `mkdocs.yml` with three known operator-authored entries (e.g.
  `- Domain Decisions: domain-decisions.md`, `- Project Spec:
  spec.md`, `- Team Notes: notes.md`); run `bash
  scripts/wiki/wiki-generate-nav.sh --root <tmp>`; assert the
  custom-nav region is byte-identical to its pre-regenerate state
  AND the auto-nav region was rewritten (line count differs from
  pre-state because the regenerate fired); (b) FR-14 AS-2 / MIT-005
  — populate a temp-copy `mkdocs.yml` with the legacy
  `# >>> M012-P01 nav` markers and three non-empty operator entries
  between them; run `wiki-generate-nav.sh`; assert the legacy markers
  are migrated to `# >>> auto-nav`, the three operator entries are
  preserved verbatim in the new `# >>> custom-nav` region, AND the
  stdout diagnostic `Migrated 3 custom nav entries from legacy
  markers to custom-nav region` was emitted (count = 3, naming the
  load-bearing visibility per MIT-005); (c) FR-14 empty-legacy
  branch — populate a temp-copy with empty legacy markers; run the
  generator; assert legacy markers are migrated to `auto-nav` shape
  AND an empty `custom-nav` block was appended AND no migration
  diagnostic was emitted (zero behavior change at empty-legacy);
  (d) FR-14 self-healing AS-3 — start with a populated `auto-nav` +
  populated `custom-nav` mkdocs.yml; manually delete the `custom-nav`
  marker pair and intervening content; re-run the generator; assert
  an empty `custom-nav` region was re-created at the standard
  insertion point (immediately after `# <<< auto-nav end`).
  - Check: `bash tools/verify/m032-p03-acceptance-shape-sc6.sh`

- `tools/verify/m032-p03-phase-suite.sh` exists, is executable,
  invokes every P03 verifier in dependency order, exits 0 iff every
  sub-gate passes, and emits a single line `SUMMARY: m032-p03-phase-suite.sh
  pass=N fail=M` before exit. The suite chains, in order:
  `m032-p03-giscus-templating.sh`, `m032-p03-with-giscus-scope.sh`,
  `m032-p03-deploy-scope.sh`, `m032-p03-wiki-deploy-cwd-gate.sh`,
  `m032-p03-custom-nav-region.sh`, `m032-p03-with-feature-pattern-doc.sh`,
  `m032-p03-throwaway-protocol-shape.sh`,
  `m032-p03-acceptance-shape-sc4.sh`, `m032-p03-acceptance-shape-sc5.sh`,
  `m032-p03-acceptance-shape-sc6.sh`. Ten sub-gates plus the suite
  line.
  - Check: `bash tools/verify/m032-p03-phase-suite.sh`

- The SC-13 / scope-guard invariant holds for the P03 diff: P03
  modifies only files declared in this phase's "Files Likely Touched"
  list. None of `packaging/install/install-{claude-code,codex,cursor}.sh`
  (those belong to P01), `packaging/bundle/manifest.yml` (P01 / P02),
  `commands/init.md` / `scripts/lifecycle/init-project.sh` (P02), the
  P02 paired-launch seam scripts at `tests/paired-m032-m033/seam-{A,B,C}.sh`
  (P02 unless P03 explicitly extends — P03 does not), `wiki/glossary.md`
  (P02), `scripts/wiki/wiki-scan-sources.sh` (P02), `scripts/knowledge/lookup-mems.sh`
  (P02), or any `.orchestrator/proposals/**` file (P04's scanner
  extensions) is touched.
  - Check: `bash tools/verify/m032-p03-scope-guard.sh`

### Artifacts

- `wiki/overrides/partials/comments.html` (existing-baseline modify, contains "{{giscus_repo}}", contains "{{giscus_repo_id}}", contains "{{giscus_category}}", contains "{{giscus_category_id}}", contains "FR-7") — modify (bundle-staged copy gets the four placeholder tokens; orchestrator-local copy retains existing `!ENV` Jinja interpolations per AD-3)
- `scripts/lifecycle/wiki-init.sh` (existing-baseline modify, contains "--with-giscus", contains "--deploy", contains "--repo", contains "--category", contains "--force-pages-reconfigure", contains "M032_GISCUS_IDS_FROM_GH_STUB", contains "M032_DEPLOY_GH_API_STUB", contains "M032_DEPLOY_PROPAGATION_TIMEOUT", contains "wiki-deploy-mutation", contains "discussions_enabled", contains "gh_pages_branch_created", contains "pages_source_configured", contains "integration-giscus-config-failed", contains "integration-giscus-config-check-failed", contains "FR-7", contains "FR-8", contains "FR-9", contains "FR-10", contains "MIT-007", contains "MIT-008", contains "execution-log.jsonl") — modify
- `scripts/wiki/wiki-deploy.sh` (existing-baseline modify, contains "FR-10", contains "repo_url", contains "remote get-url origin", contains "cross-project hazard", contains "M032_WIKI_DEPLOY_BYPASS_CWD_GATE") — modify
- `scripts/wiki/wiki-generate-nav.sh` (existing-baseline modify, contains "# >>> auto-nav", contains "# <<< auto-nav end", contains "# >>> custom-nav", contains "# <<< custom-nav end", contains "FR-14", contains "MIT-005", contains "Migrated", contains "custom nav entries from legacy markers", contains "M012-P01 nav") — modify
- `wiki/mkdocs.yml` (existing-baseline modify, contains "# >>> auto-nav", contains "# >>> custom-nav") — modify (P03/T03 self-application: run the migrated generator against the orchestrator repo's own mkdocs.yml so the M012-P01 legacy markers are migrated in-place to the new shape)
- `references/installation.md` (existing-baseline modify, contains "--with-<feature>", contains "Progressive Opt-In", contains "default-off", contains "independently composable", contains "FR-13", contains "--with-wiki", contains "--with-giscus", contains "--deploy") — modify
- `tests/m032-acceptance/throwaway-fixture-protocol.md` (min 60 lines, contains "throwaway", contains "gh repo create", contains "gh repo delete", contains "--private", contains "<ts>-m032-fixture", contains "AD-7", contains "CON-5", contains "no-orphan-state", contains "trap", contains "M013", contains "M014") — create
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (min 80 lines, contains "SC-4", contains "FR-7", contains "FR-8", contains "M032_GISCUS_IDS_FROM_GH_STUB", contains "fixture-owner/fixture-repo", contains "wiki-giscus-config-check.sh", contains "integration-giscus-config-failed", contains "{{giscus_repo}}", contains "R_kgDOFixture") — create
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (min 100 lines, contains "SC-5", contains "FR-9", contains "FR-10", contains "FR-21", contains "MIT-007", contains "MIT-008", contains "throwaway-fixture-protocol.md", contains "gh repo create", contains "gh repo delete", contains "M032_DEPLOY_PROPAGATION_TIMEOUT", contains "wiki-deploy-mutation", contains "SKIP_REASON", contains "exit 77", contains "gh auth status", contains "trap") — create
- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (min 80 lines, contains "SC-6", contains "FR-14", contains "MIT-005", contains "auto-nav", contains "custom-nav", contains "M012-P01 nav", contains "Migrated", contains "byte-identical") — create
- `tools/verify/m032-p03-giscus-templating.sh` (min 30 lines, contains "wiki/overrides/partials/comments.html", contains "{{giscus_repo}}", contains "{{giscus_repo_id}}", contains "{{giscus_category}}", contains "{{giscus_category_id}}", contains "FR-7") — create
- `tools/verify/m032-p03-with-giscus-scope.sh` (min 40 lines, contains "wiki-init.sh", contains "--with-giscus", contains "--repo", contains "--category", contains "M032_GISCUS_IDS_FROM_GH_STUB", contains "FR-8", contains "wiki-giscus-config-check.sh", contains "integration-giscus-config-failed") — create
- `tools/verify/m032-p03-deploy-scope.sh` (min 50 lines, contains "wiki-init.sh", contains "--deploy", contains "--force-pages-reconfigure", contains "MIT-007", contains "MIT-008", contains "wiki-deploy-mutation", contains "M032_DEPLOY_GH_API_STUB", contains "discussions_enabled", contains "pages_source_configured", contains "FR-9") — create
- `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` (min 30 lines, contains "wiki-deploy.sh", contains "repo_url", contains "FR-10", contains "cross-project hazard", contains "M032_WIKI_DEPLOY_BYPASS_CWD_GATE") — create
- `tools/verify/m032-p03-custom-nav-region.sh` (min 50 lines, contains "wiki-generate-nav.sh", contains "auto-nav", contains "custom-nav", contains "FR-14", contains "MIT-005", contains "M012-P01 nav", contains "Migrated") — create
- `tools/verify/m032-p03-with-feature-pattern-doc.sh` (min 25 lines, contains "references/installation.md", contains "--with-<feature>", contains "default-off", contains "independently composable", contains "FR-13") — create
- `tools/verify/m032-p03-throwaway-protocol-shape.sh` (min 25 lines, contains "tests/m032-acceptance/throwaway-fixture-protocol.md", contains "<ts>-m032-fixture", contains "gh repo create", contains "gh repo delete", contains "AD-7", contains "CON-5") — create
- `tools/verify/m032-p03-acceptance-shape-sc4.sh` (min 25 lines, contains "p02-wiki-init-with-giscus.sh", contains "SC-4", contains "M032_GISCUS_IDS_FROM_GH_STUB") — create
- `tools/verify/m032-p03-acceptance-shape-sc5.sh` (min 30 lines, contains "p03-wiki-init-deploy-live.sh", contains "SC-5", contains "throwaway-fixture-protocol.md", contains "exit 77", contains "SKIP_REASON") — create
- `tools/verify/m032-p03-acceptance-shape-sc6.sh` (min 25 lines, contains "p02-wiki-generate-nav-custom-region.sh", contains "SC-6", contains "auto-nav", contains "custom-nav") — create
- `tools/verify/m032-p03-phase-suite.sh` (min 60 lines, contains "SUMMARY:", contains "m032-p03-giscus-templating", contains "m032-p03-acceptance-shape-sc6", contains "m032-p03-phase-suite") — create
- `tools/verify/m032-p03-scope-guard.sh` (min 40 lines, contains "packaging/install/install-claude-code.sh", contains "packaging/bundle/manifest.yml", contains "commands/init.md", contains "wiki/glossary.md", contains "scripts/wiki/wiki-scan-sources.sh", contains "scripts/knowledge/lookup-mems.sh", contains ".orchestrator/proposals/", contains "SC-13") — create

### Key Links

- `scripts/lifecycle/wiki-init.sh` → `scripts/diagnostics/giscus-ids-from-gh.sh` (FR-8 — `--with-giscus` invokes the helper to fetch the four Discussions IDs)
- `scripts/lifecycle/wiki-init.sh` → `scripts/diagnostics/wiki-giscus-config-check.sh` (FR-8 — post-step verifier after partial sed-substitution)
- `scripts/lifecycle/wiki-init.sh` → `wiki/overrides/partials/comments.html` (FR-7 — `--with-giscus` sed-substitutes the four placeholder tokens against the bundle-staged copy at `<PROJECT_DIR>/wiki/overrides/partials/comments.html`)
- `scripts/lifecycle/wiki-init.sh` → `scripts/wiki/wiki-deploy.sh` (FR-9 — `--deploy` invokes the deploy wrapper as step 2 of the four-step sequence)
- `scripts/lifecycle/wiki-init.sh` → `.orchestrator/execution-log.jsonl` (MIT-008 — appends `wiki-deploy-mutation` audit-trail record before live URL prints)
- `scripts/wiki/wiki-deploy.sh` → `wiki/mkdocs.yml` (FR-10 — parses `repo_url:` for the cwd-vs-remote sanity gate)
- `scripts/wiki/wiki-generate-nav.sh` → `wiki/mkdocs.yml` (FR-14 — generator writes the `# >>> auto-nav` / `# >>> custom-nav` region pair into the orchestrator's mkdocs.yml)
- `references/installation.md` → `commands/wiki-init.md` (FR-13 — installation.md cites wiki-init's flag chain as the canonical prior art)
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` → `scripts/lifecycle/wiki-init.sh` (SC-4 invokes wiki-init with `--with-giscus`)
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` → `wiki/overrides/partials/comments.html` (SC-4 reads the partial to assert the four IDs are substituted)
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` → `tests/m032-acceptance/throwaway-fixture-protocol.md` (SC-5 implements the protocol)
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` → `scripts/lifecycle/wiki-init.sh` (SC-5 invokes the full `--with-wiki --with-giscus --deploy` flag chain)
- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` → `scripts/wiki/wiki-generate-nav.sh` (SC-6 invokes the generator against fixture mkdocs.yml states)
- `tools/verify/m032-p03-phase-suite.sh` → `tools/verify/m032-p03-giscus-templating.sh` (suite invokes the FR-7 gate first)
- `tools/verify/m032-p03-phase-suite.sh` → `tools/verify/m032-p03-acceptance-shape-sc6.sh` (suite invokes the SC-6 acceptance shape gate last)

## Tasks

### T01: FR-7 Giscus partial templating + FR-8 `--with-giscus` scope on `wiki-init.sh` + SC-4 acceptance script

See `tasks/T01-with-giscus-scope-PLAN.md`.

T01 lands the first composable scope on top of P02's default-scope `wiki-init.sh` foundation. It (a) amends `wiki/overrides/partials/comments.html` to interleave the four `{{giscus_repo}}` / `{{giscus_repo_id}}` / `{{giscus_category}}` / `{{giscus_category_id}}` placeholder tokens with the existing `{{ config.extra.giscus.* }}` Jinja interpolations such that the bundle-staged copy carries the four placeholders verbatim while the orchestrator-local copy retains the live `!ENV`-based Jinja path; (b) amends `scripts/lifecycle/wiki-init.sh` to recognize the `--with-giscus --repo <owner>/<repo> --category <name>` scope, invoke `scripts/diagnostics/giscus-ids-from-gh.sh` (with `M032_GISCUS_IDS_FROM_GH_STUB=1` test-only stub-mode envelope), parse the four `export GISCUS_*` lines from its stdout, sed-substitute the four placeholder tokens in the staged partial, and invoke `scripts/diagnostics/wiki-giscus-config-check.sh` as the post-step verifier; (c) implements the failure-propagation contract — `giscus-ids-from-gh.sh` non-zero exit propagates as `integration-giscus-config-failed: <reason>` with the partial left in placeholder state; `wiki-giscus-config-check.sh` non-zero exit propagates as `integration-giscus-config-check-failed`; (d) authors `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (SC-4) exercising the happy-path stub branch, the failure-injection branch, the re-run idempotency branch, and the overwrite branch. T01 ships `m032-p03-giscus-templating.sh`, `m032-p03-with-giscus-scope.sh`, and `m032-p03-acceptance-shape-sc4.sh` verifiers.

### T02: FR-9 + MIT-007 + MIT-008 `--deploy` scope on `wiki-init.sh` + FR-10 cwd sanity gate on `wiki-deploy.sh`

See `tasks/T02-deploy-scope-PLAN.md`.

T02 lands the second composable scope — the highest-blast-radius surface in M032 per US-4's P2 priority and the M013/M014 counter-pattern lesson. It (a) amends `scripts/wiki/wiki-deploy.sh` to add the FR-10 cwd-vs-`repo_url:` sanity gate as a hard precondition firing BEFORE the existing P02-baseline gates (giscus-config, mkdocs build, link-check, giscus-smoke); (b) amends `scripts/lifecycle/wiki-init.sh` to recognize the `--deploy` scope and implement the FR-9 + MIT-007 + MIT-008 four-step ordered sequence (`gh api PATCH /repos/.../discussions=true` → `wiki-deploy.sh` → MIT-007 read-before-write Pages guard via `gh api GET /repos/.../pages` with explicit fail-closed-on-incompatible-source diagnostic and `--force-pages-reconfigure` escape hatch → `gh api PUT /repos/.../pages` for compatible-or-absent state → MIT-008 audit-trail append → live URL print); (c) implements the audit-trail invariant — single NDJSON record appended to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` BEFORE the live URL prints, with `mutations` array reflecting the actual subset of steps that fired (Discussions-already-on omits the discussions entry, etc.); (d) implements failure-mode audit-trail — partial-success failures append a `result: "failure"` record with the failed-step name and stderr-tail before exiting non-zero; (e) honors `M032_DEPLOY_PROPAGATION_TIMEOUT` (default 90s) used by SC-5's curl retry loop; (f) honors `M032_DEPLOY_GH_API_STUB=1` test-only env-var bypassing the four `gh api` calls with deterministic stub responses for unit-level coverage of the MIT-007 branches without live-network dependency. T02 ships `m032-p03-deploy-scope.sh` and `m032-p03-wiki-deploy-cwd-gate.sh` verifiers.

### T03: FR-14 + MIT-005 custom-nav region split on `wiki-generate-nav.sh` + SC-6 acceptance script

See `tasks/T03-custom-nav-region-PLAN.md`.

T03 lands US-5 / Finding I — the operator-additions-survive-regenerate surface that defeats the silent data loss observed in the 2026-04-28 PBJ pilot. It (a) amends `scripts/wiki/wiki-generate-nav.sh` to split the existing `# >>> M012-P01 nav` / `# <<< M012-P01 nav end` marker pair into two regions: `# >>> auto-nav` / `# <<< auto-nav end` (regenerated wholly by the generator on every invocation) and `# >>> custom-nav` / `# <<< custom-nav end` (preserved verbatim across regenerates); (b) implements the empty-legacy migration branch (US-5 AS-2) — first regenerate against `mkdocs.yml` carrying the legacy markers with empty content renames the markers in-place to the new shape and appends an empty `custom-nav` block; (c) implements the MIT-005 non-empty-legacy migration branch — first regenerate against legacy markers with non-empty content moves the non-empty content verbatim into the new `custom-nav` region (NOT discarded), regenerates the auto-nav region, AND emits a stdout diagnostic `Migrated <N> custom nav entries from legacy markers to custom-nav region` (the `<N>` count is load-bearing — silent migration without operator visibility is the failure mode MIT-005 was written to prevent); (d) implements US-5 AS-3 self-healing — operator-deleted `custom-nav` markers are re-created at the standard insertion point (immediately after `# <<< auto-nav end`) on next regenerate; (e) closes the self-application loop by running `bash scripts/wiki/wiki-generate-nav.sh --root .` against the orchestrator's own `wiki/mkdocs.yml` so the existing legacy `# >>> M012-P01 nav` markers are migrated to the new shape (`<N>` for the orchestrator repo is 0 — empty-legacy branch — no orchestrator-side custom entries today); (f) authors `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (SC-6) exercising the four FR-14 branches against temp-copy mkdocs.yml fixtures. T03 ships `m032-p03-custom-nav-region.sh` and `m032-p03-acceptance-shape-sc6.sh` verifiers.

### T04: FR-13 progressive-opt-in flag-pattern doc + AD-7 throwaway-fixture-protocol + SC-5 live-deploy acceptance script

See `tasks/T04-throwaway-fixture-and-sc5-PLAN.md`.

T04 lands the M032/M013-M014 counter-pattern surface — the live-throwaway-GH-repo discipline CON-5 mandates and the FR-13 documentation that establishes `--with-<feature>` as the project-wide progressive-opt-in convention. It (a) amends `references/installation.md` to add the new `## --with-<feature> Progressive Opt-In Flag Pattern` section per FR-13 documenting the convention precedent (default-off, independently composable, opt-in is operator decision per Constitution I) and naming `--with-wiki`, `--with-giscus`, `--deploy` as the canonical M032 prior art; (b) authors `tests/m032-acceptance/throwaway-fixture-protocol.md` documenting the `gh repo create <ts>-m032-fixture --private` + `gh repo delete <ts>-m032-fixture --yes` teardown contract per AD-7 / CON-5 — timestamp-prefix naming, four no-orphan-state invariants, recovery protocol on partial-failure teardown, trap-EXIT pattern; (c) authors `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (SC-5) implementing the protocol — `gh auth status` precondition with SKIP_REASON / exit 77 branch (POSIX skip-code per MIT-001), timestamped fixture creation via `gh repo create <ts>-m032-fixture --private --add-readme`, full `--with-wiki --with-giscus --deploy` invocation, live-URL curl retry loop bounded by `M032_DEPLOY_PROPAGATION_TIMEOUT`, served-HTML `data-repo` attribute assertion, MIT-008 audit-trail record assertion, trap-EXIT teardown via `gh repo delete --yes`, post-teardown no-orphan-state verification. T04 ships `m032-p03-with-feature-pattern-doc.sh`, `m032-p03-throwaway-protocol-shape.sh`, and `m032-p03-acceptance-shape-sc5.sh` verifiers.

### T05: P03 phase-suite aggregator + scope-guard

See `tasks/T05-phase-suite-and-scope-guard-PLAN.md`.

T05 lands the verification-aggregation surface that ties P03 closed and the SC-13-bound scope-guard for the phase. It (a) authors `tools/verify/m032-p03-phase-suite.sh` chaining all ten P03 sub-gates in dependency order (`m032-p03-giscus-templating.sh` → `m032-p03-with-giscus-scope.sh` → `m032-p03-deploy-scope.sh` → `m032-p03-wiki-deploy-cwd-gate.sh` → `m032-p03-custom-nav-region.sh` → `m032-p03-with-feature-pattern-doc.sh` → `m032-p03-throwaway-protocol-shape.sh` → `m032-p03-acceptance-shape-sc4.sh` → `m032-p03-acceptance-shape-sc5.sh` → `m032-p03-acceptance-shape-sc6.sh`), single-script-file shape per AD-19, exits 0 iff every sub-gate passes, emits the `SUMMARY: m032-p03-phase-suite.sh pass=N fail=M` summary line; (b) authors `tools/verify/m032-p03-scope-guard.sh` asserting P03's diff is confined to the declared "Files Likely Touched" list — it greps `git diff --name-only` output (or accepts an explicit baseline-ref via the M032 P01/P02 baseline-ref convention at `tools/verify/fixtures/m032-p03-baseline-ref.txt`) against an allowlist of P03-owned paths and a denylist of P00/P01/P02-owned paths (`packaging/install/install-{claude-code,codex,cursor}.sh`, `packaging/bundle/manifest.yml`, `commands/init.md`, `scripts/lifecycle/init-project.sh`, `wiki/glossary.md`, `scripts/wiki/wiki-scan-sources.sh`, `scripts/knowledge/lookup-mems.sh`, `tests/paired-m032-m033/seam-{A,B,C}.sh`, `.orchestrator/proposals/**`); (c) captures `tools/verify/fixtures/m032-p03-baseline-ref.txt` per the P01/P02 baseline-ref convention. T05 modifies zero T01–T04 deliverables — it consumes them.

## Task Dependencies

```
T01 → T05
T02 → T05
T03 → T05
T04 → T05
```

Rationale: T01 (`--with-giscus` scope), T02 (`--deploy` scope), T03 (`custom-nav` region), and T04 (FR-13 doc + throwaway protocol + SC-5) are independent — none of them reads files created by another, and each owns its own verifier set. T01 and T02 both modify `scripts/lifecycle/wiki-init.sh` but at non-overlapping sections (T01 adds the `--with-giscus` flag handling; T02 adds the `--deploy` flag handling); they can run in parallel with a merge conflict resolved by section ordering. T03 modifies a different file (`scripts/wiki/wiki-generate-nav.sh`) entirely. T04 reads `wiki-init.sh`'s `--with-wiki --with-giscus --deploy` flag chain (T01 + T02 surface) only at SC-5 acceptance-script execution time, not at SC-5 authoring time — the script can be authored against the documented flag-chain contract without reading T01/T02's implementation. T05 must run after T01–T04 land because the phase-suite aggregator references all ten verifier paths and the scope-guard's allowlist must reflect the final touched-files set.

## Files Likely Touched

- `wiki/overrides/partials/comments.html` (modify — add the four `{{giscus_*}}` placeholder tokens to the bundle-staged template surface)
- `scripts/lifecycle/wiki-init.sh` (modify — add `--with-giscus` and `--deploy` scope handlers + audit-trail emission)
- `scripts/wiki/wiki-deploy.sh` (modify — add FR-10 cwd-vs-`repo_url:` sanity gate)
- `scripts/wiki/wiki-generate-nav.sh` (modify — split nav block into `auto-nav` / `custom-nav` regions with MIT-005 migration branch)
- `wiki/mkdocs.yml` (modify — self-application: run the migrated nav generator against the orchestrator repo so legacy `# >>> M012-P01 nav` markers migrate to the new region shape)
- `references/installation.md` (modify — add `## --with-<feature> Progressive Opt-In Flag Pattern` section per FR-13)
- `tests/m032-acceptance/throwaway-fixture-protocol.md` (create)
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (create)
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` (create)
- `tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh` (create)
- `tools/verify/m032-p03-giscus-templating.sh` (create)
- `tools/verify/m032-p03-with-giscus-scope.sh` (create)
- `tools/verify/m032-p03-deploy-scope.sh` (create)
- `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` (create)
- `tools/verify/m032-p03-custom-nav-region.sh` (create)
- `tools/verify/m032-p03-with-feature-pattern-doc.sh` (create)
- `tools/verify/m032-p03-throwaway-protocol-shape.sh` (create)
- `tools/verify/m032-p03-acceptance-shape-sc4.sh` (create)
- `tools/verify/m032-p03-acceptance-shape-sc5.sh` (create)
- `tools/verify/m032-p03-acceptance-shape-sc6.sh` (create)
- `tools/verify/m032-p03-phase-suite.sh` (create)
- `tools/verify/m032-p03-scope-guard.sh` (create)
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` (create — captured by T05 per the P01/P02 baseline-ref convention)
